# TinySPAN W8A8 Integer Reference

Input: `runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625\video_distill_latest_preview.png`
Quant plan: `runs\tinyspan_quant_plan\x2_quality_after_x4_20260625_x2_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
Checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
Preview: `runs\tinyspan_integer_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_preview.png`

## Image Metrics

| Pair | mismatch bytes | max diff | MAE | PSNR |
| --- | ---: | ---: | ---: | ---: |
| `pytorch_vs_fake` | `5439 / 12288` | `2` | `0.445475` | `51.587383 dB` |
| `pytorch_vs_integer` | `7684 / 12288` | `2` | `0.808350` | `47.432651 dB` |
| `fake_vs_integer` | `3929 / 12288` | `3` | `0.640381` | `46.858943 dB` |

## Stage Snapshot

| Stage | q min | q max | zero frac | sat - | sat + |
| --- | ---: | ---: | ---: | ---: | ---: |
| `input` | `0` | `127` | `0.0192` | `0.0000` | `0.0527` |
| `head.output` | `-122` | `127` | `0.0103` | `0.0000` | `0.0093` |
| `blocks.0.c1.output` | `-113` | `127` | `0.0154` | `0.0000` | `0.0009` |
| `blocks.0.act1` | `-52` | `127` | `0.0154` | `0.0000` | `0.0009` |
| `blocks.0.c2.output` | `-114` | `127` | `0.0090` | `0.0000` | `0.0038` |
| `blocks.0.act2` | `-79` | `127` | `0.0090` | `0.0000` | `0.0038` |
| `blocks.0.c3.output` | `-128` | `127` | `0.0040` | `0.0002` | `0.0009` |
| `blocks.0.residual_sum` | `-38` | `53` | `0.0316` | `0.0000` | `0.0000` |
| `blocks.0.sim_att` | `-128` | `127` | `0.0040` | `0.0002` | `0.0009` |
| `blocks.0.out` | `-3` | `55` | `0.1985` | `0.0000` | `0.0000` |
| `blocks.1.c1.output` | `-121` | `123` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.act1` | `-93` | `123` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.c2.output` | `-127` | `86` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.act2` | `-127` | `115` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.c3.output` | `-127` | `124` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.residual_sum` | `-127` | `125` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.sim_att` | `-127` | `124` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.out` | `0` | `127` | `0.0338` | `0.0000` | `0.0004` |
| `blocks.2.c1.output` | `-120` | `127` | `0.0000` | `0.0000` | `0.0010` |
| `blocks.2.act1` | `-93` | `127` | `0.0000` | `0.0000` | `0.0010` |
| `blocks.2.c2.output` | `-99` | `127` | `0.0000` | `0.0000` | `0.0009` |
| `blocks.2.act2` | `-76` | `127` | `0.0000` | `0.0000` | `0.0009` |
| `blocks.2.c3.output` | `-106` | `127` | `0.0019` | `0.0000` | `0.0009` |
| `blocks.2.residual_sum` | `-97` | `127` | `0.0144` | `0.0000` | `0.0312` |
| `blocks.2.sim_att` | `-106` | `127` | `0.0019` | `0.0000` | `0.0009` |
| `blocks.2.out` | `-8` | `127` | `0.1240` | `0.0000` | `0.0009` |
| `blocks.3.c1.output` | `-70` | `127` | `0.0010` | `0.0000` | `0.0019` |
| `blocks.3.act1` | `-55` | `127` | `0.0010` | `0.0000` | `0.0019` |
| `blocks.3.c2.output` | `-127` | `123` | `0.0001` | `0.0000` | `0.0000` |
| `blocks.3.act2` | `-106` | `127` | `0.0001` | `0.0000` | `0.0009` |
| `blocks.3.c3.output` | `-97` | `127` | `0.0009` | `0.0000` | `0.0009` |
| `blocks.3.residual_sum` | `-95` | `127` | `0.0000` | `0.0000` | `0.0303` |
| `blocks.3.sim_att` | `-97` | `127` | `0.0009` | `0.0000` | `0.0009` |
| `blocks.3.out` | `-4` | `127` | `0.0312` | `0.0000` | `0.0009` |
| `fuse_tail.output` | `-123` | `127` | `0.0009` | `0.0000` | `0.0009` |
| `reconstruct.input` | `-122` | `127` | `0.3576` | `0.0000` | `0.0023` |
| `reconstruct.output` | `0` | `0` | `1.0000` | `0.0000` | `0.0000` |
| `pixelshuffle.output` | `0` | `0` | `1.0000` | `0.0000` | `0.0000` |
| `base.input` | `-15` | `127` | `0.0134` | `0.0000` | `0.0340` |
| `output` | `-14` | `118` | `0.0134` | `0.0000` | `0.0000` |

## Interpretation

This reference consumes `tinyspan_w8a8_quant_plan.json` directly. Convolutions use exported int8 weights, int64 bias, and Q31 requant constants. Postprocess nodes use the calibrated activation scales and quantize back to int8 at each named boundary. Remaining differences against the fake W8A8 reference show the gap introduced by integer add/multiply/base-add scheduling and Q31 requantization.

Base reference mode: `rtl_fixed_q14_bicubic_x2`. For X4, the software fixed-point base branch is RTL-isomorphic with the Q14 integer bicubic path used by the hardware; PyTorch bicubic remains a visual/quality reference only.
