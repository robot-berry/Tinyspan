# TinySPAN 模型结构说明

## 目标定位

TinySPAN 是本项目的赛题主交付模型路线，用于在 ZC706 / XC7Z045 等效资源门线下完成端侧实时超分。当前硬件安全基线为：

```text
baseline: c32b4_30fps_frozen_20260613
model: TinySPAN C32 B4
scale: X4 first, X2 pending
quantization: W8A8
checkpoint: model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt
sha256: 6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938
```

## 网络结构

当前基线采用轻量 TinySPAN student：

- 特征通道数：`32`
- TinySPAN block 数：`4`
- 输入格式：RGB888 LR frame 或 LR tile
- 主验收倍率：X4
- 目标 X4 帧契约：`320x180 -> 1280x720`
- 当前板上 tile 契约：`32x32 -> 128x128`

模型来源和训练代码在：

- `train/span_model.py`
- `train/distill_tinyspan_video.py`
- `train/reds_dataset.py`
- `configs/tinyspan_c32b4_x4_reds_temporal.json`

## 硬件等价说明

当前已通过上板的 TinySPAN W8A8 base-equivalent 路线实现的是同一冻结 checkpoint、同一量化计划下的软件定点参考输出。32x32 tile 上板证据显示：

- board-vs-fixed mismatch：`0 / 49152`
- max channel diff：`0`
- board output、RTL-fixed software output、PyTorch base-equivalent preview 在当前 32x32 证据中一致

重要边界：

- 32x32 tile PASS 是硬件安全基线，不等于完整赛题完成。
- 最终赛题完成仍需要 SD/DDR 完整 LR 帧板端切块、拼接写回、完整帧实测 `>=30fps` 和 X2 独立证据。

## 质量路线

`c32b4_final_20260615` 已作为画质候选归档，但不是当前硬件安全基线。若后续切换模型，必须重新完成：

- checkpoint 冻结和 SHA256 记录
- W8A8 或新量化计划
- 软件定点参考
- RTL/memory 导出
- RTL 仿真和 bitstream
- 真实板上输出逐字节一致性验证
