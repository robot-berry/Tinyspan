# TinySPAN 硬件安全基线决策

日期：2026-06-18

当前 TinySPAN 工作流使用 `c32b4_30fps_frozen_20260613` 作为硬件安全基线推进。

## 基线信息

- Baseline ID：`c32b4_30fps_frozen_20260613`
- Checkpoint：`G:\UESTC\feitengspan1\runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt`
- SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- 模型：TinySPAN c32 b4
- 优先倍率：先 X4，后 X2
- 优先量化：W8A8

## 选择原因

- checkpoint 已冻结，source 与 frozen SHA256 一致。
- X4 `320x180 -> 1280x720` 软件实时验收通过，端到端 `36.079767 fps`。
- 已有 W8A8 量化计划、整数参考、RTL manifest 和 readiness 记录。
- `c32b4_final_20260615` 当前仍有 fused/export 边界漂移，暂不进入上板主线。

## 验收边界

这份证据包只说明“可以用该 checkpoint 推进硬件工作”，不能说明“TinySPAN 上板验收已完成”。

最终完成仍必须补齐：

- 真实 TinySPAN-trained bitstream
- 真实板上输出
- 板上输出与同一软件定点参考逐字节一致
- 实测 720p30 throughput
- 图像一致性预览 `comparison_preview.png`
- 差异热力图 `diff_heatmap.png`

## 更换基线规则

如果后续要改用 `c32b4_final_20260615` 或其它 checkpoint，必须先生成 `baseline_upgrade_report.md`，并重新证明 checkpoint 哈希、量化计划、定点参考、RTL manifest、图像一致性和 fused/export 一致性。
