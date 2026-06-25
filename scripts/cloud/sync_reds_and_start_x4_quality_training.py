#!/usr/bin/env python3
"""Sync REDS to a cloud host and optionally start TinySPAN X4 quality training.

The script intentionally reads the SSH password from an environment variable so
credentials are not stored in the repository or command history.
"""

from __future__ import annotations

import argparse
import json
import os
import posixpath
import shlex
import tarfile
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

import paramiko


TRAIN_RUN = "runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625"
DEFAULT_REMOTE_REPO = "/root/autodl-tmp/Tinyspan"
DEFAULT_REMOTE_DATA = "/root/autodl-tmp/data/REDS"


@dataclass
class UploadStats:
    checked: int = 0
    uploaded: int = 0
    skipped: int = 0
    bytes_uploaded: int = 0
    started_at: float = time.time()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=22)
    parser.add_argument("--user", default="root")
    parser.add_argument("--password-env", default="SEETA_PASS")
    parser.add_argument("--connect-retries", type=int, default=5)
    parser.add_argument("--connect-retry-delay", type=float, default=10.0)
    parser.add_argument("--local-reds-root", type=Path, default=Path("G:/REDS"))
    parser.add_argument("--remote-repo", default=DEFAULT_REMOTE_REPO)
    parser.add_argument("--remote-data", default=DEFAULT_REMOTE_DATA)
    parser.add_argument("--sync-mode", choices=("files", "sequence-tar"), default="files")
    parser.add_argument("--local-temp-dir", type=Path, default=None)
    parser.add_argument("--max-train-sequences", type=int, default=0, help="0 means all train_sharp sequences")
    parser.add_argument("--sequence-start", type=int, default=1, help="1-based sequence start after sorting")
    parser.add_argument("--sequence-end", type=int, default=0, help="1-based inclusive sequence end; 0 means all")
    parser.add_argument("--include-val", action="store_true", help="Also sync val_sharp")
    parser.add_argument("--start-training", action="store_true")
    parser.add_argument("--train-max-pairs", type=int, default=24000)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=6)
    parser.add_argument("--num-workers", type=int, default=4)
    parser.add_argument("--output", default=TRAIN_RUN)
    parser.add_argument("--progress-every", type=int, default=100)
    parser.add_argument("--dry-run", action="store_true")
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
            if attempt >= args.connect_retries:
                break
            print(f"connect attempt {attempt} failed: {exc}; retrying...", flush=True)
            time.sleep(args.connect_retry_delay)
    raise RuntimeError(f"Unable to connect after {args.connect_retries} attempts: {last_error}")


def run(client: paramiko.SSHClient, command: str, timeout: int = 300) -> str:
    stdin, stdout, stderr = client.exec_command("bash -lc " + shlex.quote(command), timeout=timeout)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    rc = stdout.channel.recv_exit_status()
    if rc != 0:
        raise RuntimeError(f"remote command failed rc={rc}\nCOMMAND={command}\nSTDOUT={out}\nSTDERR={err}")
    return out


def remote_stat_size(sftp: paramiko.SFTPClient, path: str) -> int | None:
    try:
        return int(sftp.stat(path).st_size)
    except FileNotFoundError:
        return None
    except IOError:
        return None


def ensure_remote_dir(sftp: paramiko.SFTPClient, path: str) -> None:
    parts = [part for part in path.split("/") if part]
    current = ""
    for part in parts:
        current += "/" + part
        try:
            sftp.stat(current)
        except IOError:
            sftp.mkdir(current)


def selected_files(local_root: Path, split: str, max_train_sequences: int) -> list[Path]:
    split_root = local_root / split
    if not split_root.is_dir():
        raise FileNotFoundError(f"Missing local REDS split: {split_root}")

    if split == "train_sharp" and max_train_sequences > 0:
        sequences = sorted(p for p in split_root.iterdir() if p.is_dir())[:max_train_sequences]
        files: list[Path] = []
        for seq in sequences:
            files.extend(sorted(p for p in seq.rglob("*") if p.is_file()))
        return files
    return sorted(p for p in split_root.rglob("*") if p.is_file())


def selected_sequences(local_root: Path, split: str, max_train_sequences: int) -> list[Path]:
    split_root = local_root / split
    if not split_root.is_dir():
        raise FileNotFoundError(f"Missing local REDS split: {split_root}")
    sequences = sorted(p for p in split_root.iterdir() if p.is_dir())
    if split == "train_sharp" and max_train_sequences > 0:
        return sequences[:max_train_sequences]
    return sequences


def apply_sequence_range(sequences: list[Path], start: int, end: int) -> list[Path]:
    if start < 1:
        raise ValueError("--sequence-start must be >= 1")
    if end and end < start:
        raise ValueError("--sequence-end must be 0 or >= --sequence-start")
    begin = start - 1
    finish = end if end else len(sequences)
    return sequences[begin:finish]


