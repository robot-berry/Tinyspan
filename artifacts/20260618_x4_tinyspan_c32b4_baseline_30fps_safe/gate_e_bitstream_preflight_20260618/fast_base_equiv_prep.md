# Gate E Fast Base-Equivalent 准备记录

生成时间：`2026-06-18T13:46:05+08:00`

状态：`PARTIAL_PREP`

本记录不表示 Gate E 通过。本步骤没有为 TinySPAN 启动新的 Vivado/OOC/bitstream 任务，因为主工程中已有 W8A12 Vivado bitstream 进程正在运行。

## 为什么要从 serial 改为 fast

当前 serial bicubic base generator 约 `17 cycles/output pixel`。对 X4 `320x180 -> 1280x720` 而言，输出约 `921600` 像素，100MHz 下只有约 `6fps`，不满足 30fps 目标。

后续综合重试发现，接近 `1 output pixel/cycle` 的 16 读口全帧 RAM 结构无法在 `320x180` 规模上安全推断为 BRAM。当前安全路线已改为 8 个镜像 BRAM 读口、每周期处理两行 tap，目标约 `4 cycles/output pixel`；因此后续 30fps 候选 bitstream 目标频率提高到 `150MHz`。

## 本地根工程准备

- `span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v` 新增 `USE_SERIAL_BASE` 参数，可选择 serial 或 parallel bicubic base generator。
- `span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v` 透传 `USE_SERIAL_BASE`。
- `sr_sd_axi_lite_accel.v` 和 `sr_jtag_rgb_transfer_endpoint.v` 透传 `USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL`。
- `create_vivado_jtag_full_span_bd_project.tcl` 支持 `JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL`。
- `run_vivado_bitstream_jtag_full_span_scale.ps1` 新增 `-UseTinyspanW8A8BaseEquivFast`。
- `run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` 和 `run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1` 新增 `-Fast`。
- `check_tinyspan_30fps_board_acceptance_ready.ps1` 默认目标改为 `jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit`。

## 已镜像到 Tinyspan 仓库

- `rtl/tinyspan_core`
- `rtl/board_wrapper`
- `scripts/vivado`
- `scripts/board`
- `scripts/acceptance`

## 已做静态检查

- PowerShell parser 检查通过。
- `git diff --check` 未发现格式错误。
- 关键参数 `USE_SERIAL_BASE`、`USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL`、`UseTinyspanW8A8BaseEquivFast` 和 `320x180` fast bitstream 路径均可搜索到。

下一步：等待当前 Vivado 任务结束后，先运行 TinySPAN fast RTL 语法/小尺寸综合检查，再运行 `320x180 @ 150MHz` fast bitstream 构建并归档 `timing/utilization/power/resource_gate`。
