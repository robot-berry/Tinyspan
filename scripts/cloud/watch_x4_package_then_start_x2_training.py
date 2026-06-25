#!/usr/bin/env python3
"""Wait for the cloud X4 quality package, then start cloud X2 training.

This helper only uses SSH/SFTP and starts the X2 PyTorch training process on the
remote training server. It does not run local training, Vivado, JTAG, XSCT,
board access, quantization, or RTL export.
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
DEFAULT_X4_ARTIFACT_DIR = (
    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/"
    "x4_quality_candidates/x4_quality_hr060_edge006_20260625"
)
DEFAULT_X2_RUN_DIR = "runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625"
DEFAULT_REMOTE_RESUME = "model/checkpoints/x2_quality_resume_20260625/student_latest.pt"
DEFAULT_LOCAL_RESUME = Path(
    "../runs/tinyspan_distill/video_x2_c32_b4_reds_temporal/student_latest.pt"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="SEETA_PASS")
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--remote-data", default=DEFAULT_REMOTE_DATA)
    parser.add_argument("--x4-artifact-dir", default=DEFAULT_X4_ARTIFACT_DIR)
    parser.add_argument("--x2-run-dir", default=DEFAULT_X2_RUN_DIR)
    parser.add_argument("--remote-resume-checkpoint", default=DEFAULT_REMOTE_RESUME)
    parser.add_argument("--local-resume-checkpoint", type=Path, default=DEFAULT_LOCAL_RESUME)
    parser.add_argument("--no-upload-resume", action="store_true")
    parser.add_argument("--force-upload-resume", action="store_true")
    parser.add_argument("--poll-seconds", type=int, default=600)
    parser.add_argument("--wait-seconds", type=int, default=172800)
    parser.add_argument("--connect-retries", type=int, default=5)
    parser.add_argument("--connect-retry-delay", type=float, default=15.0)
    parser.add_argument("--patch-size", type=int, default=192)
    parser.add_argument("--batch-size", type=int, default=6)
    parser.add_argument("--epochs", type=int, default=13)
    parser.add_argument("--max-pairs", type=int, default=24000)
    parser.add_argument("--save-every-steps", type=int, default=500)
    parser.add_argument("--lr", type=float, default=1e-4)
    parser.add_argument("--distill-weight", type=float, default=1.0)
    parser.add_argument("--hr-weight", type=float, default=0.2)
    parser.add_argument("--edge-weight", type=float, default=0.02)
    parser.add_argument("--temporal-weight", type=float, default=0.2)
    parser.add_argument("--num-workers", type=int, default=4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--no-amp", action="store_true")
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
        except Exception as exc:  # noqa: BLE001 - keep long watcher alive across SSH hiccups.
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
import json
import pathlib
import shlex
import subprocess

x4_artifact = pathlib.Path({json.dumps(args.x4_artifact_dir)})
x2_run = pathlib.Path({json.dumps(args.x2_run_dir)})
resume = pathlib.Path({json.dumps(args.remote_resume_checkpoint)})

def latest_metric(run):
    metrics = run / "metrics.csv"
    if not metrics.exists():
        return {{"exists": False, "last_metric": "", "epoch": 0, "step": 0}}
    lines = [line.strip() for line in metrics.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    last = lines[-1] if lines else ""
    epoch = 0
    step = 0
    if last:
        cols = last.split(",")
        if len(cols) >= 2:
            try:
                epoch = int(float(cols[0]))
                step = int(float(cols[1]))
            except ValueError:
                pass
    return {{"exists": True, "last_metric": last, "epoch": epoch, "step": step}}

pattern = "train/distill_tinyspan_video.py.*" + str(x2_run)
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
report = {{
    "x4_manifest_exists": (x4_artifact / "manifest.json").exists(),
    "x4_artifact_dir": str(x4_artifact),
    "x2_run_dir": str(x2_run),
    "x2_process_count": len(processes),
    "x2_processes": processes,
    "x2_metrics": latest_metric(x2_run),
    "x2_student_last_exists": (x2_run / "student_last.pt").exists(),
    "x2_launcher_pid_exists": (x2_run / "launcher.pid").exists(),
    "remote_resume_exists": resume.exists(),
    "remote_resume": str(resume),
}}
print(json.dumps(report, ensure_ascii=False))
PY
"""
    out = require_bash(client, command, timeout=120)
    return json.loads(out.strip().splitlines()[-1])


def sftp_mkdirs(sftp: paramiko.SFTPClient, remote_dir: str) -> None:
    parts = [part for part in remote_dir.split("/") if part]
    path = "/" if remote_dir.startswith("/") else ""
    for part in parts:
        path = posixpath.join(path, part) if path else part
        try:
            mode = sftp.stat(path).st_mode
            if not stat.S_ISDIR(mode):
                raise RuntimeError(f"Remote path exists but is not a directory: {path}")
        except FileNotFoundError:
            sftp.mkdir(path)