def sequence_size_and_count(sequence_dir: Path) -> tuple[int, int]:
    files = [p for p in sequence_dir.rglob("*") if p.is_file()]
    return len(files), sum(p.stat().st_size for p in files)


def remote_tree_size_and_count(client: paramiko.SSHClient, remote_dir: str) -> tuple[int, int]:
    command = f"""
if [ ! -d {shlex.quote(remote_dir)} ]; then
  echo "0 0"
else
  find {shlex.quote(remote_dir)} -type f ! -name '*.part' -printf '%s\\n' |
    awk '{{count += 1; bytes += $1}} END {{printf "%d %d\\n", count, bytes}}'
fi
"""
    out = run(client, command)
    count_text, bytes_text = out.strip().split()
    return int(count_text), int(bytes_text)


def make_sequence_tar(local_reds_root: Path, sequence_dir: Path, temp_dir: Path) -> Path:
    temp_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        prefix=f"{sequence_dir.parent.name}_{sequence_dir.name}_",
        suffix=".tar",
        dir=temp_dir,
        delete=False,
    ) as handle:
        tar_path = Path(handle.name)
    try:
        with tarfile.open(tar_path, "w") as tar:
            for path in sorted(sequence_dir.rglob("*")):
                if path.is_file():
                    tar.add(path, arcname=path.relative_to(local_reds_root).as_posix())
        return tar_path
    except Exception:
        tar_path.unlink(missing_ok=True)
        raise


def upload_split_sequence_tars(
    client: paramiko.SSHClient,
    sftp: paramiko.SFTPClient,
    local_reds_root: Path,
    remote_data: str,
    split: str,
    max_train_sequences: int,
    dry_run: bool,
    progress_every: int,
    local_temp_dir: Path,
    sequence_start: int,
    sequence_end: int,
) -> UploadStats:
    stats = UploadStats(started_at=time.time())
    sequences = selected_sequences(local_reds_root, split, max_train_sequences)
    if split == "train_sharp":
        sequences = apply_sequence_range(sequences, sequence_start, sequence_end)
    totals = [sequence_size_and_count(seq) for seq in sequences]
    total_files = sum(count for count, _bytes in totals)
    total_bytes = sum(_bytes for _count, _bytes in totals)
    print(f"[{split}] sequences={len(sequences)} files={total_files} bytes={total_bytes}", flush=True)

    ensure_remote_dir(sftp, remote_data)
    incoming_dir = posixpath.join(remote_data, ".incoming")
    if not dry_run:
        ensure_remote_dir(sftp, incoming_dir)

    for index, sequence_dir in enumerate(sequences, start=1):
        local_count, local_bytes = totals[index - 1]
        rel = sequence_dir.relative_to(local_reds_root).as_posix()
        remote_sequence_dir = posixpath.join(remote_data, rel)
        remote_count, remote_bytes = remote_tree_size_and_count(client, remote_sequence_dir)
        stats.checked += local_count
        if remote_count == local_count and remote_bytes == local_bytes:
            stats.skipped += local_count
        else:
            stats.uploaded += local_count
            stats.bytes_uploaded += local_bytes
            if not dry_run:
                tar_path = make_sequence_tar(local_reds_root, sequence_dir, local_temp_dir)
                remote_tar = posixpath.join(incoming_dir, f"{split}_{sequence_dir.name}.tar")
                remote_part = remote_tar + ".part"
                try:
                    sftp.put(str(tar_path), remote_part)
                    try:
                        sftp.remove(remote_tar)
                    except IOError:
                        pass
                    sftp.rename(remote_part, remote_tar)
                    run(client, f"tar -xf {shlex.quote(remote_tar)} -C {shlex.quote(remote_data)} && rm -f {shlex.quote(remote_tar)}")
                    remote_count, remote_bytes = remote_tree_size_and_count(client, remote_sequence_dir)
                    if remote_count != local_count or remote_bytes != local_bytes:
                        raise RuntimeError(
                            f"Remote verification failed for {rel}: "
                            f"local=({local_count}, {local_bytes}) remote=({remote_count}, {remote_bytes})"
                        )
                finally:
                    tar_path.unlink(missing_ok=True)

        if index % max(progress_every, 1) == 0 or index == len(sequences):
            elapsed = max(time.time() - stats.started_at, 1.0)
            mbps = stats.bytes_uploaded / elapsed / 1024 / 1024
            print(
                f"[{split}] sequences={index}/{len(sequences)} checked_files={stats.checked}/{total_files} "
                f"uploaded_files={stats.uploaded} skipped_files={stats.skipped} "
                f"uploaded_gb={stats.bytes_uploaded / 1024**3:.2f} rate_mib_s={mbps:.2f}",
                flush=True,
            )
    return stats


