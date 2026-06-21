# TinySPAN Conv3XC Fusion Check

Checkpoint: `runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
Model: X4 C32 B4
Fused checkpoint: `runs\tinyspan_fusion\c32b4_30fps_frozen_20260613_x4_c32_b4\student_fused_conv3xc.pt`
Fused manifest: `runs\tinyspan_fusion\c32b4_30fps_frozen_20260613_x4_c32_b4\tinyspan_fused_manifest.json`

## Model Output Check

| Region | Values | Max abs | MAE | MSE | PSNR |
| --- | ---: | ---: | ---: | ---: | ---: |
| `full` | `49152` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |
| `crop4` | `43200` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |
| `crop16` | `27648` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |

## Conv3XC Layer Checks

| Layer | Values | Max abs | MAE | MSE | PSNR |
| --- | ---: | ---: | ---: | ---: | ---: |
| `blocks.0.c1.full` | `32768` | `0.06152076` | `0.00184540` | `4.32340821e-05` | `43.642` |
| `blocks.0.c1.crop1` | `28800` | `0.00026920` | `0.00004558` | `3.27537997e-09` | `84.847` |
| `blocks.0.c2.full` | `32768` | `0.07066098` | `0.00198733` | `4.68911494e-05` | `43.289` |
| `blocks.0.c2.crop1` | `28800` | `0.00024551` | `0.00004619` | `3.37809536e-09` | `84.713` |
| `blocks.0.c3.full` | `32768` | `0.06104165` | `0.00199204` | `4.92304061e-05` | `43.078` |
| `blocks.0.c3.crop1` | `28800` | `0.00024641` | `0.00004596` | `3.34255801e-09` | `84.759` |
| `blocks.1.c1.full` | `32768` | `0.06890401` | `0.00182525` | `4.39569922e-05` | `43.570` |
| `blocks.1.c1.crop1` | `28800` | `0.00023401` | `0.00004392` | `3.03737147e-09` | `85.175` |
| `blocks.1.c2.full` | `32768` | `0.06338739` | `0.00203357` | `4.95880195e-05` | `43.046` |
| `blocks.1.c2.crop1` | `28800` | `0.00025809` | `0.00004470` | `3.16628412e-09` | `84.994` |
| `blocks.1.c3.full` | `32768` | `0.06166090` | `0.00193244` | `4.81538445e-05` | `43.174` |
| `blocks.1.c3.crop1` | `28800` | `0.00026242` | `0.00004766` | `3.58601948e-09` | `84.454` |
| `blocks.2.c1.full` | `32768` | `0.06164643` | `0.00155811` | `3.33316457e-05` | `44.771` |
| `blocks.2.c1.crop1` | `28800` | `0.00027445` | `0.00004464` | `3.14415161e-09` | `85.025` |
| `blocks.2.c2.full` | `32768` | `0.07019714` | `0.00205163` | `5.41757254e-05` | `42.662` |
| `blocks.2.c2.crop1` | `28800` | `0.00023459` | `0.00004683` | `3.47026607e-09` | `84.596` |
| `blocks.2.c3.full` | `32768` | `0.08512053` | `0.00191215` | `4.44217367e-05` | `43.524` |
| `blocks.2.c3.crop1` | `28800` | `0.00027478` | `0.00004639` | `3.40563155e-09` | `84.678` |
| `blocks.3.c1.full` | `32768` | `0.06407791` | `0.00207090` | `5.09075144e-05` | `42.932` |
| `blocks.3.c1.crop1` | `28800` | `0.00024837` | `0.00004579` | `3.32212902e-09` | `84.786` |
| `blocks.3.c2.full` | `32768` | `0.09433451` | `0.00194946` | `5.16290092e-05` | `42.871` |
| `blocks.3.c2.crop1` | `28800` | `0.00022981` | `0.00004451` | `3.14015258e-09` | `85.030` |
| `blocks.3.c3.full` | `32768` | `0.05438046` | `0.00170589` | `3.60978956e-05` | `44.425` |
| `blocks.3.c3.crop1` | `28800` | `0.00028192` | `0.00004561` | `3.30485728e-09` | `84.808` |

## Interpretation

The fused 3x3 kernel is algebraically exact for the interior of a single Conv3XC block. Full-frame differences can appear at padded borders when intermediate Conv3XC biases are nonzero. Hardware use should therefore validate the fused checkpoint against the PyTorch training checkpoint before treating it as the software target.
