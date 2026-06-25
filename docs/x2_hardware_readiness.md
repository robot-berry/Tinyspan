# TinySPAN X2 Hardware Readiness

- status: `PARTIAL`
- generated at: `2026-06-25T12:06:52`
- X2 training status: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json`
- X2 quant plan: ``
- X2 RTL manifest: ``

## Blockers

- `x2_quant_plan_exists`
- `x2_rtl_manifest_exists`

## Checks

| Check | Required | Status | Detail |
| --- | --- | --- | --- |
| `x2_training_status_artifact` | `False` | `PASS` | `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json` |
| `x2_quant_plan_exists` | `True` | `FAIL` | `` |
| `x2_rtl_manifest_exists` | `True` | `FAIL` | `` |
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

## Boundary

- This is a static readiness audit only.
- It does not prove X2 correctness, bitstream generation, board output, or throughput.
- X2 delivery still requires frozen checkpoint, W8A8 quant plan, X2 RTL/top, bitstream, real board output, board-vs-software equality, and `>=30fps` evidence.
