# TinySPAN Script Source Mirror

This directory stores the TinySPAN scripts relevant to the current workflow
gates. They are mirrored from `G:\UESTC\feitengspan1` for GitHub handoff and
review traceability.

Current folders:

- `vivado/`: Vivado simulation, OOC synthesis, and JTAG/full-frame bitstream
  entry scripts for the TinySPAN W8A8 base-equivalent route.
- `board/`: JTAG board smoke and output-capture wrapper.
- `acceptance/`: workflow status, board-readiness checks, 32x32 smoke
  acceptance, 720p30 acceptance, preflight hashing, hardware-tiled fixed
  reference generation, and board/software image comparison wrappers.

Until the standalone project layout is finalized, execute the live scripts from
the main workspace root `G:\UESTC\feitengspan1`, not directly from this mirror.
