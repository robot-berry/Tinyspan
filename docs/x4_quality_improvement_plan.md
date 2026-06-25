# TinySPAN X4 PSNR 28+dB 画质提升候选方案

## 结论

当前 X4 已经可以作为 X4 子任务提交，但当前提交采用的是已经闭合的安全基线，不用画质提升候选替换：

- 基线：`c32b4_30fps_frozen_20260613`
- 输入/输出：`320x180 -> 1280x720`
- 上板吞吐：`30.409639424076744fps @155MHz`
- 正确性：board/A53 in-DDR compare `0 / 2764800` mismatch
- REDS HR 单样例：`25.851911dB`

当前 X4 画质提升目标调整为 REDS HR 多图平均 PSNR `>=28dB`；`30dB` 保留为可选冲刺目标。候选必须作为独立路线重新训练、量化、导出 RTL、生成 bitstream 并上板验证，不能直接修改已经闭合的 X4 安全基线。

## PSNR 口径

`28+dB` 目标只对如下口径有效：

| 口径 | 当前值 | 目标 |
| --- | ---: | ---: |
| X4 fixed SR vs REDS HR | 25.851911 dB 单样例 | 多图平均 `>=28dB`，`30dB` 作为冲刺 |
| Student SR vs teacher | 29.459008 dB | 可辅助观察，不作为最终 HR 画质 |
| PyTorch SR vs fixed SR | 43.171866 dB | 已满足定点一致性门槛 |

因此，`28+dB/30dB` 不能用单张简单图证明，也不能用 PyTorch-vs-fixed 的一致性 PSNR 替代。正式口径必须报告 REDS val 多图平均 PSNR/SSIM，并与 bicubic baseline 同口径比较。

## 候选路线

### Q1：当前拓扑 fine-tune

优先保持硬件拓扑不变：

- scale：X4
- channels：32
- blocks：4
- tile：`64x64`
- 起点 checkpoint：`model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt`

训练方向：

- 增加 HR ground-truth 权重，降低只拟合 teacher 带来的过平滑。
- 保留 temporal loss，防止视频帧间闪烁。
- 加强 edge loss，面向文档线条、人像轮廓和会议画面细节。
- 训练后必须重新跑 W8A8 quant plan 和 fixed reference，不能沿用旧 quant plan。

阶段目标：

| 阶段 | 目标 | 说明 |
| --- | --- | --- |
| P1 | REDS val 平均 PSNR `>=28dB` 且高于 bicubic | 先证明训练方向有效 |
| P2 | REDS val 平均 PSNR 接近或达到 `30dB` | 作为画质冲刺目标 |
| P3 | 上板 `0 mismatch + >=30fps` | 只有通过后才能替换基线 |

### Q2：中等模型候选

如果 Q1 达不到 `28dB`，或已经达到 `28dB` 但还想冲刺 `30dB`，可尝试：

- `c48b4`
- `c32b6`

风险：

- 当前 X4 安全基线吞吐只有 `30.4096fps`，余量非常小。
- 增加通道或 block 很可能导致 DSP/BRAM/latency 上升，跌破 `30fps`。
- 因此 Q2 必须先做软件质量和资源估算，再进 Vivado。

### Q3：tile overlap / halo

对 tile 边界加入 overlap，再裁剪中心有效区，可能改善边缘伪影。

风险：

- 实际计算量和 DDR 访问量增加。
- 需要重新验证 tile manifest、padding/crop、拼接和 board-vs-fixed。

## 替换当前 X4 提交基线的硬门槛

候选模型只有同时满足以下条件，才能替换当前 X4 提交节点：

1. REDS val 多图平均 PSNR/SSIM 高于当前安全基线和 bicubic baseline。
2. 若声称 `28+dB` 或 `30dB`，则必须是同一口径 REDS val 多图平均结果，不是单图结果。
3. W8A8 quant plan 来自候选 checkpoint。
4. hardware-tiled fixed reference 来自同一候选 checkpoint 和 quant plan。
5. RTL/export drift 检查通过。
6. bitstream timing/resource/power 通过 ZC706/XC7Z045 等效门线。
7. 真实板卡输出与 software fixed reference `0` mismatch。
8. 真实板卡完整帧吞吐 `>=30fps`。

## 当前执行策略

当前提交节点先提交 X4 安全基线。PSNR `28+dB` 画质提升作为后续独立候选，不阻塞当前 X4 子任务提交，也不替代当前已闭合 bitstream；`30dB` 只作为额外冲刺目标。

## 服务器训练入口

X4 画质提升候选的服务器配置和启动命令见：

- `docs/x4_quality_training_server_plan_20260625.md`
- `configs/distill_tinyspan_video_x4_quality_30db.json`
- `scripts/start_tinyspan_c32b4_x4_quality_training.ps1`

默认第一组候选使用 `1x RTX 4090D/4090 24GB`，从
`model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt`
继续 fine-tune。该候选只改变训练目标权重，不改变 `c32/b4` 硬件拓扑；只有重新通过量化、RTL、bitstream、
真实板卡 `0 mismatch` 和 `>=30fps` 后，才允许替换当前 X4 提交基线。
