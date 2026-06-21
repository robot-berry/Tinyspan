# TinySPAN C32B4 Realtime Handoff

Result: `PASS`

Tag: `c32b4_30fps_frozen_20260613_gatecheck`
Checkpoint: `runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
Preview input: `external\SPAN\test_scripts\data\baboon.png`
Calibration input: `G:\REDS\train_sharp`

## Gates

| Gate | Result |
| --- | --- |
| `manifest_matches_software` | `True` |
| `integer_psnr_ok` | `True` |
| `integer_channel_diff_ok` | `True` |

## Metrics

- manifest mismatch bytes: `0`
- manifest max channel diff: `0`
- manifest PSNR vs software: `Infinity` dB
- integer mismatch bytes: `28877`
- integer max channel diff: `2`
- integer PSNR vs software: `48.835283894761` dB

## Artifacts

- fusion report: `runs\tinyspan_fusion\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4\fusion_check.md`
- fused checkpoint: `runs\tinyspan_fusion\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4\student_fused_conv3xc.pt`
- handoff manifest: `rtl\generated\tinyspan_x4_c32_b4_c32b4_30fps_frozen_20260613_gatecheck_fused\tinyspan_manifest.json`
- manifest reference: `runs\tinyspan_manifest_reference\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_32x32\tinyspan_manifest_reference_summary.md`
- manifest preview: `runs\tinyspan_manifest_reference\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_32x32\tinyspan_manifest_reference_preview.png`
- activation scales: `runs\tinyspan_calibration\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_reds4_32x32\activation_scales.json`
- W8A8 quant plan: `runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- integer reference: `runs\tinyspan_integer_reference\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_summary.md`
- integer preview: `runs\tinyspan_integer_reference\c32b4_30fps_frozen_20260613_gatecheck_x4_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_preview.png`

## Next

Only use this checkpoint for RTL/board parity if every gate above passes.
