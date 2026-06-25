# TinySPAN 赛题交付审计

生成时间：`2026-06-25T12:06:52`
总体结论：`NOT_COMPLETE`

本审计只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。

## 交付项状态

| 项目 | 状态 | 结论 | 下一步 |
| --- | --- | --- | --- |
| AI 模型结构说明文档及源代码 | `PASS` | TinySPAN C32/B4 主线模型结构、X4 硬件安全基线和 X2 训练配置已有归档。 | X2 训练完成后补充冻结 checkpoint SHA256 与最终模型状态。 |
| 训练说明文档及源代码 | `PARTIAL` | X4 训练/冻结材料已有基线；X2 独立训练正在运行但尚未完成。 | 等待 X2 训练完成后运行 post-training prep，生成冻结和量化证据。 |
| 量化说明文档、量化计划和定点参考 | `PARTIAL` | X4 W8A8 量化计划、定点参考和 tile64 整帧固定点参考已闭合；X2 量化仍缺。 | X2 freeze 后导出 X2 W8A8 quant plan，并生成 X2 定点/切块参考。 |
| 模型到硬件加速器转换工具 | `PASS` | X2/X4 通用 post-training handoff 入口已补齐，X4 RTL 导出证据已归档。 | X2 训练完成后用同一入口生成 X2 RTL manifest 与 readiness。 |
| 硬件加速器详细设计文档及源代码 | `PARTIAL` | X4 TinySPAN core、完整帧切块 shell、PS/DDR wrapper 和板卡 IP 路线已归档；X2 独立硬件证据仍缺。 | 继续保持不自研 DDR，X2 完成后补齐 X2 RTL/bitstream/board evidence。 |
| Vivado 仿真、综合/实现和 bitstream 证据 | `PARTIAL` | X4 已有 bitstream、timing/resource、真实板上 30fps 吞吐和完整帧一致性证据。 | 继续补 X2 独立 bitstream 与上板证据。 |
| 完善的验证方案与验证用例 | `PARTIAL` | X4 32x32 小图和 720p 整帧均已有正确性/吞吐验证；X2 独立验证仍缺。 | X2 完成后复用同一验证矩阵补齐证据。 |
| PPA 指标与资源门线分析 | `PARTIAL` | X4 PPA 已可支撑子任务交付：低资源、WNS 过线、板上 `30.4096fps`。 | X2 完成后汇总 X2/X4 最终 PPA。 |

## 当前阻塞项

- X4 子任务已达到可交付状态，但整赛题不能宣告完成。
- X2 独立证据仍缺：冻结、量化、RTL、bitstream、真实板上输出和 >=30fps 吞吐。
- 展示增强项可继续补：board PNG、HDMI/display 输出或 SD 写回图。

## 下一步命令

- X2 训练完成后：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 -RunDir ..\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal -Scale 2 -Tag x2_frozen_YYYYMMDD
```

## 证据索引

### AI 模型结构说明文档及源代码

- `PASS` `docs/model_design.md`
- `PASS` `train/span_model.py`
- `PASS` `configs/distill_tinyspan_video_x2_c32_b4.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/baseline_manifest.json`

### 训练说明文档及源代码

- `PASS` `docs/training_quantization.md`
- `PASS` `train/distill_tinyspan_video.py`
- `PASS` `scripts/train_tinyspan_video_x2_c32_b4.ps1`
- `PASS` `scripts/start_tinyspan_c32b4_x2_training.ps1`
- `PASS` `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\x2_training_start_20260624\x2_training_status.json`

### 量化说明文档、量化计划和定点参考

- `PASS` `docs/training_quantization.md`
- `PASS` `quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`
- `PASS` `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/tinyspan_tiled_fixed_reference_summary.json`

### 模型到硬件加速器转换工具

- `PASS` `scripts/prepare_tinyspan_c32b4_realtime_handoff.ps1`
- `PASS` `scripts/prepare_tinyspan_hardware_handoff.ps1`
- `PASS` `scripts/run_tinyspan_c32b4_post_training_prep.ps1`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py`

### 硬件加速器详细设计文档及源代码

- `PASS` `docs/hardware_design.md`
- `PASS` `docs/x2_hardware_readiness.md`
- `PASS` `rtl/tinyspan_core`
- `PASS` `rtl/board_wrapper/sr_stream_dynamic_cropper.v`
- `PASS` `rtl/board_wrapper/sr_ddr_pixel_axi_master.v`
- `PASS` `rtl/board_wrapper/sr_tile_fetch_stream_shell.v`

### Vivado 仿真、综合/实现和 bitstream 证据

- `PASS` `docs/verification_plan.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`
- `PASS` `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625\manifest.json`

### 完善的验证方案与验证用例

- `PASS` `docs/verification_plan.md`
- `PASS` `docs/x2_hardware_readiness.md`
- `PASS` `docs/gate_status.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png`

### PPA 指标与资源门线分析

- `PASS` `docs/ppa_analysis.md`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`
