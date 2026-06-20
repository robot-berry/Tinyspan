# Gate E: X4 320x180@150MHz TinySPAN bitstream

更新时间：`2026-06-20T16:05:00+08:00`

本目录归档 `c32b4_30fps_frozen_20260613` 硬件安全基线的 X4 Gate E 实现证据。该次实现使用 TinySPAN W8A8 base-equivalent fast core，输入 `320x180`，X4 输出目标为 `1280x720`。

## 结论

| 项目 | 结果 |
| --- | --- |
| Gate E bitstream 生成 | `PASS` |
| Timing | `PASS`，`clk_pl_0` period `7.000ns`，`142.857MHz`，WNS `0.074ns`，TNS `0.000ns` |
| ZC706 等效资源门限 | `PASS` |
| Power report | `PASS`，Total On-Chip Power `3.646W`，Dynamic `2.433W`，Device Static `1.213W`，Confidence `Medium` |
| RTL fast-vs-serial 仿真 | `PASS tinyspan_w8a8_fast_base_equiv outputs=256` |
| 理论 X4 720p 吞吐 | `142.857MHz / (1280*720*5) = 31.0015fps`，达到 `>=30fps` |

注意：这里通过的是 Gate E 的 bitstream、时序、资源、power report 和 RTL 推导吞吐。真实板上输出、板上输出与软件定点参考逐字节一致、以及实测板上 `>=30fps` 仍属于后续 Gate F/G/H，不能据此宣告最终上板验收完成。

## 关键证据

- Bitstream：`jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit`
- Bitstream SHA256：`B2C2F3A8571EA3FFFE596C804528AF955C19B8A56077DA879727C1AEAE91DDF2`
- Timing report：`jtag_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast_timing_impl.rpt`
- Utilization report：`jtag_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast_utilization_impl.rpt`
- Power report：`jtag_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast_power_impl.rpt`
- Resource gate：`resource_gate_xc7z045.json`
- Simulation log：`tinyspan_w8a8_fast_base_equiv_xsim.log`
- Vivado log：`vivado_bitstream_build.log`
- Power log：`report_power.log`

## 资源摘要

| 资源 | 使用 | ZC706 等效上限 | 结果 |
| --- | ---: | ---: | --- |
| LUT | `7371` | `218600` | `PASS` |
| Register | `5437` | `437200` | `PASS` |
| DSP | `94` | `900` | `PASS` |
| BRAM Tile | `330.5` | `545` | `PASS` |
| URAM | `0` | `0` | `PASS` |

## Power 摘要

`jtag_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast_power_impl.rpt`：

| 指标 | 数值 |
| --- | ---: |
| Total On-Chip Power | `3.646W` |
| Dynamic | `2.433W` |
| Device Static | `1.213W` |
| Junction Temperature | `27.7C` |
| Confidence Level | `Medium` |

Vivado 报告使用 vector-less activity propagation。`report_power.log` 中有 reset switching activity 的功耗估计精度警告，后续可用实测或 SAIF/VCD 活动文件提高置信度；当前作为 Gate E PPA 估算证据归档。

## 仿真吞吐

`tinyspan_w8a8_fast_base_equiv_xsim.log`：

```text
FAST_TIMING first_time=385000 last_time=13135000 span_cycles=1275 outputs=256
SERIAL_TIMING first_time=415000 last_time=43765000 span_cycles=4335 outputs=256
PASS tinyspan_w8a8_fast_base_equiv outputs=256
```

稳态输出间隔为 `1275 / (256 - 1) = 5` cycles/output pixel。

## 运行入口

本次 bitstream 对应的 root 工程命令为：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1 `
  -ImgW 320 -ImgH 180 -PlFreqMhz 150 -Fast `
  -RequireVivadoIdle -StableVivadoIdleSeconds 10 -VivadoMaxThreads 1 `
  -CleanLogDir board_runs\tinyspan_vivado_clean\bitstream_jtag_base_equiv\gate_e_x4_320x180_fast_xpmpipe_prew_f150_20260620_1431
```

下一步必须在 Vivado/JTAG 空闲时运行真实板卡 smoke，回读真实 board output，然后与同一 RTL-fixed TinySPAN 软件定点参考逐字节比较，并生成 `comparison_preview.png` 与 `diff_heatmap.png`。
