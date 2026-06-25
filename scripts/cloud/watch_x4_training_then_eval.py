#!/usr/bin/env python3
"""Watch cloud X4 training, then run the REDS HR software quality gate.

This helper only uses SSH/SFTP and Python evaluation scripts. It does not start
Vivado, JTAG, XSCT, board access, quantization, or RTL export.
"""

from __future__ import annotations

import argparse
import json
import os
import posixpath
import shlex
import stat
import time
from pathlib import Path
from typing import Any

import paramiko


DEFAULT_REMOTE_REPO = "/root/autodl-tmp/Tinyspan"
DEFAULT_REMOTE_DATA = "/root/autodl-tmp/data/REDS"
DEFAULT_RUN_DIR = "runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625"
DEFAULT_QUALITY_DIR = "runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val"
DEFAULT_CANDIDATE_ID = "x4_quality_hr060_edge006_20260625"
DEFAULT_ARTIFACT_ROOT = "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_candidates"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="SEETA_PASS")
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--remote-data", default=DEFAULT_REMOTE_DATA)
    parser.add_argument("--run-dir", default=DEFAULT_RUN_DIR)
    parser.add_argument("--quality-dir", default=DEFAULT_QUALITY_DIR)
    parser.add_argument("--candidate-id", default=DEFAULT_CANDIDATE_ID)
    parser.add_argument("--artifact-dir", default="")
    parser.add_argument("--poll-seconds", type=int, default=600)
    parser.add_argument("--wait-seconds", type=int, default=172800)
    parser.add_argument("--connect-retries", type=int, default=5)
    parser.add_argument("--connect-retry-delay", type=float, default=15.0)
    parser.add_argument("--min-steps", type=int, default=79200)
    parser.add_argument("--max-images", type=int, default=0, help="0 means full REDS val.")
    parser.add_argument("--border", type=int, default=4)
    parser.add_argument("--no-amp", action="store_true")
    parser.add_argument("--force-eval", action="store_true")
    parser.add_argument("--download-artifact-dir", type=Path, default=None)
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
        except Exception as exc:  # noqa: BLE001 - report and retry transport failures.
            last_error = exc
            client.close()
            if attempt < args.connect_retries:
                print(f"CONNECT_RETRY attempt={attempt} error={exc}", flush=True)
                time.sleep(max(args.connect_retry_delay, 1.0))
    raise RuntimeError(f"Unable to connect after {args.connect_retries} attempts: {last_error}")


def run_bash(client: paramiko.SSHClient, command: str, timeout: int = 300) -> tuple[int, str, str]:
    stdin, stdout, stderr = client.exec_command("bash -lc " + shlex.quote(command), timeout=timeout)
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
import json
import os
import pathlib
import shlex
import subprocess

run_dir = {json.dumps(args.run_dir)}
quality_dir = {json.dumps(args.quality_dir)}
candidate_id = {json.dumps(args.candidate_id)}
artifact_root = {json.dumps(DEFAULT_ARTIFACT_ROOT)}
artifact_dir = {json.dumps(args.artifact_dir)} or (artifact_root + "/" + candidate_id)
run = pathlib.Path(run_dir)
quality = pathlib.Path(quality_dir)
artifact = pathlib.Path(artifact_dir)

def read_tail(path, max_chars=4000):
    try:
        text = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    except FileNotFoundError:
        return ""
    return text[-max_chars:]

