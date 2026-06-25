# TinySPAN Checkpoint REDS HR Quality

- generated at: `2026-06-25T22:56:52`
- checkpoint: `/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625/student_last.pt`
- checkpoint SHA256: `B06E66FA8FEA066F111B94CF5629919BEA05D5465F913B36851CBA92BED4A9EB`
- image count: `3000`
- saved image count: `16`
- save image count setting: `16`
- scale: `X2`
- border: `2`

| Pair | PSNR mean | PSNR min | SSIM mean | MAE/255 mean |
| --- | ---: | ---: | ---: | ---: |
| `student_vs_hr` | `31.121460 dB` | `25.501036 dB` | `0.905515` | `0.017395` |
| `bicubic_vs_hr` | `30.853986 dB` | `25.305608 dB` | `0.899959` | `0.017778` |

## Decision

- student PSNR improvement over bicubic: `0.267474 dB`
- meets 28dB exploratory gate: `True`
- meets 30dB stretch gate: `True`

This is a software quality gate only. It does not replace quantization, RTL, bitstream, board-vs-fixed equality, or >=30fps evidence.
