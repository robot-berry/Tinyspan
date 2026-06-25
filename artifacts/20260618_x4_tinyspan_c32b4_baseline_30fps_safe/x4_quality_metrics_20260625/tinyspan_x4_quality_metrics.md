# TinySPAN SR Quality Metrics

- generated at: `2026-06-25T11:50:29`
- border crop: `0` px

| Pair | PSNR | SSIM | MAE/255 | Max diff | Mismatch bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| `student_vs_teacher` | `29.459008 dB` | `0.894348` | `0.022488` | `92` | `2471078/2764800` |
| `pytorch_vs_tiled_fixed` | `43.171866 dB` | `0.993147` | `0.003293` | `57` | `1679477/2764800` |
| `full_integer_vs_tiled_fixed` | `44.487280 dB` | `0.997659` | `0.000729` | `58` | `101043/2764800` |
| `pytorch_vs_full_integer` | `48.717049 dB` | `0.995183` | `0.002694` | `2` | `1641523/2764800` |

## Notes

- These metrics compare already-generated images only.
- Board correctness is still proven by board-vs-fixed byte equality; quality metrics describe image fidelity.
- If the reference is an official SPAN teacher output, PSNR/SSIM are teacher-consistency metrics, not REDS HR-ground-truth metrics.