metrics_path = run / "metrics.csv"
last_metric = ""
step = 0
epoch = 0
if metrics_path.exists():
    lines = [line.strip() for line in metrics_path.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    if lines:
        last_metric = lines[-1]
        cols = last_metric.split(",")
        if len(cols) >= 2:
            try:
                epoch = int(float(cols[0]))
                step = int(float(cols[1]))
            except ValueError:
                pass

pattern = "train/distill_tinyspan_video.py.*" + run_dir
proc = subprocess.run(
    "pgrep -af " + shlex.quote(pattern),
    shell=True,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
)
process_lines = [
    line
    for line in proc.stdout.splitlines()
    if line.strip() and "pgrep -af" not in line and "/bin/sh -c pgrep" not in line
]
stderr_path = run / "launcher_stderr.log"
report = {{
    "run_dir": run_dir,
    "quality_dir": quality_dir,
    "artifact_dir": str(artifact),
    "process_count": len(process_lines),
    "processes": process_lines,
    "metrics_exists": metrics_path.exists(),
    "last_metric": last_metric,
    "epoch": epoch,
    "step": step,
    "student_last_exists": (run / "student_last.pt").exists(),
    "student_latest_exists": (run / "student_latest.pt").exists(),
    "quality_json_exists": (quality / "tinyspan_checkpoint_reds_hr_quality.json").exists(),
    "package_manifest_exists": (artifact / "manifest.json").exists(),
    "stderr_size": stderr_path.stat().st_size if stderr_path.exists() else 0,
    "stderr_tail": read_tail(stderr_path),
}}
print(json.dumps(report, ensure_ascii=False))
PY
"""
    out = require_bash(client, command, timeout=120)
    return json.loads(out.strip().splitlines()[-1])


def run_quality_eval_and_package(client: paramiko.SSHClient, args: argparse.Namespace, artifact_dir: str) -> None:
    amp = "" if args.no_amp else " --amp"
    eval_command = f"""
set -euo pipefail
cd {shlex.quote(args.remote_repo)}
python tools/image_validation/evaluate_tinyspan_checkpoint_reds_hr.py \
  --checkpoint {shlex.quote(posixpath.join(args.run_dir, "student_last.pt"))} \
  --val-frames {shlex.quote(posixpath.join(args.remote_data, "val_sharp"))} \
  --out-dir {shlex.quote(args.quality_dir)} \
  --scale 4 \
  --channels 32 \
  --num-blocks 4 \
  --max-images {args.max_images} \
  --border {args.border}{amp}
python scripts/acceptance/package_x4_quality_candidate.py \
  --candidate-id {shlex.quote(args.candidate_id)} \
  --train-dir {shlex.quote(args.run_dir)} \
  --quality-dir {shlex.quote(args.quality_dir)} \
  --artifact-dir {shlex.quote(artifact_dir)} \
  --allow-incomplete
"""
    print("RUN_REMOTE_X4_EVAL_AND_PACKAGE", flush=True)
    out = require_bash(client, eval_command, timeout=24 * 3600)
    print(out, flush=True)


def sftp_walk(sftp: paramiko.SFTPClient, remote_dir: str):
    for item in sftp.listdir_attr(remote_dir):
        remote_path = posixpath.join(remote_dir, item.filename)
        if stat.S_ISDIR(item.st_mode):
            yield from sftp_walk(sftp, remote_path)
        elif stat.S_ISREG(item.st_mode):
            yield remote_path


def download_artifacts(client: paramiko.SSHClient, remote_repo: str, remote_artifact_dir: str, local_dir: Path) -> None:
    local_dir.mkdir(parents=True, exist_ok=True)
    sftp = client.open_sftp()
    try:
        base = posixpath.join(remote_repo, remote_artifact_dir) if not remote_artifact_dir.startswith("/") else remote_artifact_dir
        for remote_file in sftp_walk(sftp, base):
            rel = posixpath.relpath(remote_file, base)
            local_file = local_dir / rel
            local_file.parent.mkdir(parents=True, exist_ok=True)
            sftp.get(remote_file, str(local_file))
            print(f"DOWNLOADED {remote_file} -> {local_file}", flush=True)
    finally:
        sftp.close()


def main() -> int:
    args = parse_args()
    deadline = time.time() + args.wait_seconds
    client: paramiko.SSHClient | None = None
    try:
        while True:
            if client is None:
                try:
                    client = connect(args)
                except Exception as exc:  # noqa: BLE001 - keep long watcher alive across SSH hiccups.
                    if time.time() >= deadline:
                        raise
                    print(f"CONNECT_WAIT error={exc}", flush=True)
                    time.sleep(min(max(args.poll_seconds, 1), 60))
                    continue

            try:
                state = remote_inspect(client, args)
            except Exception as exc:  # noqa: BLE001 - reconnect on transport/remote shell interruptions.
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
            artifact_dir = state["artifact_dir"]

            if state["package_manifest_exists"] and not args.force_eval:
                print("X4_PACKAGE_ALREADY_EXISTS", flush=True)
                if args.download_artifact_dir is not None:
                    download_artifacts(client, args.remote_repo, artifact_dir, args.download_artifact_dir)
                return 0

            if state["process_count"] > 0:
                if time.time() >= deadline:
                    raise TimeoutError("Timed out waiting for X4 cloud training to finish.")
                time.sleep(max(args.poll_seconds, 1))
                continue

            if not state["student_last_exists"]:
                raise RuntimeError("X4 training process stopped before student_last.pt was written.")

            if args.min_steps > 0 and int(state["step"]) < args.min_steps:
                raise RuntimeError(
                    f"X4 training stopped early at step {state['step']} < required {args.min_steps}."
                )

            if state["stderr_size"]:
                print("WARNING_REMOTE_STDERR_NONEMPTY", flush=True)
                print(state["stderr_tail"], flush=True)

            run_quality_eval_and_package(client, args, artifact_dir)
            final_state = remote_inspect(client, args)
            print(json.dumps(final_state, ensure_ascii=False, indent=2), flush=True)
            if args.download_artifact_dir is not None:
                download_artifacts(client, args.remote_repo, artifact_dir, args.download_artifact_dir)
            return 0
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
