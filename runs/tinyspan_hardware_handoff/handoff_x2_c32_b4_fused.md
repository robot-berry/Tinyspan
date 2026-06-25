# TinySPAN hardware handoff

Result: `PASS`

Checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
Output dir: `rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused`
Model: X2 C32 B4
Conv3XC fused: `True`

## Checks

| Check | Result |
| --- | --- |
| `checkpoint_exists` | `True` |
| `manifest_exists` | `True` |
| `config_exists` | `True` |
| `weights_exist` | `True` |
| `scale_matches` | `True` |
| `channels_matches` | `True` |
| `blocks_matches` | `True` |

## Export

- manifest: `G:\UESTC\feitengspan1\Tinyspan\rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused\tinyspan_manifest.json`
- config: `G:\UESTC\feitengspan1\Tinyspan\rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused\tinyspan_model_config.vh`
- weight files: `30`
- total weight bytes: `539824`

Planned/export command:

```powershell
python train\export_tinyspan_to_rtl.py --checkpoint "runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt" --scale 2 --channels 32 --num-blocks 4 --output-dir "rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused" --fuse-conv3xc
```
