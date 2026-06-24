# TinySPAN PS/DDR X4 tile64 FIFO f155 A53 compare report

Date: `2026-06-25`

## Conclusion

Status: `X4_GATE_H_PASS_WITH_A53_COMPARE`

The X4 full-frame route now has both required real-board evidence:

- throughput: `30.4096394240767fps @155MHz`
- correctness: complete `1280x720` SR frame in PS DDR matches the tile64 hardware-tiled fixed-point reference byte-for-byte

DDR remains board/vendor IP only. The route uses `zynq_ultra_ps_e` / PS DDR controller IP, HP/HPC, and standard AXI interconnect. No custom DDR controller, DDR PHY, DDR arbitration fabric, or board-level DDR timing logic was added.

## Method

This run avoids the XSCT AXI-Lite status-read hang seen after `START_WRITE_DONE` by using a fixed wait and an A53 in-DDR comparator:

1. Program or reuse the tile64 FIFO f155 bitstream.
2. Initialize the board PS DDR controller with the generated `psu_init.tcl`.
3. Use XSCT `dow -data` to place:
   - packed LR input words at `0x10000000`;
   - tile64 fixed-reference RGB888 bytes at `0x14000000`;
   - poison output words at `0x11000000`.
4. Configure the TinySPAN AXI-Lite registers and start the PL accelerator.
5. Wait `1000ms` without polling post-start AXI-Lite status.
6. Run a small A53 baremetal comparator from OCM.
7. Compare all `921600` output pixels, channel by channel, in DDR.

The poison buffer makes the test sensitive to missing PL writes: a stale all-correct output buffer cannot silently pass unless the current run overwrites the poisoned data.

## Evidence

- Run directory: `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`
- Summary: `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559/tinyspan_a53_compare_summary.json`
- XSCT log: `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559/tinyspan_a53_compare.log`
- Bitstream: `vivado/ps_tinyspan_ddr_x4_tile64_fifo_f155/ps_tinyspan_ddr_x4.runs/impl_1/pstinyspanx4ddr_wrapper.bit`
- Bitstream SHA256: `A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232`
- Fixed reference: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png`
- Input image: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/lr_input_resized.png`

## Result

- Image: `320x180 -> 1280x720`
- Tile: `64x64`
- Output pixels compared: `921600`
- Total bytes compared: `2764800`
- Mismatch bytes: `0`
- Max channel diff: `0`
- A53 compare status: `0x50415353` (`PASS`)
- Custom DDR controller/PHY: `no`

The corresponding throughput evidence is the prior SKIP-read run from the same bitstream and tile contract:

- Run directory: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_tile64_fifo_f155_skipread_20260625_0412`
- Frame cycles: `5097068`
- PL frequency: `155MHz`
- FPS: `30.4096394240767`
- Tiles done: `15`
- Error register: `0x00000000`

## Current boundary

This closes X4 Gate H as a correctness-plus-throughput evidence pair for the same frozen checkpoint, quant plan, tile contract, and bitstream. It still does not close the whole contest workflow:

- X2 independent freeze/quant/RTL/bitstream/board evidence is still missing.
- A board-output PNG or display/SD writeback artifact is still useful for presentation, even though the A53 in-DDR compare proves byte-exact correctness.
