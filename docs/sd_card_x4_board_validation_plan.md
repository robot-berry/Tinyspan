# TinySPAN X4 SD Card Board Validation Plan

## Goal

After the currently running W8A12 board task is finished and the board is idle, run a TinySPAN X4 board validation using an image that already exists on the board SD card.

This validation is a presentation and scenario-evidence run for the contest workflow. It must not replace the existing X4 Gate H proof unless the evidence shows the same hard gates:

- TinySPAN X4 bitstream is the tile64 FIFO f155 route or a later verified TinySPAN route.
- Input source is recorded as board SD card, with filename and hash if available.
- Output is produced by the real board.
- Board output matches the matching hardware-tiled fixed-point software reference byte-for-byte, or an A53 in-DDR comparator reports `0` mismatch for the same reference.
- Measured throughput is `>=30fps`.

## Current Constraint

The existing TinySPAN X4 board scripts are ready for PS/DDR validation, but their input path is currently PC-file-to-DDR:

```text
scripts/board/run_ps_tinyspan_ddr_x4_smoke.ps1
scripts/board/run_ps_tinyspan_ddr_x4_a53_compare.ps1
```

These scripts convert a local `InputPng` to raw RGB on the host, write it into DDR through XSCT/A53 support logic, and then launch the PL TinySPAN core. That is valid for DDR path validation, but it is not yet a proof that the board itself read the image from SD card.

For a strict "board SD card existing image" run, one of the following must be added or confirmed:

- A PS/A53 loader that reads the image file from the board SD card into the DDR input buffer before starting TinySPAN.
- A Linux-side or baremetal FatFs SD reader path that copies the SD image into the same DDR input buffer used by the TinySPAN endpoint.
- A documented board SD export path that proves the chosen SD image is the source, then runs the existing DDR path with the same file and records the SD filename/hash as presentation evidence. This is weaker than a true PS SD-to-DDR runtime path and must be labeled as such.

## Wait Rule

Do not start this TinySPAN X4 SD validation while any board/Vivado/XSCT/JTAG task is active. In particular, wait for the current W8A12 board acceptance processes to exit:

```text
run_w8a12_32x32_plddridx_u32idx_acceptance.ps1
run_ps_w8a12_ddr_tile_writer_smoke.ps1
```

Only after these are gone should the TinySPAN X4 SD validation start.

## Planned Run Sequence

1. Confirm no active `vivado`, `xsct`, `hw_server`, W8A12 board script, or TinySPAN board script is running.
2. Confirm X2 training is still only being monitored; do not start X2 Vivado/JTAG before X2 training finishes.
3. Inventory the board SD card images and pick one image for X4.
4. If the image is already LR, require `320x180` RGB-equivalent input for X4. If it is HR, generate or locate the matching `320x180` LR input and keep the HR image as quality reference.
5. Generate the matching TinySPAN tile64 hardware-tiled fixed-point reference for the exact LR input and current X4 checkpoint/quant plan.
6. Run the TinySPAN X4 board path after the board is idle.
7. Produce a run directory under:

```text
board_runs/tinyspan_ps_ddr_x4_sd_card/
```

8. Archive a manifest with:
   - SD filename and hash if available
   - LR input hash
   - checkpoint SHA256
   - quant plan SHA256
   - bitstream SHA256
   - board output or A53 in-DDR compare summary
   - measured fps
   - quality metrics against HR/teacher reference when available

## Required Report After Board Run

After the TinySPAN X4 SD-card board run finishes, report both resource cost and SR effect:

- Resource cost: LUT/CLB LUT, FF/register, DSP, BRAM Tile, URAM, WNS/TNS, PL frequency, and bitstream SHA256.
- Throughput: frame cycles, measured fps, tile count, and whether `>=30fps` passed.
- Correctness: board-vs-fixed mismatch bytes, total bytes, max channel diff, and whether byte-exact comparison passed.
- SR effect: PSNR, SSIM, MAE, max diff against HR/teacher reference when available, plus bicubic baseline if available.
- Visuals: `board_sr.png` when available, `comparison_preview.png`, and `diff_heatmap.png`.
- Boundary: explicitly state whether the input was truly read from board SD card or only replayed through the host-to-DDR path.

## Pass Boundary

This SD card validation can strengthen the contest presentation and actual-scenario evidence. It does not make the whole contest workflow complete until X2 also has an independent frozen checkpoint, quant plan, RTL, bitstream, real board output, board-vs-fixed equality, and `>=30fps` throughput evidence.
