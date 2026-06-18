# TinySPAN 720p30 X2/X4 Board Workflow

## 1. Goal

Implement realtime X2/X4 super-resolution for a downsampled image or video
frame, running on the existing `xczu19eg-ffvc1760-2-i` board, while enforcing
the ZC706 / XC7Z045 resource limit. The final accepted output must be a full
720p frame at 30fps or higher.

This workflow assumes:

- Actual board target: `xczu19eg-ffvc1760-2-i`
- Resource gate: XC7Z045 / ZC706 limits
- X2 frame contract: `640x360 -> 1280x720`
- X4 frame contract: `320x180 -> 1280x720`
- Tile cutting is performed by hardware from SD/DDR full-frame input
- PC-side pre-cut tiles are not valid for final acceptance
- Board output must be byte-exact with the software fixed-point reference

## 2. Resource Gate

The implementation runs on the original board, but the final implementation
report must not exceed the XC7Z045 resource limits:

| Resource | Limit |
| --- | ---: |
| DSP | 900 |
| BRAM Tile | 545 |
| URAM | 0 |
| I/O | 362 |
| Slice LUT | 218600 |
| Slice Register | 437200 |

`value <= limit` is considered passing. Any `value > limit` is a failure.

## 3. Required Data Flow

```text
SD card or DDR full frame
 -> PS configuration registers
 -> PL tile scheduler
 -> DDR halo/tile fetch
 -> RGB normalize and quantize
 -> TinySPAN / SPAN compute core
 -> tail and PixelShuffle X2 or X4
 -> RGB888 output writer
 -> DDR 1280x720 output frame
 -> PS readback or display path
```

The hardware must own tile splitting, halo fetch, border handling, and final
output placement. Software may prepare the original full input frame and may
verify the final output, but it must not pre-cut the image into inference
tiles for the accepted board run.

## 4. Repository Output Policy

All future generated evidence for this workflow should be copied under:

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts
```

Use one directory per run:

```text
artifacts/YYYYMMDD_scale_model_tile_freq_shorttag/
```

Example:

```text
artifacts/20260618_x4_w8a12_tile20_h21_f50_origboard/
```

Each run directory should contain:

- `manifest.json`
- `run_summary.md`
- `checkpoint.sha256`
- `quant_plan.sha256`
- `input.sha256`
- `software_reference.sha256`
- `board_output.sha256`
- `resource_gate.json`
- `timing.rpt`
- `utilization.rpt`
- `board.log`
- `throughput.json`

Large Vivado temporary directories, `.Xil`, intermediate work folders, and
oversized logs should stay outside Git or be summarized before upload.

## 5. Workflow Gates

### Gate A - Freeze Model

Inputs:

- Final training checkpoint
- Final `metrics.csv`
- Model configuration

Outputs:

- Frozen checkpoint copy
- SHA256 hashes
- Final metric row

Pass condition:

- Checkpoint is immutable for the acceptance run
- No training process is still modifying it

### Gate B - Quantization and Software Reference

Inputs:

- Frozen checkpoint
- Calibration set
- Target scale, X2 or X4

Outputs:

- Quant plan
- Integer software reference
- Reference output image/frame

Pass condition:

- Quant plan and software reference are generated from the same frozen
  checkpoint
- SHA256 hashes are recorded

### Gate C - RTL Export

Inputs:

- Frozen checkpoint
- Quant plan

Outputs:

- RTL memory files
- RTL manifest
- Export summary

Pass condition:

- RTL export manifest references the exact checkpoint and quant plan hashes
- No stale moving checkpoint is used

### Gate D - Simulation

Inputs:

- RTL export
- Software fixed-point vectors
- Tile parameters

Outputs:

- Layer-level simulation logs
- Tile-level simulation logs
- Output comparison report

Pass condition:

- RTL tile output matches software fixed-point reference byte-for-byte

### Gate E - Implementation

Inputs:

- RTL core
- PS DDR tile writer wrapper
- Tile parameters

Current preferred low-parallel candidate:

```text
TileW=20
TileH=20
Halo=21
PL clock=50MHz
OutLanes=1
TapLanes=4
ScaleLanes=1
```

Pass condition:

- Bitstream is generated for `xczu19eg-ffvc1760-2-i`
- Timing is met
- XC7Z045 resource gate passes
- Vivado exits cleanly and no Vivado helper process remains

### Gate F - Board Smoke

Inputs:

- Accepted bitstream
- Full input frame in SD/DDR format
- PS/PL runtime scripts

Pass condition:

- Hardware target is detected
- Bitstream programs successfully
- PS initializes DDR buffers
- PL processes hardware-cut tiles
- Board output is read back

If JTAG target count is `0`, stop and fix board power, USB-JTAG, JTAG mode,
driver, or tool ownership before rerunning.

### Gate G - Final 720p30 Acceptance

Inputs:

- Frozen checkpoint
- Quant plan
- Same input frame
- Same bitstream
- Board output

Pass condition:

- Output frame size is `1280x720`
- Board output SHA256 equals software fixed-point reference SHA256
- Measured throughput is at least `30fps`
- Resource report passes the XC7Z045 gate
- All evidence is copied into `Tinyspan/artifacts/...`

## 6. Current Known Status

As of 2026-06-18:

- TinySPAN training has completed.
- A low-parallel W8A12 DDR tile writer bitstream for the original board has
  passed timing and the XC7Z045 resource gate.
- The latest board smoke did not reach bitstream programming because Vivado
  found `0` JTAG targets.
- Final acceptance is not complete until a real board output from the same
  frozen checkpoint and quant plan matches the software fixed-point reference
  and reaches 720p30.

## 7. Completion Definition

The task is complete only when both X2 and X4 requested modes have evidence
bundles showing:

```text
same frozen checkpoint
same quant plan
same full-frame input
same bitstream
software fixed-point output == board output byte-for-byte
output resolution == 1280x720
measured throughput >= 30fps
resource gate == PASS
```
