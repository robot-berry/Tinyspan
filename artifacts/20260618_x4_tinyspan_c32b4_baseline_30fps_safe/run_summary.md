# Run Summary

Run：`20260618_x4_tinyspan_c32b4_baseline_30fps_safe`

目的：锁定 `c32b4_30fps_frozen_20260613` 作为 TinySPAN 硬件安全基线，作为后续 RTL、bitstream、上板和图像一致性验证的起点。

## 当前结论

- 基线锁定：PASS
- 软件 X4 30fps 证据：PASS，`36.079767 fps`
- 量化/整数参考证据：存在
- RTL manifest 证据：存在
- 最终上板验收：NOT COMPLETE

## 仍缺内容

- 真实 TinySPAN bitstream
- 真实板上输出
- 板上输出与软件定点参考逐字节一致
- 真实板上 720p30 throughput
- 图像一致性预览和 diff 热力图

本 run 不启动 Vivado，不运行 JTAG/板卡流程。
