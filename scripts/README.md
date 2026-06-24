# TinySPAN Script Source Mirror

This directory stores the TinySPAN scripts relevant to the current workflow
gates. They are mirrored from `G:\UESTC\feitengspan1` for GitHub handoff and
review traceability.

Current folders:

- `vivado/`: Vivado simulation, OOC synthesis, and JTAG/full-frame bitstream
  entry scripts for the TinySPAN W8A8 base-equivalent route.
- `board/`: JTAG board smoke and output-capture wrapper.
  - `board/run_tinyspan_gate_h_tiledref_waitrun.ps1`: mirror-side entrypoint
    for the X4 Gate H 320x180 full-frame tiled-reference board run. It waits
    for Vivado to become idle, then calls the main workspace JTAG and
    acceptance scripts through `-WorkspaceRoot`.
- `acceptance/`: workflow status, board-readiness checks, 32x32 smoke
  acceptance, 720p30 acceptance, preflight hashing, hardware-tiled fixed
  reference generation, and board/software image comparison wrappers.
  - `acceptance/package_gate_h_tiledref_board_run.py`: copies completed Gate H
    board evidence into `artifacts/`, writes `manifest.json` and
    `run_summary.md`, and records raw frame SHA256 hashes without copying raw
    RGB frames by default.
  - `acceptance/check_gate_h_tiledref_board_run.py`: read-only post-run checker
    for Gate H. It verifies required files, board-vs-fixed byte equality, and
    measured fps without starting hardware flows.
  - `acceptance/refresh_x2_training_status.py`: refreshes the X2 training
    status artifact from live `metrics.csv`, process state, checkpoints, and
    stderr log tails without touching the running training job.
- `run_tinyspan_c32b4_post_training_prep.ps1`: common X2/X4 post-training
  entrypoint. Use `-Scale 2` for the independent X2 route and `-Scale 4` for
  X4. It refuses to freeze a still-running training checkpoint unless only
  `-DryRun` is requested.
- `prepare_tinyspan_c32b4_realtime_handoff.ps1`: common C32/B4 handoff chain
  for Conv3XC fusion, manifest reference, activation calibration, W8A8 quant
  plan export, and integer reference generation.
- `prepare_tinyspan_hardware_handoff.ps1`: generic TinySPAN checkpoint-to-RTL
  manifest exporter used by the C32/B4 handoff chain.

Until the standalone project layout is finalized, execute the live scripts from
the main workspace root `G:\UESTC\feitengspan1`, not directly from this mirror.
When testing mirror-side scripts, pass absolute paths for artifacts that still
live in the main workspace, such as `G:\UESTC\feitengspan1\runs\...`.
