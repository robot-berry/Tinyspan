"""Run a plan-driven TinySPAN W8A8 integer-style reference."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageChops, ImageDraw, ImageStat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_tinyspan_manifest_reference as manifest_ref


COEFF_Q14 = np.array(
    [
        [-1080, 6984, 12280, -1800],
        [-168, 1880, 15848, -1176],
        [-1176, 15848, 1880, -168],
        [-1800, 12280, 6984, -1080],
    ],
    dtype=np.int64,
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_i8_bin(path: Path, shape: list[int]) -> torch.Tensor:
    data = np.fromfile(path, dtype=np.int8)
    expected = int(np.prod(shape))
    if data.size != expected:
        raise ValueError(f"{path}: got {data.size} values, expected {expected}")
    return torch.from_numpy(data.astype(np.float32)).reshape(shape)


def read_i64_bin(path: Path, shape: list[int]) -> torch.Tensor:
    data = np.fromfile(path, dtype="<i8")
    expected = int(np.prod(shape))
    if data.size != expected:
        raise ValueError(f"{path}: got {data.size} values, expected {expected}")
    return torch.from_numpy(data.astype(np.float32)).reshape(shape)


def activation_qmin(plan: dict) -> int:
    return int(plan["activation_qmin"])


def activation_qmax(plan: dict) -> int:
    return int(plan["activation_qmax"])


def quantize_float(x: torch.Tensor, scale: float, plan: dict) -> torch.Tensor:
    q = torch.round(x / float(scale))
    return torch.clamp(q, activation_qmin(plan), activation_qmax(plan))


def dequantize(q: torch.Tensor, scale: float) -> torch.Tensor:
    return q.float() * float(scale)


def requant_scale(q: torch.Tensor, in_scale: float, out_scale: float, plan: dict) -> torch.Tensor:
    y = torch.round(q.float() * (float(in_scale) / float(out_scale)))
    return torch.clamp(y, activation_qmin(plan), activation_qmax(plan))


def requant_mul(q_a: torch.Tensor, scale_a: float, q_b: torch.Tensor, scale_b: float, out_scale: float, plan: dict) -> torch.Tensor:
    y = torch.round(q_a.float() * q_b.float() * (float(scale_a) * float(scale_b) / float(out_scale)))
    return torch.clamp(y, activation_qmin(plan), activation_qmax(plan))


def requant_add(q_a: torch.Tensor, scale_a: float, q_b: torch.Tensor, scale_b: float, out_scale: float, plan: dict) -> torch.Tensor:
    y = torch.round(q_a.float() * (float(scale_a) / float(out_scale)) + q_b.float() * (float(scale_b) / float(out_scale)))
    return torch.clamp(y, activation_qmin(plan), activation_qmax(plan))


def conv2d_integer(q_in: torch.Tensor, layer: dict, root: Path, plan: dict) -> torch.Tensor:
    weight = read_i8_bin(root / layer["weight_file_i8_bin"], layer["weight_shape"]).to(q_in.device)
    bias = read_i64_bin(root / layer["bias_file_i64_bin"], layer["bias_shape"]).to(q_in.device)
    acc = F.conv2d(q_in.float(), weight.float(), bias=None, stride=1, padding=1)
    acc = acc + bias.view(1, -1, 1, 1)
    multipliers = torch.tensor([int(item["multiplier_q31"]) for item in layer["requant"]], dtype=torch.float32, device=q_in.device)
    shifts = torch.tensor([int(item["shift"]) for item in layer["requant"]], dtype=torch.float32, device=q_in.device)
    scaled = torch.round(acc * multipliers.view(1, -1, 1, 1) / torch.pow(torch.tensor(2.0, device=q_in.device), shifts.view(1, -1, 1, 1)))
    return torch.clamp(scaled, activation_qmin(plan), activation_qmax(plan))


def stage_stats(q: torch.Tensor) -> dict:
    qf = q.detach().float().cpu()
    return {
        "q_min": int(qf.min().item()),
        "q_max": int(qf.max().item()),
        "zero_frac": float((qf == 0).float().mean().item()),
        "sat_neg_frac": float((qf <= -128).float().mean().item()),
        "sat_pos_frac": float((qf >= 127).float().mean().item()),
    }


def layer_map(plan: dict) -> dict[str, dict]:
    return {layer["name"]: layer for layer in plan["layers"]}


def tensor_to_rgb_u8(tensor: torch.Tensor) -> np.ndarray:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return np.rint(arr * 255.0).astype(np.uint8)


def rtl_bicubic_qbase_x4(rgb: np.ndarray) -> np.ndarray:
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


def quantized_bicubic_base(tensor: torch.Tensor, scales: dict[str, float], plan: dict) -> tuple[torch.Tensor, str]:
    scale = int(plan["scale"])
    if scale == 4:
        rgb = tensor_to_rgb_u8(tensor)
        q_base = rtl_bicubic_qbase_x4(rgb)
        q_tensor = torch.from_numpy(q_base).permute(2, 0, 1).unsqueeze(0).to(device=tensor.device).float()
        return q_tensor, "rtl_fixed_q14_bicubic_x4"

    base = F.interpolate(tensor, scale_factor=scale, mode="bicubic", align_corners=False)
    return quantize_float(base, scales["input"], plan), "pytorch_bicubic_fallback"


def run_block(q_in: torch.Tensor, index: int, layers: dict[str, dict], scales: dict[str, float], root: Path, plan: dict, stats: dict) -> torch.Tensor:
    prefix = f"blocks.{index}"
    q_c1 = conv2d_integer(q_in, layers[f"{prefix}.c1"], root, plan)
    stats[f"{prefix}.c1.output"] = stage_stats(q_c1)
    q_act1 = quantize_float(F.silu(dequantize(q_c1, scales[f"{prefix}.c1.output"])), scales[f"{prefix}.act1"], plan)
    stats[f"{prefix}.act1"] = stage_stats(q_act1)

    q_c2 = conv2d_integer(q_act1, layers[f"{prefix}.c2"], root, plan)
    stats[f"{prefix}.c2.output"] = stage_stats(q_c2)
    q_act2 = quantize_float(F.silu(dequantize(q_c2, scales[f"{prefix}.c2.output"])), scales[f"{prefix}.act2"], plan)
    stats[f"{prefix}.act2"] = stage_stats(q_act2)

    q_c3 = conv2d_integer(q_act2, layers[f"{prefix}.c3"], root, plan)
    stats[f"{prefix}.c3.output"] = stage_stats(q_c3)
    q_sum = requant_add(q_c3, scales[f"{prefix}.c3.output"], q_in, scales[f"{prefix}.c3.input"], scales[f"{prefix}.residual_sum"], plan)
    stats[f"{prefix}.residual_sum"] = stage_stats(q_sum)
    q_att = quantize_float(torch.sigmoid(dequantize(q_c3, scales[f"{prefix}.c3.output"])) - 0.5, scales[f"{prefix}.sim_att"], plan)
    stats[f"{prefix}.sim_att"] = stage_stats(q_att)
    q_out = requant_mul(q_sum, scales[f"{prefix}.residual_sum"], q_att, scales[f"{prefix}.sim_att"], scales[f"{prefix}.out"], plan)
    stats[f"{prefix}.out"] = stage_stats(q_out)
    return q_out


def run_integer_reference(plan: dict, quant_plan_path: Path, tensor: torch.Tensor) -> tuple[torch.Tensor, dict]:
    root = quant_plan_path.parent
    scales = {name: float(value) for name, value in plan["activation_scale_table"].items()}
    layers = layer_map(plan)
    stats: dict[str, dict] = {}

    q_input = quantize_float(tensor, scales["input"], plan)
    stats["input"] = stage_stats(q_input)
    q_head = conv2d_integer(q_input, layers["head"], root, plan)
    stats["head.output"] = stage_stats(q_head)

    feats: list[torch.Tensor] = []
    q = q_head
    for index in range(int(plan["num_blocks"])):
        q = run_block(q, index, layers, scales, root, plan, stats)
        feats.append(q)

    q_tail = conv2d_integer(feats[-1], layers["fuse_tail"], root, plan)
    stats["fuse_tail.output"] = stage_stats(q_tail)
    concat_scale = scales["reconstruct.input"]
    q_concat = torch.cat(
        [
            requant_scale(q_head, scales["head.output"], concat_scale, plan),
            requant_scale(feats[0], scales["blocks.0.out"], concat_scale, plan),
            requant_scale(feats[min(4, len(feats) - 1)], scales[f"blocks.{min(4, len(feats) - 1)}.out"], concat_scale, plan),
            requant_scale(q_tail, scales["fuse_tail.output"], concat_scale, plan),
        ],
        dim=1,
    )
    stats["reconstruct.input"] = stage_stats(q_concat)
    q_reconstruct = conv2d_integer(q_concat, layers["reconstruct"], root, plan)
    stats["reconstruct.output"] = stage_stats(q_reconstruct)
    q_sr = F.pixel_shuffle(q_reconstruct.float(), int(plan["scale"]))
    q_sr = requant_scale(q_sr, scales["reconstruct.output"], scales["pixelshuffle.output"], plan)
    stats["pixelshuffle.output"] = stage_stats(q_sr)

    q_base, base_reference_mode = quantized_bicubic_base(tensor, scales, plan)
    stats["base.input"] = stage_stats(q_base)
    q_out = requant_add(q_sr, scales["pixelshuffle.output"], q_base, scales["input"], scales["output"], plan)
    stats["output"] = stage_stats(q_out)
    stats["_base_reference_mode"] = base_reference_mode
    return dequantize(q_out, scales["output"]), stats


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


def compare_images(ref: Image.Image, actual: Image.Image) -> dict:
    diff = ImageChops.difference(ref, actual)
    stat = ImageStat.Stat(diff)
    extrema = [value for channel in stat.extrema for value in channel]
    data = np.frombuffer(diff.tobytes(), dtype=np.uint8)
    mse = float(np.mean(data.astype(np.float32) ** 2))
    return {
        "mismatch_bytes": int(np.count_nonzero(data)),
        "total_bytes": int(data.size),
        "max_channel_diff": int(max(extrema)),
        "mae": float(np.mean(data)),
        "mse": mse,
        "psnr_db": float("inf") if mse == 0 else float(20.0 * np.log10(255.0 / np.sqrt(mse))),
    }


def fit_tile(img: Image.Image, tile: int) -> Image.Image:
    fitted = img.copy()
    fitted.thumbnail((tile, tile), Image.Resampling.BICUBIC)
    canvas = Image.new("RGB", (tile, tile), (18, 22, 28))
    canvas.paste(fitted, ((tile - fitted.width) // 2, (tile - fitted.height) // 2))
    return canvas


def make_preview(path: Path, input_img: Image.Image, pytorch: Image.Image, fake: Image.Image, integer: Image.Image, metrics: dict, tile: int) -> None:
    diff = ImageChops.difference(fake, integer).point(lambda value: min(255, value * 16))
    panels = [
        (f"Input {input_img.width}x{input_img.height}", fit_tile(input_img, tile)),
        (f"PyTorch {pytorch.width}x{pytorch.height}", fit_tile(pytorch, tile)),
        ("Fake W8A8", fit_tile(fake, tile)),
        ("Integer W8A8", fit_tile(integer, tile)),
        ("Fake/Int Diff x16", fit_tile(diff, tile)),
    ]
    label_h = 28
    title_h = 42
    summary_h = 36
    gap = 12
    canvas = Image.new(
        "RGB",
        (len(panels) * tile + (len(panels) + 1) * gap, title_h + label_h + tile + summary_h + 2 * gap),
        (246, 248, 250),
    )
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), "TinySPAN W8A8 fake reference vs plan-driven integer reference", fill=(20, 24, 31))
    item = metrics["fake_vs_integer"]
    summary = f"fake/int mismatch {item['mismatch_bytes']}/{item['total_bytes']}, MAE {item['mae']:.3f}, PSNR {item['psnr_db']:.3f} dB, max diff {item['max_channel_diff']}"
    draw.text((gap, canvas.height - summary_h + 8), summary, fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def write_summary(path: Path, summary: dict) -> None:
    lines = [
        "# TinySPAN W8A8 Integer Reference",
        "",
        f"Input: `{summary['input']}`",
        f"Quant plan: `{summary['quant_plan']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## Image Metrics",
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
            "## Stage Snapshot",
            "",
            "| Stage | q min | q max | zero frac | sat - | sat + |",
            "| --- | ---: | ---: | ---: | ---: | ---: |",
        ]
    )
    for name, item in summary["stage_stats"].items():
        lines.append(
            f"| `{name}` | `{item['q_min']}` | `{item['q_max']}` | `{item['zero_frac']:.4f}` | "
            f"`{item['sat_neg_frac']:.4f}` | `{item['sat_pos_frac']:.4f}` |"
        )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "This reference consumes `tinyspan_w8a8_quant_plan.json` directly. Convolutions use exported int8 weights, int64 bias, and Q31 requant constants. Postprocess nodes use the calibrated activation scales and quantize back to int8 at each named boundary. Remaining differences against the fake W8A8 reference show the gap introduced by integer add/multiply/base-add scheduling and Q31 requantization.",
            "",
            f"Base reference mode: `{summary['base_reference_mode']}`. For X4, the software fixed-point base branch is RTL-isomorphic with the Q14 integer bicubic path used by the hardware; PyTorch bicubic remains a visual/quality reference only.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a TinySPAN W8A8 integer-style reference from a quant plan.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--tile", type=int, default=160)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    plan = load_json(args.quant_plan)
    checkpoint = args.checkpoint or Path(plan["source_checkpoint"])
    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    tensor, input_img = manifest_ref.image_to_tensor(args.input, args.width, args.height, device)
    original = manifest_ref.build_original_model(checkpoint, int(plan["scale"]), int(plan["channels"]), int(plan["num_blocks"]), device)
    manifest = manifest_ref.load_manifest(Path(plan["manifest"]))
    manifest_model = manifest_ref.build_fused_model_from_manifest(Path(plan["manifest"]), manifest, device)

    pytorch_out = manifest_ref.run_model(original, tensor)
    fake_out, _ = manifest_ref.run_manifest_reference(
        manifest_model,
        tensor,
        quant_activations=True,
        activation_bits=int(plan["activation_bits"]),
        activation_scales=plan["activation_scale_table"],
    )
    integer_out, stats = run_integer_reference(plan, args.quant_plan, tensor)
    base_reference_mode = str(stats.pop("_base_reference_mode", "unknown"))

    pytorch_img = tensor_to_image(pytorch_out)
    fake_img = tensor_to_image(fake_out)
    integer_img = tensor_to_image(integer_out)
    pytorch_img.save(args.out_dir / "pytorch_tinyspan.png")
    fake_img.save(args.out_dir / "fake_w8a8_tinyspan.png")
    integer_img.save(args.out_dir / "integer_w8a8_tinyspan.png")
    metrics = {
        "pytorch_vs_fake": compare_images(pytorch_img, fake_img),
        "pytorch_vs_integer": compare_images(pytorch_img, integer_img),
        "fake_vs_integer": compare_images(fake_img, integer_img),
    }
    preview = args.out_dir / "tinyspan_w8a8_integer_reference_preview.png"
    make_preview(preview, input_img, pytorch_img, fake_img, integer_img, metrics, args.tile)
    summary = {
        "input": str(args.input),
        "quant_plan": str(args.quant_plan),
        "checkpoint": str(checkpoint),
        "width": args.width,
        "height": args.height,
        "preview": str(preview),
        "base_reference_mode": base_reference_mode,
        "metrics": metrics,
        "stage_stats": stats,
    }
    (args.out_dir / "tinyspan_w8a8_integer_reference_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_summary(args.out_dir / "tinyspan_w8a8_integer_reference_summary.md", summary)
    print(json.dumps({"summary": str(args.out_dir / "tinyspan_w8a8_integer_reference_summary.md"), "preview": str(preview), "metrics": metrics["fake_vs_integer"]}, indent=2))


if __name__ == "__main__":
    main()
