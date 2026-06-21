# TinySPAN 训练相关文件索引

本文记录已经纳入 `robot-berry/Tinyspan` 仓库的 TinySPAN 训练、冻结、量化和模型到硬件导出材料。当前仓库路径为 `G:\UESTC\feitengspan1\Tinyspan`。

## 硬件安全基线

当前上板验收推进使用的冻结模型为：

```text
model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt
SHA256: 6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938
```

这个 checkpoint 是 X4 30fps 硬件安全基线，已经用于同一套 W8A8 量化计划、RTL gate、32x32 tile 板卡输出与软件定点参考逐字节一致性验证。后续板卡验收不能随意换 checkpoint；如果换模型，必须重新冻结、重新量化、重新生成软件定点参考，并重新做板上输出一致性验证。

另一个 checkpoint 也已归档：

```text
model/checkpoints/c32b4_final_20260615/student_final_candidate.pt
SHA256: F5FC59CD88D4A9DEB2CFB81F1CA47FB4FF50ECA3FD4C6F5EAC13CC6B8586AC64
```

`c32b4_final_20260615` 只作为后续画质候选保存；它不是当前硬件安全基线，不能直接替代 `c32b4_30fps_frozen_20260613` 宣称板卡通过。

## 已纳入仓库的训练材料

- `train/*.py`：TinySPAN/官方 SPAN 训练、蒸馏、REDS 数据集加载、可视化和导出源码。
- `configs/`：TinySPAN 训练配置、官方 REDS 训练配置，以及 REDS train/val meta info。
- `scripts/start_tinyspan_c32b4_training.ps1`：后台启动 C32B4 TinySPAN 训练。
- `scripts/status_tinyspan_c32b4_training.ps1`：读取训练进程、metrics、checkpoint 和日志状态。
- `scripts/train_tinyspan_video_x4_c32_b4.ps1`：前台执行 X4 C32B4 视频蒸馏训练。
- `scripts/freeze_tinyspan_c32b4_training_checkpoint.ps1`：冻结训练 checkpoint，生成固定模型身份。
- `scripts/prepare_tinyspan_c32b4_realtime_handoff.ps1`：从冻结 checkpoint 生成 fusion、校准、量化、定点参考和 handoff 摘要。
- `scripts/run_tinyspan_c32b4_post_training_prep.ps1`：训练结束后的整理入口。
- `scripts/export_tinyspan_w8a8_quant_plan.ps1`、`scripts/export_tinyspan_c32b4_30fps_w8a8_to_rtl.ps1`：量化计划和 RTL 权重导出入口。
- `tools/model_to_hardware/`：TinySPAN 融合、校准、W8A8 量化、RTL 导出、定点参考和视频验收工具。

## 已纳入仓库的训练输出

- `train/logs/video_x4_c32_b4_reds_temporal/args.json`：训练参数。
- `train/logs/video_x4_c32_b4_reds_temporal/metrics.csv`：完整训练 metrics 记录。
- `train/logs/video_x4_c32_b4_reds_temporal/*command.txt`：训练/重启命令记录。
- `train/logs/video_x4_c32_b4_reds_temporal/video_distill*_preview.png`：训练预览图。
- `model/checkpoints/c32b4_30fps_frozen_20260613/`：当前硬件安全基线 checkpoint、冻结 manifest 和说明。
- `model/checkpoints/c32b4_final_20260615/`：训练最终候选 checkpoint、冻结 manifest 和说明。

## 已纳入仓库的量化和硬件交接材料

- `model/export_manifest/c32b4_30fps_frozen_20260613/`：融合 checkpoint、fusion 检查、handoff summary 和 manifest。
- `quant/calibration/c32b4_30fps_frozen_20260613_x4_c32_b4_reds4_32x32/activation_scales.json`：REDS 校准得到的激活 scale。
- `quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8/`：W8A8 量化计划、权重、bias、requant 常数、向量和预览。
- `quant/fixed_point_reference/c32b4_30fps_frozen_20260613_x4_c32_b4_32x32_w8a8/`：同一 checkpoint 和同一量化计划下的软件定点参考。
- `rtl/generated_mem/tinyspan_x4_c32_b4_c32b4_30fps_frozen_20260613_fused/`：由冻结模型导出的 RTL memory 和模型配置。
- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/training_acceptance_x4_320x180_20260613/`：冻结模型在 X4 320x180 30 帧软件验收中的画质、流式性能和预览材料。

## 未纳入仓库的内容

- REDS 原始数据集未上传；复现实验时默认使用 `G:\REDS\train_sharp`，也可以通过脚本参数改成其他本地路径。
- 训练过程 `.log` 文件未上传，避免仓库膨胀和混入早期重启噪声；仓库中保留了训练命令、metrics、预览图和冻结 manifest。
- Vivado 缓存、`.Xil`、`.runs`、DCP、WDB、临时 raw dump 不作为训练材料上传。

## 最小复现顺序

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_tinyspan_c32b4_training.ps1 -TrainFrames G:\REDS\train_sharp
powershell -ExecutionPolicy Bypass -File scripts\status_tinyspan_c32b4_training.ps1
powershell -ExecutionPolicy Bypass -File scripts\freeze_tinyspan_c32b4_training_checkpoint.ps1 -Tag c32b4_30fps_frozen_YYYYMMDD
powershell -ExecutionPolicy Bypass -File scripts\prepare_tinyspan_c32b4_realtime_handoff.ps1 -Checkpoint model\checkpoints\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt -Tag c32b4_30fps_frozen_20260613
```

最终板卡验收必须使用同一个冻结 checkpoint 和同一个量化计划，比较硬件输出与软件定点参考，而不是只比较 PyTorch 浮点输出。
