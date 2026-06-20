# TinySPAN Board Acceptance Summary

- Status: `PASS`
- Target: `TinySPAN-x4-32x32-board`
- Board-vs-software compare: `PASS`
- Throughput: `PASS` (1831.1441 fps / target 30.0000 fps)
- Resource evidence: `PASS`
- missing resource fields: ``
- mismatch bytes: `0 / 49152`
- max channel diff: `0`
- checkpoint: `runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
- quant plan: `runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- bitstream: `vivado\bitstreams\jfs_full_span_x4_32x32_f150m_tinyspan_w8a8_base_equiv_fast.bit`
- board log: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\implementation_resources.json`
- software: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\software_reference\pytorch_base_equiv.png`
- fixed: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\software_reference\rtl_base_equiv.png`
- board: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\board_output_x4_32x32_tinyspan_w8a8_base_equiv.png`
- preview: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\acceptance\tinyspan_board_software_preview.png`
- compare summary: `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\acceptance\tinyspan_board_software_summary.json`

## Implementation Resources

- utilization report: `G:\UESTC\feitengspan1\vivado\reports\jtag_full_span_x4_32x32_f150m_tinyspan_w8a8_base_equiv_fast_utilization_impl.rpt`
- timing report: `G:\UESTC\feitengspan1\vivado\reports\jtag_full_span_x4_32x32_f150m_tinyspan_w8a8_base_equiv_fast_timing_impl.rpt`
- CLB LUTs: `5943`
- CLB Registers: `5232`
- Block RAM Tile: `10.5`
- DSPs: `78`
- WNS ns: `0.091`
- WHS ns: `0.004`
- perf frame cycles: `81916`
- perf E2E cycles: `495227437`
- measured fps: `1831.144098832951`

