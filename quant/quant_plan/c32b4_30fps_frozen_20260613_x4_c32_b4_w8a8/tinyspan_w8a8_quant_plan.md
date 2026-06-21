# TinySPAN W8A8 Quantization Plan

Manifest: `rtl\generated\tinyspan_x4_c32_b4_c32b4_30fps_frozen_20260613_fused\tinyspan_manifest.json`
Activation scales: `runs\tinyspan_calibration\c32b4_30fps_frozen_20260613_x4_c32_b4_reds4_32x32\activation_scales.json`
Layers: `15`
Activation tensors: `53`

## Conv Layers

| Layer | Input scale | Output scale | Weight scale | Bias q min..max | Requant q31 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `head` | `0.0078740157` | `0.011038055` | `0.0015142456` | `-15604..14990` | `2319690` |
| `blocks.0.c1` | `0.011038055` | `0.0071341232` | `0.0016014656` | `-15038..12315` | `5321075` |
| `blocks.0.c2` | `0.0041952678` | `0.0043536816` | `0.0016040414` | `-46383..26296` | `3319315` |
| `blocks.0.c3` | `0.0017468621` | `0.0021909447` | `0.0015542592` | `-76570..106862` | `2661218` |
| `blocks.1.c1` | `0.000574673` | `0.0025735551` | `0.0015218694` | `-259938..362770` | `729784` |
| `blocks.1.c2` | `0.0014952115` | `0.0022358773` | `0.001608161` | `-104984..105817` | `2309479` |
| `blocks.1.c3` | `0.0012531033` | `0.0025560998` | `0.0016322808` | `-145154..84578` | `1718438` |
| `blocks.2.c1` | `0.00019666241` | `0.0020082956` | `0.0016652777` | `-749014..799368` | `350195` |
| `blocks.2.c2` | `0.0011315139` | `0.0027985282` | `0.0015434119` | `-169612..117526` | `1340115` |
| `blocks.2.c3` | `0.0011531905` | `0.0028459213` | `0.0015960589` | `-127215..171876` | `1388855` |
| `blocks.3.c1` | `0.0002553573` | `0.0020389988` | `0.0015868532` | `-572790..616477` | `426774` |
| `blocks.3.c2` | `0.0011507679` | `0.0020035359` | `0.001527055` | `-110030..141149` | `1883541` |
| `blocks.3.c3` | `0.0011285341` | `0.0016683582` | `0.0016595531` | `-125623..126620` | `2410718` |
| `fuse_tail` | `9.3228096e-05` | `0.00047353987` | `0.00046391395` | `-1304877..1315233` | `196136` |
| `reconstruct` | `0.011038055` | `1e-12` | `1e-12` | `0..0` | `23704042` |

## Postprocess Nodes

| Node | Kind | Output scale |
| --- | --- | ---: |
| `blocks.0.act1` | `silu` | `0.0041952678` |
| `blocks.0.act2` | `silu` | `0.0017468621` |
| `blocks.0.residual_sum` | `add` | `0.010140975` |
| `blocks.0.sim_att` | `sigmoid_minus_half` | `0.00054422935` |
| `blocks.0.attention_mul` | `multiply` | `0.000574673` |
| `blocks.1.act1` | `silu` | `0.0014952115` |
| `blocks.1.act2` | `silu` | `0.0012531033` |
| `blocks.1.residual_sum` | `add` | `0.0025043003` |
| `blocks.1.sim_att` | `sigmoid_minus_half` | `0.00063347135` |
| `blocks.1.attention_mul` | `multiply` | `0.00019666241` |
| `blocks.2.act1` | `silu` | `0.0011315139` |
| `blocks.2.act2` | `silu` | `0.0011531905` |
| `blocks.2.residual_sum` | `add` | `0.0028567591` |
| `blocks.2.sim_att` | `sigmoid_minus_half` | `0.0007038351` |
| `blocks.2.attention_mul` | `multiply` | `0.0002553573` |
| `blocks.3.act1` | `silu` | `0.0011507679` |
| `blocks.3.act2` | `silu` | `0.0011285341` |
| `blocks.3.residual_sum` | `add` | `0.0017948482` |
| `blocks.3.sim_att` | `sigmoid_minus_half` | `0.00041553637` |
| `blocks.3.attention_mul` | `multiply` | `9.3228096e-05` |
| `pixelshuffle` | `pixelshuffle_x4_rgb` | `1e-12` |
| `base_add` | `add_bicubic_base` | `0.0084221605` |

## RTL Implications

- Use signed 8-bit activations at the named activation scale points.
- Use the fused int8 weights already exported in the TinySPAN manifest.
- Use per-layer int64 bias constants and Q31 requant constants from this plan.
- Implement SiLU, sigmoid-minus-half, residual add, attention multiply, pixelshuffle, and bicubic-base add against the named calibrated scales.
