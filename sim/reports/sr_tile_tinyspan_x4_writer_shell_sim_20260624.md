# TinySPAN X4 Full-Frame Tiling Shell XSim

Generated: `2026-06-24T16:46:44+08:00`

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\vivado\run_tinyspan_full_frame_tiling_sims.ps1 -WaitForVivadoIdleSeconds 0 -StableVivadoIdleSeconds 5
```

Result: `PASS`

## What Ran

- `sr_stream_dynamic_cropper` Vivado/xsim smoke passed.
- `sr_tile_tinyspan_x4_writer_shell` Vivado/xsim shell test passed.
- The first writer-shell attempt failed because `span_tinyspan_w8a8_scale_q31_symmetric.v` was not included in the Tcl source list. The Tcl source list was fixed and the simulation passed on rerun.

## PASS Markers

```text
PASS sr_stream_dynamic_cropper outputs=20
PASS sr_tile_tinyspan_x4_writer_shell tiles=4 writes=480 frame_cycles=17941
PASS run_tinyspan_full_frame_tiling_sims
```

## Logs

- Cropper sim log: `build/vivado_sr_stream_dynamic_cropper_sim/sr_stream_dynamic_cropper_sim.sim/sim_1/behav/xsim/simulate.log`
- Writer shell sim log: `build/ttx4_sim/ttx4_sim.sim/sim_1/behav/xsim/simulate.log`
- Writer shell elaborate log: `build/ttx4_sim/ttx4_sim.sim/sim_1/behav/xsim/elaborate.log`

## Scope Boundary

This is a Vivado/xsim shell-level tiling test. It proves that the TinySPAN X4 tile scheduler/fetch/crop/write shell can elaborate and complete a small multi-tile scenario in simulation.

It is not the final `320x180 -> 1280x720` real-board acceptance. Final X4 delivery still requires a full-frame bitstream, real board output, board-vs-fixed byte equality, and measured `>=30fps`.

## Runtime Note

The successful wrapper run took about `97s` wall-clock in this environment. A larger all-tile simulation for the full `320x180` LR frame would be expected to take longer; final throughput must be measured on board, not inferred from xsim wall time.
