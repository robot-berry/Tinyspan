# Run Summary

Run：`20260618_x4_tinyspan_c32b4_baseline_30fps_safe`

目的：锁定 `c32b4_30fps_frozen_20260613` 作为 TinySPAN 硬件安全基线，作为后续 RTL、bitstream、上板和图像一致性验证的起点。

## 当前结论

- 基线锁定：PASS
- 软件 X4 30fps 证据：PASS，`36.079767 fps`
- 量化/整数参考证据：存在
- RTL manifest 证据：存在
- X4 Gate E bitstream/timing/resource/power：PASS，证据位于 `gate_e_bitstream_x4_320x180_f150_prew_20260620`
- X4 720p 理论吞吐：PASS，`31.0015 fps`，来源为 RTL 仿真 `5 cycles/output pixel` 与实现后 `142.857MHz` 时钟
- X4 32x32 真实上板：PASS，证据位于 `gate_f_board_x4_32x32_f150_tile32_20260621`
- X4 32x32 board-vs-software：PASS，`0 / 49152` mismatch bytes，max channel diff `0`
- X4 32x32 tile throughput：PASS，`1831.144098832951 fps`
- 最终上板验收：NOT COMPLETE

## 仍缺内容

- SD/DDR 完整 LR 帧的板端 tile scheduler 闭环
- 完整帧 tile 坐标生成、halo/边界处理、有效区域裁剪、拼接写回和最终 `1280x720` 输出
- 完整帧实测板上 720p30 throughput
- X2 独立证据包

本 run 已归档 X4 Gate E bitstream 证据和 X4 `32x32` tile 真实板卡 PASS 证据。注意：`32x32` tile PASS 是完整帧板端切块拼接路线的基础证据，但还不能替代 SD/DDR 大图或视频帧的完整 tile scheduler 验收。
