# TinySPAN Checkpoint REDS HR Quality

- generated at: `2026-06-26T09:54:53`
- checkpoint: `/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x4_c32_b4_quality_hrheavy_p256_20260626/student_last.pt`
- checkpoint SHA256: `5B9D0E8D4B1A5CEB3AEDEE9AF80B23AE0D76ACE67037F6A400E7CBA4970F25F3`
- image count: `3000`
- saved image count: `3`
- save image count setting: `3`
- scale: `X4`
- border: `4`

| Pair | PSNR mean | PSNR min | SSIM mean | MAE/255 mean |
| --- | ---: | ---: | ---: | ---: |
| `student_vs_hr` | `26.384691 dB` | `21.847856 dB` | `0.736907` | `0.029895` |
| `bicubic_vs_hr` | `26.274463 dB` | `21.776484 dB` | `0.732721` | `0.030108` |

## Decision

- student PSNR improvement over bicubic: `0.110228 dB`
- meets 28dB exploratory gate: `False`
- meets 30dB stretch gate: `False`

This is a software quality gate only. It does not replace quantization, RTL, bitstream, board-vs-fixed equality, or >=30fps evidence.
