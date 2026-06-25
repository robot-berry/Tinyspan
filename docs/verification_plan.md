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
| H | X4 完整帧 720p30 上板验收 | PASS_X4：吞吐过线，A53 in-DDR 逐字节一致 |
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

4. TinySPAN PS/DDR X4 posted-write board smoke
   - 位置：`sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`
   - DDR 路线：直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR controller/PHY
   - A53 DDR alias probe：PASS
   - `32x32 -> 128x128` FULL readback：board-vs-fixed `0/49152` mismatch，max diff `0`
   - `320x180 -> 1280x720` SKIP-read：`tiles_done=60`，`22.1776304000312fps @150MHz`
   - 结论：完整帧切块和 DDR 写回能跑通，但该版本尚未完成完整帧读回一致性和 `>=30fps`

5. TinySPAN PS/DDR X4 tile64 FIFO f155 board smoke
   - 位置：`sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
   - DDR 路线：继续调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC 和 Xilinx 标准 AXI IP
   - 自研 DDR controller/PHY：无
   - A53 DDR alias probe：PASS，mismatch `0`
   - `320x180 -> 1280x720` SKIP-read：tile `64x64`，`tiles_done=15`，
     `frame_cycles=5097068`，`30.4096394240767fps @155MHz`
   - 结论：X4 完整帧真实板卡吞吐已过 `30fps`

6. TinySPAN PS/DDR X4 tile64 FIFO f155 A53 in-DDR compare
   - 位置：`sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`
   - run：`board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`
   - DDR 路线：继续调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR controller/PHY
   - 比较范围：完整 `1280x720` SR frame，`921600` pixels，`2764800` bytes
   - 结果：mismatch `0 / 2764800`，max diff `0`
   - 结论：X4 完整帧真实板卡输出与 tile64 hardware-tiled fixed reference 逐字节一致

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
   - 状态：已通过，报告见 `sim/reports/sr_tile_tinyspan_x4_writer_shell_sim_20260624.md`。

3. X4 `320x180 -> 1280x720` hardware-tiled fixed reference
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624`
   - tile：`32x32` LR，`60` 个 tile
   - 输出：`software_tiled_fixed_point_sr.png`、`tile_manifest.json`、`comparison_preview.png`、`diff_heatmap.png`
   - 结果：PASS，作为后续完整帧上板验收的 FixedPng 候选；它本身不代表真实板上完成

3b. X4 `320x180 -> 1280x720` tile64 hardware-tiled fixed reference
   - 位置：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625`
   - tile：`64x64` LR，`15` 个 tile
   - 输出：`software_tiled_fixed_point_sr.png`、`tile_manifest.json`、`comparison_preview.png`、`diff_heatmap.png`
   - 结果：PASS，作为 tile64 FIFO f155 bitstream 的 FixedPng 候选；最终板上比较必须使用同 tile contract 的参考

4. X4 最终完整帧仿真
   - `320x180 -> 1280x720`
   - 输出与软件 tiled fixed-point reference 逐字节一致
   - tiled fixed-point reference 由
     `scripts/acceptance/make_tinyspan_tiled_fixed_reference.ps1` 生成
   - 参考合同：LR edge tile 补零到固定 tile，SR 输出裁剪左上角有效区域后拼接

5. X4 完整帧上板
   - SD/DDR 输入完整 LR 帧
   - PS/PL 配置启动
   - DDR 回读完整 SR 帧，或用 A53 in-DDR comparator 对完整 SR frame 做逐字节一致性验证
   - `run_tinyspan_720p30_board_acceptance.ps1` 生成 summary、preview 和 diff
   - 每次 PS/DDR/BD/AXI 修改后先跑 A53 DDR alias probe
   - 继续使用板卡 PS DDR controller IP、HP/HPC 端口和 Xilinx AXI DMA/DataMover/VDMA/SmartConnect 等标准 IP
   - 不新增自研 DDR 控制器、DDR PHY、DDR 仲裁器或 DDR 时序模块
   - 当前 `sr_ddr_pixel_axi_master` 只作为 AXI 用户逻辑/调试桥，不作为最终高性能 I/O 方案
   - 当前 X4 tile64 FIFO f155 已通过 A53 in-DDR compare；后续 board PNG/显示/SD 写回属于展示增强

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
- `tinyspan_x4_quality_metrics.json`
- `tinyspan_x4_quality_metrics.md`
- `resource_gate.json`
- timing/utilization/power report

画质指标入口使用 `tools/image_validation/evaluate_sr_quality.py`。当前 X4 已生成
`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_metrics_20260625/tinyspan_x4_quality_metrics.json`，
其中包含 student-vs-teacher、PyTorch-vs-tile 定点和 full-integer-vs-tile 定点的 PSNR/SSIM/MAE。
注意 student-vs-teacher 是官方 SPAN teacher 一致性指标；若要报告 REDS HR 真值指标，必须把 REDS HR
图像作为 reference 重新生成质量报告。
