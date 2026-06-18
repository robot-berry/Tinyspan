# TinySPAN Gate E Bitstream Retry Notes

Status: `IN_PROGRESS`

This note records the TinySPAN X4 `320x180 -> 1280x720` fast
base-equivalent bitstream retries on 2026-06-18. These attempts do not prove
Gate E completion because no TinySPAN bitstream has been generated yet.

## Target

- Route: TinySPAN W8A8 base-equivalent fast path
- Checkpoint: `c32b4_30fps_frozen_20260613`
- Scale: X4
- LR input geometry: `320x180`
- SR output geometry: `1280x720`
- PL clock target: `100 MHz`
- Expected bitstream:
  `vivado\bitstreams\jfs_full_span_x4_320x180_f100m_tinyspan_w8a8_base_equiv_fast.bit`

## Retry Findings

| Attempt | Result | Evidence | Action |
| --- | --- | --- | --- |
| `gate_e_x4_320x180_fast_20260618_203253` | wrapper failed before Vivado | `wrapper_stderr.log` reported unsupported path format | `run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` now accepts absolute or relative `CleanLogDir` |
| `gate_e_x4_320x180_fast_20260618_203428` | synthesis failed | Vivado reported missing `span_tinyspan_w8a8_bicubic_base_x4_streamed` | Added fast bicubic base module to TinySPAN Vivado source list |
| `gate_e_x4_320x180_fast_retry_20260618_203923` | synthesis failed | Vivado reported missing `span_tinyspan_w8a8_scale_q31_symmetric` | Added Q31 scaler module to TinySPAN Vivado source list |
| `gate_e_x4_320x180_fast_retry2_20260618_204338` | precheck stopped | Vivado idle check found an active Vivado process and cleanup removed it | Wait for stable Vivado idle before retrying |
| `gate_e_x4_320x180_fast_retry3_20260618_204515` | precheck stopped | Vivado idle check found an active Vivado process and cleanup removed it | A separate W8A12 simulation later appeared active; do not start TinySPAN Vivado while it runs |

## Current Gate E State

- TinySPAN fast source-list issues found so far have been fixed.
- No valid TinySPAN bitstream exists yet.
- No utilization/timing/power report exists for this TinySPAN target yet.
- No board output exists yet.
- Final Gate E remains `BLOCKED/IN_PROGRESS` until Vivado can run to
  implementation and produce the expected bitstream plus reports.

## Next Action

When Vivado/xsim is idle, rerun:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1 `
  -ImgW 320 `
  -ImgH 180 `
  -PlFreqMhz 100 `
  -Fast `
  -RequireVivadoIdle `
  -StableVivadoIdleSeconds 10 `
  -VivadoMaxThreads 1
```

Do not claim TinySPAN board acceptance from these retry notes.
