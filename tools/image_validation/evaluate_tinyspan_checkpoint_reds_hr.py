"""Evaluate a TinySPAN checkpoint against REDS HR images.

This is the first quality gate for X4 PSNR improvement candidates. It runs the
PyTorch student checkpoint only. It does not start Vivado, JTAG, XSCT, board
access, quantization, or RTL export.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sys
from contextlib import nullcontext
from datetime import datetime
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image, ImageDraw
from torchvision.transforms.functional import to_tensor
from tqdm import tqdm

try:
    from skimage.metrics import structural_similarity
except Exception:  # pragma: no cover - optional dependency
    structural_similarity = None


IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".bmp"}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def list_images(root: Path, max_images: int) -> list[Path]:
    if root.is_file() and root.suffix.lower() in IMAGE_EXTS:
        return [root]
    if not root.is_dir():
        raise FileNotFoundError(root)
    images = sorted(path for path in root.rglob("*") if path.suffix.lower() in IMAGE_EXTS)
    if max_images > 0:
        images = images[:max_images]
    if not images:
        raise FileNotFoundError(f"No images found under {root}")
    return images


def bicubic_downsample(hr: Image.Image, scale: int) -> Image.Image:
    width = hr.width // scale
    height = hr.height // scale
    if width < 1 or height < 1:
        raise ValueError(f"Image too small for X{scale}: {hr.size}")
    return hr.resize((width, height), Image.Resampling.BICUBIC)


def tensor_to_rgb_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).cpu().numpy()
    if arr.ndim == 4:
        arr = arr[0]
    arr = np.transpose(arr, (1, 2, 0))
    return Image.fromarray(np.round(arr * 255.0).astype(np.uint8), "RGB")


def crop_border(arr: np.ndarray, border: int) -> np.ndarray:
    if border <= 0:
        return arr
    if arr.shape[0] <= 2 * border or arr.shape[1] <= 2 * border:
        raise ValueError(f"border {border} is too large for image shape {arr.shape}")
    return arr[border:-border, border:-border, :]


def image_metrics(sr: Image.Image, ref: Image.Image, border: int) -> dict[str, Any]:
    if sr.size != ref.size:
        raise ValueError(f"Image sizes differ: sr={sr.size}, ref={ref.size}")
    sr_arr = crop_border(np.asarray(sr.convert("RGB"), dtype=np.float32), border)
    ref_arr = crop_border(np.asarray(ref.convert("RGB"), dtype=np.float32), border)
    diff = sr_arr - ref_arr
    abs_diff = np.abs(diff)
    mse = float(np.mean(diff * diff))
    psnr_db = 99.0 if mse <= 0.0 else 10.0 * math.log10((255.0 * 255.0) / mse)
    ssim_value = None
    if structural_similarity is not None:
        ssim_value = float(structural_similarity(sr_arr, ref_arr, channel_axis=2, data_range=255.0))
    return {
        "psnr_db": psnr_db,
        "ssim": ssim_value,
        "mae_rgb_level": float(np.mean(abs_diff)),
        "mae_normalized": float(np.mean(abs_diff) / 255.0),
        "max_channel_diff": int(np.max(abs_diff)) if abs_diff.size else 0,
        "mse_rgb_level": mse,
        "mismatch_bytes": int(np.count_nonzero(abs_diff)),
        "total_bytes": int(abs_diff.size),
    }


def mean_or_none(values: list[float | None]) -> float | None:
    present = [float(value) for value in values if value is not None]
    if not present:
        return None
    return float(sum(present) / len(present))


def load_model(repo_root: Path, checkpoint: Path, scale: int, channels: int, num_blocks: int, device: torch.device):
    sys.path.insert(0, str(repo_root / "train"))
    from span_model import build_model  # pylint: disable=import-error,import-outside-toplevel

    model = build_model(scale=scale, channels=channels, num_blocks=num_blocks).to(device)
    ckpt = torch.load(checkpoint, map_location="cpu")
    state = ckpt.get("model", ckpt)
    model.load_state_dict(state, strict=True)
    model.eval()
    return model


def save_preview(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    thumbs: list[tuple[str, Image.Image]] = []
    for row in rows:
        thumbs.extend(
            [
                ("HR", Image.open(row["hr"]).convert("RGB")),
                ("Bicubic", Image.open(row["bicubic_sr"]).convert("RGB")),
                ("Student", Image.open(row["student_sr"]).convert("RGB")),
            ]
        )
    tile_w = 220
    tile_h = 150
    label_h = 22
    cols = 3
    out = Image.new("RGB", (cols * tile_w, len(rows) * (tile_h + label_h)), "white")
    draw = ImageDraw.Draw(out)
    for idx, (label, image) in enumerate(thumbs):
        row = idx // cols
        col = idx % cols
        thumb = image.copy()
        thumb.thumbnail((tile_w, tile_h), Image.Resampling.BICUBIC)
        x = col * tile_w + (tile_w - thumb.width) // 2
        y = row * (tile_h + label_h) + label_h
        draw.text((col * tile_w + 6, row * (tile_h + label_h) + 4), label, fill=(0, 0, 0))
        out.paste(thumb, (x, y))
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)


def write_markdown(path: Path, report: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN Checkpoint REDS HR Quality",
        "",
        f"- generated at: `{report['generated_at']}`",
        f"- checkpoint: `{report['checkpoint']}`",
        f"- checkpoint SHA256: `{report['checkpoint_sha256']}`",
        f"- image count: `{report['image_count']}`",
        f"- saved image count: `{report.get('saved_image_count', '')}`",
        f"- save image count setting: `{report.get('save_image_count', '')}`",
        f"- scale: `X{report['scale']}`",
        f"- border: `{report['border']}`",
        "",
        "| Pair | PSNR mean | PSNR min | SSIM mean | MAE/255 mean |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for key in ["student_vs_hr", "bicubic_vs_hr"]:
        item = report["summary"][key]
        ssim = item["ssim_mean"]
        lines.append(
            "| `{}` | `{:.6f} dB` | `{:.6f} dB` | `{}` | `{:.6f}` |".format(
                key,
                item["psnr_mean_db"],
                item["psnr_min_db"],
                "" if ssim is None else f"{ssim:.6f}",
                item["mae_normalized_mean"],
            )
        )
    lines.extend(
        [
            "",
            "## Decision",
            "",
            f"- student PSNR improvement over bicubic: `{report['decision']['student_psnr_gain_over_bicubic_db']:.6f} dB`",
            f"- meets 28dB exploratory gate: `{report['decision']['student_psnr_mean_ge_28db']}`",
            f"- meets 30dB stretch gate: `{report['decision']['student_psnr_mean_ge_30db']}`",
            "",
            "This is a software quality gate only. It does not replace quantization, RTL, bitstream, board-vs-fixed equality, or >=30fps evidence.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--val-frames", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("--channels", type=int, default=32)
    parser.add_argument("--num-blocks", type=int, default=4)
    parser.add_argument("--max-images", type=int, default=16)
    parser.add_argument("--border", type=int, default=4)
    parser.add_argument("--device", choices=("auto", "cuda", "cpu"), default="auto")
    parser.add_argument("--amp", action="store_true")
    parser.add_argument("--preview-count", type=int, default=3)
    parser.add_argument(
        "--save-image-count",
        type=int,
        default=0,
        help="0 saves all per-image PNGs; a positive value saves only the first N while still scoring all images.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    checkpoint = args.checkpoint if args.checkpoint.is_absolute() else repo_root / args.checkpoint
    val_frames = args.val_frames if args.val_frames.is_absolute() else repo_root / args.val_frames
    out_dir = args.out_dir if args.out_dir.is_absolute() else repo_root / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)
    if device.type == "cuda" and not torch.cuda.is_available():
        raise RuntimeError("CUDA requested but unavailable")

    model = load_model(repo_root, checkpoint, args.scale, args.channels, args.num_blocks, device)
    images = list_images(val_frames, args.max_images)
    sr_dir = out_dir / "sr_images"
    save_all_images = args.save_image_count <= 0
    if save_all_images or args.save_image_count > 0:
        sr_dir.mkdir(parents=True, exist_ok=True)

    rows: list[dict[str, Any]] = []
    preview_rows: list[dict[str, Any]] = []
    for index, hr_path in enumerate(tqdm(images, desc="x4 reds hr quality"), start=1):
        hr = Image.open(hr_path).convert("RGB")
        valid_w = (hr.width // args.scale) * args.scale
        valid_h = (hr.height // args.scale) * args.scale
        if valid_w != hr.width or valid_h != hr.height:
            hr = hr.crop((0, 0, valid_w, valid_h))
        lr = bicubic_downsample(hr, args.scale)
        bicubic_sr = lr.resize(hr.size, Image.Resampling.BICUBIC)
        tensor = to_tensor(lr).unsqueeze(0).to(device)
        with torch.no_grad():
            model_input = tensor.half() if args.amp and device.type == "cuda" else tensor
            amp_context = torch.autocast("cuda") if args.amp and device.type == "cuda" else nullcontext()
            with amp_context:
                student = model(model_input).float().clamp(0, 1)
        student_sr = tensor_to_rgb_image(student)

        stem = f"{index:04d}_{hr_path.stem}"
        should_save_images = save_all_images or index <= args.save_image_count
        hr_out = sr_dir / f"{stem}_hr.png"
        lr_out = sr_dir / f"{stem}_lr.png"
        bicubic_out = sr_dir / f"{stem}_bicubic_sr.png"
        student_out = sr_dir / f"{stem}_student_sr.png"
        if should_save_images:
            hr.save(hr_out)
            lr.save(lr_out)
            bicubic_sr.save(bicubic_out)
            student_sr.save(student_out)

        student_metrics = image_metrics(student_sr, hr, args.border)
        bicubic_metrics = image_metrics(bicubic_sr, hr, args.border)
        row = {
            "index": index,
            "source": str(hr_path),
            "saved_images": should_save_images,
            "hr": str(hr_out) if should_save_images else "",
            "lr": str(lr_out) if should_save_images else "",
            "bicubic_sr": str(bicubic_out) if should_save_images else "",
            "student_sr": str(student_out) if should_save_images else "",
            "student_vs_hr": student_metrics,
            "bicubic_vs_hr": bicubic_metrics,
        }
        rows.append(row)
        if should_save_images and len(preview_rows) < args.preview_count:
            preview_rows.append(row)

    def summarize(key: str) -> dict[str, Any]:
        psnrs = [float(row[key]["psnr_db"]) for row in rows]
        ssims = [row[key]["ssim"] for row in rows]
        maes = [float(row[key]["mae_normalized"]) for row in rows]
        return {
            "psnr_mean_db": float(sum(psnrs) / len(psnrs)),
            "psnr_min_db": float(min(psnrs)),
            "psnr_max_db": float(max(psnrs)),
            "ssim_mean": mean_or_none(ssims),
            "mae_normalized_mean": float(sum(maes) / len(maes)),
        }

    summary = {
        "student_vs_hr": summarize("student_vs_hr"),
        "bicubic_vs_hr": summarize("bicubic_vs_hr"),
    }
    gain = summary["student_vs_hr"]["psnr_mean_db"] - summary["bicubic_vs_hr"]["psnr_mean_db"]
    report = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "checkpoint": str(checkpoint),
        "checkpoint_sha256": sha256_file(checkpoint),
        "val_frames": str(val_frames),
        "image_count": len(rows),
        "scale": args.scale,
        "channels": args.channels,
        "num_blocks": args.num_blocks,
        "border": args.border,
        "device": str(device),
        "amp": bool(args.amp),
        "save_image_count": args.save_image_count,
        "saved_image_count": int(sum(1 for row in rows if row.get("saved_images"))),
        "summary": summary,
        "decision": {
            "student_psnr_gain_over_bicubic_db": float(gain),
            "student_psnr_mean_ge_28db": summary["student_vs_hr"]["psnr_mean_db"] >= 28.0,
            "student_psnr_mean_ge_30db": summary["student_vs_hr"]["psnr_mean_db"] >= 30.0,
        },
        "rows": rows,
    }

    json_path = out_dir / "tinyspan_checkpoint_reds_hr_quality.json"
    md_path = out_dir / "tinyspan_checkpoint_reds_hr_quality.md"
    csv_path = out_dir / "tinyspan_checkpoint_reds_hr_quality.csv"
    preview_path = out_dir / "tinyspan_checkpoint_reds_hr_quality_preview.png"
    json_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(md_path, report)
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "index",
                "source",
                "student_psnr_db",
                "student_ssim",
                "student_mae_normalized",
                "bicubic_psnr_db",
                "bicubic_ssim",
                "bicubic_mae_normalized",
            ],
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(
                {
                    "index": row["index"],
                    "source": row["source"],
                    "student_psnr_db": f"{row['student_vs_hr']['psnr_db']:.6f}",
                    "student_ssim": "" if row["student_vs_hr"]["ssim"] is None else f"{row['student_vs_hr']['ssim']:.6f}",
                    "student_mae_normalized": f"{row['student_vs_hr']['mae_normalized']:.8f}",
                    "bicubic_psnr_db": f"{row['bicubic_vs_hr']['psnr_db']:.6f}",
                    "bicubic_ssim": "" if row["bicubic_vs_hr"]["ssim"] is None else f"{row['bicubic_vs_hr']['ssim']:.6f}",
                    "bicubic_mae_normalized": f"{row['bicubic_vs_hr']['mae_normalized']:.8f}",
                }
            )
    save_preview(preview_path, preview_rows)
    print(f"WROTE {json_path}")
    print(f"WROTE {md_path}")
    print(f"WROTE {csv_path}")
    print(f"WROTE {preview_path}")
    print(
        "student_psnr_mean={:.6f} bicubic_psnr_mean={:.6f} gain={:.6f}".format(
            summary["student_vs_hr"]["psnr_mean_db"],
            summary["bicubic_vs_hr"]["psnr_mean_db"],
            gain,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