def upload_split(
    sftp: paramiko.SFTPClient,
    local_reds_root: Path,
    remote_data: str,
    split: str,
    max_train_sequences: int,
    dry_run: bool,
    progress_every: int,
) -> UploadStats:
    stats = UploadStats(started_at=time.time())
    files = selected_files(local_reds_root, split, max_train_sequences)
    total_bytes = sum(path.stat().st_size for path in files)
    print(f"[{split}] files={len(files)} bytes={total_bytes}", flush=True)

    for local_path in files:
        rel = local_path.relative_to(local_reds_root).as_posix()
        remote_path = posixpath.join(remote_data, rel)
        local_size = local_path.stat().st_size
        stats.checked += 1
        if remote_stat_size(sftp, remote_path) == local_size:
            stats.skipped += 1
        else:
            stats.uploaded += 1
            stats.bytes_uploaded += local_size
            if not dry_run:
                ensure_remote_dir(sftp, posixpath.dirname(remote_path))
                tmp_path = remote_path + ".part"
                sftp.put(str(local_path), tmp_path)
                try:
                    sftp.remove(remote_path)
                except IOError:
                    pass
                sftp.rename(tmp_path, remote_path)

        if stats.checked % progress_every == 0 or stats.checked == len(files):
            elapsed = max(time.time() - stats.started_at, 1.0)
            mbps = stats.bytes_uploaded / elapsed / 1024 / 1024
            print(
                f"[{split}] checked={stats.checked}/{len(files)} "
                f"uploaded={stats.uploaded} skipped={stats.skipped} "
                f"uploaded_gb={stats.bytes_uploaded / 1024**3:.2f} rate_mib_s={mbps:.2f}",
                flush=True,
            )
    return stats


def start_training(client: paramiko.SSHClient, args: argparse.Namespace) -> str:
    command = f"""
set -euo pipefail
cd {shlex.quote(args.remote_repo)}
out={shlex.quote(args.output)}
mkdir -p "$out"
if pgrep -af "[t]rain/distill_tinyspan_video.py.*{shlex.quote(args.output)}" >/dev/null; then
  echo "already_running=1"
  pgrep -af "[t]rain/distill_tinyspan_video.py.*{shlex.quote(args.output)}"
else
  : > "$out/launcher_stdout.log"
  : > "$out/launcher_stderr.log"
  nohup env TRAIN_FRAMES={shlex.quote(posixpath.join(args.remote_data, "train_sharp"))} \
    MAX_PAIRS={args.train_max_pairs} EPOCHS={args.epochs} BATCH_SIZE={args.batch_size} \
    NUM_WORKERS={args.num_workers} OUTPUT="$out" \
    bash scripts/start_tinyspan_c32b4_x4_quality_training.sh \
    > "$out/launcher_stdout.log" 2> "$out/launcher_stderr.log" < /dev/null &
  echo $! > "$out/launcher.pid"
  echo "started_launcher_pid=$!"
fi
"""
    return run(client, command)


def main() -> int:
    args = parse_args()
    local_reds_root = args.local_reds_root.resolve()
    local_temp_dir = (args.local_temp_dir or (local_reds_root.parent / ".tinyspan_cloud_sync_tmp")).resolve()
    if not local_reds_root.is_dir():
        raise SystemExit(f"Local REDS root not found: {local_reds_root}")

    client = connect(args)
    try:
        print(run(client, f"mkdir -p {shlex.quote(args.remote_data)} && df -h {shlex.quote(args.remote_data)} || true"))
        sftp = client.open_sftp()
        try:
            if args.sync_mode == "sequence-tar":
                upload_fn = lambda split, max_sequences: upload_split_sequence_tars(
                    client,
                    sftp,
                    local_reds_root,
                    args.remote_data,
                    split,
                    max_sequences,
                    args.dry_run,
                    args.progress_every,
                    local_temp_dir,
                    args.sequence_start,
                    args.sequence_end,
                )
            else:
                upload_fn = lambda split, max_sequences: upload_split(
                    sftp,
                    local_reds_root,
                    args.remote_data,
                    split,
                    max_sequences,
                    args.dry_run,
                    args.progress_every,
                )
            summary = {"train_sharp": upload_fn("train_sharp", args.max_train_sequences).__dict__}
            if args.include_val:
                summary["val_sharp"] = upload_fn("val_sharp", 0).__dict__
        finally:
            sftp.close()

        print(json.dumps(summary, indent=2), flush=True)
        if args.start_training and not args.dry_run:
            print(start_training(client, args), flush=True)
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())
