# TinySPAN 赛题交付审计

生成时间：`2026-06-25T02:00:00`

总体结论：`NOT_COMPLETE`

本审计只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。

## 交付项状态

| 项目 | 状态 | 结论 | 下一步 |
| --- | --- | --- | --- |
| AI 模型结构说明文档及源码 | `PASS` | TinySPAN C32/B4 主线模型结构、X4 硬件安全基线和 X2 训练配置已有归档。 | X2 训练完成后补充冻结 checkpoint 的 SHA256 与最终模型状态。 |
| 训练说明文档及源代码 | `PARTIAL` | X4 训练/冻结材料已有基线；X2 独立训练已启动但尚未完成。 | 等待 X2 训练完成后运行 post-training prep，生成冻结和量化证据。 |
| 量化说明文档、量化计划和定点参考 | `PARTIAL` | X4 W8A8 量化计划、32x32 定点参考和整帧 tiled FixedPng 已有；X2 量化仍缺。 | X2 freeze 后导出 X2 W8A8 quant plan，并生成 X2 定点/切块参考。 |
| 模型到硬件加速器转换工具 | `PASS` | X2/X4 通用 post-training handoff 入口已补齐，X4 RTL 导出证据已归档。 | X2 训练完成后用同一入口生成 X2 RTL manifest 与 readiness。 |
| 硬件加速器详细设计文档及源代码 | `PARTIAL` | TinySPAN core、32x32 board smoke、完整帧切块 shell、PS/DDR wrapper 和 posted-write 中间 bitstream 已有；DDR 路线明确调用板卡 PS DDR controller IP。 | 继续把阻塞式逐像素 DDR read 改为 AXI burst 或 Xilinx AXI DMA/DataMover。 |
| Vivado 仿真、综合/实现和 bitstream 证据 | `PARTIAL` | posted-write bitstream timing/resource PASS，A53 DDR alias PASS，32x32 FULL readback byte-exact PASS，完整帧 SKIP-read 跑通 60 tile。 | 补齐完整帧输出读回、board-vs-fixed 和 `>=30fps`。 |
| 完善的验证方案与验证用例 | `PARTIAL` | 32x32 board-vs-fixed byte-exact 已通过；整帧 FixedPng 预览已准备；整帧 SKIP-read 吞吐已有 `22.1776304000312fps`。 | 拿到完整帧 board_sr 后运行 720p30 acceptance，生成 comparison_preview 和 diff_heatmap。 |
| PPA 指标与资源门线分析 | `PARTIAL` | posted-write 资源很低，`CLB LUTs 6169`、`DSP 81`、WNS `0.075ns`；但完整帧实测只有 `22.1776304000312fps @150MHz`。 | 完整帧 Gate H PASS 后把最终 utilization/timing/power/throughput 汇总为最终 PPA。 |

## 当前阻塞项

- X4 完整帧真实板上输出读回仍缺，Gate H 未通过。
- X4 完整帧实测吞吐目前为 `22.1776304000312fps @150MHz`，仍低于 `30fps`。
- X2 独立证据包仍为 PARTIAL，缺冻结、量化、RTL、bitstream、真实板上输出和吞吐。

## 下一步命令

- 下一步 X4 I/O 优化：

```powershell
# 不新增自研 DDR controller/PHY；继续使用板卡 PS DDR controller IP。
# 优先把阻塞式 DDR read 改成 AXI burst 或 Xilinx AXI DMA/DataMover。
```

- X2 训练完成后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 -RunDir runs\tinyspan_distill\video_x2_c32_b4_reds_temporal -Scale 2 -Tag c32b4_x2_frozen_YYYYMMDD
```

## 证据索引

### AI 模型结构说明文档及源码

- `PASS` `docs/model_design.md`
- `PASS` `train/span_model.py`
- `PASS` `configs/distill_tinyspan_video_x2_c32_b4.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/baseline_manifest.json`

### 训练说明文档及源代码

- `PASS` `docs/training_quantization.md`
- `PASS` `train/distill_tinyspan_video.py`
- `PASS` `scripts/train_tinyspan_video_x2_c32_b4.ps1`
- `PASS` `scripts/start_tinyspan_c32b4_x2_training.ps1`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json`

### 量化说明文档、量化计划和定点参考

- `PASS` `docs/training_quantization.md`
- `PASS` `quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`
- `PASS` `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/tinyspan_tiled_fixed_reference_summary.json`

### 模型到硬件加速器转换工具

- `PASS` `scripts/prepare_tinyspan_c32b4_realtime_handoff.ps1`
- `PASS` `scripts/prepare_tinyspan_hardware_handoff.ps1`
- `PASS` `scripts/run_tinyspan_c32b4_post_training_prep.ps1`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_c_rtl_export/gate_c_summary.md`

### 硬件加速器详细设计文档及源代码

- `PASS` `docs/hardware_design.md`
- `PASS` `rtl/tinyspan_core`
- `PASS` `rtl/board_wrapper/sr_stream_dynamic_cropper.v`
- `PASS` `rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v`
- `PASS` `sim/testbench/tb_sr_tile_tinyspan_x4_writer_shell.sv`

### Vivado 仿真、综合/实现和 bitstream 证据

- `PASS` `docs/verification_plan.md`
- `PASS` `scripts/vivado/run_tinyspan_full_frame_tiling_sims.ps1`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_d_rtl_gate_rerun_20260618/tinyspan_w8a8_rtl_gate_summary.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`

### 完善的验证方案与验证用例

- `PASS` `docs/verification_plan.md`
- `PASS` `docs/gate_status.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/comparison_preview.png`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/diff_heatmap.png`
- `PARTIAL` `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_postedwrite_skipread_20260625_0136/tinyspan_ps_ddr_x4_smoke_summary.json`

### PPA 指标与资源门线分析

- `PASS` `docs/ppa_analysis.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json`
- `PARTIAL` `sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`
