# TinySPAN SR Quality Metrics

- generated at: `2026-06-25T12:00:40`
- border crop: `4` px
- resize SR to reference: `yes`

| Pair | PSNR | SSIM | MAE/255 | Max diff | Mismatch bytes | Resized |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `x4_tile64_fixed_vs_reds_hr` | `25.851911 dB` | `0.700177` | `0.031975` | `136` | `2495310/2716992` | `no` |
| `bicubic_lr_vs_reds_hr` | `25.787498 dB` | `0.699348` | `0.031871` | `133` | `2463581/2716992` | `yes` |

## Notes

- These metrics compare already-generated images only.
- Board correctness is still proven by board-vs-fixed byte equality; quality metrics describe image fidelity.
- If the reference is an official SPAN teacher output, PSNR/SSIM are teacher-consistency metrics, not REDS HR-ground-truth metrics.
