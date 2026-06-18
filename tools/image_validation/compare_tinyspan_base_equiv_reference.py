#!/usr/bin/env python3
"""Compare TinySPAN frozen-plan base-equivalent path against PyTorch reference."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageChops, ImageStat


COEFF_Q14 = np.array(
    [
        [-1080, 6984, 12280, -1800],
        [-168, 1880, 15848, -1176],
        [-1176, 15848, 1880, -168],
        [-1800, 12280, 6984, -1080],
    ],
    dtype=np.int64,
)


def q31_round(values: np.ndarray, mult: int, shift: int = 31) -> np.ndarray:
    prod = values.astype(np.int64) * np.int64(mult)
    abs_prod = np.abs(prod)
    q = (abs_prod + (1 << (shift - 1))) >> shift
    return np.where(prod < 0, -q, q)


def rtl_bicubic_qbase(rgb: np.ndarray) -> np.ndarray:
    h, w, _ = rgb.shape
    out = np.zeros((h * 4, w * 4, 3), dtype=np.int64)
    den = 255 * (1 << 28)
    for oy in range(h * 4):
        py_phase = oy & 3
        src_y_floor = (oy >> 2) + (-1 if py_phase < 2 else 0)
        wy = COEFF_Q14[py_phase]
        for ox in range(w * 4):
            px_phase = ox & 3
            src_x_floor = (ox >> 2) + (-1 if px_phase < 2 else 0)
            wx = COEFF_Q14[px_phase]
            acc = np.zeros((3,), dtype=np.int64)
            for ty in range(4):
                sy = min(max(src_y_floor - 1 + ty, 0), h - 1)
                for tx in range(4):
                    sx = min(max(src_x_floor - 1 + tx, 0), w - 1)
                    acc += rgb[sy, sx, :].astype(np.int64) * wy[ty] * wx[tx]
            num = acc * 127
            abs_num = np.abs(num)
            q = (abs_num + den // 2) // den
            q = np.where(num < 0, -q, q)
            out[oy, ox, :] = np.clip(q, -128, 127)
    return out


def q_to_rgb(q: np.ndarray, output_scale: float) -> np.ndarray:
    arr = np.clip(q.astype(np.float64) * output_scale, 0.0, 1.0)
    return np.rint(arr * 255.0).astype(np.uint8)


def load_rgb(path: Path, width: int | None, height: int | None) -> Image.Image:
    img = Image.open(path).convert("RGB")
    if width is not None and height is not None:
        img = img.resize((width, height), Image.Resampling.BICUBIC)
    return img


def collect_mismatch_records(
    ref_rgb: np.ndarray,
    rtl_rgb: np.ndarray,
    q_base_ref: np.ndarray,
    q_base_rtl: np.ndarray,
    q_out_ref: np.ndarray,
    q_out_rtl: np.ndarray,
    limit: int = 64,
) -> list[dict[str, int]]:
    diff = ref_rgb.astype(np.int16) - rtl_rgb.astype(np.int16)
    ys, xs, cs = np.nonzero(diff)
    records: list[dict[str, int]] = []
    for y, x, c in zip(ys[:limit], xs[:limit], cs[:limit]):
        records.append(
            {
                "y": int(y),
                "x": int(x),
                "channel": int(c),
                "pytorch_rgb": int(ref_rgb[y, x, c]),
                "rtl_fixed_rgb": int(rtl_rgb[y, x, c]),
                "rgb_diff": int(diff[y, x, c]),
                "pytorch_q_base": int(q_base_ref[y, x, c]),
                "rtl_fixed_q_base": int(q_base_rtl[y, x, c]),
                "pytorch_q_out": int(q_out_ref[y, x, c]),
                "rtl_fixed_q_out": int(q_out_rtl[y, x, c]),
            }
        )
    return records


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    plan = json.loads(args.plan.read_text(encoding="utf-8"))
    scales = plan["activation_scale_table"]
    input_scale = float(scales["input"])
    output_scale = float(scales["output"])
    base_q31 = int(round((input_scale / output_scale) * (1 << 31)))

    img = load_rgb(args.input, args.width, args.height)
    rgb = np.asarray(img, dtype=np.uint8)

    tensor = torch.from_numpy(rgb).permute(2, 0, 1).unsqueeze(0).float() / 255.0
    base = F.interpolate(tensor, scale_factor=4, mode="bicubic", align_corners=False)
    q_base_ref = torch.round(base / input_scale).clamp(-128, 127).squeeze(0).permute(1, 2, 0).numpy().astype(np.int64)
    q_out_ref = q31_round(q_base_ref, base_q31)
    q_out_ref = np.clip(q_out_ref, -128, 127)
    ref_rgb = q_to_rgb(q_out_ref, output_scale)

    q_base_rtl = rtl_bicubic_qbase(rgb)
    q_out_rtl = q31_round(q_base_rtl, base_q31)
    q_out_rtl = np.clip(q_out_rtl, -128, 127)
    rtl_rgb = q_to_rgb(q_out_rtl, output_scale)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    ref_img = Image.fromarray(ref_rgb, "RGB")
    rtl_img = Image.fromarray(rtl_rgb, "RGB")
    diff = ImageChops.difference(ref_img, rtl_img)
    ref_img.save(args.out_dir / "pytorch_base_equiv.png")
    rtl_img.save(args.out_dir / "rtl_base_equiv.png")
    diff.save(args.out_dir / "diff.png")

    diff_arr = np.asarray(diff, dtype=np.uint8)
    mismatch_bytes = int(np.count_nonzero(diff_arr))
    summary = {
        "pass": bool(mismatch_bytes == 0),
        "pytorch_vs_rtl_fixed_pass": bool(mismatch_bytes == 0),
        "mismatch_bytes": mismatch_bytes,
        "total_bytes": int(diff_arr.size),
        "max_channel_diff": int(diff_arr.max()) if diff_arr.size else 0,
        "mean_channel_diff": list(ImageStat.Stat(diff).mean),
        "base_q31": base_q31,
        "reference_policy": {
            "byte_exact_board_gate": "compare board output against the RTL-isomorphic fixed-point software reference",
            "pytorch_bicubic_output": "visual quality reference only; do not use it as the byte-exact board gate",
        },
        "pytorch_quantized_output": str(args.out_dir / "pytorch_base_equiv.png"),
        "rtl_fixed_output": str(args.out_dir / "rtl_base_equiv.png"),
        "diff_output": str(args.out_dir / "diff.png"),
        "mismatch_record_limit": 64,
        "mismatch_records": collect_mismatch_records(
            ref_rgb,
            rtl_rgb,
            q_base_ref,
            q_base_rtl,
            q_out_ref,
            q_out_rtl,
        ),
    }
    (args.out_dir / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0 if summary["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
