# TinySPAN W8A8 Integer Reference

Input: `external\SPAN\test_scripts\data\baboon.png`
Quant plan: `runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
Checkpoint: `G:\UESTC\feitengspan1\runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
Preview: `Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_b_integer_reference_rtl_fixed_base_32x32_20260618\tinyspan_w8a8_integer_reference_preview.png`

## Image Metrics

| Pair | mismatch bytes | max diff | MAE | PSNR |
| --- | ---: | ---: | ---: | ---: |
| `pytorch_vs_fake` | `26261 / 49152` | `2` | `0.536641` | `50.795930 dB` |
| `pytorch_vs_integer` | `28877 / 49152` | `2` | `0.675090` | `48.835284 dB` |
| `fake_vs_integer` | `11688 / 49152` | `3` | `0.509664` | `47.632572 dB` |

## Stage Snapshot

| Stage | q min | q max | zero frac | sat - | sat + |
| --- | ---: | ---: | ---: | ---: | ---: |
| `input` | `0` | `124` | `0.0003` | `0.0000` | `0.0000` |
| `head.output` | `-96` | `77` | `0.0194` | `0.0000` | `0.0000` |
| `blocks.0.c1.output` | `-98` | `96` | `0.0150` | `0.0000` | `0.0000` |
| `blocks.0.act1` | `-55` | `109` | `0.0150` | `0.0000` | `0.0000` |
| `blocks.0.c2.output` | `-112` | `83` | `0.0198` | `0.0000` | `0.0000` |
| `blocks.0.act2` | `-106` | `122` | `0.0198` | `0.0000` | `0.0000` |
| `blocks.0.c3.output` | `-120` | `120` | `0.0010` | `0.0000` | `0.0000` |
| `blocks.0.residual_sum` | `-35` | `34` | `0.0242` | `0.0000` | `0.0000` |
| `blocks.0.sim_att` | `-120` | `120` | `0.0010` | `0.0000` | `0.0000` |
| `blocks.0.out` | `-3` | `39` | `0.1578` | `0.0000` | `0.0000` |
| `blocks.1.c1.output` | `-91` | `127` | `0.0003` | `0.0000` | `0.0054` |
| `blocks.1.act1` | `-69` | `127` | `0.0003` | `0.0000` | `0.0054` |
| `blocks.1.c2.output` | `-127` | `124` | `0.0068` | `0.0000` | `0.0000` |
| `blocks.1.act2` | `-97` | `126` | `0.0068` | `0.0000` | `0.0000` |
| `blocks.1.c3.output` | `-127` | `76` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.residual_sum` | `-127` | `78` | `0.0085` | `0.0000` | `0.0000` |
| `blocks.1.sim_att` | `-127` | `76` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.1.out` | `0` | `127` | `0.0322` | `0.0000` | `0.0002` |
| `blocks.2.c1.output` | `-120` | `127` | `0.0000` | `0.0000` | `0.0019` |
| `blocks.2.act1` | `-94` | `127` | `0.0000` | `0.0000` | `0.0019` |
| `blocks.2.c2.output` | `-127` | `91` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.2.act2` | `-127` | `124` | `0.0000` | `0.0000` | `0.0000` |
| `blocks.2.c3.output` | `-96` | `127` | `0.0000` | `0.0000` | `0.0009` |
| `blocks.2.residual_sum` | `-83` | `127` | `0.0000` | `0.0000` | `0.0293` |
| `blocks.2.sim_att` | `-96` | `127` | `0.0000` | `0.0000` | `0.0009` |
| `blocks.2.out` | `0` | `127` | `0.0009` | `0.0000` | `0.0009` |
| `blocks.3.c1.output` | `-118` | `127` | `0.0009` | `0.0000` | `0.0303` |
| `blocks.3.act1` | `-92` | `127` | `0.0009` | `0.0000` | `0.0303` |
| `blocks.3.c2.output` | `-101` | `127` | `0.0010` | `0.0000` | `0.0000` |
| `blocks.3.act2` | `-81` | `127` | `0.0010` | `0.0000` | `0.0000` |
| `blocks.3.c3.output` | `-127` | `125` | `0.0009` | `0.0000` | `0.0000` |
| `blocks.3.residual_sum` | `-116` | `127` | `0.0283` | `0.0000` | `0.0312` |
| `blocks.3.sim_att` | `-127` | `125` | `0.0009` | `0.0000` | `0.0000` |
| `blocks.3.out` | `-11` | `127` | `0.1157` | `0.0000` | `0.0009` |
| `fuse_tail.output` | `-128` | `121` | `0.0000` | `0.0000` | `0.0000` |
| `reconstruct.input` | `-96` | `77` | `0.3369` | `0.0000` | `0.0000` |
| `reconstruct.output` | `0` | `0` | `1.0000` | `0.0000` | `0.0000` |
| `pixelshuffle.output` | `0` | `0` | `1.0000` | `0.0000` | `0.0000` |
| `base.input` | `1` | `127` | `0.0000` | `0.0000` | `0.0002` |
| `output` | `1` | `119` | `0.0000` | `0.0000` | `0.0000` |

## Interpretation

This reference consumes `tinyspan_w8a8_quant_plan.json` directly. Convolutions use exported int8 weights, int64 bias, and Q31 requant constants. Postprocess nodes use the calibrated activation scales and quantize back to int8 at each named boundary. Remaining differences against the fake W8A8 reference show the gap introduced by integer add/multiply/base-add scheduling and Q31 requantization.

Base reference mode: `rtl_fixed_q14_bicubic_x4`. For X4, the software fixed-point base branch is RTL-isomorphic with the Q14 integer bicubic path used by the hardware; PyTorch bicubic remains a visual/quality reference only.
