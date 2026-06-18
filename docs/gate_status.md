# TinySPAN 赛题完成状态

更新时间：`2026-06-18T13:22:42`

当前硬件安全基线：`c32b4_30fps_frozen_20260613`
Checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
软件 X4 720p30 证据：`36.07976731418754 fps`

## Gate 状态

| Gate | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| A0 TinySPAN 硬件安全基线预检 | `PASS` | baseline_manifest.json / baseline_decision.md | 继续沿 c32b4_30fps_frozen_20260613 推进 |
| A 冻结 TinySPAN 模型 | `PASS` | frozen checkpoint SHA256 已固定 | 禁止使用仍在变化的 checkpoint |
| B TinySPAN 量化与软件定点参考 | `PASS` | W8A8 quant plan + integer reference summary | 后续 board 输出必须对齐同一软件定点参考 |
| C TinySPAN RTL 导出 | `PASS` | Gate C re-export + TinySPAN W8A8 RTL manifest | 进入 RTL 仿真与实现前检查 |
| D TinySPAN RTL 仿真 | `PASS` | 当前 artifacts 中 Gate D RTL gate rerun PASS | 进入 Gate E bitstream 生成前检查 |
| E TinySPAN 实现与资源约束 | `BLOCKED` | bitstream 缺失 | 生成真实 TinySPAN bitstream 并归档 timing/utilization/power |
| F TinySPAN 板卡冒烟测试 | `BLOCKED` | 真实板上输出缺失 | bitstream 通过后运行真实板卡 smoke，回读 board output |
| G TinySPAN 图像一致性可视化验证 | `BLOCKED` | 缺 board_sr.png / comparison_preview.png / diff_heatmap.png | 拿到真实 board output 后运行图像一致性验证 |
| H TinySPAN 最终 720p30 验收 | `BLOCKED` | 缺 byte-exact board compare、board 720p30、resource gate | 等 E/F/G 通过后执行最终验收 |
| X2 X2 独立证据包 | `BLOCKED` | 当前主证据为 X4，X2 需独立证据包 | 完成 X4 闭环后补齐 X2 量化/RTL/board 证据 |

## 当前硬阻塞

- 真实 TinySPAN-trained bitstream 尚未生成。
- 真实板上输出尚未回读。
- 板上输出与软件定点参考的逐字节一致性尚未完成。
- 板上 720p30 throughput 和 resource gate 尚未完成。
- X2 证据包尚未补齐。

本文件由 `scripts/acceptance/update_workflow_status.py` 生成，不启动 Vivado、JTAG 或板卡流程。
