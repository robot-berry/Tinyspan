"""Package an X4 quality-training candidate for review.

This script is file-only. It copies a cloud/local X4 training checkpoint,
training logs, and REDS HR quality metrics into an auditable candidate package.
It does not run training, quantization, RTL export, Vivado, JTAG, XSCT, or board
access.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_ARTIFACT_ROOT = Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_candidates")
DEFAULT_TRAIN_DIR = Path("runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625")
DEFAULT_QUALITY_DIR = Path("runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val")


def sha256_file(path: Path | None) -> str:
    if path is None or not path.exists() or not path.is_file():
        return ""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def resolve(root: Path, value: str | Path | None) -> Path | None:
    if value is None or str(value) == "":
        return None
    path = Path(value)
    if path.is_absolute():
        return path
    return (root / path).resolve()


def rel(root: Path, path: Path | None) -> str:
    if path is None:
        return ""
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return str(path)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def copy_one(source: Path | None, dest_dir: Path, copied: list[dict[str, Any]], missing: list[str], *, required: bool) -> str:
    if source is None or not source.exists() or not source.is_file():
        if required:
            missing_path = "" if source is None else str(source)
            if missing_path not in missing:
                missing.append(missing_path)
        return ""
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / source.name
    if source.resolve() != dest.resolve():
        shutil.copy2(source, dest)
    item = {
        "source": str(source),
        "artifact": str(dest),
        "bytes": dest.stat().st_size,
        "sha256": sha256_file(dest),
    }
    copied.append(item)
    return str(dest)


def latest_existing(candidates: list[Path]) -> Path | None:
    existing = [path for path in candidates if path.exists() and path.is_file()]
    if not existing:
        return None
    return sorted(existing, key=lambda path: path.stat().st_mtime, reverse=True)[0]


def write_markdown(path: Path, manifest: dict[str, Any]) -> None:
    decision = manifest["decision"]
    quality = manifest["quality_summary"]
    lines = [
        "# TinySPAN X4 Quality Candidate Package",
        "",
        f"- candidate: `{manifest['candidate_id']}`",
        f"- status: `{manifest['status']}`",
        f"- generated at: `{manifest['generated_at']}`",
        f"- checkpoint SHA256: `{manifest['checkpoint_sha256']}`",
        f"- image count: `{quality.get('image_count', '')}`",
        f"- student PSNR mean: `{quality.get('student_psnr_mean_db', '')}`",
        f"- bicubic PSNR mean: `{quality.get('bicubic_psnr_mean_db', '')}`",
        f"- PSNR gain over bicubic: `{decision.get('student_psnr_gain_over_bicubic_db', '')}`",
        f"- meets exploratory gate: `{decision.get('software_quality_gate_pass')}`",
        f"- meets 30dB stretch gate: `{decision.get('student_psnr_mean_ge_30db')}`",
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--candidate-id", default="x4_quality_hr060_edge006_20260625")
    parser.add_argument("--train-dir", type=Path, default=DEFAULT_TRAIN_DIR)
    parser.add_argument("--quality-dir", type=Path, default=DEFAULT_QUALITY_DIR)
    parser.add_argument("--artifact-dir", type=Path, default=Path(""))
    parser.add_argument("--checkpoint", type=Path, default=Path(""))
    parser.add_argument("--min-psnr-db", type=float, default=28.0)
    parser.add_argument("--min-psnr-gain-db", type=float, default=0.0)
    parser.add_argument("--target-psnr-db", type=float, default=30.0)
    parser.add_argument("--allow-incomplete", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo = args.repo_root.resolve()
    train_dir = resolve(repo, args.train_dir)
    quality_dir = resolve(repo, args.quality_dir)
    assert train_dir is not None
    assert quality_dir is not None
    artifact_dir = (
        (repo / DEFAULT_ARTIFACT_ROOT / args.candidate_id).resolve()
        if str(args.artifact_dir) == ""
        else resolve(repo, args.artifact_dir)
    )
    assert artifact_dir is not None
    artifact_dir.mkdir(parents=True, exist_ok=True)

    checkpoint = resolve(repo, args.checkpoint) if str(args.checkpoint) else latest_existing(
        [train_dir / "student_last.pt", train_dir / "student_latest.pt"]
    )
    quality_json = quality_dir / "tinyspan_checkpoint_reds_hr_quality.json"
    quality_md = quality_dir / "tinyspan_checkpoint_reds_hr_quality.md"
    quality_csv = quality_dir / "tinyspan_checkpoint_reds_hr_quality.csv"
    quality_preview = quality_dir / "tinyspan_checkpoint_reds_hr_quality_preview.png"

    missing: list[str] = []
    copied: list[dict[str, Any]] = []
    quality_report: dict[str, Any] = {}
    if quality_json.exists():
        quality_report = read_json(quality_json)
    else:
        missing.append(str(quality_json))

    training_files = [
        (checkpoint, True),
        (train_dir / "metrics.csv", False),
        (train_dir / "args.json", False),
        (train_dir / "train_command.txt", False),
        (train_dir / "train_command_linux.txt", False),
        (train_dir / "video_distill_preview.png", False),
        (train_dir / "video_distill_latest_preview.png", False),
    ]
    quality_files = [
        (quality_json, True),
        (quality_md, True),
        (quality_csv, True),
        (quality_preview, True),
    ]
    for source, required in training_files + quality_files:
        copy_one(source, artifact_dir, copied, missing, required=required)

    summary = quality_report.get("summary", {})
    student = summary.get("student_vs_hr", {})
    bicubic = summary.get("bicubic_vs_hr", {})
    decision_report = quality_report.get("decision", {})
    student_psnr = float(student.get("psnr_mean_db", 0.0) or 0.0)
    bicubic_psnr = float(bicubic.get("psnr_mean_db", 0.0) or 0.0)
    gain = float(decision_report.get("student_psnr_gain_over_bicubic_db", student_psnr - bicubic_psnr) or 0.0)
    software_quality_gate_pass = bool(
        not missing
        and student_psnr >= args.min_psnr_db
        and gain > args.min_psnr_gain_db
    )
    decision = {
        "software_quality_gate_pass": software_quality_gate_pass,
        "min_psnr_db": args.min_psnr_db,
        "min_psnr_gain_db": args.min_psnr_gain_db,
        "target_psnr_db": args.target_psnr_db,
        "student_psnr_gain_over_bicubic_db": gain,
        "student_psnr_mean_ge_28db": student_psnr >= 28.0,
        "student_psnr_mean_ge_30db": student_psnr >= args.target_psnr_db,
        "continue_to_quant_rtl_board": software_quality_gate_pass,
    }
    manifest = {
        "candidate_id": args.candidate_id,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "status": "PASS_SOFTWARE_QUALITY_GATE" if software_quality_gate_pass else "INCOMPLETE_OR_REJECTED",
        "software_quality_gate_pass": software_quality_gate_pass,
        "repo_root": str(repo),
        "train_dir": rel(repo, train_dir),
        "quality_dir": rel(repo, quality_dir),
        "artifact_dir": rel(repo, artifact_dir),
        "checkpoint": rel(repo, checkpoint),
        "checkpoint_sha256": sha256_file(checkpoint),
        "quality_summary": {
            "image_count": quality_report.get("image_count"),
            "student_psnr_mean_db": student.get("psnr_mean_db"),
            "student_ssim_mean": student.get("ssim_mean"),
            "student_mae_normalized_mean": student.get("mae_normalized_mean"),
            "bicubic_psnr_mean_db": bicubic.get("psnr_mean_db"),
            "bicubic_ssim_mean": bicubic.get("ssim_mean"),
            "bicubic_mae_normalized_mean": bicubic.get("mae_normalized_mean"),
        },
        "decision": decision,
        "copied": copied,
        "missing_required": missing,
        "boundary": [
            "This package is only an X4 software quality candidate gate.",
            "It does not replace X4_SUBMIT_20260625_CURRENT_BASELINE.",
            "Replacing the X4 baseline still requires new quantization, RTL/export checks, bitstream, real board-vs-fixed equality, and >=30fps evidence.",
            "This script is file-only and does not start training, Vivado, JTAG, XSCT, board access, quantization, or RTL export.",
        ],
    }
    manifest_path = artifact_dir / "manifest.json"
    summary_path = artifact_dir / "run_summary.md"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(summary_path, manifest)
    print(json.dumps({"manifest": str(manifest_path), "summary": str(summary_path), "software_quality_gate_pass": software_quality_gate_pass, "missing": missing}, indent=2))
    if not software_quality_gate_pass and not args.allow_incomplete:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
