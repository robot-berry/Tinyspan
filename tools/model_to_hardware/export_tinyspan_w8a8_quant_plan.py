"""Export hardware-oriented W8A8 constants for a fused TinySPAN manifest."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import numpy as np

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_i8_mem(path: Path, shape: list[int]) -> np.ndarray:
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
    return np.asarray(values, dtype=np.int8).reshape(shape)


def write_i8_bin(path: Path, values: np.ndarray) -> None:
    path.write_bytes(values.astype(np.int8).reshape(-1).tobytes())


def write_i64_bin(path: Path, values: np.ndarray) -> None:
    path.write_bytes(values.astype("<i8").reshape(-1).tobytes())


def write_hex_mem(path: Path, values: list[int], bits: int) -> None:
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    lines = [f"{int(v) & mask:0{width}x}" for v in values]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def tensor_stats(q: np.ndarray) -> dict:
    q32 = q.astype(np.int32)
    return {
        "q_min": int(q32.min()),
        "q_max": int(q32.max()),
        "zero_frac": float(np.mean(q32 == 0)),
        "sat_neg_frac": float(np.mean(q32 <= -128)),
        "sat_pos_frac": float(np.mean(q32 >= 127)),
    }


def ratio_to_q31(value: float) -> dict:
    shift = 31
    multiplier = int(round(float(value) * (1 << shift)))
    if value > 0.0 and multiplier < 1:
        multiplier = 1
    return {
        "real_multiplier": float(value),
        "multiplier_q31": multiplier,
        "shift": shift,
    }


def manifest_items(manifest: dict) -> dict[str, dict]:
    return {item["name"]: item for item in manifest["weights"]}


def conv_specs(num_blocks: int) -> list[dict]:
    specs = [
        {
            "name": "head",
            "weight_name": "head.weight",
            "bias_name": "head.bias",
            "input_scale_ref": "head.input",
            "output_scale_ref": "head.output",
        }
    ]
    for index in range(num_blocks):
        prefix = f"blocks.{index}"
        for conv_name in ("c1", "c2", "c3"):
            specs.append(
                {
                    "name": f"{prefix}.{conv_name}",
                    "weight_name": f"{prefix}.{conv_name}.conv.weight",
                    "bias_name": f"{prefix}.{conv_name}.conv.bias",
                    "input_scale_ref": f"{prefix}.{conv_name}.input",
                    "output_scale_ref": f"{prefix}.{conv_name}.output",
                }
            )
    specs.extend(
        [
            {
                "name": "fuse_tail",
                "weight_name": "fuse_tail.weight",
                "bias_name": "fuse_tail.bias",
                "input_scale_ref": "fuse_tail.input",
                "output_scale_ref": "fuse_tail.output",
            },
            {
                "name": "reconstruct",
                "weight_name": "reconstruct.weight",
                "bias_name": "reconstruct.bias",
                "input_scale_ref": "reconstruct.input",
                "output_scale_ref": "reconstruct.output",
            },
        ]
    )
    return specs


def postprocess_specs(num_blocks: int) -> list[dict]:
    specs: list[dict] = []
    for index in range(num_blocks):
        prefix = f"blocks.{index}"
        specs.extend(
            [
                {
                    "name": f"{prefix}.act1",
                    "kind": "silu",
                    "input_scale_ref": f"{prefix}.c1.output",
                    "output_scale_ref": f"{prefix}.act1",
                },
                {
                    "name": f"{prefix}.act2",
                    "kind": "silu",
                    "input_scale_ref": f"{prefix}.c2.output",
                    "output_scale_ref": f"{prefix}.act2",
                },
                {
                    "name": f"{prefix}.residual_sum",
                    "kind": "add",
                    "input_a_scale_ref": f"{prefix}.c3.output",
                    "input_b_scale_ref": f"{prefix}.c3.input",
                    "output_scale_ref": f"{prefix}.residual_sum",
                },
                {
                    "name": f"{prefix}.sim_att",
                    "kind": "sigmoid_minus_half",
                    "input_scale_ref": f"{prefix}.c3.output",
                    "output_scale_ref": f"{prefix}.sim_att",
                },
                {
                    "name": f"{prefix}.attention_mul",
                    "kind": "multiply",
                    "input_a_scale_ref": f"{prefix}.residual_sum",
                    "input_b_scale_ref": f"{prefix}.sim_att",
                    "output_scale_ref": f"{prefix}.out",
                },
            ]
        )
    specs.extend(
        [
            {
                "name": "pixelshuffle",
                "kind": "pixelshuffle_x4_rgb",
                "input_scale_ref": "reconstruct.output",
                "output_scale_ref": "pixelshuffle.output",
            },
            {
                "name": "base_add",
                "kind": "add_bicubic_base",
                "input_a_scale_ref": "pixelshuffle.output",
                "input_b_scale_ref": "input",
                "output_scale_ref": "output",
            },
        ]
    )
    return specs


def q_scale_table(activation_scales: dict, refs: list[str]) -> dict:
    table = {}
    for ref in refs:
        if ref not in activation_scales:
            raise KeyError(f"missing activation scale: {ref}")
        table[ref] = float(activation_scales[ref])
    return table


def build_layer(
    spec: dict,
    items: dict[str, dict],
    manifest_root: Path,
    activation_scales: dict,
    out_weight_dir: Path,
    activation_bits: int,
    weight_bits: int,
) -> dict:
    weight_item = items[spec["weight_name"]]
    bias_item = items[spec["bias_name"]]
    q_weight = read_i8_mem(manifest_root / weight_item["file"], weight_item["shape"])
    q_bias_export = read_i8_mem(manifest_root / bias_item["file"], bias_item["shape"]).astype(np.float64)
    weight_scale = float(weight_item["quant_scale"])
    bias_export_scale = float(bias_item["quant_scale"])
    bias_fp = q_bias_export * bias_export_scale
    input_scale = float(activation_scales[spec["input_scale_ref"]])
    output_scale = float(activation_scales[spec["output_scale_ref"]])
    bias_scale = input_scale * weight_scale
    bias_q = np.rint(bias_fp / bias_scale).astype(np.int64)
    requant = ratio_to_q31(input_scale * weight_scale / output_scale)
    out_channels = int(q_weight.shape[0])
    safe = spec["name"].replace(".", "_")
    weight_bin = out_weight_dir / f"{safe}_w_i8.bin"
    bias_bin = out_weight_dir / f"{safe}_bias_i64.bin"
    weight_mem = out_weight_dir / f"{safe}_w_i8.mem"
    bias_mem = out_weight_dir / f"{safe}_bias_i64.mem"
    requant_mem = out_weight_dir / f"{safe}_requant_q31.mem"
    shift_mem = out_weight_dir / f"{safe}_requant_shift_u8.mem"
    write_i8_bin(weight_bin, q_weight)
    write_i64_bin(bias_bin, bias_q)
    write_hex_mem(weight_mem, [int(v) for v in q_weight.reshape(-1)], 8)
    write_hex_mem(bias_mem, [int(v) for v in bias_q.reshape(-1)], 64)
    write_hex_mem(requant_mem, [requant["multiplier_q31"]] * out_channels, 32)
    write_hex_mem(shift_mem, [requant["shift"]] * out_channels, 8)
    return {
        "name": spec["name"],
        "weight_name": spec["weight_name"],
        "bias_name": spec["bias_name"],
        "input_scale_ref": spec["input_scale_ref"],
        "output_scale_ref": spec["output_scale_ref"],
        "input_scale": input_scale,
        "output_scale": output_scale,
        "weight_bits": weight_bits,
        "activation_bits": activation_bits,
        "activation_qmin": -(2 ** (activation_bits - 1)),
        "activation_qmax": 2 ** (activation_bits - 1) - 1,
        "weight_shape": list(q_weight.shape),
        "bias_shape": list(q_bias_export.shape),
        "weight_scale": weight_scale,
        "bias_export_scale": bias_export_scale,
        "bias_integer_scale": bias_scale,
        "bias_q_i64_min": int(bias_q.min()),
        "bias_q_i64_max": int(bias_q.max()),
        "requant": [requant for _ in range(out_channels)],
        "requant_numel": out_channels,
        "weight_file_i8_bin": str(weight_bin.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "bias_file_i64_bin": str(bias_bin.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "weight_mem_i8_hex": str(weight_mem.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "bias_mem_i64_hex": str(bias_mem.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "requant_q31_mem": str(requant_mem.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "requant_shift_mem": str(shift_mem.relative_to(out_weight_dir.parent)).replace("\\", "/"),
        "source_weight_mem": weight_item["file"],
        "source_bias_mem": bias_item["file"],
        "quantized_weight_stats": tensor_stats(q_weight),
    }


def write_markdown(path: Path, plan: dict) -> None:
    lines = [
        "# TinySPAN W8A8 Quantization Plan",
        "",
        f"Manifest: `{plan['manifest']}`",
        f"Activation scales: `{plan['activation_scales_file']}`",
        f"Layers: `{plan['layer_count']}`",
        f"Activation tensors: `{plan['activation_scale_count']}`",
        "",
        "## Conv Layers",
        "",
        "| Layer | Input scale | Output scale | Weight scale | Bias q min..max | Requant q31 |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for layer in plan["layers"]:
        rq = layer["requant"][0]
        lines.append(
            f"| `{layer['name']}` | `{layer['input_scale']:.8g}` | `{layer['output_scale']:.8g}` | "
            f"`{layer['weight_scale']:.8g}` | `{layer['bias_q_i64_min']}..{layer['bias_q_i64_max']}` | "
            f"`{rq['multiplier_q31']}` |"
        )
    lines.extend(
        [
            "",
            "## Postprocess Nodes",
            "",
            "| Node | Kind | Output scale |",
            "| --- | --- | ---: |",
        ]
    )
    for node in plan["postprocess"]:
        out_ref = node.get("output_scale_ref")
        out_scale = plan["activation_scale_table"].get(out_ref, "")
        if isinstance(out_scale, float):
            out_text = f"`{out_scale:.8g}`"
        else:
            out_text = ""
        lines.append(f"| `{node['name']}` | `{node['kind']}` | {out_text} |")
    lines.extend(
        [
            "",
            "## RTL Implications",
            "",
            "- Use signed 8-bit activations at the named activation scale points.",
            "- Use the fused int8 weights already exported in the TinySPAN manifest.",
            "- Use per-layer int64 bias constants and Q31 requant constants from this plan.",
            "- Implement SiLU, sigmoid-minus-half, residual add, attention multiply, pixelshuffle, and bicubic-base add against the named calibrated scales.",
            "",
        ]
    )
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export TinySPAN W8A8 fixed-point quantization constants.")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--activation-scales", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--activation-bits", type=int, default=8)
    parser.add_argument("--weight-bits", type=int, default=8)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    manifest = load_json(args.manifest)
    if not manifest.get("conv3xc_fused", False):
        raise SystemExit("TinySPAN W8A8 export requires a fused manifest")
    calibration = load_json(args.activation_scales)
    activation_scales = calibration["activation_scales"]
    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    weight_dir = out_dir / "weights"
    weight_dir.mkdir(exist_ok=True)
    items = manifest_items(manifest)
    refs = sorted(activation_scales)
    layers = [
        build_layer(spec, items, args.manifest.parent, activation_scales, weight_dir, args.activation_bits, args.weight_bits)
        for spec in conv_specs(int(manifest["num_blocks"]))
    ]
    plan = {
        "source": "TinySPAN fused W8A8 hardware quantization plan",
        "manifest": str(args.manifest),
        "source_checkpoint": manifest.get("source_checkpoint"),
        "activation_scales_file": str(args.activation_scales),
        "scale": int(manifest["scale"]),
        "channels": int(manifest["channels"]),
        "num_blocks": int(manifest["num_blocks"]),
        "conv3xc_fused": bool(manifest.get("conv3xc_fused", False)),
        "weight_bits": args.weight_bits,
        "activation_bits": args.activation_bits,
        "activation_qmin": -(2 ** (args.activation_bits - 1)),
        "activation_qmax": 2 ** (args.activation_bits - 1) - 1,
        "layer_count": len(layers),
        "activation_scale_count": len(activation_scales),
        "activation_scale_table": q_scale_table(activation_scales, refs),
        "layers": layers,
        "postprocess": postprocess_specs(int(manifest["num_blocks"])),
        "notes": [
            "Conv target: q_out = round((sum(q_in * q_w) + q_bias) * real_multiplier), with real_multiplier = input_scale * weight_scale / output_scale.",
            "Bias target: q_bias = round(bias_fp32 / (input_scale * weight_scale)).",
            "This plan uses the fused manifest's per-tensor int8 weight scale, matching the current .mem handoff package.",
            "Postprocess nodes must use the named activation scales from activation_scale_table.",
        ],
    }
    out_json = out_dir / "tinyspan_w8a8_quant_plan.json"
    out_json.write_text(json.dumps(plan, indent=2), encoding="utf-8")
    write_markdown(out_dir / "tinyspan_w8a8_quant_plan.md", plan)
    print(json.dumps({"out": str(out_json), "layers": len(layers), "activation_scales": len(activation_scales)}, indent=2))


if __name__ == "__main__":
    main()
