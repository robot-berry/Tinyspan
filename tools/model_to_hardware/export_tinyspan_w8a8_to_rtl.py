#!/usr/bin/env python3
"""Export TinySPAN W8A8 quant-plan constants for RTL integration."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export TinySPAN W8A8 RTL constants.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--out-lanes", type=int, default=8)
    parser.add_argument("--tap-lanes", type=int, default=16)
    return parser.parse_args()


def safe_name(name: str) -> str:
    return name.replace(".", "_").replace("/", "_")


def macro_name(name: str) -> str:
    return safe_name(name).upper()


def sv_path(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/")


def read_hex_bytes(path: Path) -> list[int]:
    values: list[int] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        text = line.strip()
        if not text or text.startswith("//") or text.startswith("#"):
            continue
        values.append(int(text, 16) & 0xFF)
    return values


def pack_weight_groups(input_mem: Path, output_mem: Path, out_ch: int, tap_count: int, out_lanes: int, tap_lanes: int) -> int:
    weights = read_hex_bytes(input_mem)
    expected = out_ch * tap_count
    if len(weights) != expected:
        raise ValueError(f"{input_mem}: expected {expected} scalar weights, found {len(weights)}")

    out_groups = (out_ch + out_lanes - 1) // out_lanes
    tap_groups = (tap_count + tap_lanes - 1) // tap_lanes
    bytes_per_group = out_lanes * tap_lanes
    lines: list[str] = []
    for out_group in range(out_groups):
        for tap_group in range(tap_groups):
            group = [0] * bytes_per_group
            for out_lane in range(out_lanes):
                global_out = out_group * out_lanes + out_lane
                for tap_lane in range(tap_lanes):
                    global_tap = tap_group * tap_lanes + tap_lane
                    lane = out_lane * tap_lanes + tap_lane
                    if global_out < out_ch and global_tap < tap_count:
                        group[lane] = weights[global_out * tap_count + global_tap]
            lines.append("".join(f"{byte:02x}" for byte in reversed(group)))
    output_mem.parent.mkdir(parents=True, exist_ok=True)
    output_mem.write_text("\n".join(lines) + "\n", encoding="ascii")
    return len(lines)


def clamp_i8(value: int) -> int:
    return max(-128, min(127, int(value)))


def quantize(value: float, scale: float) -> int:
    return clamp_i8(round(value / scale))


def silu(x: float) -> float:
    return x / (1.0 + math.exp(-x))


def write_lut(path: Path, values: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(f"{v & 0xff:02x}" for v in values) + "\n", encoding="ascii")


def q31(value: float) -> dict[str, int | float]:
    shift = 31
    multiplier = int(round(float(value) * (1 << shift)))
    if value > 0.0 and multiplier < 1:
        multiplier = 1
    return {"real_multiplier": float(value), "multiplier_q31": multiplier, "shift": shift}


def make_postprocess_exports(plan: dict, out_dir: Path) -> tuple[list[dict], list[str]]:
    scales = {name: float(value) for name, value in plan["activation_scale_table"].items()}
    exports: list[dict] = []
    header_lines: list[str] = []
    x_values = list(range(-128, 128))

    for index in range(int(plan["num_blocks"])):
        block = f"blocks.{index}"
        block_safe = macro_name(block)
        act1 = [quantize(silu(x * scales[f"{block}.c1.output"]), scales[f"{block}.act1"]) for x in x_values]
        act2 = [quantize(silu(x * scales[f"{block}.c2.output"]), scales[f"{block}.act2"]) for x in x_values]
        sim_att = [
            quantize((1.0 / (1.0 + math.exp(-(x * scales[f"{block}.c3.output"])))) - 0.5, scales[f"{block}.sim_att"])
            for x in x_values
        ]
        lut_specs = [
            ("ACT1", f"{block}.act1", act1),
            ("ACT2", f"{block}.act2", act2),
            ("SIM_ATT", f"{block}.sim_att", sim_att),
        ]
        block_export = {"block": block, "luts": {}, "constants": {}}
        for label, tensor_name, values in lut_specs:
            lut_path = out_dir / "postprocess" / f"{safe_name(tensor_name)}_lut_i8.mem"
            write_lut(lut_path, values)
            block_export["luts"][label.lower()] = str(lut_path)
            header_lines.append(f'`define TINYSPAN_W8A8_{block_safe}_{label}_LUT_FILE "{sv_path(lut_path)}"')

        sum_a = q31(scales[f"{block}.c3.output"] / scales[f"{block}.residual_sum"])
        sum_b = q31(scales[f"{block}.c3.input"] / scales[f"{block}.residual_sum"])
        mul = q31(scales[f"{block}.residual_sum"] * scales[f"{block}.sim_att"] / scales[f"{block}.out"])
        block_export["constants"] = {"sum_a": sum_a, "sum_b": sum_b, "mul": mul}
        header_lines.extend(
            [
                f"`define TINYSPAN_W8A8_{block_safe}_SUM_A_Q31 64'sd{sum_a['multiplier_q31']}",
                f"`define TINYSPAN_W8A8_{block_safe}_SUM_B_Q31 64'sd{sum_b['multiplier_q31']}",
                f"`define TINYSPAN_W8A8_{block_safe}_SUM_SHIFT {sum_a['shift']}",
                f"`define TINYSPAN_W8A8_{block_safe}_MUL_Q31 64'sd{mul['multiplier_q31']}",
                f"`define TINYSPAN_W8A8_{block_safe}_MUL_SHIFT {mul['shift']}",
            ]
        )
        exports.append(block_export)
    return exports, header_lines


def main() -> None:
    args = parse_args()
    if args.out_lanes <= 0 or args.tap_lanes <= 0:
        raise ValueError("lane counts must be positive")

    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    root = args.quant_plan.parent
    args.out_dir.mkdir(parents=True, exist_ok=True)
    group_dir = args.out_dir / "mem"

    layer_exports: list[dict] = []
    header_lines = [
        "`ifndef TINYSPAN_W8A8_RTL_LAYERS_VH",
        "`define TINYSPAN_W8A8_RTL_LAYERS_VH",
        "// Auto-generated by tools/export_tinyspan_w8a8_to_rtl.py.",
        f"`define TINYSPAN_W8A8_SCALE {int(plan['scale'])}",
        f"`define TINYSPAN_W8A8_CHANNELS {int(plan['channels'])}",
        f"`define TINYSPAN_W8A8_BLOCKS {int(plan['num_blocks'])}",
        f"`define TINYSPAN_W8A8_ACT_W {int(plan['activation_bits'])}",
        f"`define TINYSPAN_W8A8_OUT_LANES {args.out_lanes}",
        f"`define TINYSPAN_W8A8_TAP_LANES {args.tap_lanes}",
        "",
    ]

    for idx, layer in enumerate(plan["layers"]):
        name = str(layer["name"])
        shape = [int(v) for v in layer["weight_shape"]]
        out_ch = shape[0]
        in_ch = shape[1]
        kernel_taps = 1
        for dim in shape[2:]:
            kernel_taps *= int(dim)
        tap_count = in_ch * kernel_taps
        safe = safe_name(name)
        macro = macro_name(name)
        scalar_weight = root / layer["weight_mem_i8_hex"]
        group_weight = group_dir / f"{safe}_w_i8_group_ol{args.out_lanes}_tl{args.tap_lanes}.mem"
        group_count = pack_weight_groups(scalar_weight, group_weight, out_ch, tap_count, args.out_lanes, args.tap_lanes)

        bias_file = root / layer["bias_mem_i64_hex"]
        requant_file = root / layer["requant_q31_mem"]
        shift_file = root / layer["requant_shift_mem"]
        for file_path in (bias_file, requant_file, shift_file):
            if not file_path.exists():
                raise FileNotFoundError(file_path)

        layer_exports.append(
            {
                "index": idx,
                "name": name,
                "in_channels": in_ch,
                "out_channels": out_ch,
                "kernel_taps": kernel_taps,
                "tap_count": tap_count,
                "group_weight_mem": str(group_weight),
                "group_count": group_count,
                "bias_i64_mem": str(bias_file),
                "requant_q31_mem": str(requant_file),
                "requant_shift_mem": str(shift_file),
            }
        )
        header_lines.extend(
            [
                f"`define TINYSPAN_W8A8_LAYER_{idx}_NAME \"{name}\"",
                f"`define TINYSPAN_W8A8_{macro}_IN_CH {in_ch}",
                f"`define TINYSPAN_W8A8_{macro}_OUT_CH {out_ch}",
                f"`define TINYSPAN_W8A8_{macro}_KERNEL_TAPS {kernel_taps}",
                f"`define TINYSPAN_W8A8_{macro}_TAP_COUNT {tap_count}",
                f'`define TINYSPAN_W8A8_{macro}_WEIGHT_GROUP_FILE "{sv_path(group_weight)}"',
                f'`define TINYSPAN_W8A8_{macro}_BIAS_I64_FILE "{sv_path(bias_file)}"',
                f'`define TINYSPAN_W8A8_{macro}_REQUANT_Q31_FILE "{sv_path(requant_file)}"',
                f'`define TINYSPAN_W8A8_{macro}_REQUANT_SHIFT_FILE "{sv_path(shift_file)}"',
                "",
            ]
        )

    postprocess_exports, postprocess_header = make_postprocess_exports(plan, args.out_dir)
    header_lines.extend(postprocess_header)
    header_lines.extend(["", "`endif", ""])
    header_path = args.out_dir / "tinyspan_w8a8_layers.vh"
    header_path.write_text("\n".join(header_lines), encoding="ascii")

    manifest = {
        "source_quant_plan": str(args.quant_plan),
        "source_checkpoint": plan.get("source_checkpoint", ""),
        "scale": int(plan["scale"]),
        "channels": int(plan["channels"]),
        "num_blocks": int(plan["num_blocks"]),
        "activation_bits": int(plan["activation_bits"]),
        "out_lanes": args.out_lanes,
        "tap_lanes": args.tap_lanes,
        "header": str(header_path),
        "layers": layer_exports,
        "postprocess": postprocess_exports,
    }
    manifest_path = args.out_dir / "tinyspan_w8a8_rtl_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    summary_path = args.out_dir / "tinyspan_w8a8_rtl_export.md"
    summary_path.write_text(
        "# TinySPAN W8A8 RTL Export\n\n"
        f"- source quant plan: `{args.quant_plan}`\n"
        f"- source checkpoint: `{manifest['source_checkpoint']}`\n"
        f"- channels: `{manifest['channels']}`\n"
        f"- blocks: `{manifest['num_blocks']}`\n"
        f"- layer count: `{len(layer_exports)}`\n"
        f"- postprocess block count: `{len(postprocess_exports)}`\n"
        f"- out lanes: `{args.out_lanes}`\n"
        f"- tap lanes: `{args.tap_lanes}`\n"
        f"- header: `{header_path}`\n"
        f"- manifest: `{manifest_path}`\n",
        encoding="utf-8",
    )
    print(json.dumps({"manifest": str(manifest_path), "header": str(header_path), "summary": str(summary_path)}, indent=2))


if __name__ == "__main__":
    main()
