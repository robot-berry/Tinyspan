"""Refresh the TinySPAN X2 training status artifact from live outputs.

This script is read-only with respect to training: it only reads metrics,
process state, and log tails, then rewrites the Tinyspan status JSON/Markdown.
It does not start training, Vivado, JTAG, or board flows.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_STATUS = Path(
    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/"
    "x2_training_start_20260624/x2_training_status.json"
)
DEFAULT_OUTPUT = Path("runs/tinyspan_distill/video_x2_c32_b4_reds_temporal")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def read_latest_metric(metrics: Path) -> dict[str, Any]:
    if not metrics.exists():
        return {}
    with metrics.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        return {}
    row = rows[-1]
    parsed: dict[str, Any] = {}
    for key, value in row.items():
        if value is None:
            parsed[key] = value
            continue
        try:
            parsed[key] = int(value)
            continue
        except ValueError:
            pass
        try:
            parsed[key] = float(value)
            continue
        except ValueError:
            parsed[key] = value
    return parsed


def timespan_text(seconds: float) -> str:
    seconds = max(0, int(seconds))
    days, rem = divmod(seconds, 24 * 3600)
    hours, rem = divmod(rem, 3600)
    minutes, sec = divmod(rem, 60)
    return f"{days:02d}.{hours:02d}:{minutes:02d}:{sec:02d}"


def find_training_processes(output_leaf: str) -> dict[str, Any]:
    ps = rf"""
$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Process |
  Where-Object {{
    $_.ProcessId -ne $PID -and
    $_.CommandLine -match 'distill_tinyspan_video.py|train_tinyspan_video_x2_c32_b4.ps1' -and
    $_.CommandLine -match '{re.escape(output_leaf)}'
  }} |
  Select-Object ProcessId,Name,CommandLine |
  ConvertTo-Json -Depth 3
"""
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError:
        return {"processes": [], "launcher_pid": None, "python_pid": None}
    text = proc.stdout.strip()
    if not text:
        return {"processes": [], "launcher_pid": None, "python_pid": None}
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {"processes": [], "launcher_pid": None, "python_pid": None, "raw": text}
    rows = data if isinstance(data, list) else [data]
    launcher_pid = None
    python_pid = None
    for row in rows:
        name = str(row.get("Name", "")).lower()
        cmd = str(row.get("CommandLine", ""))
        if name == "python.exe" and "distill_tinyspan_video.py" in cmd:
            python_pid = row.get("ProcessId")
        if name == "powershell.exe" and "train_tinyspan_video_x2_c32_b4.ps1" in cmd:
            launcher_pid = row.get("ProcessId")
    return {"processes": rows, "launcher_pid": launcher_pid, "python_pid": python_pid}


def find_postprep_watchers(output_leaf: str) -> dict[str, Any]:
    ps = rf"""
$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Process |
  Where-Object {{
    $_.ProcessId -ne $PID -and
    $_.Name -eq 'powershell.exe' -and
    $_.CommandLine -match 'watch_tinyspan_x2_training_then_postprep\.ps1' -and
    $_.CommandLine -match '{re.escape(output_leaf)}'
  }} |
  Select-Object ProcessId,Name,CommandLine |
  ConvertTo-Json -Depth 3
