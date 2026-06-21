"""Estimate TinySPAN-family realtime candidates for hardware testing.

This is a sizing tool for choosing the next software-trained student model.
It does not train a model. It estimates both the training graph cost and the
expected fused deployment cost from `train/span_model.py`.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class Candidate:
    scale: int
    channels: int
    blocks: int
    fused_macs_per_lr_pixel: int
    unfused_macs_per_lr_pixel: int
    fused_params: int
    unfused_params: int
    fused_720p30_dsp_packed_200mhz_80p: int
    fused_720p30_fps_200mhz_80p: float
    fused_720p60_fps_200mhz_80p: float
    fused_1080p30_fps_200mhz_80p: float
    fused_720p30_dsp_packed_250mhz_80p: int
    fused_720p30_fps_250mhz_80p: float
    realtime_720p30_200mhz_80p: bool
    realtime_720p60_250mhz_80p: bool
    quality_proxy: int


def conv2d_macs(in_ch: int, out_ch: int, kernel: int) -> int:
    return in_ch * out_ch * kernel * kernel


def conv2d_params(in_ch: int, out_ch: int, kernel: int, bias: bool = True) -> int:
    return conv2d_macs(in_ch, out_ch, kernel) + (out_ch if bias else 0)


def tinyspan_cost(scale: int, channels: int, blocks: int) -> tuple[int, int, int, int]:
    c = channels
    hidden = c * 2

    head_macs = conv2d_macs(3, c, 3)
    head_params = conv2d_params(3, c, 3)

    # Conv3XC training graph: 1x1 C->2C, 3x3 2C->2C, 1x1 2C->C, skip 1x1 C->C.
    conv3xc_unfused_macs = (
        conv2d_macs(c, hidden, 1)
        + conv2d_macs(hidden, hidden, 3)
        + conv2d_macs(hidden, c, 1)
        + conv2d_macs(c, c, 1)
    )
    conv3xc_unfused_params = (
        conv2d_params(c, hidden, 1)
        + conv2d_params(hidden, hidden, 3)
        + conv2d_params(hidden, c, 1)
        + conv2d_params(c, c, 1)
    )

    # Deployment target after offline fusing Conv3XC into one 3x3 C->C kernel.
    conv3xc_fused_macs = conv2d_macs(c, c, 3)
    conv3xc_fused_params = conv2d_params(c, c, 3)

    spab_unfused_macs = 3 * conv3xc_unfused_macs
    spab_unfused_params = 3 * conv3xc_unfused_params
    spab_fused_macs = 3 * conv3xc_fused_macs
    spab_fused_params = 3 * conv3xc_fused_params

    fuse_tail_macs = conv2d_macs(c, c, 3)
    fuse_tail_params = conv2d_params(c, c, 3)
    reconstruct_out = 3 * scale * scale
    reconstruct_macs = conv2d_macs(c * 4, reconstruct_out, 3)
    reconstruct_params = conv2d_params(c * 4, reconstruct_out, 3)

    fused_macs = head_macs + blocks * spab_fused_macs + fuse_tail_macs + reconstruct_macs
    unfused_macs = head_macs + blocks * spab_unfused_macs + fuse_tail_macs + reconstruct_macs
    fused_params = head_params + blocks * spab_fused_params + fuse_tail_params + reconstruct_params
    unfused_params = head_params + blocks * spab_unfused_params + fuse_tail_params + reconstruct_params
    return fused_macs, unfused_macs, fused_params, unfused_params


def fps_for(
    *,
    macs_per_lr_pixel: int,
    width: int,
    height: int,
    clock_mhz: float,
    dsp_total: int,
    macs_per_dsp: float,
    utilization: float,
) -> float:
    lanes = math.floor(dsp_total * macs_per_dsp * utilization)
    return lanes * clock_mhz * 1_000_000.0 / (macs_per_lr_pixel * width * height)


def dsp_for_target(
    *,
    macs_per_lr_pixel: int,
    width: int,
    height: int,
    fps: float,
    clock_mhz: float,
    macs_per_dsp: float,
) -> int:
    required_macs_s = macs_per_lr_pixel * width * height * fps
    required_lanes = math.ceil(required_macs_s / (clock_mhz * 1_000_000.0))
    return math.ceil(required_lanes / macs_per_dsp)


def build_candidates(args: argparse.Namespace) -> list[Candidate]:
    candidates: list[Candidate] = []
    for channels in args.channels:
        for blocks in args.blocks:
            fused_macs, unfused_macs, fused_params, unfused_params = tinyspan_cost(args.scale, channels, blocks)
            fps_720p30_200 = fps_for(
                macs_per_lr_pixel=fused_macs,
                width=320,
                height=180,
                clock_mhz=200.0,
                dsp_total=args.dsp_total,
                macs_per_dsp=args.macs_per_dsp,
                utilization=0.80,
            )
            fps_720p60_200 = fps_720p30_200
            fps_1080p30_200 = fps_for(
                macs_per_lr_pixel=fused_macs,
                width=480,
                height=270,
                clock_mhz=200.0,
                dsp_total=args.dsp_total,
                macs_per_dsp=args.macs_per_dsp,
                utilization=0.80,
            )
            fps_720p30_250 = fps_for(
                macs_per_lr_pixel=fused_macs,
                width=320,
                height=180,
                clock_mhz=250.0,
                dsp_total=args.dsp_total,
                macs_per_dsp=args.macs_per_dsp,
                utilization=0.80,
            )
            candidates.append(
                Candidate(
                    scale=args.scale,
                    channels=channels,
                    blocks=blocks,
                    fused_macs_per_lr_pixel=fused_macs,
                    unfused_macs_per_lr_pixel=unfused_macs,
                    fused_params=fused_params,
                    unfused_params=unfused_params,
                    fused_720p30_dsp_packed_200mhz_80p=dsp_for_target(
                        macs_per_lr_pixel=fused_macs,
                        width=320,
                        height=180,
                        fps=30.0,
                        clock_mhz=200.0,
                        macs_per_dsp=args.macs_per_dsp,
                    ),
                    fused_720p30_fps_200mhz_80p=fps_720p30_200,
                    fused_720p60_fps_200mhz_80p=fps_720p60_200,
                    fused_1080p30_fps_200mhz_80p=fps_1080p30_200,
                    fused_720p30_dsp_packed_250mhz_80p=dsp_for_target(
                        macs_per_lr_pixel=fused_macs,
                        width=320,
                        height=180,
                        fps=30.0,
                        clock_mhz=250.0,
                        macs_per_dsp=args.macs_per_dsp,
                    ),
                    fused_720p30_fps_250mhz_80p=fps_720p30_250,
                    realtime_720p30_200mhz_80p=fps_720p30_200 >= 30.0,
                    realtime_720p60_250mhz_80p=fps_720p30_250 >= 60.0,
                    quality_proxy=fused_params,
                )
            )
    return sorted(candidates, key=lambda item: (item.realtime_720p30_200mhz_80p, item.quality_proxy), reverse=True)


def training_command(c: Candidate, *, output: str) -> str:
    return (
        "python train\\distill_tinyspan_video.py "
        "--train-frames G:\\REDS\\train_sharp "
        f"--scale {c.scale} --channels {c.channels} --num-blocks {c.blocks} "
        "--patch-size 192 --batch-size 8 --epochs 50 --max-pairs 24000 "
        f"--output {output} --amp"
    )


def acceptance_command(c: Candidate, *, checkpoint: str, output: str) -> str:
    return (
        "python tools\\run_tinyspan_realtime_acceptance.py "
        f"--checkpoint {checkpoint} --scale {c.scale} "
        f"--student-channels {c.channels} --student-blocks {c.blocks} "
        "--input external\\SPAN\\test_scripts\\data\\baboon.png "
        "--width 320 --height 180 --fps 30 --stream-frames 60 --quality-frames 30 "
        "--min-fps 30 --half --async-writer --motion --preview-tile 180 "
        f"--out-dir {output}"
    )


def handoff_command(c: Candidate, *, checkpoint: str) -> str:
    return (
        "powershell -ExecutionPolicy Bypass -File scripts\\prepare_tinyspan_hardware_handoff.ps1 "
        f"-Checkpoint {checkpoint} -Scale {c.scale} -Channels {c.channels} -Blocks {c.blocks} "
        f"-OutputDir rtl\\generated\\tinyspan_x{c.scale}_c{c.channels}_b{c.blocks}_candidate"
    )


def write_markdown(path: Path, candidates: list[Candidate], args: argparse.Namespace) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    feasible = [c for c in candidates if c.realtime_720p30_200mhz_80p]
    recommended = next((c for c in feasible if c.channels == 24 and c.blocks == 4), feasible[0] if feasible else candidates[0])
    stretch = next((c for c in feasible if c.channels == 32 and c.blocks == 5), feasible[0] if feasible else candidates[0])
    baseline = next((c for c in candidates if c.channels == 16 and c.blocks == 3), recommended)
    tag = f"x{recommended.scale}_c{recommended.channels}_b{recommended.blocks}"
    checkpoint = f"runs\\tinyspan_distill\\video_{tag}_reds_temporal\\student_last.pt"
    lines = [
        "# TinySPAN Realtime Candidate Sizing",
        "",
        "Purpose: choose a software-trained student model that can still be mapped to FPGA for video SR while preserving a clear software-to-hardware parity target.",
        "",
        "## Assumptions",
        "",
        f"- scale: `X{args.scale}`",
        f"- DSP budget: `{args.dsp_total}`",
        f"- packed INT8 assumption: `{args.macs_per_dsp:g}` MAC/DSP/cycle",
        "- usable DSP budget for pass/fail rows: `80%`",
        "- target demo: X4 `320x180 -> 1280x720 @30fps`",
        "- fused deployment assumes each `Conv3XC` is folded into one `3x3 C->C` kernel before RTL/quantized-reference implementation.",
        "",
        "## Candidate Table",
        "",
        "| Candidate | Fused MACs/LR px | Unfused MACs/LR px | Fused params | 720p30 DSP @200MHz | FPS @200MHz 80% | FPS @250MHz 80% | 1080p30 FPS @200MHz 80% | 720p30 pass |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for c in candidates:
        name = f"X{c.scale} C{c.channels} B{c.blocks}"
        lines.append(
            "| "
            + " | ".join(
                [
                    f"`{name}`",
                    f"`{c.fused_macs_per_lr_pixel:,}`",
                    f"`{c.unfused_macs_per_lr_pixel:,}`",
                    f"`{c.fused_params:,}`",
                    f"`{c.fused_720p30_dsp_packed_200mhz_80p}`",
                    f"`{c.fused_720p30_fps_200mhz_80p:.1f}`",
                    f"`{c.fused_720p30_fps_250mhz_80p:.1f}`",
                    f"`{c.fused_1080p30_fps_200mhz_80p:.1f}`",
                    "`yes`" if c.realtime_720p30_200mhz_80p else "`no`",
                ]
            )
            + " |"
        )

    lines += [
        "",
        "## Recommended Next Candidate",
        "",
        f"Recommended next full REDS/video distillation target: `X{recommended.scale} C{recommended.channels} B{recommended.blocks}`.",
        "",
        "Reason:",
        "",
        "- It keeps a large margin over `720p30` in the fused hardware estimate.",
        "- It is meaningfully larger than the existing C16/B3 smoke model, so it has a better chance to close the teacher-quality gap.",
        "- It is still much smaller than full REDS-trained SPAN and should be a better hardware target for realtime video.",
        "",
        "Training command:",
        "",
        "```powershell",
        training_command(recommended, output=f"runs\\tinyspan_distill\\video_{tag}_reds_temporal"),
        "```",
        "",
        "Software realtime/quality acceptance command:",
        "",
        "```powershell",
        acceptance_command(recommended, checkpoint=checkpoint, output=f"runs\\tinyspan_acceptance\\video_{tag}_320x180_60f"),
        "```",
        "",
        "Hardware handoff command after a checkpoint passes software acceptance:",
        "",
        "```powershell",
        handoff_command(recommended, checkpoint=checkpoint),
        "```",
        "",
        "## Candidate Tiers",
        "",
        f"- Baseline already proven in the software realtime gate: `X{baseline.scale} C{baseline.channels} B{baseline.blocks}`. Use it to keep the hardware parity path moving.",
        f"- Recommended balanced target: `X{recommended.scale} C{recommended.channels} B{recommended.blocks}`. This is the first full REDS/video distillation candidate to try.",
        f"- Quality stretch target: `X{stretch.scale} C{stretch.channels} B{stretch.blocks}`. It has higher estimated quality capacity but needs Conv3XC fusion and tighter hardware scheduling discipline.",
        "",
        "## Interpretation",
        "",
        "The full REDS W8A12 SPAN remains the image-quality teacher and hardware arithmetic reference. Realtime video should move to a trained TinySPAN-family student, then prove parity through the same staged chain: PyTorch checkpoint, quantized/fixed reference, RTL simulation, board output, and comparison preview.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_int_list(text: str) -> list[int]:
    return [int(item.strip()) for item in text.split(",") if item.strip()]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Estimate TinySPAN realtime candidate sizes.")
    parser.add_argument("--scale", type=int, choices=(2, 4), default=4)
    parser.add_argument("--channels", type=parse_int_list, default=parse_int_list("8,12,16,20,24,32"))
    parser.add_argument("--blocks", type=parse_int_list, default=parse_int_list("1,2,3,4,5,6"))
    parser.add_argument("--dsp-total", type=int, default=1968)
    parser.add_argument("--macs-per-dsp", type=float, default=2.0)
    parser.add_argument("--out-json", type=Path, default=Path("runs/tinyspan_candidates/tinyspan_realtime_candidates.json"))
    parser.add_argument("--out-md", type=Path, default=Path("docs/design/tinyspan_realtime_candidate_sizing_2026_06_13.md"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    candidates = build_candidates(args)
    result = {
        "assumptions": {
            "scale": args.scale,
            "dsp_total": args.dsp_total,
            "macs_per_dsp": args.macs_per_dsp,
            "target": "X4 320x180 -> 1280x720 @30fps",
            "deployment": "Conv3XC fused to one 3x3 C->C kernel",
        },
        "candidates": [asdict(c) for c in candidates],
    }
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(result, indent=2), encoding="utf-8")
    write_markdown(args.out_md, candidates, args)
    print(json.dumps(result, indent=2))
    print(f"Wrote {args.out_json}")
    print(f"Wrote {args.out_md}")


if __name__ == "__main__":
    main()
