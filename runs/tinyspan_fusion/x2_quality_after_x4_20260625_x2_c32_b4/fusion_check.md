# TinySPAN Conv3XC Fusion Check

Checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
Model: X2 C32 B4
Fused checkpoint: `runs\tinyspan_fusion\x2_quality_after_x4_20260625_x2_c32_b4\student_fused_conv3xc.pt`
Fused manifest: `runs\tinyspan_fusion\x2_quality_after_x4_20260625_x2_c32_b4\tinyspan_fused_manifest.json`

## Model Output Check

| Region | Values | Max abs | MAE | MSE | PSNR |
| --- | ---: | ---: | ---: | ---: | ---: |
| `full` | `12288` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |
| `crop4` | `10800` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |
| `crop16` | `6912` | `0.00000000` | `0.00000000` | `0.00000000e+00` | `99.000` |

## Conv3XC Layer Checks

| Layer | Values | Max abs | MAE | MSE | PSNR |
| --- | ---: | ---: | ---: | ---: | ---: |
| `blocks.0.c1.full` | `32768` | `0.06058010` | `0.00160577` | `3.27625567e-05` | `44.846` |
| `blocks.0.c1.crop1` | `28800` | `0.00025296` | `0.00004510` | `3.21943783e-09` | `84.922` |
| `blocks.0.c2.full` | `32768` | `0.07798731` | `0.00175642` | `3.88345579e-05` | `44.108` |
| `blocks.0.c2.crop1` | `28800` | `0.00024652` | `0.00004635` | `3.39670247e-09` | `84.689` |
| `blocks.0.c3.full` | `32768` | `0.08849090` | `0.00257178` | `7.74532673e-05` | `41.110` |
| `blocks.0.c3.crop1` | `28800` | `0.00026289` | `0.00004482` | `3.18188942e-09` | `84.973` |
| `blocks.1.c1.full` | `32768` | `0.06700718` | `0.00181222` | `4.06402905e-05` | `43.910` |
| `blocks.1.c1.crop1` | `28800` | `0.00023299` | `0.00004508` | `3.20328808e-09` | `84.944` |
| `blocks.1.c2.full` | `32768` | `0.06977457` | `0.00195748` | `4.82115793e-05` | `43.168` |
| `blocks.1.c2.crop1` | `28800` | `0.00023869` | `0.00004510` | `3.21296856e-09` | `84.931` |
| `blocks.1.c3.full` | `32768` | `0.07204980` | `0.00180344` | `4.26276019e-05` | `43.703` |
| `blocks.1.c3.crop1` | `28800` | `0.00024144` | `0.00004636` | `3.40817929e-09` | `84.675` |
| `blocks.2.c1.full` | `32768` | `0.06640797` | `0.00224199` | `5.65825430e-05` | `42.473` |
| `blocks.2.c1.crop1` | `28800` | `0.00023290` | `0.00004654` | `3.41939033e-09` | `84.661` |
| `blocks.2.c2.full` | `32768` | `0.08231199` | `0.00218054` | `5.65933587e-05` | `42.472` |
| `blocks.2.c2.crop1` | `28800` | `0.00026560` | `0.00004603` | `3.34419181e-09` | `84.757` |
| `blocks.2.c3.full` | `32768` | `0.06589600` | `0.00174663` | `3.88119297e-05` | `44.110` |
| `blocks.2.c3.crop1` | `28800` | `0.00023386` | `0.00004692` | `3.47952089e-09` | `84.585` |
| `blocks.3.c1.full` | `32768` | `0.08675630` | `0.00222951` | `6.36088371e-05` | `41.965` |
| `blocks.3.c1.crop1` | `28800` | `0.00026262` | `0.00004709` | `3.49330054e-09` | `84.568` |
| `blocks.3.c2.full` | `32768` | `0.07043460` | `0.00173032` | `3.78059849e-05` | `44.224` |
| `blocks.3.c2.crop1` | `28800` | `0.00026250` | `0.00004739` | `3.53611829e-09` | `84.515` |
| `blocks.3.c3.full` | `32768` | `0.05655271` | `0.00157116` | `3.15719881e-05` | `45.007` |
| `blocks.3.c3.crop1` | `28800` | `0.00027251` | `0.00004508` | `3.20023141e-09` | `84.948` |

## Interpretation

The fused 3x3 kernel is algebraically exact for the interior of a single Conv3XC block. Full-frame differences can appear at padded borders when intermediate Conv3XC biases are nonzero. Hardware use should therefore validate the fused checkpoint against the PyTorch training checkpoint before treating it as the software target.
