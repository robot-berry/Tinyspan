# TinySPAN PS/DDR X4 tile64 FIFO f155 board report

Date: `2026-06-25`

## Conclusion

Status: `THROUGHPUT_PASS`

This run keeps the DDR route fixed to the board `zynq_ultra_ps_e` / PS DDR controller IP with the FACE-ZUSSD reference PS DDR configuration. No custom DDR controller, DDR PHY, board-level DDR timing logic, or DDR arbitration fabric was added.

The RTL optimization is TinySPAN user logic only:

- `rtl/board_wrapper/sr_tile_rgb_buffer_streamer.v`
  - adds a small stream FIFO and two-stage read pipeline;
  - reduces per-pixel tile-buffer read stalls before the TinySPAN stream input;
  - fixes the issue counter width so power-of-two tile sizes such as `64x64` are not truncated.

The `sr_ddr_pixel_axi_master` path is still a transitional AXI debug/user path through the PS DDR IP. It is not a custom DDR controller and should not be treated as the final high-performance I/O implementation. Final delivery should continue toward Xilinx AXI DMA/DataMover/VDMA or burst-oriented vendor-IP data movement.

## Bitstream

- Bitstream: `vivado/ps_tinyspan_ddr_x4_tile64_fifo_f155/ps_tinyspan_ddr_x4.runs/impl_1/pstinyspanx4ddr_wrapper.bit`
- SHA256: `A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232`
- Route: TinySPAN PS DDR X4 via board PS DDR controller IP
- Custom DDR controller/PHY: `no`
- Tile: `64x64`
- PL frequency: `155MHz`

## Timing and resources

- WNS: `0.020ns`
- TNS: `0.000ns`
- WHS: `0.007ns`
- THS: `0.000ns`
- Timing constraints: met
- CLB LUTs: `6353`
- CLB Registers: `4647`
- Block RAM Tile: `27`
- DSPs: `81`
- URAM: `0`

## Simulation

Vivado behavioral endpoint simulation passed after the tile-stream FIFO change:

```text
PASS sr_ddr_tinyspan_x4_endpoint_data pixels=16384 writes=16384
$finish called at time : 886535 ns
```

The previous back-to-back endpoint simulation ended at about `906985 ns`, so this change reduces one `32x32` endpoint data case by about `20450 ns` in the behavioral model.

## Board evidence

### A53 DDR alias probe

- Run directory: `board_runs/a53_ddr_alias_probe/probe_20260625_0410_tile64_fifo_f155`
- Result: `A53_DDR_ALIAS_PASS=1`
- Mismatches: `0`

This confirms that the PS DDR configuration is still valid for this bitstream.

### X4 320x180 full-frame SKIP-read smoke

- Run directory: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_tile64_fifo_f155_skipread_20260625_0412`
- Image: `320x180 -> 1280x720`
- Tile size: `64x64`
- Tiles done: `15`
- Readback mode: `SKIP`
- Status: `PASS`
- Status reg: `0x00000009`
- Error reg: `0x00000000`
- Frame cycles: `5097068`
- FPS at 155MHz: `30.4096394240767`

This is real-board full-frame throughput evidence above the `30fps` target. Because readback mode is `SKIP`, this report by itself is not final Gate H correctness evidence.

## Follow-up correctness evidence

The matching full-frame correctness evidence has since been added with an A53 in-DDR comparator:

- Report: `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`
- Run directory: `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`
- Output pixels compared: `921600`
- Mismatch bytes: `0 / 2764800`
- Max channel diff: `0`

## Fixed reference prepared

The matching tile64 hardware-tiled software reference has been generated:

- Reference directory: `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625`
- Fixed PNG: `software_tiled_fixed_point_sr.png`
- Preview: `comparison_preview.png`
- Diff heatmap: `diff_heatmap.png`
- Tile manifest: `tile_manifest.json`
- Tile count: `15`

The final board output must be compared against this tile64 reference, not the older tile32 reference.

## Remaining gap

This throughput report is paired with the A53 in-DDR byte-exact compare report above. A visible board-output PNG or display/SD writeback artifact is still useful for presentation, but X4 Gate H correctness and throughput evidence are now both present.

The next readback path must keep using board/vendor IP:

1. Keep the board PS DDR controller IP, HP/HPC port, SmartConnect, and Xilinx AXI DMA/DataMover/VDMA path as the formal direction.
2. Do not add a custom DDR controller, DDR PHY, DDR timing module, or custom DDR arbitration fabric.
3. Use fixed-wait or DMA/DataMover-style output dumping to avoid the current XSCT status-read hang after `START_WRITE_DONE`.
4. Only claim final Gate H after the real board output matches the tile64 fixed reference byte-for-byte and the same run sustains `>=30fps`.
