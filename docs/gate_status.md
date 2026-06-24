# TinySPAN 赛题完成状态

更新时间：`2026-06-24T17:28:33`

当前硬件安全基线：`c32b4_30fps_frozen_20260613`
Checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
软件 X4 720p30 证据：`36.07976731418754 fps`

## Gate 状态

| Gate | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| A0 TinySPAN 硬件安全基线预检 | `PASS` | baseline_manifest.json / baseline_decision.md | 继续沿 c32b4_30fps_frozen_20260613 推进 |
| A 冻结 TinySPAN 模型 | `PASS` | frozen checkpoint SHA256 已固定 | 禁止使用仍在变化的 checkpoint |
| B TinySPAN 量化与软件定点参考 | `PASS` | W8A8 quant plan + integer reference summary；X4 full-frame tiled FixedPng ready，tiles 60 | 后续 board 输出必须对齐同一软件定点参考 |
| C TinySPAN RTL 导出 | `PASS` | Gate C re-export + TinySPAN W8A8 RTL manifest | 进入 RTL 仿真与实现前检查 |
| D TinySPAN RTL 仿真 | `PASS` | 当前 artifacts 中 Gate D RTL gate rerun PASS | 进入 Gate E bitstream 生成前检查 |
| E TinySPAN 实现与资源约束 | `PASS` | X4 320x180 Gate E bitstream/resource PASS；WNS 0.074ns，理论 31.0015fps | 继续接入完整帧板端 tile scheduler |
| F TinySPAN 板卡冒烟测试 | `PASS` | X4 32x32 真实板卡 smoke PASS；fps 1831.14409883295，LUT 5943，DSP 78 | 扩展到 SD/DDR 完整帧板端切块和回写 |
| G TinySPAN 图像一致性可视化验证 | `PASS` | X4 32x32 board-vs-fixed byte-exact；mismatch 0/49152，max diff 0 | 扩展到完整帧拼接可视化和 diff heatmap |
| H TinySPAN 最终 720p30 验收 | `BLOCKED` | 32x32 tile 已 PASS；X4 整帧 tiled FixedPng 已准备；缺真实完整帧板上输出和实测 720p30 | 完成完整帧 tile controller、bitstream、板上回读和吞吐验收 |
| X2 X2 独立证据包 | `PARTIAL` | X2 TinySPAN smoke PASS，正式训练运行中；epoch 3 step 8592 | 等待 X2 训练完成，再冻结、量化、导出 RTL、上板验证 |

## 当前硬阻塞

- 32x32 LR tile 的真实 TinySPAN 板上输出已经 PASS，但还没有 SD/DDR 完整 LR 帧的板端 tile scheduler 闭环。
- X4 `320x180 -> 1280x720` 的 hardware-tiled FixedPng 已生成，可作为后续真实板上输出比较的目标。
- 还没有真实板上完整帧 tile 坐标生成、边缘 padding、动态有效区域裁剪、拼接写回和最终 `1280x720` 回读输出证据。
- 还没有完整帧实测板上 `720p30` throughput。
- X2 已启动 TinySPAN 独立训练，但 X2 冻结、量化、RTL、bitstream、真实板上输出和 `>=30fps` 证据仍未补齐。

## Gate E 证据

- Bitstream：`jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit`
- Bitstream SHA256：`B2C2F3A8571EA3FFFE596C804528AF955C19B8A56077DA879727C1AEAE91DDF2`
- Timing：WNS `0.074ns`，TNS `0.0ns`，frequency `142.857MHz`
- Resource gate：`PASS`，LUT `7371`，Register `5437`，DSP `94`，BRAM Tile `330.5`
- 理论 X4 720p throughput：`31.0015fps`

## X2 TinySPAN 训练状态

- 状态：`training_running`
- Student：`TinySPAN X2 c32 b4`
- Smoke：`PASS`，checkpoint `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_reds_smoke_x2_c32_b4\student_last.pt`
- Formal training：`RUNNING`，output `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal`
- Latest observed：epoch `3`，step `8592`，speed `1.517 step/s`
- Acceptance boundary：`NOT_ACCEPTED`

说明：X2 训练运行中只能证明路线已启动；不能替代 X2 frozen checkpoint、量化、RTL、bitstream、板上输出和吞吐验收。

## X4 完整帧 tiled FixedPng 证据

- 状态：`PASS`
- 输入：`320x180`
- 输出：`1280x720`
- Tile：`32x32`，数量 `60`
- Checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- Quant plan SHA256：`EB6EEDDDE9360F61E6FC30141B2A1E6539E519CB226AC18B8C219B9E40092C9D`
- FixedPng：`G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\software_tiled_fixed_point_sr.png`
- Preview：`G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\comparison_preview.png`
- Diff heatmap：`G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\diff_heatmap.png`
- Full-integer vs tiled：mismatch `215682/2764800`，max diff `58`，PSNR `42.680956787380666 dB`

说明：该证据是软件侧硬件同构参考，只证明后续板上比较目标已准备好；不能替代真实完整帧 bitstream、板上回读和实测吞吐。

## Gate F/G 32x32 上板证据

- Board-vs-fixed：`mismatch 0/49152`，max diff `0`
- Perf-only throughput：`1831.14409883295fps`
- Resource：LUT `5943`，Register `5232`，DSP `78`，BRAM Tile `10.5`
- Timing：WNS `0.091ns`，WHS `0.004ns`
- Preview：`board_runs\tinyspan_w8a8_base_equiv_jtag\gate_f_x4_32x32_f150_20260621_tile32\acceptance\tinyspan_board_software_preview.png`

本文件由 `scripts/acceptance/update_workflow_status.py` 生成，不启动 Vivado、JTAG 或板卡流程。
