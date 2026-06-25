# TinySPAN X2 Hardware Readiness

- status: `READY`
- generated at: `2026-06-26T06:31:01`
- X2 training status: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json`
- X2 quant plan: `runs/tinyspan_quant_plan/x2_quality_after_x4_20260625_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json`
- X2 RTL manifest: `rtl/generated/tinyspan_c32b4_x2_quality_after_x4_20260625_x2_w8a8/tinyspan_w8a8_rtl_manifest.json`
- X2 Gate H manifest: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/manifest.json`

## Blockers

- none

## Checks

| Check | Required | Status | Detail |
| --- | --- | --- | --- |
| `x2_training_status_artifact` | `False` | `PASS` | `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json` |
| `x2_quant_plan_exists` | `True` | `PASS` | `runs/tinyspan_quant_plan/x2_quality_after_x4_20260625_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json` |
| `x2_rtl_manifest_exists` | `True` | `PASS` | `rtl/generated/tinyspan_c32b4_x2_quality_after_x4_20260625_x2_w8a8/tinyspan_w8a8_rtl_manifest.json` |
| `x2_bicubic_base_rtl_exists` | `True` | `PASS` | `rtl/tinyspan_core/span_tinyspan_w8a8_bicubic_base_x2_streamed.v` |
| `board_shell_scale_parameterized` | `True` | `PASS` | `rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v contains 'parameter integer SCALE'` |
| `ddr_endpoint_scale_parameterized` | `True` | `PASS` | `rtl/board_wrapper/sr_ddr_tinyspan_x4_tile_writer_endpoint.v contains 'parameter integer SCALE'` |
| `bd_script_accepts_scale_env` | `True` | `PASS` | `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl contains 'PS_TINYSPAN_DDR_X4_SCALE scale'` |
| `bd_script_scale_not_hardcoded_4` | `True` | `PASS` | `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl does not contain 'CONFIG.SCALE {4}'` |
| `bd_wrapper_exposes_scale_parameter` | `True` | `PASS` | `scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1 contains '[int]$Scale = 4'` |
| `full_stream_top_selects_x2_scale` | `True` | `PASS` | `rtl/tinyspan_core/span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v contains 'SCALE == 2'` |
| `full_stream_top_instantiates_x2_base` | `True` | `PASS` | `rtl/tinyspan_core/span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v contains 'span_tinyspan_w8a8_bicubic_base_x2_streamed'` |
| `integer_reference_uses_q14_x2` | `True` | `PASS` | `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py contains 'rtl_fixed_q14_bicubic_x2'` |
| `acceptance_preflight_supports_scale` | `True` | `PASS` | `scripts/acceptance/check_tinyspan_720p30_acceptance_inputs.ps1 contains 'expectedInputWidth'` |

## Post-Training Gate Order

训练仍在运行时只允许刷新状态，不启动 Vivado/JTAG/板卡流程。训练达到目标 step 且进程退出后，按下面顺序推进：

1. `freeze_handoff_quant_rtl`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 -RunDir ..\runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625 -Scale 2 -Tag x2_quality_after_x4_20260625
```

- starts Vivado/board flow: `False`
- expected: frozen X2 checkpoint and SHA256 manifest at runs/tinyspan_frozen_candidates/x2_quality_after_x4_20260625/student_final.pt
- expected: X2 W8A8 quant plan at runs/tinyspan_quant_plan/x2_quality_after_x4_20260625_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json
- expected: X2 RTL manifest at rtl/generated/tinyspan_c32b4_x2_quality_after_x4_20260625_x2_w8a8/tinyspan_w8a8_rtl_manifest.json
- expected: X2 hardware-tiled fixed reference at artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625/software_tiled_fixed_point_sr.png
- expected: readiness report that remains incomplete until the X2 bitstream and board output exist

2. `x2_bitstream`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\vivado\run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1 -Scale 2 -ImgW 640 -ImgH 360 -TileW 64 -TileH 64 -PlFreqMhz 155 -BitstreamOut vivado/bitstreams/tinyspan_x2_c32b4_x2_quality_after_x4_20260625_board.bit -RequireVivadoIdle
```

- starts Vivado/board flow: `True`
- expected: X2 bitstream copied to vivado/bitstreams/tinyspan_x2_c32b4_x2_quality_after_x4_20260625_board.bit
- expected: timing, utilization, power, and resource-gate evidence under the XC7Z045/ZC706 limits

3. `x2_board_acceptance`

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\acceptance\run_tinyspan_720p30_board_acceptance.ps1 -Scale 2 -InputWidth 640 -InputHeight 360 -TileWidth 64 -TileHeight 64 -SoftwarePng artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625/pytorch_training_sr.png -FixedPng artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625/software_tiled_fixed_point_sr.png -BoardRaw REPLACE_WITH_X2_BOARD_OUTPUT.rgb -MeasuredFps REPLACE_WITH_MEASURED_FPS -Checkpoint runs/tinyspan_frozen_candidates/x2_quality_after_x4_20260625/student_final.pt -QuantPlan runs/tinyspan_quant_plan/x2_quality_after_x4_20260625_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json -Bitstream vivado/bitstreams/tinyspan_x2_c32b4_x2_quality_after_x4_20260625_board.bit -BoardLog REPLACE_WITH_X2_BOARD_RESOURCE_OR_RUN_LOG.json -OutDir artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_tile64x64
```

- starts Vivado/board flow: `True`
- expected: real X2 board output from the same frozen checkpoint and quant plan
- expected: A53/DDR or board-side compare mismatch 0 and max channel diff 0
- expected: measured full-frame throughput >=30fps
- expected: board_sr.png, comparison_preview.png, and diff_heatmap.png for visual review

4. `x2_package_manifest`

```powershell
python .\scripts\acceptance\package_tinyspan_gate_h_board_acceptance.py --repo-root . --acceptance-dir artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_tile64x64 --scale 2 --input-width 640 --input-height 360 --tile-width 64 --tile-height 64 --tile-count 60 --status PASS_X2 --route "TinySPAN PS/DDR X2 via board zynq_ultra_ps_e / PS DDR controller IP"
```

- starts Vivado/board flow: `False`
- expected: manifest.json with checkpoint, quant plan, bitstream, throughput, correctness, and copied image evidence
- expected: run_summary.md for review without opening the raw logs
- expected: package_pass true only after board-vs-fixed equality, >=30fps, and required evidence are present

## Boundary

- This is a static readiness audit only.
- It does not prove X2 correctness, bitstream generation, board output, or throughput.
- X2 delivery still requires frozen checkpoint, W8A8 quant plan, X2 RTL/top, bitstream, real board output, board-vs-software equality, and `>=30fps` evidence.
