# TinySPAN 赛题完成状态

更新时间：`2026-06-21T02:05:00+08:00`

当前硬件安全基线：`c32b4_30fps_frozen_20260613`

Checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`

软件 X4 720p30 证据：`36.07976731418754 fps`

## Gate 状态

| Gate | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| A0 TinySPAN 硬件安全基线预检 | `PASS` | `baseline_manifest.json` / `baseline_decision.md` | 继续沿 `c32b4_30fps_frozen_20260613` 推进 |
| A 冻结 TinySPAN 模型 | `PASS` | frozen checkpoint SHA256 已固定 | 禁止使用仍在变化的 checkpoint |
| B TinySPAN 量化与软件定点参考 | `PASS` | W8A8 quant plan + RTL-fixed integer reference | 后续 board 输出必须对齐同一软件定点参考 |
| C TinySPAN RTL 导出 | `PASS` | Gate C re-export + TinySPAN W8A8 RTL manifest | 保持 checkpoint / quant plan / RTL manifest 一致 |
| D TinySPAN RTL 仿真 | `PASS` | RTL gate rerun PASS；fast-vs-serial 仿真 PASS | 已进入 Gate E |
| E TinySPAN 实现与资源约束 | `PASS` | `gate_e_bitstream_x4_320x180_f150_prew_20260620`：bitstream SHA256、timing WNS `0.074ns`、resource gate PASS、power `3.646W`、理论 X4 720p `31.0015fps`；`gate_f_board_x4_32x32_f150_tile32_20260621`：32x32 bitstream timing/resource/power PASS | 进入完整帧 tile scheduler |
| F TinySPAN 板卡冒烟测试 | `PASS` | `gate_f_board_x4_32x32_f150_tile32_20260621`：真实板上输出已回读，input counter `1024`，output counter `16384`，error flags `0x00000000` | 扩展到 SD/DDR 完整帧板端切块 |
| G TinySPAN 图像一致性可视化验证 | `PASS` | `gate_f_board_x4_32x32_f150_tile32_20260621`：board-vs-software `0/49152` mismatch，max diff `0`，preview 已归档 | 扩展到完整帧 tile 拼接可视化 |
| H TinySPAN 最终 720p30 验收 | `BLOCKED` | 32x32 tile 已 PASS，但缺完整 SD/DDR frame tile scheduler、完整帧拼接输出、X2 独立证据 | 完成板端完整帧切块拼接与 X2 证据后执行最终验收 |
| X2 X2 独立证据包 | `BLOCKED` | 当前主证据为 X4，X2 需独立证据包 | 完成 X4 闭环后补齐 X2 量化/RTL/board 证据 |

## 当前硬阻塞

- 32x32 LR tile 的真实 TinySPAN 板上输出已经 PASS，但还没有 SD/DDR 完整 LR 帧的板端 tile scheduler 闭环。
- 还没有完整帧 tile 坐标生成、halo/边界处理、有效区域裁剪、拼接写回和最终 `1280x720` 输出证据。
- 还没有完整帧实测板上 `720p30` throughput。
- X2 证据包尚未补齐。
- 最终 SD/DDR 大图或视频帧路线必须是板端切块拼接：当前验收优先 `32x32` LR tile，`64x64` LR tile 作为后续资源允许时的备选；PC 端预切 tile 和一次性整帧 TinySPAN 核不能替代最终验收路线。

## 最新 Gate E 证据

- 证据包：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620`
- Bitstream：`jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit`
- Bitstream SHA256：`B2C2F3A8571EA3FFFE596C804528AF955C19B8A56077DA879727C1AEAE91DDF2`
- Timing：`clk_pl_0` period `7.000ns`，`142.857MHz`，WNS `0.074ns`，TNS `0.000ns`
- Resource gate：`PASS`，LUT `7371`，Register `5437`，DSP `94`，BRAM Tile `330.5`，URAM `0`
- Power：Total On-Chip Power `3.646W`，Dynamic `2.433W`，Device Static `1.213W`，Confidence `Medium`
- RTL throughput：fast-vs-serial 仿真稳态 `5 cycles/output pixel`
- X4 720p 理论吞吐：`142.857MHz / (1280*720*5) = 31.0015fps`

注意：理论吞吐来自 RTL 仿真输出间隔和实现后时钟，不等同于实测板上吞吐。最终完成必须以真实板上输出和实测 throughput 为准。
同时，`320x180` X4 Gate E 证据只说明当前 TinySPAN 核具备 720p30 理论吞吐和资源余量；最终 SD 卡图片/视频帧方案仍需要板端 tile scheduler 对完整 LR 帧进行 `32x32` 或 `64x64` 切块、halo、推理、裁剪和拼接。

## 最新 Gate F/G 32x32 上板证据

- 证据包：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621`
- Bitstream SHA256：`82066FFE79D61C2128C19A68E1F88FDB989294B21380B4E1546071076A1DA600`
- Board RGB SHA256：`37A3F28A50777A0AA9A4504B02AAD764BA7AFBC6B0D8908DAA5673777FD3F55F`
- Board-vs-software：`PASS`，mismatch bytes `0 / 49152`，max channel diff `0`
- Throughput：`PASS`，perf-only `81916` cycles，`1831.144098832951 fps`
- Timing：WNS `0.091ns`，WHS `0.004ns`
- Resource gate：`PASS`，LUT `5943`，Register `5232`，DSP `78`，BRAM Tile `10.5`，URAM `0`
- Power：Total On-Chip Power `3.469W`，Dynamic `2.260W`，Device Static `1.209W`
- Preview：`acceptance/tinyspan_board_software_preview.png`