"""
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
    except OSError:
        return {"processes": [], "watcher_pid": None}
    text = proc.stdout.strip()
    if not text:
        return {"processes": [], "watcher_pid": None}
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return {"processes": [], "watcher_pid": None, "raw": text}
    rows = data if isinstance(data, list) else [data]
    pids = [row.get("ProcessId") for row in rows if row.get("ProcessId")]
    return {"processes": rows, "watcher_pid": pids[0] if pids else None, "watcher_pids": pids}


def tail_text(path: Path, max_lines: int = 20, tail_bytes: int = 64_000) -> list[str]:
    if not path.exists():
        return []
    with path.open("rb") as handle:
        handle.seek(0, 2)
        size = handle.tell()
        handle.seek(max(0, size - tail_bytes))
        text = handle.read().decode("utf-8", errors="replace")
    return text.splitlines()[-max_lines:]


def latest_log(log_root: Path, patterns: list[str], fallback: Path) -> Path:
    candidates: list[Path] = []
    if log_root.is_dir():
        for pattern in patterns:
            candidates.extend(path for path in log_root.glob(pattern) if path.is_file())
    if not candidates:
        return fallback
    return sorted(candidates, key=lambda path: path.stat().st_mtime, reverse=True)[0]


def recent_error_hints(stderr: Path, tail_bytes: int = 256_000) -> list[str]:
    if not stderr.exists():
        return []
    with stderr.open("rb") as handle:
        handle.seek(0, 2)
        size = handle.tell()
        handle.seek(max(0, size - tail_bytes))
        text = handle.read().decode("utf-8", errors="replace")
    hints: list[str] = []
    pattern = re.compile(r"traceback|exception|cuda out of memory|nan|error", re.IGNORECASE)
    for line in text.splitlines():
        if pattern.search(line):
            hints.append(line.strip())
    return hints[-20:]


def file_info(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False}
    return {
        "path": str(path),
        "exists": True,
        "bytes": path.stat().st_size,
        "mtime": datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
        "sha256": sha256_file(path) if path.is_file() and path.stat().st_size <= 32 * 1024 * 1024 else "",
    }


def write_markdown(path: Path, status: dict[str, Any]) -> None:
    formal = status.get("formal_training", {})
    latest = formal.get("latest_observed", {})
    processes = formal.get("observed_processes", {})
    watcher = formal.get("postprep_watcher", {})
    boundary = status.get("acceptance_boundary", {})
    missing = boundary.get("missing", [])
    lines = [
        "# TinySPAN X2 Training Status",
        "",
        f"- status: `{status.get('status', '')}`",
        f"- updated at: `{status.get('updated_at', '')}`",
        f"- output: `{formal.get('output', '')}`",
        f"- launcher PID: `{processes.get('launcher_pid', '')}`",
        f"- python PID: `{processes.get('python_pid', '')}`",
        f"- post-training watcher PID: `{watcher.get('watcher_pid', '')}`",
        f"- post-training watcher latest: `{watcher.get('latest_line', '')}`",
        f"- latest epoch: `{latest.get('epoch', '')}`",
        f"- latest step: `{latest.get('step', '')} / {latest.get('total_steps', '')}`",
        f"- progress: `{latest.get('progress_percent', '')}`%",
        f"- speed: `{latest.get('steps_per_second', '')}` steps/s",
        f"- ETA: `{latest.get('eta', '')}`",
        f"- loss: `{latest.get('loss', '')}`",
        f"- student PSNR: `{latest.get('student_psnr', '')}`",
        f"- recent error hints: `{latest.get('stderr_error_hints', '')}`",
        "",
        "## Boundary",
        "",
        f"- acceptance status: `{boundary.get('status', '')}`",
    ]
    for item in missing:
        lines.append(f"- missing: `{item}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace-root", type=Path, default=Path(".."))
    parser.add_argument("--tinyspan-root", type=Path, default=Path("."))
    parser.add_argument("--status-json", type=Path, default=DEFAULT_STATUS)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--total-steps", type=int, default=198000)
    args = parser.parse_args()

    tinyspan_root = args.tinyspan_root.resolve()
    workspace_root = (tinyspan_root / args.workspace_root).resolve() if not args.workspace_root.is_absolute() else args.workspace_root.resolve()
    status_json = (tinyspan_root / args.status_json).resolve() if not args.status_json.is_absolute() else args.status_json.resolve()
    status_md = status_json.with_suffix(".md")
    output = (workspace_root / args.output).resolve() if not args.output.is_absolute() else args.output.resolve()
    log_root = tinyspan_root / "logs"
    train_stdout = latest_log(
        log_root,
        ["x2_quality_resume_train_*.out.log", "x2_*train*.out.log"],
        output / "train_stdout.log",
    )
    train_stderr = latest_log(
        log_root,
        ["x2_quality_resume_train_*.err.log", "x2_*train*.err.log"],
        output / "train_stderr.log",
    )
    watcher_stdout = latest_log(
        log_root,
        ["x2_quality_resume_watcher_*.out.log", "x2_*watcher*.out.log"],
        status_json.parent / "x2_postprep_watcher_stdout.log",
    )
    watcher_stderr = latest_log(
        log_root,
        ["x2_quality_resume_watcher_*.err.log", "x2_*watcher*.err.log"],
        status_json.parent / "x2_postprep_watcher_stderr.log",
    )

    status = read_json(status_json)
    formal = status.setdefault("formal_training", {})
    formal["status"] = "RUNNING"
    formal["output"] = str(output)
    formal["metrics"] = str(output / "metrics.csv")
    formal["stdout"] = str(train_stdout)
    formal["stderr"] = str(train_stderr)

    latest = read_latest_metric(output / "metrics.csv")
    speed = float(latest.get("steps_per_second") or 0.0)
    step = int(latest.get("step") or 0)
    remaining = max(0, args.total_steps - step)
    eta = timespan_text(remaining / speed) if speed > 0 else ""
    hints = recent_error_hints(train_stderr)
    status["status"] = "training_running"
    status["updated_at"] = datetime.now().isoformat(timespec="seconds")
    process_info = find_training_processes(output.name)
    formal["observed_processes"] = {
        "launcher_pid": process_info.get("launcher_pid"),
        "python_pid": process_info.get("python_pid"),
        "processes": process_info.get("processes", []),
    }
    watcher_info = find_postprep_watchers(output.name)
    watcher_stdout_tail = tail_text(watcher_stdout)
    watcher_stderr_tail = tail_text(watcher_stderr)
    formal["postprep_watcher"] = {
        "status": "RUNNING" if watcher_info.get("watcher_pid") else "NOT_RUNNING",
        "watcher_pid": watcher_info.get("watcher_pid"),
        "watcher_pids": watcher_info.get("watcher_pids", []),
        "processes": watcher_info.get("processes", []),
        "stdout": file_info(watcher_stdout),
        "stderr": file_info(watcher_stderr),
        "latest_line": watcher_stdout_tail[-1] if watcher_stdout_tail else "",
        "stdout_tail": watcher_stdout_tail,
        "stderr_tail": watcher_stderr_tail,
    }
    formal["latest_observed"] = {
        "epoch": int(latest.get("epoch") or 0),
        "step": step,
        "total_steps": args.total_steps,
        "progress_percent": round(100.0 * step / args.total_steps, 4) if args.total_steps > 0 else 0,
        "loss": latest.get("loss"),
        "distill_loss": latest.get("distill_loss"),
        "hr_loss": latest.get("hr_loss"),
        "edge_loss": latest.get("edge_loss"),
        "temporal_loss": latest.get("temporal_loss"),
        "teacher_psnr": latest.get("teacher_psnr"),
        "student_psnr": latest.get("student_psnr"),
        "seconds": latest.get("seconds"),
        "steps_per_second": speed,
        "eta": eta,
        "stderr_error_hints": "none" if not hints else hints,
    }
    formal["latest_artifacts"] = {
        "student_latest": file_info(output / "student_latest.pt"),
        "preview": file_info(output / "video_distill_latest_preview.png"),
        "metrics": file_info(output / "metrics.csv"),
        "stdout": file_info(train_stdout),
        "stderr": file_info(train_stderr),
    }
    status_json.parent.mkdir(parents=True, exist_ok=True)
    status_json.write_text(json.dumps(status, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(status_md, status)
    print(json.dumps({"status_json": str(status_json), "status_md": str(status_md), "latest_observed": formal["latest_observed"]}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
