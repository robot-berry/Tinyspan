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

## TinySPAN PS/DDR tile64 FIFO f155 吞吐候选

证据报告：

```text
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md
```

该版本继续直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC 端口和 Xilinx 标准
AXI IP，不实现自研 DDR controller、DDR PHY、DDR 仲裁器或板级 DDR 时序逻辑。tile buffer FIFO
优化属于 TinySPAN AXI 用户逻辑。

| 指标 | 数值 |
| --- | ---: |
| CLB LUTs | 6353 |
| CLB Registers | 4647 |
| DSP | 81 |
| Block RAM Tile | 27 |
| URAM | 0 |
| WNS | 0.020ns |
| TNS | 0.000ns |
| X4 320x180 SKIP-read | 30.4096394240767fps |
| X4 320x180 A53 in-DDR compare | 0 / 2764800 mismatch |
| Tile count | 15 |
| Frame cycles | 5097068 |

tile64 FIFO f155 后，完整帧板上吞吐相对 posted-write tile32 版本 `22.1776304000312fps` 提升到
`30.4096394240767fps`，约为 `1.37x`，首次给出 X4 完整帧真实板卡 `>=30fps` 吞吐证据。
随后 A53 in-DDR comparator 对完整 SR frame 做了 `2764800` 字节逐字节比较，mismatch `0`，
max diff `0`。因此 X4 Gate H 的吞吐和正确性证据已闭合；board PNG/显示/SD 写回仍可作为展示增强。

## 面积与吞吐判断

TinySPAN 的优势是模型小、DSP 需求低、bit-exact 闭合难度低。在当前资源门线下，TinySPAN 比 W8A12 更适合作为赛题主交付路线：

- 已有真实板上 `0 mismatch` 证据
- 资源远低于 XC7Z045 门线
- Gate E 理论 720p30 刚好过线
- 32x32 tile 级吞吐余量很大

当前主要风险不是 compute core，而是完整帧系统正确性闭环与最终 I/O 工程化：

- SD/DDR 访问效率
- tile 调度开销
- 边缘 tile padding/crop
- 输出写回和 PS 回读
- X2 独立实现与验证

当前 X4 完整帧吞吐和 byte-exact 正确性已经由 tile64 FIFO f155 SKIP-read 与 A53 in-DDR compare
闭合。下一步应在不自研 DDR 的前提下，把过渡性的 AXI 调试桥收敛到 Xilinx AXI DMA/DataMover/VDMA
等标准 IP 路线，并补 X2 独立证据。

## 可提升方向

当前方法可以继续提升，重点不是扩大 TinySPAN compute core，而是提高整帧 I/O 与 tile 调度余量。
X4 tile64 FIFO f155 已经达到 `30.4096394240767fps`，但相对 `30fps` 的余量不大，因此后续优化应按
风险从低到高推进：

| 优先级 | 提升方向 | 验收条件 |
| --- | --- | --- |
| P0 | X2 训练完成后补齐独立 X2 证据包 | X2 checkpoint、quant plan、RTL、bitstream、真实板上输出、逐字节一致性和 `>=30fps` 全部闭合 |
| P1 | 将单像素 AXI 调试桥收敛为 AXI burst、DataMover、DMA 或 VDMA | X4 仍保持 A53 DDR alias PASS、mismatch `0`、`>=30fps` |
| P1 | 加入 LR 读、TinySPAN 计算、SR 写回的 ping-pong buffer | frame cycles 下降，且完整帧 byte-exact 不变 |
| P2 | 补充 DDR 导出的 `board_sr.png`、`comparison_preview.png` 和 `diff_heatmap.png` | 图片可查看，哈希与 manifest 对齐，不走 JTAG 全帧读回 |
| P3 | 尝试更大 tile 或更高频率 | 必须重新通过 BRAM、时序、边缘裁剪、完整帧吞吐和逐字节一致性 |

所有提升都继续调用板卡/厂商 DDR 与 AXI IP，不新增自研 DDR controller、DDR PHY 或板级 DDR 时序逻辑。
任一优化如果导致 X4 Gate H 证据失效，应立即回退到当前 tile64 FIFO f155 安全基线，并把该优化只作为
实验分支记录。

## 最终 PPA 有效条件

只有完整帧真实板上输出正确、Vivado bitstream 有效、资源门线 PASS 且实测 `>=30fps` 后，PPA 才能作为最终赛题得分证据。当前 Gate E/F 是强基线，但仍不能替代最终 Gate H。
