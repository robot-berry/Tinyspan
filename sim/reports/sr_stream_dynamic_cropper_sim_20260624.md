# sr_stream_dynamic_cropper Simulation

Date: `2026-06-24`

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_stream_dynamic_cropper.ps1 -RequireVivadoIdle -StableVivadoIdleSeconds 5
```

Result: `PASS`

Key log line:

```text
PASS sr_stream_dynamic_cropper outputs=20
```

Coverage:

- Input raster: `8x6`
- Dynamic valid region: `5x4`
- Expected output pixels: `20`
- Backpressure applied on `m_ready`
- Checked output order, `m_user`, row `m_last`, and output count

Root workspace log:

```text
G:\UESTC\feitengspan1\build\vivado_sr_stream_dynamic_cropper_sim\sr_stream_dynamic_cropper_sim.sim\sim_1\behav\xsim\simulate.log
```

This proves the dynamic edge-tile cropper can drain a fixed-size upstream tile stream while emitting only the valid top-left region needed by full-frame TinySPAN tiling.
