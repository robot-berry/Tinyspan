# Gate E TinySPAN Bitstream Preflight

生成时间：`2026-06-18T13:27:37+08:00`

状态：`BLOCKED`

本次检查只读取现有文件与脚本，不启动 Vivado，不运行 JTAG/板卡流程。

## 结论

当前工程尚未找到可作为最终验收的真实 TinySPAN-trained bitstream。`c32b4_30fps_frozen_20260613` 已经具备 checkpoint、W8A8 量化、软件定点参考、RTL manifest 和 Gate D RTL 复验通过证据，但 Gate E 仍缺实现阶段的 bitstream、timing、utilization、power 和资源门限报告。

## 不能替代最终 Gate E 的内容

- W8A12 DDR/tile-writer bitstream 是参考路线，不能替代 TinySPAN 验收。
- W8A10 candidate/full-span smoke bitstream 是参考路线，不能替代 TinySPAN 验收。
- `scripts/run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1` 是 32x32 JTAG/base-equivalent smoke 路线，不能替代 720p30 full-frame TinySPAN bitstream。

## Gate E 通过条件

- 生成同一 frozen checkpoint 与同一 W8A8 quant plan 的真实 TinySPAN bitstream。
- bitstream 支持硬件侧从 SD/DDR 读取完整降采样帧并切块处理，不能依赖 PC 端预切块作为最终证据。
- 归档 `timing.rpt`、`utilization.rpt`、`power.rpt` 或等价报告。
- 生成 `resource_gate.json`，并证明资源不超过 ZC706/XC7Z045 等效门限。
- 记录 bitstream 路径、SHA256、Vivado 版本、top module、约束、频率和实现日志摘要。

下一步：生成 TinySPAN full-frame/tile-scheduler bitstream；bitstream 与资源报告通过后再进入 Gate F 板卡冒烟测试。
