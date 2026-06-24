# TinySPAN PS/DDR X4 bitstream report - 2026-06-24

## 结论

TinySPAN X4 PS/DDR Block Design 已完成综合、实现、路由和 bitstream 生成。该路线直接调用板卡
`zynq_ultra_ps_e` / PS DDR controller IP，通过标准 AXI 连接到 PS `S_AXI_HP0_FPD` DDR 端口；
未实现自定义 DDR controller、DDR PHY 或板级 DDR 时序逻辑。

本报告只证明 TinySPAN PS/DDR bitstream 与 PPA 报告已经生成，不代表真实板上图像输出一致性或
`720p30` 实测验收已经完成。

## 运行入口

```text
scripts\vivado\run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1 -RequireVivadoIdle -MaxThreads 4
```

## 关键产物

```text
bitstream:
G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4\ps_tinyspan_ddr_x4.runs\impl_1\pstinyspanx4ddr_wrapper.bit

vivado log:
G:\UESTC\feitengspan1\Tinyspan\build\ps_tinyspan_ddr_x4_bitstream_vivado.log

utilization:
G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4\reports\ps_tinyspan_ddr_x4_utilization_impl.rpt

timing:
G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4\reports\ps_tinyspan_ddr_x4_timing_impl.rpt

power:
G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4\reports\ps_tinyspan_ddr_x4_power_impl.rpt
```

Bitstream size: `36,343,257` bytes

Bitstream SHA256:

```text
3E4EEFCD9225A6B7BB3B6CB413FB10A891249E87D2157D9EF3D553465AD6FF7C
```

## Timing 摘要

Vivado routed timing summary:

```text
WNS  = 0.224 ns
TNS  = 0.000 ns
WHS  = 0.015 ns
THS  = 0.000 ns
WPWS = 1.833 ns
TPWS = 0.000 ns
```

结论：所有用户指定 timing constraints 均满足。

## 资源摘要

Vivado routed utilization:

```text
CLB LUTs      = 6,665 / 522,720  = 1.28%
CLB Registers = 4,673 / 1,045,440 = 0.45%
Block RAM Tile = 9 / 984          = 0.91%
DSPs          = 81 / 1,968        = 4.12%
```

## 功耗摘要

Vivado vector-less power estimate:

```text
Total On-Chip Power = 3.581 W
Dynamic             = 2.371 W
Device Static       = 1.210 W
```

备注：功耗报告包含 PS8/PS DDR controller 相关估算，用于 PPA 证据归档；真实功耗仍需板上测量。

## 下一步

1. 编写 PS/XSCT 侧 DDR smoke：写入 LR RGB frame 到 DDR、配置 AXI-Lite 寄存器、启动 TinySPAN、
   轮询 done/error、读取 frame_cycles/tiles_done。
2. 用同一冻结 checkpoint/量化计划生成软件定点参考，读取 DDR 输出帧并做逐像素/逐字节一致性验证。
3. 以 frame_cycles 和板端运行时间计算 `320x180 -> 1280x720` X4 整帧吞吐，并继续补齐 X2 路线证据。
