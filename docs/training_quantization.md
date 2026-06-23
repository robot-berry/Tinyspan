# TinySPAN 训练与量化说明

## 数据集

赛题数据集为 REDS。仓库不上传 REDS 原始数据，默认本地路径为：

```text
G:\REDS\train_sharp
```

训练、校准和验证脚本均支持通过参数切换本地数据路径。

## 训练流程

主要训练入口：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_tinyspan_c32b4_training.ps1
powershell -ExecutionPolicy Bypass -File scripts\status_tinyspan_c32b4_training.ps1
```

已归档训练材料：

- `train/logs/video_x4_c32_b4_reds_temporal/args.json`
- `train/logs/video_x4_c32_b4_reds_temporal/metrics.csv`
- `train/logs/video_x4_c32_b4_reds_temporal/video_distill_latest_preview.png`
- `model/checkpoints/c32b4_30fps_frozen_20260613/freeze_manifest.json`

## 冻结基线

当前硬件安全基线：

```text
checkpoint: model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt
sha256: 6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938
```

该 checkpoint 已被固定，不再允许训练进程继续覆盖。任何新 checkpoint 进入硬件主线前，必须生成新的 baseline upgrade report。

## 量化方案

当前主线量化为 W8A8：

- 权重：INT8
- 激活：INT8
- bias/requant：由量化计划记录
- 软件定点参考：与 RTL/板上验收逐字节对齐

关键材料：

- `quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8/`
- `quant/fixed_point_reference/c32b4_30fps_frozen_20260613_x4_c32_b4_32x32_w8a8/`
- `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`
- `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py`

## 模型到硬件转换

转换链路：

```text
frozen checkpoint
 -> fused TinySPAN checkpoint / manifest
 -> activation calibration
 -> W8A8 quant plan
 -> software fixed-point reference
 -> RTL memory / model config
 -> Vivado RTL simulation / bitstream
```

RTL memory 和 manifest 已归档在：

```text
rtl/generated_mem/tinyspan_x4_c32_b4_c32b4_30fps_frozen_20260613_fused/
```

## 当前量化边界

当前 32x32 上板通过的是 TinySPAN W8A8 base-equivalent 硬件安全路线。最终整帧赛题交付仍需要在同一 checkpoint 和同一量化计划下完成完整帧板上输出验证。

