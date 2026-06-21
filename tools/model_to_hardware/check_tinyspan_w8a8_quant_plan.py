"""Validate TinySPAN W8A8 quantization-plan files and scale references."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def hex_line_count(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="ascii").splitlines() if line.strip())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Check a TinySPAN W8A8 quantization plan.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    root = args.quant_plan.parent
    activation_scales = plan["activation_scale_table"]
    require(plan.get("conv3xc_fused") is True, "plan must target a fused TinySPAN manifest")
    require(int(plan["weight_bits"]) == 8, "weight_bits must be 8")
    require(int(plan["activation_bits"]) == 8, "activation_bits must be 8")
    require(int(plan["layer_count"]) == len(plan["layers"]), "layer_count mismatch")
    require(int(plan["activation_scale_count"]) == len(activation_scales), "activation_scale_count mismatch")

    for layer in plan["layers"]:
        name = layer["name"]
        require(layer["input_scale_ref"] in activation_scales, f"{name}: missing input scale")
        require(layer["output_scale_ref"] in activation_scales, f"{name}: missing output scale")
        require(float(layer["input_scale"]) == float(activation_scales[layer["input_scale_ref"]]), f"{name}: input scale mismatch")
        require(float(layer["output_scale"]) == float(activation_scales[layer["output_scale_ref"]]), f"{name}: output scale mismatch")
        weight_shape = [int(v) for v in layer["weight_shape"]]
        out_channels = weight_shape[0]
        weight_count = int(np.prod(weight_shape))
        bias_count = int(np.prod([int(v) for v in layer["bias_shape"]]))
        require(bias_count == out_channels, f"{name}: bias/out-channel mismatch")
        weight_path = root / layer["weight_file_i8_bin"]
        bias_path = root / layer["bias_file_i64_bin"]
        weight_mem_path = root / layer["weight_mem_i8_hex"]
        bias_mem_path = root / layer["bias_mem_i64_hex"]
        requant_path = root / layer["requant_q31_mem"]
        shift_path = root / layer["requant_shift_mem"]
        require(weight_path.exists(), f"{name}: missing weight file")
        require(bias_path.exists(), f"{name}: missing bias file")
        require(weight_mem_path.exists(), f"{name}: missing weight hex mem")
        require(bias_mem_path.exists(), f"{name}: missing bias hex mem")
        require(requant_path.exists(), f"{name}: missing requant file")
        require(shift_path.exists(), f"{name}: missing shift file")
        require(weight_path.stat().st_size == weight_count, f"{name}: weight file size mismatch")
        require(bias_path.stat().st_size == bias_count * 8, f"{name}: bias file size mismatch")
        require(hex_line_count(weight_mem_path) == weight_count, f"{name}: weight hex line count mismatch")
        require(hex_line_count(bias_mem_path) == bias_count, f"{name}: bias hex line count mismatch")
        require(hex_line_count(requant_path) == out_channels, f"{name}: requant line count mismatch")
        require(hex_line_count(shift_path) == out_channels, f"{name}: shift line count mismatch")
        require(len(layer["requant"]) == out_channels, f"{name}: requant metadata count mismatch")
        for rq in layer["requant"]:
            require(int(rq["shift"]) == 31, f"{name}: unexpected requant shift")
            require(int(rq["multiplier_q31"]) > 0, f"{name}: non-positive requant multiplier")
            require(float(rq["real_multiplier"]) > 0.0, f"{name}: non-positive real multiplier")

    for node in plan["postprocess"]:
        for key, value in node.items():
            if key.endswith("_scale_ref"):
                require(value in activation_scales, f"{node['name']}: missing scale ref {value}")

    print(
        json.dumps(
            {
                "quant_plan": str(args.quant_plan),
                "layers": len(plan["layers"]),
                "postprocess": len(plan["postprocess"]),
                "activation_scales": len(activation_scales),
                "status": "PASS",
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
