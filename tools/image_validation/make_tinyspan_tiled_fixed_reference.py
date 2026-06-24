#!/usr/bin/env python3
"""Create a hardware-tile-isomorphic TinySPAN fixed-point reference image.

The final board route does not process a whole LR frame with one monolithic
TinySPAN core. It enumerates LR tiles in hardware, zero-pads edge tiles to the
fixed core size, runs the 32x32 X4 core, crops the valid HR region, and stitches
the result back into a full frame. This script mirrors that contract in software
so the final board output can be compared against the right byte-exact target.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

import numpy as np
import torch
from PIL import Image, ImageChops, ImageDraw, ImageStat


def find_repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "train" / "span_model.py").exists():
            return parent
    return Path(__file__).resolve().parents[2]


REPO_ROOT = find_repo_root()
MODEL_TO_HARDWARE = REPO_ROOT / "tools" / "model_to_hardware"
sys.path.insert(0, str(MODEL_TO_HARDWARE))

import run_tinyspan_manifest_reference as manifest_ref  # noqa: E402
import run_tinyspan_w8a8_integer_reference as int_ref  # noqa: E402


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_file(path: Path | None) -> str:
    if path is None or not path.exists():
        return ""
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def resolve_path(path: Path, base: Path) -> Path:
    if path.is_absolute():
        return path
    candidate = (base / path).resolve()
    if candidate.exists():
        return candidate
    return (REPO_ROOT / path).resolve()


def resolve_checkpoint(plan: dict[str, Any], arg_checkpoint: Path | None) -> Path | None:
    candidates: list[Path] = []
    if arg_checkpoint is not None:
        candidates.append(arg_checkpoint)
    source = plan.get("source_checkpoint")
    if source:
        candidates.append(Path(str(source)))
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
        rel = (REPO_ROOT / candidate).resolve()
        if rel.exists():
            return rel
        matches = list((REPO_ROOT / "model" / "checkpoints").rglob(candidate.name))
        if matches:
            return matches[0].resolve()
    return None


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


def image_metrics(ref: Image.Image, actual: Image.Image) -> dict[str, Any]:
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.Resampling.BICUBIC)
    diff = ImageChops.difference(ref, actual)
    arr = np.frombuffer(diff.tobytes(), dtype=np.uint8)
    mse = float(np.mean(arr.astype(np.float32) ** 2)) if arr.size else 0.0
    extrema = [value for channel in ImageStat.Stat(diff).extrema for value in channel]
    return {
        "mismatch_bytes": int(np.count_nonzero(arr)),
        "total_bytes": int(arr.size),
        "max_channel_diff": int(max(extrema)) if extrema else 0,
        "mae": float(np.mean(arr)) if arr.size else 0.0,
        "mse": mse,
        "psnr_db": float("inf") if mse == 0.0 else float(20.0 * math.log10(255.0 / math.sqrt(mse))),
    }


def diff_heatmap(ref: Image.Image, actual: Image.Image, gain: int) -> Image.Image:
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.Resampling.BICUBIC)
    diff = ImageChops.difference(ref, actual)
    return diff.point(lambda value: min(255, value * gain))


def fit_tile(img: Image.Image, tile: int) -> Image.Image:
    fitted = img.copy()
    fitted.thumbnail((tile, tile), Image.Resampling.BICUBIC)
    canvas = Image.new("RGB", (tile, tile), (18, 22, 28))
    canvas.paste(fitted, ((tile - fitted.width) // 2, (tile - fitted.height) // 2))
    return canvas


def draw_preview(
    path: Path,
    input_img: Image.Image,
    pytorch_img: Image.Image | None,
    full_integer_img: Image.Image | None,
    tiled_img: Image.Image,
    heatmap: Image.Image,
    metrics: dict[str, Any],
    tile: int,
) -> None:
    panels: list[tuple[str, Image.Image]] = [(f"LR input {input_img.width}x{input_img.height}", fit_tile(input_img, tile))]
    if pytorch_img is not None:
        panels.append((f"PyTorch SR {pytorch_img.width}x{pytorch_img.height}", fit_tile(pytorch_img, tile)))
    if full_integer_img is not None:
        panels.append((f"Full-frame fixed {full_integer_img.width}x{full_integer_img.height}", fit_tile(full_integer_img, tile)))
    panels.extend(
        [
            (f"Tiled fixed {tiled_img.width}x{tiled_img.height}", fit_tile(tiled_img, tile)),
            (f"Tiled/full diff x{metrics['diff_gain']}", fit_tile(heatmap, tile)),
        ]
    )

    label_h = 28
    title_h = 42
    summary_h = 42
    gap = 12
    width = len(panels) * tile + (len(panels) + 1) * gap
    height = title_h + label_h + tile + summary_h + 2 * gap
    canvas = Image.new("RGB", (width, height), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), "TinySPAN hardware-tiled fixed-point reference", fill=(20, 24, 31))
    pair = metrics.get("full_integer_vs_tiled") or metrics.get("pytorch_vs_tiled") or {}
    summary = (
        f"tile contract {metrics['tile_width']}x{metrics['tile_height']} zero-pad/crop; "
        f"mismatch {pair.get('mismatch_bytes', 'n/a')}/{pair.get('total_bytes', 'n/a')}, "
        f"max diff {pair.get('max_channel_diff', 'n/a')}"
    )
    draw.text((gap, height - summary_h + 8), summary, fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def make_tile_tensor(tensor: torch.Tensor, x: int, y: int, valid_w: int, valid_h: int, tile_w: int, tile_h: int) -> torch.Tensor:
    tile = torch.zeros((1, tensor.shape[1], tile_h, tile_w), dtype=tensor.dtype, device=tensor.device)
    tile[:, :, :valid_h, :valid_w] = tensor[:, :, y : y + valid_h, x : x + valid_w]
    return tile


def run_tiled_reference(
    plan: dict[str, Any],
    quant_plan: Path,
    tensor: torch.Tensor,
    *,
    width: int,
    height: int,
    tile_w: int,
    tile_h: int,
    scale: int,
) -> tuple[Image.Image, list[dict[str, int]]]:
    out_tensor = torch.zeros((1, 3, height * scale, width * scale), dtype=torch.float32, device=tensor.device)
    tiles: list[dict[str, int]] = []
    tile_index = 0
    with torch.inference_mode():
        for tile_y in range(0, height, tile_h):
            valid_h = min(tile_h, height - tile_y)
            for tile_x in range(0, width, tile_w):
                valid_w = min(tile_w, width - tile_x)
                tile_tensor = make_tile_tensor(tensor, tile_x, tile_y, valid_w, valid_h, tile_w, tile_h)
                tile_out, _ = int_ref.run_integer_reference(plan, quant_plan, tile_tensor)
                out_y = tile_y * scale
                out_x = tile_x * scale
                hr_h = valid_h * scale
                hr_w = valid_w * scale
                out_tensor[:, :, out_y : out_y + hr_h, out_x : out_x + hr_w] = tile_out[:, :, :hr_h, :hr_w]
                tiles.append(
                    {
                        "tile_index": tile_index,
                        "tile_x": tile_x,
                        "tile_y": tile_y,
                        "valid_w": valid_w,
                        "valid_h": valid_h,
                        "padded_w": tile_w,
                        "padded_h": tile_h,
                        "output_x": out_x,
                        "output_y": out_y,
                        "output_w": hr_w,
                        "output_h": hr_h,
                        "input_byte_offset": ((tile_y * width) + tile_x) * 3,
                        "output_byte_offset": (((tile_y * scale) * (width * scale)) + (tile_x * scale)) * 3,
                    }
                )
                tile_index += 1
    return tensor_to_image(out_tensor), tiles


def write_markdown(path: Path, summary: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN Tiled Fixed-Point Reference",
        "",
        f"Status: `{'PASS' if summary['pass'] else 'WARN'}`",
        "",
        "## Contract",
        "",
        f"- LR input: `{summary['input_width']}x{summary['input_height']}`",
        f"- SR output: `{summary['output_width']}x{summary['output_height']}`",
        f"- tile: `{summary['tile_width']}x{summary['tile_height']}`",
        f"- scale: `X{summary['scale']}`",
        f"- padding policy: `{summary['padding_policy']}`",
        f"- crop policy: `{summary['crop_policy']}`",
        f"- tile count: `{summary['tile_count']}`",
        "",
        "## Evidence",
        "",
        f"- input image: `{summary['input']}`",
        f"- checkpoint: `{summary.get('checkpoint', '')}`",
        f"- checkpoint SHA256: `{summary.get('checkpoint_sha256', '')}`",
        f"- quant plan: `{summary['quant_plan']}`",
        f"- quant plan SHA256: `{summary['quant_plan_sha256']}`",
        f"- tiled fixed reference: `{summary['outputs']['software_tiled_fixed_point_sr']}`",
        f"- comparison preview: `{summary['outputs']['comparison_preview']}`",
        f"- diff heatmap: `{summary['outputs']['diff_heatmap']}`",
        f"- tile manifest: `{summary['outputs']['tile_manifest']}`",
        "",
        "## Metrics",
        "",
        "| Pair | mismatch bytes | max diff | MAE | PSNR |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for name, item in summary["metrics"].items():
        lines.append(
            f"| `{name}` | `{item['mismatch_bytes']} / {item['total_bytes']}` | "
            f"`{item['max_channel_diff']}` | `{item['mae']:.6f}` | `{item['psnr_db']:.6f} dB` |"
        )
    lines.extend(
        [
            "",
            "## Acceptance Use",
            "",
            "`software_tiled_fixed_point_sr.png` is the byte-exact `FixedPng` candidate for the full-frame board acceptance script. The board output must still be generated by a real bitstream and compared separately; this reference alone does not prove board acceptance.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate TinySPAN tile-isomorphic full-frame fixed reference.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--tile-width", type=int, default=32)
    parser.add_argument("--tile-height", type=int, default=32)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--preview-tile", type=int, default=180)
    parser.add_argument("--diff-gain", type=int, default=8)
    parser.add_argument("--skip-pytorch", action="store_true")
    parser.add_argument("--skip-full-integer", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    quant_plan = resolve_path(args.quant_plan, REPO_ROOT)
    input_path = resolve_path(args.input, REPO_ROOT)
    plan = load_json(quant_plan)
    scale = int(plan["scale"])
    checkpoint = resolve_checkpoint(plan, args.checkpoint)

    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    tensor, input_img = manifest_ref.image_to_tensor(input_path, args.width, args.height, device)
    input_img.save(args.out_dir / "lr_input_resized.png")

    pytorch_img: Image.Image | None = None
    if not args.skip_pytorch:
        if checkpoint is None:
            raise SystemExit("checkpoint is required for PyTorch training-output reference")
        original = manifest_ref.build_original_model(checkpoint, scale, int(plan["channels"]), int(plan["num_blocks"]), device)
        with torch.inference_mode():
            pytorch_img = tensor_to_image(manifest_ref.run_model(original, tensor))
        pytorch_img.save(args.out_dir / "pytorch_training_sr.png")

    full_integer_img: Image.Image | None = None
    if not args.skip_full_integer:
        with torch.inference_mode():
            full_integer_out, _ = int_ref.run_integer_reference(plan, quant_plan, tensor)
        full_integer_img = tensor_to_image(full_integer_out)
        full_integer_img.save(args.out_dir / "software_full_frame_fixed_point_sr.png")

    tiled_img, tiles = run_tiled_reference(
        plan,
        quant_plan,
        tensor,
        width=args.width,
        height=args.height,
        tile_w=args.tile_width,
        tile_h=args.tile_height,
        scale=scale,
    )
    tiled_img.save(args.out_dir / "software_tiled_fixed_point_sr.png")

    metrics: dict[str, Any] = {}
    heatmap_ref = full_integer_img or pytorch_img or tiled_img
    if pytorch_img is not None:
        metrics["pytorch_vs_tiled"] = image_metrics(pytorch_img, tiled_img)
    if full_integer_img is not None:
        metrics["full_integer_vs_tiled"] = image_metrics(full_integer_img, tiled_img)
    if pytorch_img is not None and full_integer_img is not None:
        metrics["pytorch_vs_full_integer"] = image_metrics(pytorch_img, full_integer_img)

    heatmap = diff_heatmap(heatmap_ref, tiled_img, args.diff_gain)
    heatmap.save(args.out_dir / "diff_heatmap.png")

    preview_metrics = {
        "tile_width": args.tile_width,
        "tile_height": args.tile_height,
        "diff_gain": args.diff_gain,
        **metrics,
    }
    draw_preview(
        args.out_dir / "comparison_preview.png",
        input_img,
        pytorch_img,
        full_integer_img,
        tiled_img,
        heatmap,
        preview_metrics,
        args.preview_tile,
    )

    tile_manifest = {
        "input_width": args.width,
        "input_height": args.height,
        "output_width": args.width * scale,
        "output_height": args.height * scale,
        "scale": scale,
        "tile_width": args.tile_width,
        "tile_height": args.tile_height,
        "padding_policy": "zero-pad LR edge tiles to fixed tile size before TinySPAN core",
        "crop_policy": "crop top-left valid_w*scale by valid_h*scale region from each SR tile",
        "tiles": tiles,
    }
    tile_manifest_path = args.out_dir / "tile_manifest.json"
    tile_manifest_path.write_text(json.dumps(tile_manifest, indent=2), encoding="utf-8")

    summary = {
        "pass": True,
        "input": str(input_path),
        "input_sha256": sha256_file(input_path),
        "input_width": args.width,
        "input_height": args.height,
        "output_width": args.width * scale,
        "output_height": args.height * scale,
        "scale": scale,
        "tile_width": args.tile_width,
        "tile_height": args.tile_height,
        "tile_count": len(tiles),
        "padding_policy": tile_manifest["padding_policy"],
        "crop_policy": tile_manifest["crop_policy"],
        "checkpoint": str(checkpoint) if checkpoint else "",
        "checkpoint_sha256": sha256_file(checkpoint),
        "quant_plan": str(quant_plan),
        "quant_plan_sha256": sha256_file(quant_plan),
        "device": str(device),
        "metrics": metrics,
        "outputs": {
            "lr_input_resized": str(args.out_dir / "lr_input_resized.png"),
            "pytorch_training_sr": str(args.out_dir / "pytorch_training_sr.png") if pytorch_img is not None else "",
            "software_full_frame_fixed_point_sr": str(args.out_dir / "software_full_frame_fixed_point_sr.png") if full_integer_img is not None else "",
            "software_tiled_fixed_point_sr": str(args.out_dir / "software_tiled_fixed_point_sr.png"),
            "comparison_preview": str(args.out_dir / "comparison_preview.png"),
            "diff_heatmap": str(args.out_dir / "diff_heatmap.png"),
            "tile_manifest": str(tile_manifest_path),
        },
    }
    summary_json = args.out_dir / "tinyspan_tiled_fixed_reference_summary.json"
    summary_md = args.out_dir / "tinyspan_tiled_fixed_reference_summary.md"
    summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_markdown(summary_md, summary)
    print(json.dumps({"summary": str(summary_md), "fixed_png": summary["outputs"]["software_tiled_fixed_point_sr"], "tile_count": len(tiles)}, indent=2))


if __name__ == "__main__":
    main()
