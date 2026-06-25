# TinySPAN Board Acceptance Summary

- Status: `PASS`
- Target: `TinySPAN X2 720p30`
- Board-vs-fixed-point compare: `PASS`
- Throughput: `PASS` (32.8605 fps / target 30.0000 fps)
- Resource evidence: `PASS`
- missing resource fields: ``
- board-vs-fixed mismatch bytes: `0 / 2764800`
- board-vs-fixed max channel diff: `0`
- board-vs-training: `{'mismatch_bytes': 1666116, 'total_bytes': 2764800, 'max_channel_diff': 41, 'ref_size': [1280, 720], 'actual_size': [1280, 720], 'size_match': True}`
- fixed-vs-training: `{'mismatch_bytes': 1666116, 'total_bytes': 2764800, 'max_channel_diff': 41, 'ref_size': [1280, 720], 'actual_size': [1280, 720], 'size_match': True}`
- checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
- quant plan: `runs\tinyspan_quant_plan\x2_quality_after_x4_20260625_x2_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- bitstream: `vivado\bitstreams\tinyspan_x2_c32b4_x2_quality_after_x4_20260625_tile64_o16_wrpipe_rgbpipe_f188_div8_perf_board.bit`
- board log: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626\implementation_resources.json`
- software: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625\pytorch_training_sr.png`
- fixed: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625\software_tiled_fixed_point_sr.png`
- board: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626\board_sr_a53_equal_to_fixed.png`
- preview: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626\tinyspan_board_software_preview.png`
- compare summary: `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626\tinyspan_board_software_summary.json`

## Implementation Resources

- utilization report: `G:\UESTC\feitengspan1\Tinyspan\vivado\x2_640x360_t64_f188_div8_parallel_x2q_o16_wrpipe_rgbpipe_perf_20260626_0548\reports\ps_tinyspan_ddr_x4_utilization_impl.rpt`
- timing report: `G:\UESTC\feitengspan1\Tinyspan\vivado\x2_640x360_t64_f188_div8_parallel_x2q_o16_wrpipe_rgbpipe_perf_20260626_0548\reports\ps_tinyspan_ddr_x4_timing_impl.rpt`
- CLB LUTs: `6647`
- CLB Registers: `5031`
- Block RAM Tile: `27`
- DSPs: `100`
- WNS ns: `0.002`
- WHS ns: `0.014`
- perf frame cycles: `5706307`
- perf E2E cycles: `5706307`
- measured fps: `32.86048226988138`

