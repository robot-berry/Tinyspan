#!/usr/bin/env python3
"""Wait for cloud X2 training, download the final run, then run local post-prep.

This helper deliberately stops before Vivado, JTAG, XSCT, or board access. It
bridges the gap between the cloud training run and the local freeze/quant/RTL
readiness flow used for TinySPAN X2 delivery.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import posixpath
import shlex
import stat
import subprocess
import time
from pathlib import Path
from typing import Any

import paramiko


DEFAULT_REMOTE_REPO = "/root/autodl-tmp/Tinyspan"
DEFAULT_RUN_DIR = "runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625"
DEFAULT_TAG = "x2_quality_after_x4_20260625"
DEFAULT_LOCAL_RUN_DIR = Path("runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="SEETA_PASS")
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--run-dir", default=DEFAULT_RUN_DIR)
    parser.add_argument("--local-run-dir", type=Path, default=DEFAULT_LOCAL_RUN_DIR)
    parser.add_argument("--tag", default=DEFAULT_TAG)
    parser.add_argument("--scale", type=int, default=2)
    parser.add_argument("--min-steps", type=int, default=51480)
    parser.add_argument("--poll-seconds", type=int, default=300)
    parser.add_argument("--wait-seconds", type=int, default=259200)
    parser.add_argument("--connect-retries", type=int, default=5)
    parser.add_argument("--connect-retry-delay", type=float, default=15.0)
    parser.add_argument("--skip-postprep", action="store_true")
    parser.add_argument("--postprep-extra-arg", action="append", default=[])
    return parser.parse_args()


def connect(args: argparse.Namespace) -> paramiko.SSHClient:
    password = os.environ.get(args.password_env)
    if not password:
        raise SystemExit(f"Set ${args.password_env} before running this script.")
    last_error: Exception | None = None
    for attempt in range(1, args.connect_retries + 1):
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            client.connect(
                hostname=args.host,
                port=args.port,
                username=args.user,
                password=password,
                timeout=45,
                banner_timeout=45,
                auth_timeout=45,
                look_for_keys=False,
                allow_agent=False,
            )
            return client
        except Exception as exc:  # noqa: BLE001 - keep watcher alive across SSH hiccups.
            last_error = exc
            client.close()
            if attempt < args.connect_retries:
                print(f"CONNECT_RETRY attempt={attempt} error={exc}", flush=True)
                time.sleep(max(args.connect_retry_delay, 1.0))
    raise RuntimeError(f"Unable to connect after {args.connect_retries} attempts: {last_error}")


def run_bash(client: paramiko.SSHClient, command: str, timeout: int = 300) -> tuple[int, str, str]:
    _stdin, stdout, stderr = client.exec_command("bash -lc " + shlex.quote(command), timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    rc = stdout.channel.recv_exit_status()
    return rc, out, err


def require_bash(client: paramiko.SSHClient, command: str, timeout: int = 300) -> str:
    rc, out, err = run_bash(client, command, timeout=timeout)
    if rc != 0:
        raise RuntimeError(f"remote command failed rc={rc}\nCOMMAND={command}\nSTDOUT={out}\nSTDERR={err}")
    return out


def remote_inspect(client: paramiko.SSHClient, args: argparse.Namespace) -> dict[str, Any]:
    command = f"""
cd {shlex.quote(args.remote_repo)}
python - <<'PY'
import csv
import json
import pathlib
import shlex
import subprocess
import time

run_dir = {json.dumps(args.run_dir)}
run = pathlib.Path(run_dir)
metrics = run / "metrics.csv"
last_metric = {{}}
row_count = 0
if metrics.exists():
    with metrics.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            row_count += 1
            last_metric = row
step = 0
epoch = 0
try:
    step = int(float(last_metric.get("step", "0") or 0))
    epoch = int(float(last_metric.get("epoch", "0") or 0))
except Exception:
    pass
