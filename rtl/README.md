# TinySPAN RTL Source Mirror

This directory stores the TinySPAN RTL files that are relevant to the current
Gate E implementation route.

The authoritative live workspace is `G:\UESTC\feitengspan1`. These files are
mirrored here so the GitHub handoff contains the TinySPAN core and board-wrapper
source used by the workflow evidence. Vivado execution is still performed from
the main workspace until the full standalone Tinyspan project is assembled.

Current mirrored route:

- `tinyspan_core/`: TinySPAN W8A8 base-equivalent RGB888 core, including the
  serial base generator and the fast/parallel base generator.
- `board_wrapper/`: AXI-Lite/JTAG board-facing wrappers with rectangular
  `IMG_W`/`IMG_H` support.

The active target is `c32b4_30fps_frozen_20260613`, X4 `320x180 -> 1280x720`.
