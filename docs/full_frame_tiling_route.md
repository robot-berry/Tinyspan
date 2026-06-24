# TinySPAN Full-Frame Tiling Route

更新时间：`2026-06-25`

## 路线决定

最终主线采用 **完整 LR 帧板端切块拼接**，不把 PC 端预切 tile 作为最终输入，也不把一次性整帧 TinySPAN 核作为赛题主线。

目标链路：

```text
SD/DDR 完整 LR 帧
 -> 板端 tile scheduler
 -> 32x32 LR tile fetch / padding
 -> TinySPAN 32x32 X4 tile core
 -> 128x128 SR tile writeback
 -> DDR 完整 SR 帧
 -> PS 回读 / 显示 / SD 写回
```

DDR 访问约束：后续不自研 DDR 控制器、DDR PHY 或板级 DDR 时序逻辑。完整帧输入输出必须复用板卡
`zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC 端口，以及 Xilinx AXI DMA/VDMA/DataMover/
SmartConnect 等标准 IP。TinySPAN 侧只保留 AXI 用户逻辑、tile scheduler、计算核心和必要调试桥。

最终 X4 验收尺寸：

- LR 输入：`320x180`
- SR 输出：`1280x720`
- tile：`32x32` LR tile 作为正确性安全基线；`64x64` LR tile 作为当前完整帧吞吐候选

`160x90 -> 640x360` 可以作为完整帧切块调度 smoke，但不能替代最终 `320x180 -> 1280x720` 验收。

## 已有基础

- TinySPAN X4 `32x32 -> 128x128` 真实板卡已通过：
  `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621`
- Board-vs-fixed：`0 / 49152` mismatch bytes，max channel diff `0`
- 32x32 tile perf-only：`1831.144098832951 fps`
- 32x32 tile bitstream timing：WNS `0.091ns`
- 32x32 tile 资源：LUT `5943`，Register `5232`，DSP `78`，BRAM Tile `10.5`

## 可复用模块

- `rtl/board/sr_tile_scheduler.v`
  - 枚举完整 LR 帧中的 tile 坐标、有效宽高、输入地址和输出地址。
- `rtl/board/sr_tile_fetch_stream_shell.v`
  - 从完整 LR 帧线性 RGB888 buffer 读取一个 tile，并对边缘 tile 做硬件零填充。
- `rtl/board/sr_tile_rgb_buffer_streamer.v`
  - tile-local RGB888 buffer，输出固定尺寸 tile stream。
- `rtl/board/sr_tile_output_writer.v`
  - 将一个 SR tile 的有效输出写回完整 SR 帧的正确 DDR 地址。
- `rtl/tinyspan_core/span_tinyspan_w8a8_bicubic_base_x4_streamed.v`
  - 已验证的 TinySPAN X4 `32x32` tile compute 核。
- `scripts/acceptance/run_tinyspan_720p30_board_acceptance.ps1`
  - 已有完整 `320x180 -> 1280x720` 验收壳，用于最终整帧输出比较和资源/吞吐记录。

## 当前缺口

已新增 TinySPAN X4 full-frame tile controller 骨架：

- `rtl/board_wrapper/sr_stream_dynamic_cropper.v`
- `rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v`

根工程同步开发源位于：

- `G:\UESTC\feitengspan1\rtl\board\sr_stream_dynamic_cropper.v`
- `G:\UESTC\feitengspan1\rtl\board\sr_tile_tinyspan_x4_writer_shell.v`

`sr_tile_tinyspan_x4_writer_shell` 负责把这些模块串起来：

1. 启动 `sr_tile_scheduler` 枚举 `320x180` LR frame 的所有 `32x32` tile。
2. 对每个 tile，触发 `sr_tile_fetch_stream_shell` 从 SD/DDR LR frame 读入 tile。
3. 将 tile stream 喂给 TinySPAN `32x32` X4 compute 核。
4. 用 `sr_stream_dynamic_cropper` 消费完整 `128x128` SR tile，并只输出 edge tile 的有效区域。
5. 将有效 SR 区域送入 `sr_tile_output_writer`，写回完整 SR 帧地址。
6. 等当前 tile 读入、推理、裁剪和写回都完成后再取下一 tile。
7. 最后给出 frame done、tile count、cycle counter、error flags。

当前完成状态：

- `sr_stream_dynamic_cropper` Vivado/xsim 已通过。
- `sr_tile_tinyspan_x4_writer_shell` 小帧 Vivado/xsim 已通过。
- TinySPAN PS/DDR X4 Block Design 已接入板卡 `zynq_ultra_ps_e` / PS DDR controller IP。
- FACE-ZUSSD 参考 PS DDR 配置已应用，A53 DDR alias probe 已通过。
- `32x32 -> 128x128` FULL readback smoke 已通过，board-vs-fixed mismatch `0 / 49152`。
- `320x180 -> 1280x720` SKIP-read smoke 已跑完 60 个 tile，`22.1776304000312fps @150MHz`。
- tile64 FIFO f155 版本已跑完 `320x180 -> 1280x720` 的 15 个 tile，SKIP-read 实测
  `30.4096394240767fps @155MHz`，A53 DDR alias probe 仍为 PASS。该版本继续调用板卡
  PS DDR controller IP，不新增自研 DDR controller/PHY。
- tile64 FIFO f155 版本已通过 A53 in-DDR 完整帧比较：
  `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`，
  mismatch `0 / 2764800`，max diff `0`。

仍未完成的工作：

- `320x180 -> 1280x720` 可展示 board PNG、显示或 SD 写回材料。
- 把最终输出读回/显示链路从 XSCT 调试读回推进到 Xilinx AXI DMA/DataMover/VDMA 或 PS 批量读回路线。
- 当前 `sr_ddr_pixel_axi_master` 只作为 AXI 用户逻辑/调试桥，不作为最终高性能 I/O 方案。

已准备的仿真入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\vivado\run_vivado_sim_sr_stream_dynamic_cropper.ps1 -RequireVivadoIdle
powershell -ExecutionPolicy Bypass -File scripts\vivado\run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.ps1 -RequireVivadoIdle
powershell -ExecutionPolicy Bypass -File scripts\vivado\run_tinyspan_full_frame_tiling_sims.ps1 -WaitForVivadoIdleSeconds 7200
```

