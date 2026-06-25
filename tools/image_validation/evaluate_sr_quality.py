"""Evaluate SR image quality against reference images.

This tool is intentionally image-only: it does not run PyTorch, Vivado, JTAG,
XSCT, or board access. It is used to turn already-generated SR/reference PNGs
into auditable PSNR/SSIM/MAE metrics for contest delivery.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
from PIL import Image

try:
    from skimage.metrics import structural_similarity
except Exception:  # pragma: no cover - optional dependency
    structural_similarity = None


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def read_rgb(path: Path) -> np.ndarray:
    if not path.exists():
        raise FileNotFoundError(path)
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def crop_border(image: np.ndarray, border: int) -> np.ndarray:
    if border <= 0:
        return image
    if image.shape[0] <= 2 * border or image.shape[1] <= 2 * border:
        raise ValueError(f"border {border} is too large for image shape {image.shape}")
    return image[border:-border, border:-border, :]


def psnr_db(mse: float) -> float:
    if mse <= 0.0:
        return 99.0
    return 10.0 * math.log10((255.0 * 255.0) / mse)


def metric_pair(label: str, sr_path: Path, ref_path: Path, border: int, resize_sr_to_reference: bool) -> dict[str, Any]:
    sr_image = Image.open(sr_path).convert("RGB")
    ref_image = Image.open(ref_path).convert("RGB")
    sr_original_size = sr_image.size
    ref_size = ref_image.size
    sr_resized_for_metric = False
    if sr_image.size != ref_image.size and resize_sr_to_reference:
        sr_image = sr_image.resize(ref_image.size, Image.Resampling.BICUBIC)
        sr_resized_for_metric = True
    sr_raw = np.asarray(sr_image, dtype=np.float32)
    ref_raw = np.asarray(ref_image, dtype=np.float32)
    if sr_raw.shape != ref_raw.shape:
        raise ValueError(f"{label}: image shapes differ: sr={sr_raw.shape}, ref={ref_raw.shape}")

    sr = crop_border(sr_raw, border)
    ref = crop_border(ref_raw, border)
    diff = sr - ref
    abs_diff = np.abs(diff)
    mse = float(np.mean(diff * diff))
    mae = float(np.mean(abs_diff))
    max_diff = int(np.max(abs_diff)) if abs_diff.size else 0
    mismatch_bytes = int(np.count_nonzero(abs_diff))
    total_bytes = int(abs_diff.size)
    ssim_value: float | None = None
    if structural_similarity is not None:
        ssim_value = float(structural_similarity(sr, ref, channel_axis=2, data_range=255.0))

    return {
        "label": label,
        "sr": str(sr_path),
        "sr_sha256": sha256_file(sr_path),
        "reference": str(ref_path),
        "reference_sha256": sha256_file(ref_path),
        "sr_original_width": int(sr_original_size[0]),
        "sr_original_height": int(sr_original_size[1]),
        "reference_width": int(ref_size[0]),
        "reference_height": int(ref_size[1]),
        "sr_resized_for_metric": sr_resized_for_metric,
        "width": int(sr.shape[1]),
        "height": int(sr.shape[0]),
        "channels": int(sr.shape[2]),
        "border": border,
        "mismatch_bytes": mismatch_bytes,
        "total_bytes": total_bytes,
        "max_channel_diff": max_diff,
        "mae_rgb_level": mae,
        "mae_normalized": mae / 255.0,
        "mse_rgb_level": mse,
        "psnr_db": psnr_db(mse),
        "ssim": ssim_value,
    }


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN SR Quality Metrics",
        "",
        f"- generated at: `{report['generated_at']}`",
        f"- border crop: `{report['border']}` px",
        f"- resize SR to reference: `{'yes' if report['resize_sr_to_reference'] else 'no'}`",
        "",
        "| Pair | PSNR | SSIM | MAE/255 | Max diff | Mismatch bytes | Resized |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for item in report["pairs"]:
        ssim_value = item.get("ssim")
        ssim_text = "" if ssim_value is None else f"{ssim_value:.6f}"
        lines.append(
            "| `{label}` | `{psnr:.6f} dB` | `{ssim}` | `{mae:.6f}` | `{max_diff}` | `{mismatch}/{total}` | `{resized}` |".format(
                label=item["label"],
                psnr=item["psnr_db"],
                ssim=ssim_text,
                mae=item["mae_normalized"],
                max_diff=item["max_channel_diff"],
                mismatch=item["mismatch_bytes"],
                total=item["total_bytes"],
                resized="yes" if item.get("sr_resized_for_metric") else "no",
            )
        )

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- These metrics compare already-generated images only.",
            "- Board correctness is still proven by board-vs-fixed byte equality; quality metrics describe image fidelity.",
            "- If the reference is an official SPAN teacher output, PSNR/SSIM are teacher-consistency metrics, not REDS HR-ground-truth metrics.",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--pair",
        nargs=3,
        action="append",
        metavar=("LABEL", "SR_PNG", "REFERENCE_PNG"),
        required=True,
        help="Image pair to evaluate. Repeat for multiple pairs.",
    )
    parser.add_argument("--border", type=int, default=0, help="Pixels to crop from all sides before metrics.")
    parser.add_argument(
        "--resize-sr-to-reference",
        action="store_true",
        help="If SR and reference sizes differ, bicubic-resize SR to reference size before metrics.",
    )
    parser.add_argument("--json-out", type=Path, required=True)
    parser.add_argument("--md-out", type=Path, required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    pairs = [
        metric_pair(label, Path(sr).resolve(), Path(ref).resolve(), args.border, args.resize_sr_to_reference)
        for label, sr, ref in args.pair
    ]
    report = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "border": args.border,
        "resize_sr_to_reference": args.resize_sr_to_reference,
        "pair_count": len(pairs),
        "pairs": pairs,
    }
    args.json_out.parent.mkdir(parents=True, exist_ok=True)
    args.json_out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(args.md_out, report)
    print(f"WROTE {args.json_out}")
    print(f"WROTE {args.md_out}")
    for item in pairs:
        print(
            "{label}: psnr={psnr:.6f}dB ssim={ssim} mae={mae:.6f} maxdiff={maxdiff}".format(
                label=item["label"],
                psnr=item["psnr_db"],
                ssim="" if item["ssim"] is None else f"{item['ssim']:.6f}",
                mae=item["mae_rgb_level"],
                maxdiff=item["max_channel_diff"],
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