def upload_resume_checkpoint(client: paramiko.SSHClient, args: argparse.Namespace, state: dict[str, Any]) -> None:
    if args.no_upload_resume or state["remote_resume_exists"]:
        return
    local_path = args.local_resume_checkpoint.resolve()
    if not local_path.exists():
        print(f"WARNING_LOCAL_X2_RESUME_MISSING {local_path}", flush=True)
        return

    remote_path = posixpath.join(args.remote_repo, args.remote_resume_checkpoint)
    remote_dir = posixpath.dirname(remote_path)
    print(f"UPLOAD_X2_RESUME {local_path} -> {remote_path}", flush=True)
    sftp = client.open_sftp()
    try:
        sftp_mkdirs(sftp, remote_dir)
        sftp.put(str(local_path), remote_path)
    finally:
        sftp.close()


def maybe_upload_resume(client: paramiko.SSHClient, args: argparse.Namespace, state: dict[str, Any]) -> None:
    if args.no_upload_resume:
        return
    if state["remote_resume_exists"] and not args.force_upload_resume:
        return
    if state["remote_resume_exists"] and args.force_upload_resume:
        require_bash(
            client,
            f"cd {shlex.quote(args.remote_repo)} && rm -f {shlex.quote(args.remote_resume_checkpoint)}",
            timeout=120,
        )
        state["remote_resume_exists"] = False
    upload_resume_checkpoint(client, args, state)


def start_x2_training(client: paramiko.SSHClient, args: argparse.Namespace) -> None:
    amp_flag = "" if args.no_amp else " --amp"
    resume_flag = ""
    resume_check = (
        f"if [ -f {shlex.quote(args.remote_resume_checkpoint)} ]; then "
        f"RESUME_FLAG=\"--resume-student {shlex.quote(args.remote_resume_checkpoint)}\"; "
        "else RESUME_FLAG=\"\"; fi"
    )
    command = f"""
set -euo pipefail
cd {shlex.quote(args.remote_repo)}
RUN_DIR={shlex.quote(args.x2_run_dir)}
TRAIN_FRAMES={shlex.quote(posixpath.join(args.remote_data, "train_sharp"))}
mkdir -p "$RUN_DIR"
if pgrep -af "train/distill_tinyspan_video.py.*$RUN_DIR" | grep -v "pgrep -af" >/dev/null; then
  echo "X2_TRAINING_ALREADY_RUNNING"
  exit 0
fi
if [ -f "$RUN_DIR/student_last.pt" ]; then
  echo "X2_RUN_ALREADY_HAS_STUDENT_LAST"
  exit 0
fi
{resume_check}
nohup python -u train/distill_tinyspan_video.py \
  --train-frames "$TRAIN_FRAMES" \
  --scale 2 \
  --channels 32 \
  --num-blocks 4 \
  --patch-size {args.patch_size} \
  --batch-size {args.batch_size} \
  --epochs {args.epochs} \
  --max-steps 0 \
  --max-pairs {args.max_pairs} \
  --output "$RUN_DIR" \
  --save-every-steps {args.save_every_steps} \
  --lr {args.lr:.8g} \
  --distill-weight {args.distill_weight:.8g} \
  --hr-weight {args.hr_weight:.8g} \
  --edge-weight {args.edge_weight:.8g} \
  --temporal-weight {args.temporal_weight:.8g} \
  --num-workers {args.num_workers} \
  --seed {args.seed} \
  $RESUME_FLAG{amp_flag} \
  > "$RUN_DIR/launcher_stdout.log" \
  2> "$RUN_DIR/launcher_stderr.log" \
  < /dev/null &
PID=$!
echo "$PID" > "$RUN_DIR/launcher.pid"
echo "STARTED_X2_TRAINING pid=$PID run_dir=$RUN_DIR resume=$RESUME_FLAG"
"""
    out = require_bash(client, command, timeout=120)
    print(out, flush=True)


def main() -> int:
    args = parse_args()
    deadline = time.time() + args.wait_seconds
    client: paramiko.SSHClient | None = None
    try:
        while True:
            if client is None:
                try:
                    client = connect(args)
                except Exception as exc:  # noqa: BLE001 - keep watcher alive across SSH hiccups.
                    if time.time() >= deadline:
                        raise
                    print(f"CONNECT_WAIT error={exc}", flush=True)
                    time.sleep(min(max(args.poll_seconds, 1), 60))
                    continue

            try:
                state = remote_inspect(client, args)
            except Exception as exc:  # noqa: BLE001 - reconnect on transient failures.
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
            if state["x2_process_count"] > 0:
                print("X2_ALREADY_RUNNING_ON_CLOUD", flush=True)
                return 0
            if state["x2_student_last_exists"]:
                print("X2_ALREADY_HAS_STUDENT_LAST", flush=True)
                return 0
            if state["x4_manifest_exists"]:
                maybe_upload_resume(client, args, state)
                start_x2_training(client, args)
                final_state = remote_inspect(client, args)
                print(json.dumps(final_state, ensure_ascii=False, indent=2), flush=True)
                return 0
            if time.time() >= deadline:
                raise TimeoutError("Timed out waiting for X4 cloud package manifest.")
            time.sleep(max(args.poll_seconds, 1))
    finally:
        if client is not None:
            client.close()


if __name__ == "__main__":
    raise SystemExit(main())
