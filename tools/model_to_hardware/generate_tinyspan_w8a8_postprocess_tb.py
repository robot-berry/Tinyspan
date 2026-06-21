"""Generate TinySPAN W8A8 postprocess vector testbench and preview."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw


SAMPLES = [-128, -96, -64, -17, -1, 0, 1, 13, 37, 64, 96, 127]


def clamp_i8(value: int) -> int:
    return max(-128, min(127, int(value)))


def q31(value: float) -> dict:
    shift = 31
    multiplier = int(round(value * (1 << shift)))
    if value > 0.0 and multiplier < 1:
        multiplier = 1
    return {"real_multiplier": float(value), "multiplier_q31": multiplier, "shift": shift}


def round_shift(value: int, shift: int) -> int:
    if shift <= 0:
        return value
    offset = 1 << (shift - 1)
    if value >= 0:
        value += offset
    else:
        value -= offset
    return value >> shift


def requant_add_q31(a: int, b: int, a_q31: int, b_q31: int, shift: int = 31) -> int:
    return clamp_i8(round_shift(a * a_q31 + b * b_q31, shift))


def requant_mul_q31(a: int, b: int, mul_q31: int, shift: int = 31) -> int:
    return clamp_i8(round_shift(a * b * mul_q31, shift))


def silu(x: float) -> float:
    return x / (1.0 + math.exp(-x))


def quantize(value: float, scale: float) -> int:
    return clamp_i8(round(value / scale))


def hex_line(value: int, bits: int) -> str:
    return f"{value & ((1 << bits) - 1):0{(bits + 3) // 4}x}"


def sv_literal(value: int, bits: int = 8) -> str:
    return f"{bits}'h{value & ((1 << bits) - 1):0{(bits + 3) // 4}x}"


def write_lut(path: Path, values: list[int]) -> None:
    path.write_text("\n".join(hex_line(v, 8) for v in values) + "\n", encoding="ascii")


def make_luts(scales: dict[str, float], block: str, out_dir: Path) -> dict[str, str]:
    x_values = list(range(-128, 128))
    act1 = [quantize(silu(x * scales[f"{block}.c1.output"]), scales[f"{block}.act1"]) for x in x_values]
    act2 = [quantize(silu(x * scales[f"{block}.c2.output"]), scales[f"{block}.act2"]) for x in x_values]
    sim_att = [quantize((1.0 / (1.0 + math.exp(-(x * scales[f"{block}.c3.output"])))) - 0.5, scales[f"{block}.sim_att"]) for x in x_values]
    files = {}
    for name, values in ((f"{block}.act1", act1), (f"{block}.act2", act2), (f"{block}.sim_att", sim_att)):
        safe = name.replace(".", "_")
        path = out_dir / f"{safe}_lut_i8.mem"
        write_lut(path, values)
        files[name] = str(path.resolve()).replace("\\", "/")
    return files


def vector_tile(values: list[int], tile: int) -> Image.Image:
    side = 1
    while side * side < len(values):
        side += 1
    img = Image.new("RGB", (side, side), (0, 0, 0))
    pix = []
    neg = max(1, abs(min(values or [0])))
    pos = max(1, max(values or [1]))
    for idx in range(side * side):
        v = values[idx] if idx < len(values) else 0
        if v >= 0:
            pix.append((int(v * 255 / pos), 72, 32))
        else:
            pix.append((32, 72, int(-v * 255 / neg)))
    img.putdata(pix)
    return img.resize((tile, tile), Image.Resampling.NEAREST)


def make_preview(path: Path, vectors: dict, tile: int) -> None:
    panels = [
        ("act1", vector_tile([v["expected"] for v in vectors["act1"]], tile)),
        ("act2", vector_tile([v["expected"] for v in vectors["act2"]], tile)),
        ("residual_sum", vector_tile([v["expected"] for v in vectors["residual_sum"]], tile)),
        ("sim_att", vector_tile([v["expected"] for v in vectors["sim_att"]], tile)),
        ("attention_mul", vector_tile([v["expected"] for v in vectors["attention_mul"]], tile)),
    ]
    gap = 12
    title_h = 42
    label_h = 28
    summary_h = 34
    canvas = Image.new("RGB", (len(panels) * tile + (len(panels) + 1) * gap, title_h + label_h + tile + summary_h + 2 * gap), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), "TinySPAN W8A8 postprocess vector RTL preview", fill=(20, 24, 31))
    draw.text((gap, canvas.height - summary_h + 8), "RTL expected vectors generated from calibrated scales; xsim PASS means mismatch 0", fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def render_tb(block: str, luts: dict[str, str], vectors: dict, constants: dict) -> str:
    checks = []
    for v in vectors["act1"]:
        checks.extend(
            [
                f"        x = {sv_literal(v['x'])}; #1;",
                f"        if (act1_o !== {sv_literal(v['expected'])}) begin $display(\"MISMATCH act1 x=%0d got=%0d expected=%0d\", $signed(x), $signed(act1_o), $signed({sv_literal(v['expected'])})); mismatches++; end",
            ]
        )
    for v in vectors["act2"]:
        checks.extend(
            [
                f"        x = {sv_literal(v['x'])}; #1;",
                f"        if (act2_o !== {sv_literal(v['expected'])}) begin $display(\"MISMATCH act2 x=%0d got=%0d expected=%0d\", $signed(x), $signed(act2_o), $signed({sv_literal(v['expected'])})); mismatches++; end",
            ]
        )
    for v in vectors["sim_att"]:
        checks.extend(
            [
                f"        x = {sv_literal(v['x'])}; #1;",
                f"        if (sim_att_o !== {sv_literal(v['expected'])}) begin $display(\"MISMATCH sim_att x=%0d got=%0d expected=%0d\", $signed(x), $signed(sim_att_o), $signed({sv_literal(v['expected'])})); mismatches++; end",
            ]
        )
    for v in vectors["residual_sum"]:
        checks.extend(
            [
                f"        a = {sv_literal(v['a'])}; b = {sv_literal(v['b'])}; #1;",
                f"        if (sum_o !== {sv_literal(v['expected'])}) begin $display(\"MISMATCH residual_sum a=%0d b=%0d got=%0d expected=%0d\", $signed(a), $signed(b), $signed(sum_o), $signed({sv_literal(v['expected'])})); mismatches++; end",
            ]
        )
    for v in vectors["attention_mul"]:
        checks.extend(
            [
                f"        a = {sv_literal(v['a'])}; b = {sv_literal(v['b'])}; #1;",
                f"        if (mul_o !== {sv_literal(v['expected'])}) begin $display(\"MISMATCH attention_mul a=%0d b=%0d got=%0d expected=%0d\", $signed(a), $signed(b), $signed(mul_o), $signed({sv_literal(v['expected'])})); mismatches++; end",
            ]
        )
    return f"""`timescale 1ns/1ps

module tb_tinyspan_w8a8_postprocess_{block.replace('.', '_')};
    localparam int ACT_W = 8;

    logic signed [ACT_W-1:0] x;
    logic signed [ACT_W-1:0] a;
    logic signed [ACT_W-1:0] b;
    wire signed [ACT_W-1:0] act1_o;
    wire signed [ACT_W-1:0] act2_o;
    wire signed [ACT_W-1:0] sim_att_o;
    wire signed [ACT_W-1:0] sum_o;
    wire signed [ACT_W-1:0] mul_o;
    int mismatches;

    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("{luts[f'{block}.act1']}")) u_act1 (.x_i(x), .y_o(act1_o));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("{luts[f'{block}.act2']}")) u_act2 (.x_i(x), .y_o(act2_o));
    span_w8a12_unary_lut #(.ACT_W(ACT_W), .LUT_FILE("{luts[f'{block}.sim_att']}")) u_sim_att (.x_i(x), .y_o(sim_att_o));
    span_w8a8_scale_add #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .A_Q31(64'sd{constants['sum_a']['multiplier_q31']}),
        .B_Q31(64'sd{constants['sum_b']['multiplier_q31']})
    ) u_sum (.a_i(a), .b_i(b), .q_o(sum_o));
    span_w8a8_scale_mul #(
        .ACT_W(ACT_W),
        .SHIFT(31),
        .MUL_Q31(64'sd{constants['mul']['multiplier_q31']})
    ) u_mul (.a_i(a), .b_i(b), .q_o(mul_o));

    initial begin
        mismatches = 0;
{chr(10).join(checks)}
        if (mismatches != 0)
            $fatal(1, "TinySPAN W8A8 postprocess mismatch count=%0d", mismatches);
        $display("PASS tinyspan_w8a8_postprocess_{block.replace('.', '_')}");
        $finish;
    end
endmodule
"""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate TinySPAN W8A8 postprocess vectors and TB.")
    parser.add_argument("--quant-plan", type=Path, required=True)
    parser.add_argument("--block", default="blocks.0")
    parser.add_argument("--out-dir", type=Path, default=Path("build/generated_tinyspan_w8a8_postprocess_tb"))
    parser.add_argument("--vectors", type=Path, default=Path("runs/tinyspan_quant_plan/tinyspan_w8a8_postprocess_vectors.json"))
    parser.add_argument("--preview", type=Path, default=Path("runs/tinyspan_quant_plan/tinyspan_w8a8_postprocess_preview.png"))
    parser.add_argument("--tile", type=int, default=144)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    plan = json.loads(args.quant_plan.read_text(encoding="utf-8"))
    scales = {k: float(v) for k, v in plan["activation_scale_table"].items()}
    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.vectors.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    luts = make_luts(scales, args.block, args.out_dir)
    constants = {
        "sum_a": q31(scales[f"{args.block}.c3.output"] / scales[f"{args.block}.residual_sum"]),
        "sum_b": q31(scales[f"{args.block}.c3.input"] / scales[f"{args.block}.residual_sum"]),
        "mul": q31(scales[f"{args.block}.residual_sum"] * scales[f"{args.block}.sim_att"] / scales[f"{args.block}.out"]),
    }
    vectors = {
        "act1": [{"x": x, "expected": quantize(silu(x * scales[f"{args.block}.c1.output"]), scales[f"{args.block}.act1"])} for x in SAMPLES],
        "act2": [{"x": x, "expected": quantize(silu(x * scales[f"{args.block}.c2.output"]), scales[f"{args.block}.act2"])} for x in SAMPLES],
        "sim_att": [{"x": x, "expected": quantize(1.0 / (1.0 + math.exp(-(x * scales[f"{args.block}.c3.output"]))) - 0.5, scales[f"{args.block}.sim_att"])} for x in SAMPLES],
        "residual_sum": [],
        "attention_mul": [],
    }
    for idx, a in enumerate(SAMPLES):
        b = SAMPLES[-(idx + 1)]
        vectors["residual_sum"].append(
            {
                "a": a,
                "b": b,
                "expected": requant_add_q31(a, b, constants["sum_a"]["multiplier_q31"], constants["sum_b"]["multiplier_q31"]),
            }
        )
        vectors["attention_mul"].append(
            {
                "a": a,
                "b": b,
                "expected": requant_mul_q31(a, b, constants["mul"]["multiplier_q31"]),
            }
        )
    tb = args.out_dir / f"tb_tinyspan_w8a8_postprocess_{args.block.replace('.', '_')}.sv"
    tb.write_text(render_tb(args.block, luts, vectors, constants), encoding="ascii")
    output = {
        "quant_plan": str(args.quant_plan),
        "block": args.block,
        "testbench": str(tb),
        "luts": luts,
        "constants": constants,
        "vectors": vectors,
        "preview": str(args.preview),
    }
    args.vectors.write_text(json.dumps(output, indent=2), encoding="utf-8")
    make_preview(args.preview, vectors, args.tile)
    print(json.dumps({"testbench": str(tb), "vectors": str(args.vectors), "preview": str(args.preview)}, indent=2))


if __name__ == "__main__":
    main()
