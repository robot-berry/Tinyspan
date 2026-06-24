"""Package TinySPAN Gate H tiled-reference board-run evidence.

This script is intentionally file-only: it does not start Vivado, JTAG, board,
or training work. It copies the final Gate H summaries/images/logs into the
Tinyspan artifact tree and writes a manifest with SHA256 hashes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_ARTIFACT_DIR = Path(
    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/"
    "gate_h_board_x4_320x180_f150_tiledref_20260624"
)
DEFAULT_RUN_DIR = Path(
    "board_runs/tinyspan_w8a8_base_equiv_jtag/"
    "gate_h_x4_320x180_f150_20260624_tiledref"
)
DEFAULT_WAIT_LOG_DIR = Path(
    "board_runs/tinyspan_w8a8_base_equiv_jtag/"
    "gate_h_x4_320x180_f150_20260624_tiledref_waitrun"
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def rel(path: Path, root: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def copy_evidence(
    source: Path,
    dest_dir: Path,
    *,
    required: bool,
    copied: list[dict[str, Any]],
    missing: list[str],
) -> None:
    if not source.exists():
        if required:
            missing.append(str(source))
        return
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / source.name
    shutil.copy2(source, dest)
    copied.append(
        {
            "source": str(source),
            "artifact": str(dest),
            "bytes": dest.stat().st_size,
            "sha256": sha256_file(dest),
        }
    )


def write_markdown(path: Path, manifest: dict[str, Any]) -> None:
    acceptance = manifest.get("acceptance_summary") or {}
    lines = [
        "# TinySPAN Gate H Board Evidence Package",
        "",
        f"- status: `{'PASS' if manifest['package_pass'] else 'INCOMPLETE'}`",
        f"- generated at: `{manifest['generated_at']}`",
        f"- source run dir: `{manifest['source_run_dir']}`",
        f"- artifact dir: `{manifest['artifact_dir']}`",
        f"- board acceptance pass: `{acceptance.get('pass', '')}`",
        f"- board-vs-fixed compare pass: `{acceptance.get('compare_pass', '')}`",
        f"- fps pass: `{acceptance.get('fps_pass', '')}`",
        f"- measured fps: `{acceptance.get('measured_fps', '')}`",
        f"- mismatch bytes: `{acceptance.get('mismatch_bytes', '')} / {acceptance.get('total_bytes', '')}`",
        f"- max channel diff: `{acceptance.get('max_channel_diff', '')}`",
        "",
        "## Copied Evidence",
        "",
    ]
    for item in manifest["copied"]:
        lines.append(f"- `{Path(item['artifact']).name}`: `{item['sha256']}` ({item['bytes']} bytes)")
    if manifest["raw_hashes"]:
        lines.extend(["", "## Raw Frame Hashes", ""])
        for item in manifest["raw_hashes"]:
            lines.append(f"- `{item['path']}`: `{item['sha256']}` ({item['bytes']} bytes)")
    if manifest["missing_required"]:
        lines.extend(["", "## Missing Required Evidence", ""])
        for item in manifest["missing_required"]:
            lines.append(f"- `{item}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace-root", type=Path, default=Path(".."))
    parser.add_argument("--tinyspan-root", type=Path, default=Path("."))
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--wait-log-dir", type=Path, default=DEFAULT_WAIT_LOG_DIR)
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--allow-incomplete", action="store_true")
    parser.add_argument("--include-raw", action="store_true")
    args = parser.parse_args()

    tinyspan_root = args.tinyspan_root.resolve()
    workspace_root = (tinyspan_root / args.workspace_root).resolve() if not args.workspace_root.is_absolute() else args.workspace_root.resolve()
    run_dir = (workspace_root / args.run_dir).resolve() if not args.run_dir.is_absolute() else args.run_dir.resolve()
    wait_log_dir = (workspace_root / args.wait_log_dir).resolve() if not args.wait_log_dir.is_absolute() else args.wait_log_dir.resolve()
    artifact_dir = (tinyspan_root / args.artifact_dir).resolve() if not args.artifact_dir.is_absolute() else args.artifact_dir.resolve()

    copied: list[dict[str, Any]] = []
    missing: list[str] = []
    raw_hashes: list[dict[str, Any]] = []

    acceptance_dir = run_dir / "acceptance_tiled_fixed"
    required_files = [
        run_dir / "implementation_resources.json",
        run_dir / "board_output_x4_320x180_tinyspan_w8a8_base_equiv.png",
        acceptance_dir / "tinyspan_720p30_board_acceptance_summary.json",
        acceptance_dir / "tinyspan_720p30_board_acceptance_summary.md",
        acceptance_dir / "tinyspan_board_software_summary.json",
        acceptance_dir / "tinyspan_board_software_summary.md",
        acceptance_dir / "tinyspan_board_software_preview.png",
        acceptance_dir / "tinyspan_board_software_diff_heatmap.png",
    ]
    optional_files = [
        wait_log_dir / "waitrun_stdout.log",
        wait_log_dir / "waitrun_stderr.log",
        wait_log_dir / "vivado_idle_wait.log",
        wait_log_dir / "jtag_smoke_wrapper.log",
        wait_log_dir / "acceptance_tiled_fixed_wrapper.log",
        run_dir / "jtag_transfer.log",
        run_dir / "jtag_perf_only.log",
        run_dir / "vivado_idle_precheck.log",
        run_dir / "vivado_cleanup.log",
    ]

    for source in required_files:
        copy_evidence(source, artifact_dir, required=True, copied=copied, missing=missing)
    for source in optional_files:
        copy_evidence(source, artifact_dir / "logs", required=False, copied=copied, missing=missing)

    raw_files = [
        run_dir / "input_x4_320x180_tinyspan_w8a8_base_equiv.rgb",
        run_dir / "board_output_x4_320x180_tinyspan_w8a8_base_equiv.rgb",
    ]
    for source in raw_files:
        if source.exists():
            raw_hashes.append(
                {
                    "path": str(source),
                    "bytes": source.stat().st_size,
                    "sha256": sha256_file(source),
                    "copied": bool(args.include_raw),
                }
            )
            if args.include_raw:
                copy_evidence(source, artifact_dir / "raw", required=False, copied=copied, missing=missing)
        elif not args.allow_incomplete:
            missing.append(str(source))

    acceptance_summary_path = acceptance_dir / "tinyspan_720p30_board_acceptance_summary.json"
    acceptance_summary = read_json(acceptance_summary_path)
    package_pass = (
        not missing
        and acceptance_summary is not None
        and bool(acceptance_summary.get("pass"))
        and bool(acceptance_summary.get("compare_pass"))
        and bool(acceptance_summary.get("fps_pass"))
        and int(acceptance_summary.get("mismatch_bytes", -1)) == 0
        and int(acceptance_summary.get("max_channel_diff", -1)) == 0
    )

    manifest = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "package_pass": package_pass,
        "allow_incomplete": bool(args.allow_incomplete),
        "include_raw": bool(args.include_raw),
        "workspace_root": str(workspace_root),
        "tinyspan_root": str(tinyspan_root),
        "source_run_dir": str(run_dir),
        "source_wait_log_dir": str(wait_log_dir),
        "artifact_dir": str(artifact_dir),
        "artifact_dir_relative": rel(artifact_dir, tinyspan_root),
        "acceptance_summary": acceptance_summary,
        "copied": copied,
        "raw_hashes": raw_hashes,
        "missing_required": missing,
    }
    artifact_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = artifact_dir / "manifest.json"
    summary_path = artifact_dir / "run_summary.md"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    write_markdown(summary_path, manifest)

    print(json.dumps({"manifest": str(manifest_path), "summary": str(summary_path), "package_pass": package_pass, "missing": missing}, indent=2))
    if not package_pass and not args.allow_incomplete:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
