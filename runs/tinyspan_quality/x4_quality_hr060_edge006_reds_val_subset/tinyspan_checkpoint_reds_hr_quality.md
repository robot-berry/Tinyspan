# TinySPAN Checkpoint REDS HR Quality

- generated at: `2026-06-25T14:36:39`
- checkpoint: `/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625/student_last.pt`
- checkpoint SHA256: `457CE12C7057D8190E462C9671C28E137AD92AE3B50441E9722EBFFDF3635398`
- image count: `16`
- scale: `X4`
- border: `4`

| Pair | PSNR mean | PSNR min | SSIM mean | MAE/255 mean |
| --- | ---: | ---: | ---: | ---: |
| `student_vs_hr` | `25.865854 dB` | `25.576539 dB` | `0.695029` | `0.031757` |
| `bicubic_vs_hr` | `25.763312 dB` | `25.474006 dB` | `0.691067` | `0.031949` |

## Decision

- student PSNR improvement over bicubic: `0.102542 dB`
- meets 28dB exploratory gate: `False`
- meets 30dB stretch gate: `False`

This is a software quality gate only. It does not replace quantization, RTL, bitstream, board-vs-fixed equality, or >=30fps evidence.
