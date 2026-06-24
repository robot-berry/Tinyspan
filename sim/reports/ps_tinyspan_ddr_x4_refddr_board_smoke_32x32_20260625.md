# TinySPAN PS/DDR X4 Reference-DDR Board Smoke 32x32 Report

日期：2026-06-25

## 结论

使用 FACE-ZUSSD 参考 PS DDR 配置重新生成 TinySPAN PS/DDR X4 bitstream 后，DDR alias 门禁与
`32x32 -> 128x128` 真实板上 smoke 均已通过。

该路线继续直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR 控制器、DDR PHY 或板级 DDR 时序逻辑。

## Bitstream

```text
Bitstream: G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4\ps_tinyspan_ddr_x4.runs\impl_1\pstinyspanx4ddr_wrapper.bit
SHA256:    54787AF743B84741B53C2CAF69AB52081284735F905B6A0AB379E4D0183F3F45
Build log: G:\UESTC\feitengspan1\Tinyspan\build\ps_tinyspan_ddr_x4_bitstream_vivado.log
```

Vivado timing/resource:

```text
WNS=0.224ns
TNS=0.000ns
WHS=0.015ns
THS=0.000ns
CLB LUTs=6665
CLB Registers=4673
Block RAM Tile=9
DSP=81
```

## DDR alias 门禁

```text
Run dir: G:\UESTC\feitengspan1\Tinyspan\board_runs\a53_ddr_alias_probe\probe_20260625_0052_refddr
Status:  PASS
Base:    0x12000000
Stride:  0x00004000
Count:   8
Mismatch: 0
```

关键日志：

```text
A53_DDR_ALIAS_STATUS=0x50415353
A53_DDR_ALIAS_MISMATCHES=0
A53_DDR_ALIAS_PASS=1
```

## TinySPAN 32x32 board smoke

```text
Run dir: G:\UESTC\feitengspan1\Tinyspan\board_runs\tinyspan_ps_ddr_x4_smoke\x4_32x32_refddr_20260625_0053
Input:   32x32 RGB888
Output:  128x128 RGB888
Scale:   X4
Readback: FULL
Status:  PASS
```

正确性：

```text
board-vs-fixed mismatch bytes: 0 / 49152
max channel diff: 0
board-vs-fixed pass: true
```

性能：

```text
frame_cycles: 392866
fps from frame cycles @ 150MHz: 381.809573747792
tiles_done: 1
status_reg: 0x00000009
error_reg: 0x00000000
```

输出文件：

```text
Board PNG:     G:\UESTC\feitengspan1\Tinyspan\board_runs\tinyspan_ps_ddr_x4_smoke\x4_32x32_refddr_20260625_0053\board_output_128x128.png
Preview:       G:\UESTC\feitengspan1\Tinyspan\board_runs\tinyspan_ps_ddr_x4_smoke\x4_32x32_refddr_20260625_0053\board_vs_fixed_preview.png
Diff heatmap:  G:\UESTC\feitengspan1\Tinyspan\board_runs\tinyspan_ps_ddr_x4_smoke\x4_32x32_refddr_20260625_0053\board_vs_fixed_diff_heatmap.png
Summary JSON:  G:\UESTC\feitengspan1\Tinyspan\board_runs\tinyspan_ps_ddr_x4_smoke\x4_32x32_refddr_20260625_0053\tinyspan_ps_ddr_x4_smoke_summary.json
```

## 完成边界

该结果证明参考 PS DDR 配置修复了旧 bitstream 的 DDR 地址别名问题，并且 TinySPAN X4 `32x32`
真实板上输出已经与同一软件定点参考逐字节一致。

这仍不是最终赛题交付完成证据。后续还需要：

1. 完整帧 `320x180 -> 1280x720` 板端切块、拼接写回与 board-vs-fixed 一致性。
2. 完整帧实测 `>=30fps` throughput。
3. X2 独立 bitstream、真实板上输出和一致性证据。
