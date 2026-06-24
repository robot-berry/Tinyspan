# TinySPAN PPA 分析

## 资源门线

赛题按 ZC706 / XC7Z045 等效资源约束评估：

| 资源 | 上限 |
| --- | ---: |
| LUT | 218600 |
| Register | 437200 |
| DSP | 900 |
| BRAM Tile | 545 |
| URAM | 0 |

## Gate E：X4 320x180 bitstream

证据包：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620
```

| 指标 | 数值 |
| --- | ---: |
| LUT | 7371 |
| Register | 5437 |
| DSP | 94 |
| BRAM Tile | 330.5 |
| URAM | 0 |
| WNS | 0.074ns |
| Total On-Chip Power | 3.646W |
| 理论 X4 720p throughput | 31.0015fps |

说明：Gate E 的吞吐来自 RTL 稳态输出间隔和实现后时钟估算，不等同于完整帧实测板上 throughput。

## Gate F：X4 32x32 tile 上板

证据包：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621
```

| 指标 | 数值 |
| --- | ---: |
| LUT | 5943 |
| Register | 5232 |
| DSP | 78 |
| BRAM Tile | 10.5 |
| WNS | 0.091ns |
| WHS | 0.004ns |
| Total On-Chip Power | 3.469W |
| Perf-only tile throughput | 1831.144098832951fps |

## TinySPAN PS/DDR posted-write 中间版本

证据报告：

```text
sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md
```

该版本直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP 和 HP/HPC 端口，不实现自研 DDR
controller、DDR PHY 或板级 DDR 时序逻辑。posted-write 修改只属于 AXI 用户逻辑。

| 指标 | 数值 |
| --- | ---: |
| CLB LUTs | 6169 |
| CLB Registers | 4667 |
| DSP | 81 |
| Block RAM Tile | 9 |
| URAM | 0 |
| WNS | 0.075ns |
| TNS | 0.000ns |
| X4 32x32 FULL readback | 1313.14015582597fps |
| X4 32x32 board-vs-fixed | 0 / 49152 mismatch |
| X4 320x180 SKIP-read | 22.1776304000312fps |

posted-write 后完整帧吞吐相比单 beat 阻塞写版本 `6.6843209982062fps` 提升到
`22.1776304000312fps`，约为 `3.32x`。但它仍低于 `30fps`，且完整帧使用 `SKIP` readback，
不能替代最终完整帧图像一致性验收。

## 面积与吞吐判断

TinySPAN 的优势是模型小、DSP 需求低、bit-exact 闭合难度低。在当前资源门线下，TinySPAN 比 W8A12 更适合作为赛题主交付路线：

- 已有真实板上 `0 mismatch` 证据
- 资源远低于 XC7Z045 门线
- Gate E 理论 720p30 刚好过线
- 32x32 tile 级吞吐余量很大

当前主要风险不是 compute core，而是完整帧系统开销：

- SD/DDR 访问效率
- tile 调度开销
- 边缘 tile padding/crop
- 输出写回和 PS 回读
- X2 独立实现与验证

当前最明确的吞吐瓶颈已收敛到 PS/DDR I/O：posted-write 已显著降低输出写回等待，
下一步应在不自研 DDR 的前提下，把剩余阻塞式逐像素 DDR read 改成 AXI burst 或 Xilinx
AXI DMA/DataMover 读 tile/halo。

## 最终 PPA 有效条件

只有完整帧真实板上输出正确、Vivado bitstream 有效、资源门线 PASS 且实测 `>=30fps` 后，PPA 才能作为最终赛题得分证据。当前 Gate E/F 是强基线，但仍不能替代最终 Gate H。
