# TinySPAN 验证方案与用例

## 验证原则

每个验收结果必须能追溯到同一个冻结 checkpoint 和同一个量化计划。最终通过条件不是视觉相似，而是：

```text
board output == software fixed-point reference
```

逐字节一致后，再报告画质指标、预览图、吞吐和 PPA。

## Gate 划分

| Gate | 目标 | 当前状态 |
| --- | --- | --- |
| A0/A | 冻结 TinySPAN 安全基线 | PASS |
| B | W8A8 量化与软件定点参考 | PASS |
| C | RTL/memory 导出 | PASS |
| D | RTL 仿真 | PASS |
| E | X4 320x180 bitstream、资源和理论吞吐 | PASS |
| F | X4 32x32 真实板卡 smoke | PASS |
| G | X4 32x32 图像一致性可视化 | PASS |
| H | X4 完整帧 720p30 上板验收 | BLOCKED |
| X2 | X2 独立证据包 | BLOCKED |

## 已有验证用例

1. TinySPAN W8A8 RTL primitive / postprocess gate
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_d_rtl_gate_rerun_20260618`
   - 结果：PASS

2. X4 320x180 Gate E bitstream
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620`
   - 结果：timing/resource/power PASS，理论 X4 720p `31.0015fps`

3. X4 32x32 tile 真实板卡 smoke
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621`
   - 结果：board-vs-fixed `0/49152` mismatch，perf-only `1831.144098832951fps`

## 下一批验证用例

1. `sr_stream_dynamic_cropper` 单元仿真
   - 输入固定 `128x128` stream
   - valid region 覆盖 `128x128`、`128x80`、`64x64`
   - 检查输出数量、坐标顺序和 backpressure
   - 已新增基础 testbench：`sim/testbench/tb_sr_stream_dynamic_cropper.sv`
   - 已新增运行入口：`scripts/vivado/run_vivado_sim_sr_stream_dynamic_cropper.ps1`
   - 可用总入口：`scripts/vivado/run_tinyspan_full_frame_tiling_sims.ps1`
   - 当前基础用例已通过：`sim/reports/sr_stream_dynamic_cropper_sim_20260624.md`

2. `sr_tile_tinyspan_x4_writer_shell` 小帧仿真
   - `64x64 -> 256x256`
   - `96x48 -> 384x192`
   - 验证 tile count、边缘 padding、有效区域裁剪和写回地址
   - 已新增基础 testbench：`sim/testbench/tb_sr_tile_tinyspan_x4_writer_shell.sv`
   - 当前小帧用例：`6x5 -> 24x20`，tile `4x4`，覆盖右边缘和底边缘非整 tile。
   - 已新增运行入口：`scripts/vivado/run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.ps1`
   - 可用总入口：`scripts/vivado/run_tinyspan_full_frame_tiling_sims.ps1`
   - 状态：待 Vivado 空闲后运行。2026-06-24 最近一次尝试被 W8A12 DDR tile-writer bitstream 进程占用，未启动 TinySPAN full-frame xsim。

3. X4 `320x180 -> 1280x720` hardware-tiled fixed reference
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624`
   - tile：`32x32` LR，`60` 个 tile
   - 输出：`software_tiled_fixed_point_sr.png`、`tile_manifest.json`、`comparison_preview.png`、`diff_heatmap.png`
   - 结果：PASS，作为后续完整帧上板验收的 FixedPng 候选；它本身不代表真实板上完成

4. X4 最终完整帧仿真
   - `320x180 -> 1280x720`
   - 输出与软件 tiled fixed-point reference 逐字节一致
   - tiled fixed-point reference 由
     `scripts/acceptance/make_tinyspan_tiled_fixed_reference.ps1` 生成
   - 参考合同：LR edge tile 补零到固定 tile，SR 输出裁剪左上角有效区域后拼接

5. X4 完整帧上板
   - SD/DDR 输入完整 LR 帧
   - PS/PL 配置启动
   - DDR 回读完整 SR 帧
   - `run_tinyspan_720p30_board_acceptance.ps1` 生成 summary、preview 和 diff

6. X2 独立证据
   - 独立 X2 量化/RTL/bitstream/board output
   - `640x360 -> 1280x720`

## 输出材料

每个最终验收 run 至少保留：

- `manifest.json`
- `run_summary.md`
- `tinyspan_720p30_board_acceptance_summary.json`
- `tinyspan_720p30_board_acceptance_summary.md`
- `software_fixed_point_sr.png`
- `software_tiled_fixed_point_sr.png`
- `tile_manifest.json`
- `tinyspan_tiled_fixed_reference_summary.json`
- `tinyspan_tiled_fixed_reference_summary.md`
- `board_sr.png`
- `comparison_preview.png`
- `diff_heatmap.png`
- `throughput.json`
- `resource_gate.json`
- timing/utilization/power report
