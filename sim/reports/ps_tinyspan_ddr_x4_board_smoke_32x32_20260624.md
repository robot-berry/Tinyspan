# TinySPAN PS/DDR X4 32x32 board smoke status

Date: 2026-06-24

## Route

- Main route: TinySPAN X4, not W8A12.
- DDR policy: use board ZynqMP PS DDR controller IP through Vivado Block Design.
- Do not implement a custom DDR controller, DDR PHY, or board-level DDR timing logic.
- Current `sr_ddr_pixel_axi_master` is only a single-beat AXI debug bridge for smoke/mismatch isolation. It is not the final 720p30 I/O performance route.

## Real Board Smoke Evidence

- Run directory:
  `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_20260624_230920`
- Bitstream:
  `vivado/ps_tinyspan_ddr_x4/ps_tinyspan_ddr_x4.runs/impl_1/pstinyspanx4ddr_wrapper.bit`
- Board output:
  `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_20260624_230920/board_output_128x128.png`
- Status register: `0x00000009`
- Error register: `0x00000000`
- Tiles done: `1`
- Frame cycles: `430346`
- Small-tile FPS from frame cycles at 150 MHz: `348.556742714002`

This proves that the PS/DDR bitstream can be programmed, PS can write the LR input into DDR, PL can start TinySPAN, PL can write an HR output frame into DDR, and PS/XSCT can read back a real board output image.

## Current Correctness Gate

The board output does not yet match the software fixed-point tiled TinySPAN result.

- Comparison summary:
  `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_20260624_230920/board_vs_fixed_summary.md`
- Board-vs-fixed mismatch bytes: `24138 / 49152`
- Max channel diff: `215`
- Observed pattern: row blocks repeat/shift by 32 HR rows. For example, board rows `0..31` match the fixed reference rows `32..63`, and board rows `64..95` match fixed rows `96..127`.

Therefore this is not a completed board-acceptance result. It must not be reported as TinySPAN X4 correctness acceptance.

## New Isolation Simulations

Two new RTL simulations were added to narrow the mismatch:

1. `tb_span_tinyspan_w8a8_fast_backpressure`
   - Runs the parallel fast TinySPAN base core against a no-backpressure reference core.
   - Result: `PASS tinyspan_w8a8_fast_backpressure outputs=16384`.
   - Meaning: the parallel TinySPAN core is stable under output backpressure in this test.

2. `tb_sr_tile_tinyspan_x4_writer_shell_data`
   - Compares `sr_tile_tinyspan_x4_writer_shell` output against a direct TinySPAN core for one full `32x32 -> 128x128` tile.
   - Uses `BYTES_PER_PIXEL=4` and output write backpressure.
   - Result: `PASS sr_tile_tinyspan_x4_writer_shell_data pixels=16384 frame_cycles=98321`.
   - Meaning: fetch, local tile buffer, TinySPAN wrapper, crop, and output writer match the direct core in RTL simulation.

3. `tb_sr_ddr_tinyspan_x4_endpoint_data`
   - Adds `sr_ddr_tinyspan_x4_tile_writer_endpoint`, AXI-Lite control, `sr_ddr_pixel_axi_master`, and a behavioral AXI DDR model.
   - Result: `PASS sr_ddr_tinyspan_x4_endpoint_data pixels=16384 writes=16384`.
   - Meaning: endpoint-level AXI control/data behavior matches the direct TinySPAN core in simulation.

## Current Diagnosis

The mismatch is now narrowed outside the pure TinySPAN RTL behavior checked above. The next likely causes are:

- stale or out-of-date Vivado BD/bitstream contents;
- actual PS HP0/AXI interconnect integration behavior that differs from the simple AXI memory model;
- XSCT DDR write/read access ordering or memory map issue;
- board-side run script using an older bitstream than the current RTL source.

## Required Next Step

Before moving to larger frame tests, rebuild or regenerate the TinySPAN PS/DDR bitstream from the current committed RTL and rerun the same `32x32` board smoke with full readback. Acceptance may proceed only after:

- board output from the rebuilt bitstream matches `software_tiled_fixed_point_sr.png` byte-for-byte;
- the run directory contains board output, fixed reference, preview, diff heatmap, and summary;
- the report explicitly ties the bitstream SHA, quant plan/checkpoint, software reference, and board output to the same TinySPAN route.
