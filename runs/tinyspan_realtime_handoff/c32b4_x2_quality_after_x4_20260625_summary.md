# TinySPAN C32B4 Realtime Handoff

Result: `PASS`

Tag: `x2_quality_after_x4_20260625`
Scale: `X2`
Checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
Preview input: `runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625\video_distill_latest_preview.png`
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
- integer mismatch bytes: `7684`
- integer max channel diff: `2`
- integer PSNR vs software: `47.4326512217236` dB

## Artifacts

- fusion report: `runs\tinyspan_fusion\x2_quality_after_x4_20260625_x2_c32_b4\fusion_check.md`
- fused checkpoint: `runs\tinyspan_fusion\x2_quality_after_x4_20260625_x2_c32_b4\student_fused_conv3xc.pt`
- handoff manifest: `rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused\tinyspan_manifest.json`
- manifest reference: `runs\tinyspan_manifest_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32\tinyspan_manifest_reference_summary.md`
- manifest preview: `runs\tinyspan_manifest_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32\tinyspan_manifest_reference_preview.png`
- activation scales: `runs\tinyspan_calibration\x2_quality_after_x4_20260625_x2_c32_b4_reds4_32x32\activation_scales.json`
- W8A8 quant plan: `runs\tinyspan_quant_plan\x2_quality_after_x4_20260625_x2_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- integer reference: `runs\tinyspan_integer_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_summary.md`
- integer preview: `runs\tinyspan_integer_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_preview.png`

## Next

Only use this checkpoint for RTL/board parity if every gate above passes.
