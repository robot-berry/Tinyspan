# TinySPAN 赛题交付审计

生成时间：`2026-06-25`

总体结论：`NOT_COMPLETE`

本审计只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。

## 交付项状态

| 项目 | 状态 | 结论 | 下一步 |
| --- | --- | --- | --- |
| AI 模型结构说明文档及源码 | `PASS` | TinySPAN C32/B4 主线模型结构、X4 硬件安全基线和 X2 训练配置已有归档。 | X2 训练完成后补充冻结 checkpoint 的 SHA256 与最终模型状态。 |
| 训练说明文档及源代码 | `PARTIAL` | X4 训练/冻结材料已有基线；X2 独立训练已启动但尚未完成。 | 等待 X2 训练完成后运行 post-training prep，生成冻结和量化证据。 |
| 量化说明文档、量化计划和定点参考 | `PARTIAL` | X4 W8A8 量化计划、32x32 定点参考和整帧 tiled FixedPng 已有；X2 量化仍缺。 | X2 freeze 后导出 X2 W8A8 quant plan，并生成 X2 定点/切块参考。 |
| 模型到硬件加速器转换工具 | `PASS` | X2/X4 通用 post-training handoff 入口已补齐，X4 RTL 导出证据已归档。 | X2 训练完成后用同一入口生成 X2 RTL manifest 与 readiness。 |
| 硬件加速器详细设计文档及源代码 | `PARTIAL` | TinySPAN core、32x32 board smoke、完整帧切块 shell、PS/DDR wrapper、posted-write 和 tile64 FIFO f155 bitstream 已有；DDR 路线明确调用板卡 PS DDR controller IP。 | 补齐完整帧读回一致性，并把正式 I/O 收敛到 Xilinx AXI DMA/DataMover/VDMA 等标准 IP。 |
| Vivado 仿真、综合/实现和 bitstream 证据 | `PARTIAL` | tile64 FIFO f155 bitstream timing/resource PASS，A53 DDR alias PASS，32x32 FULL readback byte-exact PASS，完整帧 SKIP-read `30.4096394240767fps @155MHz`，A53 in-DDR compare `0/2764800` mismatch。 | X4 已闭合；继续补 X2 bitstream/board 证据。 |
| 完善的验证方案与验证用例 | `PARTIAL` | 32x32 board-vs-fixed byte-exact 已通过；tile32/tile64 整帧 FixedPng 预览已准备；tile64 整帧吞吐和 A53 完整帧一致性已通过。 | 补 X2 独立验证；X4 可继续补 board PNG/显示/SD 写回展示材料。 |
| PPA 指标与资源门线分析 | `PARTIAL` | tile64 FIFO f155 资源很低，`CLB LUTs 6353`、`DSP 81`、WNS `0.020ns`；完整帧 SKIP-read 实测 `30.4096394240767fps @155MHz`，正确性 `0/2764800` mismatch。 | X2 完成后汇总 X2/X4 最终 PPA。 |

## 当前阻塞项

- X4 完整帧 Gate H 已有吞吐和 A53 in-DDR 完整帧一致性证据。
- X4 可展示 board PNG、显示或 SD 写回材料仍可补强，但不再阻塞 X4 byte-exact 正确性结论。
- X2 独立证据包仍为 PARTIAL，缺冻结、量化、RTL、bitstream、真实板上输出和吞吐。

## 下一步命令

- 下一步 X4 I/O 优化：

```powershell
# 不新增自研 DDR controller/PHY/仲裁器/时序模块；继续使用板卡 PS DDR controller IP。
# 正式 I/O 优先调用 Xilinx AXI DMA/DataMover/VDMA/SmartConnect 等标准 IP。
# X4 A53 in-DDR byte-exact 已闭合；继续补 X2 独立证据与展示材料。
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
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/tinyspan_tiled_fixed_reference_summary.json`

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
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`

### 完善的验证方案与验证用例

- `PASS` `docs/verification_plan.md`
- `PASS` `docs/gate_status.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/comparison_preview.png`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/diff_heatmap.png`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png`
- `PARTIAL` `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_postedwrite_skipread_20260625_0136/tinyspan_ps_ddr_x4_smoke_summary.json`
- `PARTIAL` `board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_tile64_fifo_f155_skipread_20260625_0412/tinyspan_ps_ddr_x4_smoke_summary.json`
- `PASS` `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559/tinyspan_a53_compare_summary.json`

### PPA 指标与资源门线分析

- `PASS` `docs/ppa_analysis.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json`
- `PARTIAL` `sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`
- `PARTIAL` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`
