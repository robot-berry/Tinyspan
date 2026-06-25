# TinySPAN W8A8 Quantization Plan

Manifest: `rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused\tinyspan_manifest.json`
Activation scales: `runs\tinyspan_calibration\x2_quality_after_x4_20260625_x2_c32_b4_reds4_32x32\activation_scales.json`
Layers: `15`
Activation tensors: `53`

## Conv Layers

| Layer | Input scale | Output scale | Weight scale | Bias q min..max | Requant q31 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `head` | `0.0078740157` | `0.0086116344` | `0.0015153267` | `-15632..15386` | `2975410` |
| `blocks.0.c1` | `0.0086116344` | `0.006536168` | `0.0016267778` | `-15987..16243` | `4602783` |
| `blocks.0.c2` | `0.0045516221` | `0.0030474951` | `0.001513987` | `-48470..37784` | `4855961` |
| `blocks.0.c3` | `0.0018149905` | `0.0026431608` | `0.0015494968` | `-88061..124264` | `2284922` |
| `blocks.1.c1` | `0.00070095004` | `0.0021655017` | `0.0016364636` | `-222937..228331` | `1137535` |
| `blocks.1.c2` | `0.0012307077` | `0.0026815538` | `0.0015513009` | `-151927..125609` | `1528954` |
| `blocks.1.c3` | `0.0011146525` | `0.0027307633` | `0.0015412964` | `-153790..165520` | `1351050` |
| `blocks.2.c1` | `0.00023255027` | `0.0020567279` | `0.0015507259` | `-697786..732387` | `376535` |
| `blocks.2.c2` | `0.0011619122` | `0.0023521332` | `0.001532603` | `-115399..206418` | `1625814` |
| `blocks.2.c3` | `0.0013504298` | `0.0021329178` | `0.0015870773` | `-105134..118159` | `2157873` |
| `blocks.3.c1` | `0.00014997371` | `0.0026193992` | `0.001473011` | `-824505..1495888` | `181113` |
| `blocks.3.c2` | `0.0015255574` | `0.0017170983` | `0.0015233694` | `-103709..77577` | `2906488` |
| `blocks.3.c3` | `0.00091899181` | `0.0021048351` | `0.0015922204` | `-146587..157768` | `1492886` |
| `fuse_tail` | `0.00014077213` | `0.00045376344` | `0.00046397684` | `-749371..865183` | `309110` |
| `reconstruct` | `0.0086116344` | `1e-12` | `1e-12` | `0..0` | `18493344` |

## Postprocess Nodes

| Node | Kind | Output scale |
| --- | --- | ---: |
| `blocks.0.act1` | `silu` | `0.0045516221` |
| `blocks.0.act2` | `silu` | `0.0018149905` |
| `blocks.0.residual_sum` | `add` | `0.0092876973` |
| `blocks.0.sim_att` | `sigmoid_minus_half` | `0.00065465423` |
| `blocks.0.attention_mul` | `multiply` | `0.00070095004` |
| `blocks.1.act1` | `silu` | `0.0012307077` |
| `blocks.1.act2` | `silu` | `0.0011146525` |
| `blocks.1.residual_sum` | `add` | `0.0027092558` |
| `blocks.1.sim_att` | `sigmoid_minus_half` | `0.00067592959` |
| `blocks.1.attention_mul` | `multiply` | `0.00023255027` |
| `blocks.2.act1` | `silu` | `0.0011619122` |
| `blocks.2.act2` | `silu` | `0.0013504298` |
| `blocks.2.residual_sum` | `add` | `0.0022281352` |
| `blocks.2.sim_att` | `sigmoid_minus_half` | `0.00052999274` |
| `blocks.2.attention_mul` | `multiply` | `0.00014997373` |
| `blocks.3.act1` | `silu` | `0.0015255574` |
| `blocks.3.act2` | `silu` | `0.00091899181` |
| `blocks.3.residual_sum` | `add` | `0.0021189954` |
| `blocks.3.sim_att` | `sigmoid_minus_half` | `0.00052309787` |
| `blocks.3.attention_mul` | `multiply` | `0.00014077213` |
| `pixelshuffle` | `pixelshuffle_x4_rgb` | `1e-12` |
| `base_add` | `add_bicubic_base` | `0.0084457425` |

## RTL Implications

- Use signed 8-bit activations at the named activation scale points.
- Use the fused int8 weights already exported in the TinySPAN manifest.
- Use per-layer int64 bias constants and Q31 requant constants from this plan.
- Implement SiLU, sigmoid-minus-half, residual add, attention multiply, pixelshuffle, and bicubic-base add against the named calibrated scales.
