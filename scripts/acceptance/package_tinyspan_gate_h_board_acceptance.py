"""Package TinySPAN Gate H board-acceptance evidence into a manifest.

This script is file-only. It does not start Vivado, JTAG, XSCT, board access,
or training. It is intended to run after run_tinyspan_720p30_board_acceptance.ps1
has produced a passing acceptance summary.
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
    "gate_h_board_x2_640x360_tile64x64"
)


def sha256_file(path: Path | None) -> str:
    if path is None or not path.exists() or not path.is_file():
        return ""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def resolve_path(root: Path, value: str | None) -> Path | None:
    if not value:
        return None
    path = Path(value)
    if path.is_absolute():
        return path
    return (root / path).resolve()


def rel(path: Path | None, root: Path) -> str:
    if path is None:
        return ""
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def copy_optional(source: Path | None, dest_dir: Path, copied: list[dict[str, Any]], *, required: bool, missing: list[str]) -> str:
    if source is None or not source.exists():
        if required:
            missing_path = str(source) if source is not None else ""
            if missing_path not in missing:
                missing.append(missing_path)
        return ""
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / source.name
    if source.resolve() != dest.resolve():
        shutil.copy2(source, dest)
    copied.append(
        {
            "source": str(source),
            "artifact": str(dest),
            "bytes": dest.stat().st_size,
            "sha256": sha256_file(dest),
        }
    )
    return str(dest)


def write_markdown(path: Path, manifest: dict[str, Any]) -> None:
    acceptance = manifest["acceptance_summary"]
    correctness = manifest["correctness"]
    throughput = manifest["throughput"]
    lines = [
        "# TinySPAN Gate H Board Acceptance Package",
        "",
        f"- status: `{'PASS' if manifest['package_pass'] else 'INCOMPLETE'}`",
        f"- generated at: `{manifest['generated_at']}`",
        f"- gate: `{manifest['gate']}`",
        f"- scale: `X{manifest['scale']}`",
        f"- input: `{manifest['input_resolution']['width']}x{manifest['input_resolution']['height']}`",
        f"- output: `{manifest['output_resolution']['width']}x{manifest['output_resolution']['height']}`",
        f"- tile: `{manifest['tile']['width']}x{manifest['tile']['height']}`",
        f"- measured fps: `{throughput['fps']}`",
        f"- mismatch bytes: `{correctness['mismatch_bytes']} / {correctness['total_bytes']}`",
        f"- max channel diff: `{correctness['max_channel_diff']}`",
        f"- checkpoint SHA256: `{manifest['checkpoint_sha256']}`",
        f"- quant plan SHA256: `{manifest['quant_plan_sha256']}`",
        f"- bitstream SHA256: `{manifest['bitstream']['sha256']}`",
        "",
        "## Acceptance Summary",
        "",
        f"- summary JSON: `{manifest['acceptance_summary_path']}`",
        f"- pass: `{acceptance.get('pass')}`",
        f"- compare pass: `{acceptance.get('compare_pass')}`",
        f"- fps pass: `{acceptance.get('fps_pass')}`",
        f"- resources pass: `{acceptance.get('resources_pass')}`",
        "",
        "## Copied Evidence",
        "",
    ]
    for item in manifest["copied"]:
        lines.append(f"- `{Path(item['artifact']).name}`: `{item['sha256']}` ({item['bytes']} bytes)")
    if manifest["missing_required"]:
        lines.extend(["", "## Missing Required Evidence", ""])
        for item in manifest["missing_required"]:
            lines.append(f"- `{item}`")
    lines.extend(["", "## Boundary", ""])
    for item in manifest["boundary"]:
        lines.append(f"- {item}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--acceptance-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--artifact-dir", type=Path, default=Path(""))
    parser.add_argument("--scale", type=int, required=True, choices=(2, 4))
    parser.add_argument("--input-width", type=int, required=True)
    parser.add_argument("--input-height", type=int, required=True)
    parser.add_argument("--output-width", type=int, default=1280)
    parser.add_argument("--output-height", type=int, default=720)
    parser.add_argument("--tile-width", type=int, required=True)
    parser.add_argument("--tile-height", type=int, required=True)
    parser.add_argument("--tile-count", type=int, default=0)
    parser.add_argument("--status", default="")
    parser.add_argument("--route", default="TinySPAN PS/DDR via board PS DDR controller IP")
    parser.add_argument("--source-run-dir", default="")
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()

    repo = args.repo_root.resolve()
    acceptance_dir = resolve_path(repo, str(args.acceptance_dir))
    assert acceptance_dir is not None
    artifact_dir = (
        acceptance_dir
        if str(args.artifact_dir) == ""
        else resolve_path(repo, str(args.artifact_dir))
    )
    assert artifact_dir is not None
    artifact_dir.mkdir(parents=True, exist_ok=True)

    summary_json = acceptance_dir / "tinyspan_720p30_board_acceptance_summary.json"
    summary_md = acceptance_dir / "tinyspan_720p30_board_acceptance_summary.md"
    compare_json = acceptance_dir / "tinyspan_board_software_summary.json"
    compare_md = acceptance_dir / "tinyspan_board_software_summary.md"
    preview = acceptance_dir / "tinyspan_board_software_preview.png"
    diff_heatmap = acceptance_dir / "diff_heatmap.png"

    missing: list[str] = []
    copied: list[dict[str, Any]] = []
    if not summary_json.exists():
        missing.append(str(summary_json))
        acceptance: dict[str, Any] = {}
    else:
        acceptance = read_json(summary_json)

    for source in [summary_json, summary_md, compare_json, compare_md, preview, diff_heatmap]:
        copy_optional(source, artifact_dir, copied, required=source in [summary_json, compare_json, preview, diff_heatmap], missing=missing)

    checkpoint = resolve_path(repo, str(acceptance.get("checkpoint", "")))
    quant_plan = resolve_path(repo, str(acceptance.get("quant_plan", "")))
    bitstream = resolve_path(repo, str(acceptance.get("bitstream", "")))
    board_log = resolve_path(repo, str(acceptance.get("board_log", "")))
    fixed = resolve_path(repo, str(acceptance.get("fixed", "")))
    board = resolve_path(repo, str(acceptance.get("board", "")))
    software = resolve_path(repo, str(acceptance.get("software", "")))

    package_pass = bool(
        not missing
        and acceptance.get("pass")
        and acceptance.get("compare_pass")
        and acceptance.get("fps_pass")
        and acceptance.get("resources_pass", True)
        and int(acceptance.get("mismatch_bytes", -1)) == 0
        and int(acceptance.get("max_channel_diff", -1)) == 0
        and args.output_width == 1280
        and args.output_height == 720
        and float(acceptance.get("measured_fps", 0.0)) >= 30.0
        and bitstream is not None
        and bitstream.exists()
    )

    status = args.status or ("PASS_X2" if args.scale == 2 else "PASS_X4")
    manifest = {
        "artifact_id": artifact_dir.name,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "gate": "H",
        "status": status if package_pass else "INCOMPLETE",
        "package_pass": package_pass,
        "pass": package_pass,
        "route": args.route,
        "no_custom_ddr_controller_or_phy": True,
        "scale": args.scale,
        "input_resolution": {"width": args.input_width, "height": args.input_height},
        "output_resolution": {"width": args.output_width, "height": args.output_height},
        "tile": {
            "width": args.tile_width,
            "height": args.tile_height,
            "count": args.tile_count,
            "padding_policy": f"zero-pad LR edge tiles to fixed {args.tile_width}x{args.tile_height} before TinySPAN core",
            "crop_policy": "crop valid_w*scale by valid_h*scale SR region from each tile",
        },
        "checkpoint": rel(checkpoint, repo),
        "checkpoint_sha256": sha256_file(checkpoint),
        "quant_plan": rel(quant_plan, repo),
        "quant_plan_sha256": sha256_file(quant_plan),
        "bitstream": {
            "path": rel(bitstream, repo),
            "sha256": sha256_file(bitstream),
        },
        "board_log": rel(board_log, repo),
        "board_log_sha256": sha256_file(board_log),
        "acceptance_summary_path": rel(summary_json, repo),
        "acceptance_summary": acceptance,
        "throughput": {
            "status": "PASS" if acceptance.get("fps_pass") else "FAIL",
            "fps": acceptance.get("measured_fps"),
            "minimum_fps": acceptance.get("target_fps", 30),
            "frame_cycles": (acceptance.get("board_resources") or {}).get("perf_frame_cycles"),
            "source_run": args.source_run_dir,
        },
        "correctness": {
            "status": "PASS" if acceptance.get("compare_pass") else "FAIL",
            "fixed_reference_png": rel(fixed, repo),
            "software_png": rel(software, repo),
            "board_output": rel(board, repo),
            "mismatch_bytes": acceptance.get("mismatch_bytes"),
            "total_bytes": acceptance.get("total_bytes"),
            "max_channel_diff": acceptance.get("max_channel_diff"),
            "compare_pass": bool(acceptance.get("compare_pass")),
        },
        "copied": copied,
        "missing_required": missing,
        "boundary": [
            f"This closes X{args.scale} Gate H only when package_pass is true.",
            "The board output must be generated by a real bitstream and compared against the same frozen checkpoint and quant plan.",
            "This packaging step is file-only and does not start Vivado, JTAG, XSCT, board access, or training.",
        ],
    }

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
