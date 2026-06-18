"""Compare a TinySPAN checkpoint with a fused manifest weight reference."""

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


def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


def import_tinyspan():
    train_root = repo_root() / "train"
    sys.path.insert(0, str(train_root))
    from export_tinyspan_to_rtl import fuse_model_conv3xc
    from span_model import build_model

    return build_model, fuse_model_conv3xc


def read_i8_mem(path: Path, shape: list[int], scale: float) -> torch.Tensor:
    values: list[int] = []
    for raw in path.read_text(encoding="ascii").splitlines():
        text = raw.strip()
        if not text:
            continue
        value = int(text, 16)
        if value >= 128:
            value -= 256
        values.append(value)
    expected = int(np.prod(shape))
    if len(values) != expected:
        raise ValueError(f"{path}: got {len(values)} values, expected {expected}")
    q = torch.tensor(values, dtype=torch.float32).reshape(shape)
    return q * float(scale)


def load_manifest(path: Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if not manifest.get("conv3xc_fused", False):
        raise ValueError("this reference expects a fused TinySPAN manifest")
    return manifest


def load_manifest_state_dict(manifest_path: Path, manifest: dict) -> dict[str, torch.Tensor]:
    root = manifest_path.parent
    state: dict[str, torch.Tensor] = {}
    for item in manifest["weights"]:
        name = item["name"]
        state[name] = read_i8_mem(root / item["file"], item["shape"], float(item["quant_scale"]))
    return state


def build_original_model(checkpoint: Path, scale: int, channels: int, blocks: int, device: torch.device) -> torch.nn.Module:
    build_model, _ = import_tinyspan()
    ckpt = torch.load(checkpoint, map_location="cpu")
    model = build_model(scale=scale, channels=channels, num_blocks=blocks)
    model.load_state_dict(ckpt["model"], strict=True)
    model.eval().to(device)
    return model


def build_fused_model_from_checkpoint(checkpoint: Path, scale: int, channels: int, blocks: int, device: torch.device) -> torch.nn.Module:
    build_model, fuse_model_conv3xc = import_tinyspan()
    ckpt = torch.load(checkpoint, map_location="cpu")
    model = build_model(scale=scale, channels=channels, num_blocks=blocks)
    model.load_state_dict(ckpt["model"], strict=True)
    fuse_model_conv3xc(model)
    model.eval().to(device)
    return model


def build_fused_model_from_manifest(manifest_path: Path, manifest: dict, device: torch.device) -> torch.nn.Module:
    build_model, fuse_model_conv3xc = import_tinyspan()
    model = build_model(
        scale=int(manifest["scale"]),
        channels=int(manifest["channels"]),
        num_blocks=int(manifest["num_blocks"]),
    )
    fuse_model_conv3xc(model)
    state = load_manifest_state_dict(manifest_path, manifest)
    missing, unexpected = model.load_state_dict(state, strict=False)
    if missing or unexpected:
        raise ValueError(f"manifest state mismatch: missing={missing}, unexpected={unexpected}")
    model.eval().to(device)
    return model


def image_to_tensor(path: Path, width: int, height: int, device: torch.device) -> tuple[torch.Tensor, Image.Image]:
    img = Image.open(path).convert("RGB").resize((width, height), Image.Resampling.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    tensor = torch.from_numpy(arr).permute(2, 0, 1).unsqueeze(0).to(device)
    return tensor, img


def tensor_to_image(tensor: torch.Tensor) -> Image.Image:
    arr = tensor.detach().float().clamp(0, 1).squeeze(0).permute(1, 2, 0).cpu().numpy()
    return Image.fromarray(np.rint(arr * 255.0).astype(np.uint8), "RGB")


def qparams_symmetric(tensor: torch.Tensor, bits: int = 8) -> tuple[torch.Tensor, int, int]:
    qmin = -(2 ** (bits - 1))
    qmax = 2 ** (bits - 1) - 1
    max_abs = tensor.detach().float().abs().max()
    scale = torch.clamp(max_abs / float(qmax), min=1e-12)
    return scale, qmin, qmax


def fake_quant_symmetric(
    tensor: torch.Tensor,
    name: str,
    scales: dict,
    *,
    bits: int,
    enabled: bool,
) -> torch.Tensor:
    if not enabled:
        scales[name] = {"enabled": False}
        return tensor
    qmin = -(2 ** (bits - 1))
    qmax = 2 ** (bits - 1) - 1
    overrides = scales.get("__overrides__", {})
    override = overrides.get(name)
    if override is None:
        scale, qmin, qmax = qparams_symmetric(tensor, bits=bits)
    else:
        scale = torch.as_tensor(float(override), dtype=tensor.dtype, device=tensor.device)
    q = torch.clamp(torch.round(tensor / scale), qmin, qmax)
    dq = q * scale
    q_float = q.detach().float()
    scales[name] = {
        "enabled": True,
        "override": override is not None,
        "bits": bits,
        "scale_min": float(scale.detach().cpu()),
        "scale_max": float(scale.detach().cpu()),
        "q_min": float(q_float.min().cpu()),
        "q_max": float(q_float.max().cpu()),
        "zero_frac": float((q_float == 0).float().mean().cpu()),
        "sat_neg_frac": float((q_float <= qmin).float().mean().cpu()),
        "sat_pos_frac": float((q_float >= qmax).float().mean().cpu()),
    }
    return dq


def qconv2d(
    x: torch.Tensor,
    conv: torch.nn.Conv2d,
    name: str,
    scales: dict,
    *,
    activation_bits: int,
    quant_activations: bool,
) -> torch.Tensor:
    xq = fake_quant_symmetric(x, f"{name}.input", scales, bits=activation_bits, enabled=quant_activations)
    y = F.conv2d(xq, conv.weight, conv.bias, stride=conv.stride, padding=conv.padding, dilation=conv.dilation, groups=conv.groups)
    return fake_quant_symmetric(y, f"{name}.output", scales, bits=activation_bits, enabled=quant_activations)


def run_fused_block_ptq(
    x: torch.Tensor,
    block: torch.nn.Module,
    prefix: str,
    scales: dict,
    *,
    activation_bits: int,
    quant_activations: bool,
) -> torch.Tensor:
    out1 = qconv2d(x, block.c1.conv, f"{prefix}.c1", scales, activation_bits=activation_bits, quant_activations=quant_activations)
    out1 = F.silu(out1)
    out1 = fake_quant_symmetric(out1, f"{prefix}.act1", scales, bits=activation_bits, enabled=quant_activations)

    out2 = qconv2d(out1, block.c2.conv, f"{prefix}.c2", scales, activation_bits=activation_bits, quant_activations=quant_activations)
    out2 = F.silu(out2)
    out2 = fake_quant_symmetric(out2, f"{prefix}.act2", scales, bits=activation_bits, enabled=quant_activations)

    h = qconv2d(out2, block.c3.conv, f"{prefix}.c3", scales, activation_bits=activation_bits, quant_activations=quant_activations)
    residual_sum = h + x
    residual_sum = fake_quant_symmetric(residual_sum, f"{prefix}.residual_sum", scales, bits=activation_bits, enabled=quant_activations)
    att = torch.sigmoid(h) - 0.5
    att = fake_quant_symmetric(att, f"{prefix}.sim_att", scales, bits=activation_bits, enabled=quant_activations)
    out = residual_sum * att
    return fake_quant_symmetric(out, f"{prefix}.out", scales, bits=activation_bits, enabled=quant_activations)


def run_manifest_reference(
    model: torch.nn.Module,
    tensor: torch.Tensor,
    *,
    quant_activations: bool,
    activation_bits: int,
    activation_scales: dict | None = None,
) -> tuple[torch.Tensor, dict]:
    scales: dict = {"__overrides__": activation_scales or {}}
    with torch.inference_mode():
        base = F.interpolate(tensor, scale_factor=model.scale, mode="bicubic", align_corners=False)
        xq = fake_quant_symmetric(tensor, "input", scales, bits=activation_bits, enabled=quant_activations)
        feat0 = qconv2d(xq, model.head, "head", scales, activation_bits=activation_bits, quant_activations=quant_activations)
        feats: list[torch.Tensor] = []
        out = feat0
        for index, block in enumerate(model.blocks):
            out = run_fused_block_ptq(
                out,
                block,
                f"blocks.{index}",
                scales,
                activation_bits=activation_bits,
                quant_activations=quant_activations,
            )
            feats.append(out)

        early = feats[0]
        deep_index = min(4, len(feats) - 1)
        deep = feats[deep_index]
        fused_tail = qconv2d(feats[-1], model.fuse_tail, "fuse_tail", scales, activation_bits=activation_bits, quant_activations=quant_activations)
        concat = torch.cat([feat0, early, deep, fused_tail], dim=1)
        concat = fake_quant_symmetric(concat, "reconstruct.input", scales, bits=activation_bits, enabled=quant_activations)
        sr = qconv2d(concat, model.reconstruct, "reconstruct", scales, activation_bits=activation_bits, quant_activations=quant_activations)
        sr = model.upsample(sr)
        sr = fake_quant_symmetric(sr, "pixelshuffle.output", scales, bits=activation_bits, enabled=quant_activations)
        out_img = base + sr
        out_img = fake_quant_symmetric(out_img, "output", scales, bits=activation_bits, enabled=quant_activations)
    return out_img, scales


def run_model(model: torch.nn.Module, tensor: torch.Tensor) -> torch.Tensor:
    with torch.inference_mode():
        return model(tensor)


def compare_tensors(ref: torch.Tensor, actual: torch.Tensor, crop: int = 0) -> dict:
    a = ref.detach().float()
    b = actual.detach().float()
    if crop > 0 and a.shape[-1] > crop * 2 and a.shape[-2] > crop * 2:
        a = a[..., crop:-crop, crop:-crop]
        b = b[..., crop:-crop, crop:-crop]
    diff = (a - b).abs()
    mse = float(torch.mean((a - b) ** 2).cpu())
    return {
        "values": int(diff.numel()),
        "max_abs": float(diff.max().cpu()),
        "mae": float(diff.mean().cpu()),
        "mse": mse,
        "psnr_db": float("inf") if mse == 0 else float(20.0 * np.log10(1.0 / np.sqrt(mse))),
    }


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


def make_preview(
    path: Path,
    input_img: Image.Image,
    pytorch_img: Image.Image,
    fused_img: Image.Image,
    manifest_img: Image.Image,
    metrics: dict,
    tile: int,
    mode: str,
) -> None:
    diff = ImageChops.difference(pytorch_img, manifest_img).point(lambda value: min(255, value * 16))
    manifest_label = "Manifest W8A8 Ref" if mode == "weight-activation" else "Manifest W8 Ref"
    panels = [
        (f"Input {input_img.width}x{input_img.height}", fit_tile(input_img, tile)),
        (f"PyTorch {pytorch_img.width}x{pytorch_img.height}", fit_tile(pytorch_img, tile)),
        ("Fused FP32", fit_tile(fused_img, tile)),
        (manifest_label, fit_tile(manifest_img, tile)),
        ("Diff x16", fit_tile(diff, tile)),
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
    draw.text((gap, 12), f"TinySPAN software checkpoint vs fused manifest reference ({mode})", fill=(20, 24, 31))
    img_gap = metrics["image_pytorch_vs_manifest"]
    summary = (
        f"manifest mismatch {img_gap['mismatch_bytes']}/{img_gap['total_bytes']}, "
        f"MAE {img_gap['mae']:.3f}, PSNR {img_gap['psnr_db']:.3f} dB, "
        f"max diff {img_gap['max_channel_diff']}"
    )
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
        "# TinySPAN Manifest Reference",
        "",
        f"Input: `{summary['input']}`",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Manifest: `{summary['manifest']}`",
        f"Mode: `{summary['mode']}`",
        f"Activation bits: `{summary['activation_bits']}`",
        f"Activation scales: `{summary['activation_scales']}`",
        f"Output directory: `{summary['out_dir']}`",
        f"Preview: `{summary['preview']}`",
        "",
        "## Image Metrics",
        "",
        "| Pair | mismatch bytes | max diff | MAE | PSNR |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for name in ("image_pytorch_vs_fused", "image_fused_vs_manifest", "image_pytorch_vs_manifest"):
        item = summary["metrics"][name]
        lines.append(
            f"| `{name}` | `{item['mismatch_bytes']} / {item['total_bytes']}` | "
            f"`{item['max_channel_diff']}` | `{item['mae']:.6f}` | `{item['psnr_db']:.6f} dB` |"
        )
    lines.extend(
        [
            "",
            "## Tensor Metrics",
            "",
            "| Pair | region | values | max abs | MAE | PSNR |",
            "| --- | --- | ---: | ---: | ---: | ---: |",
        ]
    )
    for name in ("tensor_pytorch_vs_fused", "tensor_fused_vs_manifest", "tensor_pytorch_vs_manifest"):
        for region, item in summary["metrics"][name].items():
            lines.append(
                f"| `{name}` | `{region}` | `{item['values']}` | `{item['max_abs']:.8f}` | "
                f"`{item['mae']:.8f}` | `{item['psnr_db']:.6f} dB` |"
            )
    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "This reference consumes the fused TinySPAN handoff manifest and its exported int8 `.mem` weights, then dequantizes them with each tensor's exported `quant_scale`. In `weight-activation` mode it also applies symmetric fake-int activation quantization with optional calibrated activation scale overrides. It is still a PyTorch-level reference, but it fixes the scale names and quantization points needed for the integer RTL reference.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run a TinySPAN fused-manifest weight reference.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--width", type=int, required=True)
    parser.add_argument("--height", type=int, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--device", default="auto", choices=("auto", "cuda", "cpu"))
    parser.add_argument("--mode", choices=("weight-ref", "weight-activation"), default="weight-ref")
    parser.add_argument("--activation-scales", type=Path)
    parser.add_argument("--activation-bits", type=int, default=8)
    parser.add_argument("--tile", type=int, default=160)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    manifest = load_manifest(args.manifest)
    checkpoint = args.checkpoint or Path(manifest["source_checkpoint"])
    if args.device == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(args.device)

    scale = int(manifest["scale"])
    channels = int(manifest["channels"])
    blocks = int(manifest["num_blocks"])
    tensor, input_img = image_to_tensor(args.input, args.width, args.height, device)

    original = build_original_model(checkpoint, scale, channels, blocks, device)
    fused = build_fused_model_from_checkpoint(checkpoint, scale, channels, blocks, device)
    manifest_model = build_fused_model_from_manifest(args.manifest, manifest, device)
    activation_scales = None
    if args.activation_scales:
        calibration = json.loads(args.activation_scales.read_text(encoding="utf-8"))
        activation_scales = calibration.get("activation_scales", calibration)

    pytorch_out = run_model(original, tensor)
    fused_out = run_model(fused, tensor)
    if args.mode == "weight-ref":
        manifest_out, scales = run_manifest_reference(
            manifest_model,
            tensor,
            quant_activations=False,
            activation_bits=args.activation_bits,
            activation_scales=None,
        )
    else:
        manifest_out, scales = run_manifest_reference(
            manifest_model,
            tensor,
            quant_activations=True,
            activation_bits=args.activation_bits,
            activation_scales=activation_scales,
        )

    pytorch_img = tensor_to_image(pytorch_out)
    fused_img = tensor_to_image(fused_out)
    manifest_img = tensor_to_image(manifest_out)
    pytorch_img.save(args.out_dir / "pytorch_tinyspan.png")
    fused_img.save(args.out_dir / "fused_fp32_tinyspan.png")
    manifest_img.save(args.out_dir / "manifest_weight_ref_tinyspan.png")

    crop = max(0, scale * 4)
    metrics = {
        "image_pytorch_vs_fused": compare_images(pytorch_img, fused_img),
        "image_fused_vs_manifest": compare_images(fused_img, manifest_img),
        "image_pytorch_vs_manifest": compare_images(pytorch_img, manifest_img),
        "tensor_pytorch_vs_fused": {
            "full": compare_tensors(pytorch_out, fused_out, crop=0),
            f"crop{crop}": compare_tensors(pytorch_out, fused_out, crop=crop),
        },
        "tensor_fused_vs_manifest": {
            "full": compare_tensors(fused_out, manifest_out, crop=0),
            f"crop{crop}": compare_tensors(fused_out, manifest_out, crop=crop),
        },
        "tensor_pytorch_vs_manifest": {
            "full": compare_tensors(pytorch_out, manifest_out, crop=0),
            f"crop{crop}": compare_tensors(pytorch_out, manifest_out, crop=crop),
        },
    }

    preview = args.out_dir / "tinyspan_manifest_reference_preview.png"
    make_preview(preview, input_img, pytorch_img, fused_img, manifest_img, metrics, args.tile, args.mode)

    summary = {
        "input": str(args.input),
        "checkpoint": str(checkpoint),
        "manifest": str(args.manifest),
        "out_dir": str(args.out_dir),
        "scale": scale,
        "channels": channels,
        "num_blocks": blocks,
        "device": str(device),
        "mode": args.mode,
        "activation_bits": args.activation_bits,
        "activation_scales": str(args.activation_scales) if args.activation_scales else None,
        "preview": str(preview),
        "metrics": metrics,
        "scale_order": [key for key in scales.keys() if key != "__overrides__"],
        "scales": {key: value for key, value in scales.items() if key != "__overrides__"},
        "note": "PyTorch-level fused manifest reference; integer requantization RTL constants are still a later export step.",
    }
    (args.out_dir / "tinyspan_manifest_reference_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    write_summary(args.out_dir / "tinyspan_manifest_reference_summary.md", summary)
    print(json.dumps({"summary": str(args.out_dir / "tinyspan_manifest_reference_summary.md"), "preview": str(preview), "metrics": metrics["image_pytorch_vs_manifest"]}, indent=2))


if __name__ == "__main__":
    main()
