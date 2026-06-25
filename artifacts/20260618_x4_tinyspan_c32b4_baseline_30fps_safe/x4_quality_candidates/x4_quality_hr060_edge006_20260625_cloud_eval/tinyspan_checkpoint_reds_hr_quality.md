# TinySPAN Checkpoint REDS HR Quality

- generated at: `2026-06-25T20:40:26`
- checkpoint: `/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625/student_last.pt`
- checkpoint SHA256: `B94D888A10D909A18897C64CD1256EA8511D065322A00EE1534784EB72384694`
- image count: `3000`
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
