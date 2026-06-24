# TinySPAN 硬件加速器设计说明

## 总体数据流

最终主线为板端完整帧切块，而不是 PC 端预切 tile：

```text
SD/DDR 完整 LR 帧
 -> tile scheduler
 -> LR tile fetch / edge padding
 -> TinySPAN 32x32 X4 core
 -> dynamic valid-region crop
 -> SR tile writeback
 -> DDR 完整 1280x720 SR 帧
 -> PS 回读 / 显示 / SD 写回
```

DDR 不作为自研模块实现。正式路线直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，
通过 HP/HPC 端口和 AXI/AXI DMA/VDMA/DataMover/SmartConnect 等标准 IP 访问帧 buffer。
TinySPAN RTL 侧只实现 AXI 用户逻辑、tile scheduler、TinySPAN compute 和调试 bridge，不实现 DDR
controller、DDR PHY 或板级 DDR 时序。

## 已通过硬件基线

已通过真实板卡的 X4 32x32 tile 证据：

- 证据包：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621`
- board-vs-fixed：`0 / 49152` mismatch
- max channel diff：`0`
- perf-only throughput：`1831.144098832951 fps`
- timing：WNS `0.091ns`
- resource：LUT `5943`，Register `5232`，DSP `78`，BRAM Tile `10.5`

## 当前新增整帧控制模块

为推进完整帧切块路线，新增：

- `rtl/board/sr_stream_dynamic_cropper.v`
- `rtl/board/sr_tile_tinyspan_x4_writer_shell.v`
- `sim/testbench/tb_sr_stream_dynamic_cropper.sv`
- `sim/testbench/tb_sr_tile_tinyspan_x4_writer_shell.sv`
- `scripts/vivado/run_vivado_sim_sr_stream_dynamic_cropper.ps1`
- `scripts/vivado/run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.ps1`
- `scripts/vivado/run_tinyspan_full_frame_tiling_sims.ps1`

`sr_stream_dynamic_cropper` 用于解决边缘 tile 的动态有效区域问题。TinySPAN 32x32 X4 核固定输出 `128x128`，但 `320x180` 的底边 tile 只有 `32x20` LR 有效区域，对应 `128x80` SR 有效区域。裁剪器会消费完整 `128x128` 输出，只把有效区域送入 writer，避免上游 core 因无效区域无法排空而卡住。

`sr_tile_tinyspan_x4_writer_shell` 串联：

- `sr_tile_scheduler`
- `sr_tile_fetch_stream_shell`
- `span_tinyspan_w8a8_full_streamed_rgb888_base_equiv`
- `sr_stream_dynamic_cropper`
- `sr_tile_output_writer`

该 shell 是完整帧 SD/DDR 路线的 RTL 集成起点。

## PS/DDR 集成状态

TinySPAN PS/DDR X4 Block Design 已接入板卡 PS DDR controller IP：

- 控制路径：`PS M_AXI_HPM0_FPD -> sr0/s_axi`
- 数据路径：`sr0/m_axi -> PS S_AXI_HP0_FPD -> DDR`
- 控制基址：`0xA0000000`
- PS DDR 配置：从 FACE-ZUSSD 参考工程抽取并应用到 `zynq_ultra_ps_e`

2026-06-25 的 posted-write 中间版本结果：

- bitstream SHA256：`3B7C4EEF6E2F0428ED442E06A2D5910A4156C8AAAF3F5534D605E5C15CDCCFC0`
- A53 DDR alias probe：PASS
- `32x32 -> 128x128` FULL readback：board-vs-fixed mismatch `0 / 49152`，max diff `0`
- `320x180 -> 1280x720` SKIP-read：`tiles_done=60`，`22.1776304000312fps @150MHz`
- 报告：`sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`

该结果证明完整帧板端切块和 DDR 写回链路已能运行，但还不是最终验收：完整帧输出尚未读回做
board-vs-fixed 一致性验证，吞吐也仍低于 `30fps`。

## 资源门线

最终资源按 ZC706 / XC7Z045 等效门限判断：

| 资源 | 上限 |
| --- | ---: |
| LUT | 218600 |
| Register | 437200 |
| DSP | 900 |
| BRAM Tile | 545 |
| URAM | 0 |
| I/O | 362 |

## 完成边界

当前不是最终完整赛题完成。最终必须满足：

- X4 `320x180 -> 1280x720` 完整帧真实板上输出
- X2 `640x360 -> 1280x720` 独立证据
- 硬件输出与同一软件定点参考逐字节一致
- 实测完整帧 throughput `>=30fps`
- Vivado utilization/timing/power 和资源门线 PASS
