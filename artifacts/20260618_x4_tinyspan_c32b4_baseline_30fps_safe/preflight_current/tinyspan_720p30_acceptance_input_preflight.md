# TinySPAN 720p30 Acceptance Input Preflight

Ready: `False`

This preflight does not start Vivado, JTAG, or board runs.

## Evidence Fingerprints

- checkpoint SHA256: `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- quant plan SHA256: `EB6EEDDDE9360F61E6FC30141B2A1E6539E519CB226AC18B8C219B9E40092C9D`
- bitstream SHA256: ``
- board raw SHA256: ``
- board png SHA256: ``
- board log SHA256: ``

## Checks

- `PASS` lr_input_contract: `320x180, expected 320x180`
- `PASS` sr_output_contract: `1280x720, expected 1280x720`
- `PASS` tile_contract: `32x32, expected 32x32`
- `PASS` measured_fps_ge_30: `measured_fps=36.0797673141875`
- `PASS` checkpoint_exists: `runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
- `PASS` quant_plan_exists: `runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- `FAIL` bitstream_exists: `vivado\bitstreams\tinyspan_c32b4_30fps_frozen_20260613.bit`
- `FAIL` board_log_exists: ``
- `PASS` bitstream_extension_is_bit: `vivado\bitstreams\tinyspan_c32b4_30fps_frozen_20260613.bit`
- `FAIL` real_board_output_exists: `BoardRaw=; BoardPng=`
- `PASS` quant_plan_source_checkpoint_matches: `quant=G:\UESTC\feitengspan1\runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt; checkpoint=runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
- `FAIL` board_resource_fields_complete: `BoardLog missing`
- `FAIL` board_log_bitstream_matches: `BoardLog missing`
- `FAIL` board_log_measured_fps_matches: `BoardLog missing`