pattern = "train/distill_tinyspan_video.py.*" + run_dir
proc = subprocess.run(
    "pgrep -af " + shlex.quote(pattern),
    shell=True,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
processes = [
    line
    for line in proc.stdout.splitlines()
    if line.strip() and "pgrep -af" not in line and "/bin/sh -c pgrep" not in line
]
student_last = run / "student_last.pt"
student_latest = run / "student_latest.pt"
stderr = run / "launcher_stderr.log"
report = {{
    "remote_now": subprocess.getoutput("date +'%F %T %z'"),
    "run_dir": run_dir,
    "process_count": len(processes),
    "processes": processes,
    "metrics_exists": metrics.exists(),
    "metrics_rows": row_count,
    "last_metric": last_metric,
    "epoch": epoch,
    "step": step,
    "student_last_exists": student_last.exists(),
    "student_latest_exists": student_latest.exists(),
    "student_last_size": student_last.stat().st_size if student_last.exists() else 0,
    "student_latest_size": student_latest.stat().st_size if student_latest.exists() else 0,
    "stderr_size": stderr.stat().st_size if stderr.exists() else 0,
    "disk": subprocess.getoutput("df -h /root/autodl-tmp | tail -1"),
}}
print(json.dumps(report, ensure_ascii=False))
PY
"""
    out = require_bash(client, command, timeout=120)
    return json.loads(out.strip().splitlines()[-1])


def remote_file_exists(sftp: paramiko.SFTPClient, remote_file: str) -> bool:
    try:
        attrs = sftp.stat(remote_file)
    except FileNotFoundError:
        return False
    return stat.S_ISREG(attrs.st_mode)


def download_training_run(client: paramiko.SSHClient, args: argparse.Namespace) -> None:
    local_dir = args.local_run_dir
    local_dir.mkdir(parents=True, exist_ok=True)
    remote_base = posixpath.join(args.remote_repo, args.run_dir)
    wanted = [
        "student_last.pt",
        "student_latest.pt",
        "metrics.csv",
        "args.json",
        "train_command_linux.txt",
        "video_distill_preview.png",
        "video_distill_latest_preview.png",
        "launcher_stdout.log",
        "launcher_stderr.log",
    ]
    sftp = client.open_sftp()
    try:
        for name in wanted:
            remote_file = posixpath.join(remote_base, name)
            if not remote_file_exists(sftp, remote_file):
                print(f"REMOTE_FILE_MISSING {remote_file}", flush=True)
                continue
            local_file = local_dir / name
            local_file.parent.mkdir(parents=True, exist_ok=True)
            sftp.get(remote_file, str(local_file))
            print(f"DOWNLOADED {remote_file} -> {local_file}", flush=True)
    finally:
        sftp.close()


def local_step(local_run_dir: Path) -> int:
    metrics = local_run_dir / "metrics.csv"
    if not metrics.exists():
        return 0
    last: dict[str, str] = {}
    with metrics.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            last = row
    try:
        return int(float(last.get("step", "0") or 0))
    except ValueError:
        return 0


def postprep_outputs_exist(tag: str) -> bool:
    quant = Path(f"runs/tinyspan_quant_plan/{tag}_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json")
    rtl = Path(f"rtl/generated/tinyspan_c32b4_{tag}_x2_w8a8/tinyspan_w8a8_rtl_manifest.json")
    frozen = Path(f"runs/tinyspan_frozen_candidates/{tag}/student_final.pt")
    return quant.exists() and rtl.exists() and frozen.exists()


def run_postprep(args: argparse.Namespace) -> None:
    if postprep_outputs_exist(args.tag):
        print(f"POSTPREP_ALREADY_EXISTS tag={args.tag}", flush=True)
        return
    cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "scripts\\run_tinyspan_c32b4_post_training_prep.ps1",
        "-RunDir",
        str(args.local_run_dir),
        "-Scale",
        str(args.scale),
        "-Tag",
        args.tag,
    ]
    cmd.extend(args.postprep_extra_arg)
    print("RUN_LOCAL_POSTPREP " + " ".join(cmd), flush=True)
    result = subprocess.run(cmd, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"post-training prep failed with exit code {result.returncode}")


def main() -> int:
    args = parse_args()
    deadline = time.time() + args.wait_seconds
    client: paramiko.SSHClient | None = None
    try:
        while True:
            if postprep_outputs_exist(args.tag):
                print(f"POSTPREP_ALREADY_EXISTS tag={args.tag}", flush=True)
                return 0
            if client is None:
                try:
                    client = connect(args)
                except Exception as exc:  # noqa: BLE001
                    if time.time() >= deadline:
                        raise
                    print(f"CONNECT_WAIT error={exc}", flush=True)
                    time.sleep(min(max(args.poll_seconds, 1), 60))
                    continue
            try:
                state = remote_inspect(client, args)
            except Exception as exc:  # noqa: BLE001
                print(f"INSPECT_RECONNECT error={exc}", flush=True)
                try:
                    client.close()
                except Exception:
                    pass
                client = None
                if time.time() >= deadline:
                    raise
                time.sleep(min(max(args.poll_seconds, 1), 60))
                continue
            print(json.dumps(state, ensure_ascii=False, indent=2), flush=True)
            if state["process_count"] > 0:
                if time.time() >= deadline:
                    raise TimeoutError("Timed out waiting for X2 training to finish.")
                time.sleep(max(args.poll_seconds, 1))
                continue
            if not state["student_last_exists"]:
                if not state["metrics_exists"] and time.time() < deadline:
                    print("WAIT_X2_CLOUD_TRAINING_START", flush=True)
                    time.sleep(max(args.poll_seconds, 1))
                    continue
                raise RuntimeError("X2 training stopped before student_last.pt was written.")
            if args.min_steps > 0 and int(state["step"]) < args.min_steps:
                raise RuntimeError(f"X2 training stopped early at step {state['step']} < {args.min_steps}.")
            download_training_run(client, args)
            if local_step(args.local_run_dir) < args.min_steps:
                raise RuntimeError(f"Downloaded metrics do not reach {args.min_steps} steps.")
            if args.skip_postprep:
                print("SKIP_POSTPREP=True", flush=True)
                return 0
            run_postprep(args)
            return 0
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
