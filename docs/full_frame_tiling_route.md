# TinySPAN Full-Frame Tiling Route

更新时间：`2026-06-21T02:30:00+08:00`

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

最终 X4 验收尺寸：

- LR 输入：`320x180`
- SR 输出：`1280x720`
- tile：优先 `32x32` LR tile，`64x64` 仅作为后续资源允许时的优化候选

`160x90 -> 640x360` 可以作为完整帧切块调度 smoke，但不能替代最终 `320x180 -> 1280x720` 验收。

## 已有基础

- TinySPAN X4 `32x32 -> 128x128` 真实板卡已通过：
  `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621`
- Board-vs-software：`0 / 49152` mismatch bytes，max channel diff `0`
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

还需要新增或接入一个 TinySPAN full-frame tile controller，负责把这些模块串起来：

1. 启动 `sr_tile_scheduler` 枚举 `320x180` LR frame 的所有 `32x32` tile。
2. 对每个 tile，触发 `sr_tile_fetch_stream_shell` 从 SD/DDR LR frame 读入 tile。
3. 将 tile stream 喂给 TinySPAN `32x32` X4 compute 核。
4. 将 TinySPAN 输出的 `128x128` SR tile 送入 `sr_tile_output_writer`。
5. 等当前 tile 写回完成后再取下一 tile。
6. 最后给出 frame done、tile count、cycle counter、error flags。

## 验收顺序

1. `32x32` tile 已完成真实上板 PASS，作为安全基线。
2. RTL 仿真先做小完整帧：`64x64 -> 256x256` 或 `160x90 -> 640x360`，验证 tile 坐标、边缘 tile、写回地址和拼接。
3. RTL 仿真再做最终 X4：`320x180 -> 1280x720`，输出与软件 tiled reference 逐字节一致。
4. 生成 full-frame tiled bitstream，记录 timing/resource/power。
5. 真实板卡运行完整 `320x180 -> 1280x720`，回读 DDR SR frame。
6. 用 `run_tinyspan_720p30_board_acceptance.ps1` 验证：
   - board output == software fixed-point tiled reference，逐字节一致
   - `comparison_preview.png` 可查看
   - 实测完整帧 throughput `>= 30fps`
   - 资源不超过 XC7Z045 / ZC706 等效门限

## 完成边界

只有完整 `320x180 -> 1280x720` X4 frame，以及 X2 独立证据都满足同一 checkpoint、同一量化方案、真实板上输出、逐字节一致和 `>=30fps` 后，才能宣告赛题最终完成。
