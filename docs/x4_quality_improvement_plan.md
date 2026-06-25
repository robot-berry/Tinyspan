# TinySPAN X4 画质提升路线

## 目的

当前 X4 安全基线 `c32b4_30fps_frozen_20260613` 已经完成真实板卡闭合：

- `320x180 -> 1280x720`
- `30.409639424076744fps @155MHz`
- board-vs-fixed `0 / 2764800` mismatch
- ZC706 / XC7Z045 等效资源门线内

但 REDS HR 样例中，TinySPAN X4 fixed output 相对 bicubic baseline 的 PSNR/SSIM 只略有提升：

| Pair | PSNR | SSIM |
| --- | ---: | ---: |
| TinySPAN X4 tile64 fixed vs REDS HR | 25.851911 dB | 0.700177 |
| Bicubic LR vs REDS HR | 25.787498 dB | 0.699348 |

因此后续可以提升画质，但必须保持当前 X4 bitstream 作为安全基线。任何画质候选只有在重新通过软件、量化、RTL、bitstream、真实板卡和 `>=30fps` 后，才能替换当前基线。

## 不可破坏的安全基线

以下证据不得被候选模型覆盖：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md
```

候选模型应放入新的 artifact 目录，例如：

```text
artifacts/20260625_x4_tinyspan_quality_candidate/
```

## 提升方向

### PSNR 目标口径

`35dB` 是否可达取决于 PSNR 的 reference：

| PSNR reference | 当前值 | 35dB 可达性 | 用途 |
| --- | ---: | --- | --- |
| PyTorch SR vs hardware-tiled fixed SR | 43.171866 dB | 已超过 | 衡量量化/定点/切块误差 |
| Full-integer SR vs hardware-tiled fixed SR | 44.487280 dB | 已超过 | 衡量整帧定点与 tile 定点一致性 |
| PyTorch SR vs full-integer SR | 48.717049 dB | 已超过 | 衡量 PyTorch 到整数参考漂移 |
| Student SR vs SPAN teacher | 29.459008 dB | 可作为提升目标，但不保证到 35dB | 衡量学生模型拟合 teacher |
| TinySPAN X4 fixed SR vs REDS HR | 25.851911 dB | 当前硬件约束下不应设为硬目标 | 衡量真实超分还原度 |

因此：

- `35dB` 可以作为定点一致性、量化误差、PyTorch-to-fixed 漂移的硬门槛；当前已经满足。
- `35dB` 不适合作为 X4 REDS HR 真值 PSNR 的交付硬门槛。对 `320x180 -> 1280x720` 的 X4 自然图像超分，TinySPAN 低资源 720p30 路线更现实的目标是稳定超过 bicubic，并在多张 REDS val 与会议/文档展示图上提高平均 PSNR/SSIM。
- 如果必须冲击 REDS HR `35dB`，需要更强模型、更大训练集、更复杂损失和更高算力，极可能破坏 ZC706 等效资源、功耗和 `>=30fps` 约束。

### Q1：先提升训练，不改硬件结构

这是优先路线。目标是在 `c32b4` 拓扑不变的情况下，提高量化后画质。

建议改动：

- 使用 REDS train/val 的 HR/LR 对进行更完整训练和验证。
- 保留 SPAN/teacher distillation，但增加 HR ground-truth loss。
- 损失函数从单一 L1 扩展为：

```text
L = L1(SR, HR) + alpha * L1(SR, teacher) + beta * edge_loss + gamma * ssim_loss
```

- 加入 QAT 或 fake-quant 训练，使 W8A8 量化误差进入训练闭环。
- 加强会议场景 crop：人像、文档、文字、边缘线条。

软件验收门槛：

- REDS val 至少 5 张图，TinySPAN fixed-vs-HR 平均 PSNR 高于 bicubic baseline。
- 单张展示图不能作为替换依据，必须有平均指标。
- PyTorch-vs-fixed PSNR 不低于当前 `43.17dB` 的量级，避免训练提升被定点误差吃掉。

### Q2：中等模型候选

如果 Q1 提升不足，再尝试中等模型：

- `c48b4`：通道从 32 增至 48，block 不变。
- `c32b6`：通道不变，block 从 4 增至 6。

硬件风险：

- 当前 X4 吞吐只有 `30.4096fps`，余量很小。
- 通道或 block 增加会提高 DSP/BRAM/latency，可能跌破 `30fps`。
- 因此中等模型必须先跑软件质量和资源估算，再进 Vivado。

候选替换门槛：

- `>=30fps` 真实板卡吞吐。
- board-vs-fixed `0` mismatch。
- ZC706 / XC7Z045 等效资源门线内。
- REDS val 平均 PSNR/SSIM 明显高于当前安全基线和 bicubic baseline。

### Q3：tile overlap / halo

在 tile 边缘加入 overlap，再裁剪中心有效区域，可以减轻边缘伪影，提升文档线条和人脸边缘稳定性。

风险：

- 每帧实际计算量增加。
- tile 数、DDR 读写和 crop 逻辑都会变复杂。
- 当前 `30fps` 余量有限，halo 只能作为画质候选，不应直接改主线。

验收门槛：

- 边缘 tile padding/crop 与 tile manifest 自动化验证通过。
- full-frame board-vs-fixed `0` mismatch。
- 真实板卡 `>=30fps`。

### Q4：实际 SD 卡图片展示集

板子 SD 卡中的会议/文档/人像图适合作为展示验证集，不替代 REDS 正式训练集。

要求：

- 对每张 HR 展示图生成对应 LR 输入。
- 输出 TinySPAN SR、bicubic baseline、diff heatmap 和 quality metrics。
- 若严格声称“板上 SD 卡读图”，必须由 PS/A53 从 SD 读入 DDR，不能用 host-to-DDR replay 冒充。

## 推荐执行顺序

1. 保持当前 X4 Gate H 安全基线不变。
2. 等 X2 训练稳定运行时，只做离线准备，不抢占 GPU。
3. X2 训练结束后，再决定是否启动 X4 Q1 画质候选训练。
4. Q1 软件指标优于当前安全基线后，导出 W8A8 quant plan。
5. 生成 fixed reference 和 tile64 reference。
6. 跑 RTL/export drift 检查。
7. 重新综合实现，检查资源、时序和功耗。
8. 上板跑吞吐和 A53 in-DDR full-frame compare。
9. 只有全部通过，才更新 `WORKFLOW.md` 和交付索引，把候选提升为新基线。

## 当前结论

可以提升超分效果，但不能直接在当前闭合 bitstream 上“调参数”后宣称提升。正确路线是保留 `c32b4_30fps_frozen_20260613` 作为 X4 安全基线，同时新建画质候选分支。候选必须以 REDS val 平均指标、量化后定点指标和真实板卡 `0 mismatch + >=30fps` 为替换条件。
