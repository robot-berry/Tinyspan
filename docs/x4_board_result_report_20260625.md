# TinySPAN X4 上板资源与超分效果报告

生成日期：`2026-06-25`

## 结论

当前 X4 安全基线已经完成真实板卡闭合：

- 路线：TinySPAN PS/DDR X4，直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC 和标准 AXI IP。
- 自研 DDR controller/PHY：无。
- 输入/输出：`320x180 -> 1280x720`。
- tile：`64x64` LR tile，共 `15` 个 tile。
- 吞吐：`30.409639424076744fps @155MHz`。
- 正确性：A53 在 DDR 中比较完整 SR frame，`0 / 2764800` mismatch，max channel diff `0`。
- 状态：`PASS_X4`。该结论只关闭 X4，不关闭整赛题；整赛题仍缺 X2 独立证据。

## 上板证据

正式 X4 Gate H manifest：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json
```

吞吐证据：

```text
board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_tile64_fifo_f155_skipread_20260625_0412
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md
```

正确性证据：

```text
board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md
```

该正确性 run 使用 poison output buffer，避免旧输出残留导致误通过。比较对象是同一 frozen checkpoint、同一 quant plan、同一 tile64 contract 生成的 hardware-tiled fixed-point reference。

## 资源、时序和功耗

Vivado 实际实现器件为 `xczu19eg-ffvc1760-2-i`：

| 指标 | 数值 |
| --- | ---: |
| CLB LUTs | 6353 |
| CLB Registers | 4647 |
| DSP | 81 |
| Block RAM Tile | 27 |
| URAM | 0 |
| WNS | 0.020ns |
| TNS | 0.000ns |
| WHS | 0.007ns |
| THS | 0.000ns |
| PL frequency | 155MHz |
| Total On-Chip Power | 3.969W |
| Dynamic Power | 2.755W |
| Device Static Power | 1.213W |
| Power confidence | Medium |

按 ZC706 / XC7Z045 资源门线折算：

| 指标 | 使用量 | ZC706/XC7Z045 门线 | 占比 |
| --- | ---: | ---: | ---: |
| LUT | 6353 | 218600 | 2.91% |
| Register | 4647 | 437200 | 1.06% |
| DSP | 81 | 900 | 9.00% |
| BRAM Tile | 27 | 545 | 4.95% |
| URAM | 0 | 0 | 0 |

## 超分效果

板上输出与 fixed-point reference 的一致性已经闭合：

| 项目 | 数值 |
| --- | ---: |
| 输出像素 | 921600 |
| 比较字节 | 2764800 |
| mismatch bytes | 0 |
| max channel diff | 0 |

可查看图像材料：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png
```

当前 board-output PNG 不是最终硬证据；最终硬证据是 A53 in-DDR full-frame compare。因为比较结果为 `0` mismatch，`software_tiled_fixed_point_sr.png` 可代表本次板上输出的像素效果。

## 画质指标

训练/定点一致性指标：

| Pair | PSNR | SSIM | MAE/255 | Max diff |
| --- | ---: | ---: | ---: | ---: |
| student_vs_teacher | 29.459008 dB | 0.894348 | 0.022488 | 92 |
| pytorch_vs_tiled_fixed | 43.171866 dB | 0.993147 | 0.003293 | 57 |
| full_integer_vs_tiled_fixed | 44.487280 dB | 0.997659 | 0.000729 | 58 |
| pytorch_vs_full_integer | 48.717049 dB | 0.995183 | 0.002694 | 2 |

REDS HR 样例画质指标：

| Pair | PSNR | SSIM | MAE/255 | Max diff |
| --- | ---: | ---: | ---: | ---: |
| x4_tile64_fixed_vs_reds_hr | 25.851911 dB | 0.700177 | 0.031975 | 136 |
| bicubic_lr_vs_reds_hr | 25.787498 dB | 0.699348 | 0.031871 | 133 |

当前 X4 安全基线相对 bicubic 的 REDS HR 样例提升较小，因此它更适合作为“正确性、实时性、低资源”安全基线。当前 X4 提交节点采用本基线；PSNR `28+dB` 画质提升按 `docs/x4_quality_improvement_plan.md` 作为独立候选推进，`30dB` 仅作为额外冲刺目标。只有重新完成量化、RTL、bitstream、真实板卡 `0` mismatch 和 `>=30fps` 后，候选才能替换本基线。

## 边界

- X4 子任务已经达到可交付状态。
- 板上 SD 卡直接读图尚未作为严格证据闭合；当前正式链路是 host/XSCT 将输入写入 DDR 后由 PL 运行，再由 A53 在 DDR 内比较。
- 整赛题仍需要 X2 完成训练冻结、量化、RTL、bitstream、真实板上输出、board-vs-fixed 一致性和 `>=30fps` 吞吐证据。
