# TinySPAN 720p30 Board Acceptance Readiness

Ready: `False`

Handoff summary: `runs\tinyspan_realtime_handoff\c32b4_c32b4_30fps_frozen_20260613_summary.json`
RTL manifest: `rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8\tinyspan_w8a8_rtl_manifest.json`
Head frontend DCP: `build\vivado_tinyspan_w8a8_head_frontend_synth\tinyspan_w8a8_head_frontend_synth.dcp`
Final RGB888 top: `rtl\span\span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v`
Base equivalence compare script: `scripts\compare_tinyspan_base_equiv_reference.ps1`
JTAG build script: `scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1`
JTAG smoke script: `scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1`
720p30 acceptance script: `scripts\run_tinyspan_720p30_board_acceptance.ps1`
720p30 preflight script: `scripts\check_tinyspan_720p30_acceptance_inputs.ps1`
Acceptance summary writer: `tools\write_tinyspan_board_acceptance_summary.py`
Board resource log writer: `tools\write_board_resource_log.py`
Vivado idle script: `scripts\check_vivado_idle.ps1`
Vivado cleanup script: `scripts\cleanup_vivado_processes.ps1`
Expected bitstream: `vivado\bitstreams\tinyspan_c32b4_30fps_frozen_20260613.bit`
Board output: ``

| Check | Result | Detail |
| --- | --- | --- |
| `handoff_summary_exists` | `PASS` | `runs\tinyspan_realtime_handoff\c32b4_c32b4_30fps_frozen_20260613_summary.json` |
| `handoff_passed` | `PASS` | `passed=True` |
| `checkpoint` | `PASS` | `runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt` |
| `manifest` | `PASS` | `rtl\generated\tinyspan_x4_c32_b4_c32b4_30fps_frozen_20260613_fused\tinyspan_manifest.json` |
| `quant_plan` | `PASS` | `runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json` |
| `integer_reference_summary` | `PASS` | `runs\tinyspan_integer_reference\c32b4_30fps_frozen_20260613_x4_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_summary.md` |
| `integer_reference_preview` | `PASS` | `runs\tinyspan_integer_reference\c32b4_30fps_frozen_20260613_x4_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_preview.png` |
| `tinyspan_w8a8_rtl_manifest_exists` | `PASS` | `rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8\tinyspan_w8a8_rtl_manifest.json` |
| `tinyspan_w8a8_rtl_layer_count` | `PASS` | `layers=15, expected=15` |
| `tinyspan_w8a8_rtl_postprocess_blocks` | `PASS` | `blocks=4, expected=4` |
| `tinyspan_w8a8_rtl_channels` | `PASS` | `channels=32, expected=32` |
| `tinyspan_w8a8_rtl_header` | `PASS` | `rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8\tinyspan_w8a8_layers.vh` |
| `tinyspan_w8a8_rtl_references_exist` | `PASS` | `missing_refs=0` |
| `tinyspan_w8a8_head_frontend_synth_dcp` | `PASS` | `build\vivado_tinyspan_w8a8_head_frontend_synth\tinyspan_w8a8_head_frontend_synth.dcp` |
| `tinyspan_w8a8_final_rgb888_top` | `PASS` | `rtl\span\span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v` |
| `tinyspan_base_equiv_compare_script` | `PASS` | `scripts\compare_tinyspan_base_equiv_reference.ps1` |
| `tinyspan_jtag_build_script` | `PASS` | `scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` |
| `tinyspan_jtag_smoke_script` | `PASS` | `scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1` |
| `tinyspan_720p30_acceptance_script` | `PASS` | `scripts\run_tinyspan_720p30_board_acceptance.ps1` |
| `tinyspan_720p30_preflight_script` | `PASS` | `scripts\check_tinyspan_720p30_acceptance_inputs.ps1` |
| `tinyspan_board_resource_log_writer` | `PASS` | `tools\write_board_resource_log.py` |
| `vivado_idle_script` | `PASS` | `scripts\check_vivado_idle.ps1` |
| `vivado_cleanup_script` | `PASS` | `scripts\cleanup_vivado_processes.ps1` |
| `tinyspan_acceptance_summary_resource_embed` | `PASS` | `tools\write_tinyspan_board_acceptance_summary.py` |
| `tinyspan_acceptance_summary_requires_resources` | `PASS` | `tools\write_tinyspan_board_acceptance_summary.py` |
| `tinyspan_720p30_acceptance_locks_720p` | `PASS` | `scripts\run_tinyspan_720p30_board_acceptance.ps1` |
| `tinyspan_720p30_acceptance_locks_tile32` | `PASS` | `scripts\run_tinyspan_720p30_board_acceptance.ps1` |
| `tinyspan_720p30_acceptance_requires_resource_json` | `PASS` | `scripts\run_tinyspan_720p30_board_acceptance.ps1` |
| `tinyspan_jtag_build_vivado_idle_precheck` | `PASS` | `scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` |
| `tinyspan_jtag_build_vivado_cleanup` | `PASS` | `scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` |
| `tinyspan_jtag_smoke_vivado_idle_precheck` | `PASS` | `scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1` |
| `tinyspan_jtag_smoke_vivado_cleanup` | `PASS` | `scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1` |
| `tinyspan_trained_bitstream_exists` | `FAIL` | `vivado\bitstreams\tinyspan_c32b4_30fps_frozen_20260613.bit` |
| `real_board_output_provided` | `FAIL` | `BoardOutput is empty` |
