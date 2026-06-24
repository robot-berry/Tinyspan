# TinySPAN PS/DDR X4 posted-write board report

Date: `2026-06-25`

## Conclusion

Status: `PARTIAL_PASS`

The TinySPAN PS/DDR X4 route now uses the board `zynq_ultra_ps_e` / PS DDR controller IP with the FACE-ZUSSD reference PS DDR configuration. No custom DDR controller, DDR PHY, or board-level DDR timing logic was added.

The RTL change in this run is AXI user logic only:

- `rtl/board_wrapper/sr_ddr_pixel_axi_master.v`
  - changed output writes from blocking single-beat writes to posted single-beat AXI writes;
  - keeps a small outstanding-write counter;
  - reads remain blocking.
- `rtl/board_wrapper/sr_ddr_tinyspan_x4_tile_writer_endpoint.v`
  - waits for the AXI write path to drain before reporting frame `done`;
  - latches frame cycles after DDR write completion, not at shell-only completion.

This improves complete-frame X4 throughput from `6.6843209982062fps` to `22.1776304000312fps` at `150MHz`, but it is still below the `>=30fps` delivery target.

## Bitstream

- Bitstream: `vivado/ps_tinyspan_ddr_x4/ps_tinyspan_ddr_x4.runs/impl_1/pstinyspanx4ddr_wrapper.bit`
- SHA256: `3B7C4EEF6E2F0428ED442E06A2D5910A4156C8AAAF3F5534D605E5C15CDCCFC0`
- Route: TinySPAN PS DDR X4 via board PS DDR controller IP
- Custom DDR controller/PHY: `no`

## Timing and resources

- WNS: `0.075ns`
- TNS: `0.000ns`
- WHS: `0.019ns`
- THS: `0.000ns`
- CLB LUTs: `6169`
- CLB Registers: `4667`
- Block RAM Tile: `9`
- DSPs: `81`
- URAM: `0`

## Simulation

Vivado behavioral endpoint simulation passed:

```text
PASS sr_ddr_tinyspan_x4_endpoint_data pixels=16384 writes=16384
```

## Board evidence

### A53 DDR alias probe

The A53 DDR alias probe passed after programming the posted-write bitstream:

- Run directory: `board_runs/a53_ddr_alias_probe/probe_20260625_0132_postedwrite`
- Result: `PASS run_a53_ddr_alias_probe`

This keeps the reference PS DDR configuration gate closed: the board DDR address alias issue observed in the old bitstream is not present.

### X4 32x32 correctness smoke

- Run directory: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_postedwrite_20260625_0133`
- Image: `32x32 -> 128x128`
- Readback mode: `FULL`
- Status: `PASS`
- Status reg: `0x00000009`
- Error reg: `0x00000000`
- Tiles done: `1`
- Frame cycles: `114230`
- FPS at 150MHz: `1313.14015582597`
- Board-vs-fixed mismatch bytes: `0 / 49152`
- Max channel diff: `0`
- Board PNG: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_postedwrite_20260625_0133/board_output_128x128.png`
- Preview: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_postedwrite_20260625_0133/board_vs_fixed_preview.png`
- Diff heatmap: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_postedwrite_20260625_0133/board_vs_fixed_diff_heatmap.png`

### X4 320x180 full-frame SKIP-read smoke

- Run directory: `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_postedwrite_skipread_20260625_0136`
- Image: `320x180 -> 1280x720`
- Tile size: `32x32`
- Tiles done: `60`
- Readback mode: `SKIP`
- Status: `PASS`
- Status reg: `0x00000009`
- Error reg: `0x00000000`
- Frame cycles: `6763572`
- FPS at 150MHz: `22.1776304000312`

This run proves that the full-frame board-side tile scheduler can process all 60 X4 tiles and write the output frame through the PS DDR IP route. Because readback mode is `SKIP`, it is throughput evidence only and is not a final image-correctness acceptance run.

## Remaining gap

The current complete-frame throughput still needs about `35%` improvement to reach `30fps` at `150MHz`.

Recommended next optimization path:

1. Keep using the board PS DDR controller IP and HP/HPC port.
2. Replace the remaining blocking per-pixel read path with AXI burst or Xilinx AXI DMA/DataMover based transfers.
3. Keep the A53 DDR alias probe and X4 `32x32` board-vs-fixed smoke as regression gates after every PS/DDR/BD/AXI change.
4. Only claim final Gate H after a full `320x180 -> 1280x720` board output is read back and matches the hardware-tiled fixed reference byte-for-byte at `>=30fps`.
