"""Generate TinySPAN W8A8 conv-layer vector testbenches."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np


def safe_name(name: str) -> str:
    return name.replace(".", "_")


def signed_sv(value: int, bits: int = 8) -> str:
    return f"-{bits}'sd{abs(value)}" if value < 0 else f"{bits}'sd{value}"


def read_i8_bin(path: Path, shape: list[int]) -> np.ndarray:
    data = np.fromfile(path, dtype=np.int8)
    expected = int(np.prod(shape))
    if data.size != expected:
        raise ValueError(f"{path}: got {data.size} values, expected {expected}")
    return data.astype(np.int32).reshape(shape)


def read_i64_bin(path: Path, shape: list[int]) -> np.ndarray:
    data = np.fromfile(path, dtype="<i8")
    expected = int(np.prod(shape))
    if data.size != expected:
        raise ValueError(f"{path}: got {data.size} values, expected {expected}")
    return data.astype(np.int64).reshape(shape)


def requant(acc: int, bias: int, multiplier: int, shift: int, bits: int) -> int:
    product = (int(acc) + int(bias)) * int(multiplier)
    if shift > 0:
        offset = 1 << (shift - 1)
        if product >= 0:
            product += offset
            q = product >> shift
        else:
            q = -(((-product) + offset) >> shift)
    else:
        q = product
    qmin = -(1 << (bits - 1))
    qmax = (1 << (bits - 1)) - 1
    return max(qmin, min(qmax, q))


def layer_params(layer: dict) -> tuple[int, int, int]:
    shape = [int(v) for v in layer["weight_shape"]]
    out_ch = shape[0]
    in_ch = shape[1]
    kernel_taps = int(np.prod(shape[2:]))
    return in_ch, out_ch, kernel_taps


def make_window(layer_name: str, tap_count: int) -> list[int]:
    return [((idx * 37 + len(layer_name) * 11) % 256) - 128 for idx in range(tap_count)]


def conv_vector(layer: dict, root: Path) -> dict:
    in_ch, out_ch, kernel_taps = layer_params(layer)
    tap_count = in_ch * kernel_taps
    weights = read_i8_bin(root / layer["weight_file_i8_bin"], layer["weight_shape"]).reshape(out_ch, tap_count)
    bias = read_i64_bin(root / layer["bias_file_i64_bin"], layer["bias_shape"])
    requant_q31 = [int(item["multiplier_q31"]) for item in layer["requant"]]
    shifts = [int(item["shift"]) for item in layer["requant"]]
    window = make_window(layer["name"], tap_count)
    outputs: list[int] = []
    for channel in range(out_ch):
        acc = int(np.dot(np.asarray(window, dtype=np.int64), weights[channel].astype(np.int64)))
        outputs.append(requant(acc, int(bias[channel]), requant_q31[channel], shifts[channel], int(layer["activation_bits"])))
    return {
        "layer": layer["name"],
        "tap_count": tap_count,
        "in_channels": in_ch,
        "out_channels": out_ch,
        "kernel_taps": kernel_taps,
        "window_values": window,
        "output_values": outputs,
        "output_min": min(outputs),
        "output_max": max(outputs),
    }


def sv_string(path: Path) -> str:
    return str(path.resolve()).replace("\\", "/")


def render_tb(layer: dict, vector: dict, root: Path) -> str:
    name = layer["name"]
    safe = safe_name(name)
    in_ch, out_ch, kernel_taps = layer_params(layer)
    tap_count = vector["tap_count"]
    if tap_count != in_ch * kernel_taps:
        raise ValueError(f"{name}: vector tap count mismatch")

    window_lines = "\n".join(f"            window_values[{idx}] = {signed_sv(value)};" for idx, value in enumerate(vector["window_values"]))
    expected_lines = "\n".join(f"            expected[{idx}] = {signed_sv(value)};" for idx, value in enumerate(vector["output_values"]))
    weight_file = sv_string(root / layer["weight_mem_i8_hex"])
    bias_file = sv_string(root / layer["bias_mem_i64_hex"])
    requant_file = sv_string(root / layer["requant_q31_mem"])
    shift_file = sv_string(root / layer["requant_shift_mem"])
    return f"""`timescale 1ns/1ps

module tb_tinyspan_w8a8_{safe}_vector;
    localparam int IN_CH = {in_ch};
    localparam int OUT_CH = {out_ch};
    localparam int KERNEL_TAPS = {kernel_taps};
    localparam int ACT_W = 8;
    localparam int ACC_W = 48;
    localparam int TAP_COUNT = IN_CH * KERNEL_TAPS;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic s_valid;
    wire s_ready;
    logic signed [ACT_W-1:0] window_values [0:TAP_COUNT-1];
    logic [TAP_COUNT*ACT_W-1:0] window_i;
    wire m_valid;
    logic m_ready;
    wire [OUT_CH*ACT_W-1:0] feat_o;
    logic signed [ACT_W-1:0] expected [0:OUT_CH-1];

    int i;
    int cyc;
    int mismatches;
    logic signed [ACT_W-1:0] got;

    always #5 clk = ~clk;

    span_w8a12_conv_layer #(
        .IN_CH(IN_CH),
        .OUT_CH(OUT_CH),
        .KERNEL_TAPS(KERNEL_TAPS),
        .ACT_W(ACT_W),
        .ACC_W(ACC_W),
        .BIAS_BEFORE_REQUANT(1),
        .WEIGHT_FILE("{weight_file}"),
        .BIAS_I64_FILE("{bias_file}"),
        .REQUANT_Q31_FILE("{requant_file}"),
        .REQUANT_SHIFT_FILE("{shift_file}")
    ) dut (
        .clk(clk),
        .rst(rst),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .window_i(window_i),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .feat_o(feat_o)
    );

    initial begin
        s_valid = 1'b0;
        m_ready = 1'b1;
        window_i = {{TAP_COUNT*ACT_W{{1'b0}}}};
        mismatches = 0;

{window_lines}
{expected_lines}

        for (i = 0; i < TAP_COUNT; i = i + 1)
            window_i[i*ACT_W +: ACT_W] = window_values[i];

        repeat (5) @(posedge clk);
        rst = 1'b0;
        wait (s_ready);
        s_valid = 1'b1;
        @(posedge clk);
        s_valid = 1'b0;

        for (cyc = 0; cyc < 200000; cyc = cyc + 1) begin
            @(posedge clk);
            if (m_valid)
                break;
        end

        if (!m_valid)
            $fatal(1, "timeout waiting for TinySPAN W8A8 {name} output");

        for (i = 0; i < OUT_CH; i = i + 1) begin
            got = feat_o[i*ACT_W +: ACT_W];
            if (got !== expected[i]) begin
                $display("MISMATCH {name} ch=%0d got=%0d expected=%0d", i, got, expected[i]);
                mismatches++;
            end
        end

        if (mismatches != 0)
            $fatal(1, "TinySPAN W8A8 {name} vector mismatch count=%0d", mismatches);

        $display("PASS tinyspan_w8a8_{safe}_vector");
        $finish;
    end
endmodule
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate TinySPAN W8A8 conv vector testbenches.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, default=Path("build/generated_tinyspan_w8a8_conv_vector_tbs"))
    parser.add_argument("--vectors", type=Path, default=Path("runs/tinyspan_quant_plan/tinyspan_w8a8_conv_vectors.json"))
    parser.add_argument("--layers", nargs="+", default=["head", "blocks.0.c1", "reconstruct"])
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.vectors.parent.mkdir(parents=True, exist_ok=True)
    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    layers = {layer["name"]: layer for layer in plan["layers"]}
    root = args.quant_plan.parent
    selected = list(layers) if args.layers == ["all"] else args.layers
    vectors = []
    generated = []
    for name in selected:
        if name not in layers:
            raise KeyError(f"unknown layer: {name}")
        vector = conv_vector(layers[name], root)
        vectors.append(vector)
        tb_path = args.out_dir / f"tb_tinyspan_w8a8_{safe_name(name)}_vector.sv"
        tb_path.write_text(render_tb(layers[name], vector, root), encoding="ascii")
        generated.append(str(tb_path))
    output = {
        "quant_plan": str(args.quant_plan),
        "layers": selected,
        "conv_vectors": vectors,
        "generated": generated,
    }
    args.vectors.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(json.dumps({"vectors": str(args.vectors), "generated": generated}, indent=2))


if __name__ == "__main__":
    main()