根工程开发入口位于：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_stream_dynamic_cropper.ps1 -RequireVivadoIdle
powershell -ExecutionPolicy Bypass -File scripts\run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.ps1 -RequireVivadoIdle
powershell -ExecutionPolicy Bypass -File scripts\run_tinyspan_full_frame_tiling_sims.ps1 -WaitForVivadoIdleSeconds 7200
```

当前状态：

- `sr_stream_dynamic_cropper` 基础 Vivado/xsim 已通过，报告见 `sim/reports/sr_stream_dynamic_cropper_sim_20260624.md`。
- 已生成 X4 `320x180 -> 1280x720` tile `32x32` 的 software hardware-tiled fixed reference：
  `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624`。
  该目录中的 `software_tiled_fixed_point_sr.png` 是后续完整帧板上回读比较的 FixedPng 候选，
  `tile_manifest.json` 记录 60 个 tile 的输入/输出坐标与 byte offset。
- `sr_tile_tinyspan_x4_writer_shell` 小帧 Vivado/xsim 已运行通过，报告见
  `sim/reports/sr_tile_tinyspan_x4_writer_shell_sim_20260624.md`。
  结果：`PASS sr_tile_tinyspan_x4_writer_shell tiles=4 writes=480 frame_cycles=17941`。
  这证明整帧切块 shell 的小规模多 tile 场景可以通过仿真；后续 posted-write bitstream 和
  SKIP-read 上板证据已补齐，但完整输出读回、board-vs-fixed 和 `>=30fps` 实测仍待完成。
- TinySPAN PS/DDR X4 posted-write 中间版本已上板：
  - `32x32 -> 128x128` FULL readback：board-vs-fixed `0 / 49152`，max diff `0`，
    `1313.14015582597fps @150MHz`。
  - `320x180 -> 1280x720` SKIP-read：`tiles_done=60`，`frame_cycles=6763572`，
    `22.1776304000312fps @150MHz`。
  - 报告见 `sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`。
  - 该历史版本仍低于 30fps，且完整帧没有读回做 board-vs-fixed，因此不是最终 Gate H PASS。
- TinySPAN PS/DDR X4 tile64 FIFO f155 版本已上板：
  - `320x180 -> 1280x720` SKIP-read：`tiles_done=15`，`frame_cycles=5097068`，
    `30.4096394240767fps @155MHz`。
  - bitstream SHA256：`A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232`。
  - timing：`WNS=0.020ns`，`TNS=0.000ns`，约束满足。
  - resource：CLB LUTs `6353`，CLB Registers `4647`，DSP `81`，BRAM Tile `27`。
  - 报告见 `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`。
  - A53 in-DDR 完整帧比较已通过，mismatch `0 / 2764800`，max diff `0`。
  - X4 Gate H 的吞吐和正确性证据已闭合；board PNG/显示/SD 写回仍可作为展示增强。

## 验收顺序

1. `32x32` tile 已完成真实上板 PASS，作为安全基线。
2. RTL 仿真先做小完整帧：`64x64 -> 256x256` 或 `160x90 -> 640x360`，验证 tile 坐标、边缘 tile、写回地址和拼接。
3. RTL 仿真再做最终 X4：`320x180 -> 1280x720`，输出与软件 tiled reference 逐字节一致。
4. 生成 full-frame tiled bitstream，记录 timing/resource/power。
5. 保持 A53 DDR alias probe 作为 PS/DDR/BD 回归门禁；后续仍直接调用板卡 PS DDR IP、
   HP/HPC 端口和 Xilinx AXI DMA/DataMover/VDMA/SmartConnect 等标准 IP，不新增自研 DDR 控制器、
   DDR PHY 或 DDR 时序模块。
6. 用软件生成同构完整帧参考：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\acceptance\make_tinyspan_tiled_fixed_reference.ps1 `
  -InputPng <完整LR输入图> `
  -InputWidth 320 -InputHeight 180 `
  -TileWidth 32 -TileHeight 32
```

该步骤输出 `software_tiled_fixed_point_sr.png`、`tile_manifest.json`、
`comparison_preview.png` 和 `diff_heatmap.png`。最终板上比较的 FixedPng 必须来自这个
tile 同构参考，而不是一次性整帧 TinySPAN 软件输出。

7. 真实板卡运行完整 `320x180 -> 1280x720`，回读 DDR SR frame，或使用 A53 in-DDR comparator
   对完整 DDR SR frame 做逐字节验证。tile64 FIFO f155 的 FixedPng
   必须使用 `full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625` 目录下的
   `software_tiled_fixed_point_sr.png`。
8. 用 `run_tinyspan_720p30_board_acceptance.ps1` 验证：
   - board output == software fixed-point tiled reference，逐字节一致
   - `comparison_preview.png` 可查看
   - `diff_heatmap.png` 可查看
   - 实测完整帧 throughput `>= 30fps`
   - 资源不超过 XC7Z045 / ZC706 等效门限

## 完成边界

只有完整 `320x180 -> 1280x720` X4 frame，以及 X2 独立证据都满足同一 checkpoint、同一量化方案、真实板上输出、逐字节一致和 `>=30fps` 后，才能宣告赛题最终完成。
