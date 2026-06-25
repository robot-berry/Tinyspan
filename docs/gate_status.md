# TinySPAN 赛题完成状态

更新时间：`2026-06-25T13:10:18`

当前硬件安全基线：`c32b4_30fps_frozen_20260613`
Checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`

## 总体结论

- `NOT_COMPLETE`：X4 子任务已经达到可交付状态；整赛题仍缺 X2 独立证据。
- X4 Gate H：`30.409639424076744fps`，`0/2764800` mismatch。
- X2 训练：epoch `33`，step `128163/198000`。

## Gate 状态

| Gate | 状态 | 证据 | 下一步 |
| --- | --- | --- | --- |
| A0 TinySPAN 硬件安全基线预检 | `PASS` | 已锁定 `c32b4_30fps_frozen_20260613` 作为硬件安全基线。 | 继续基于该基线推进 X4 交付和 X2 独立证据。 |
| A 冻结 TinySPAN 模型 | `PASS` | checkpoint SHA256 `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`。 | 禁止用仍在变化的 checkpoint 替代冻结证据。 |
| B TinySPAN 量化与软件定点参考 | `PASS` | X4 W8A8 quant plan、定点参考和 tile64 整帧固定点参考已归档。 | X2 训练完成后导出 X2 W8A8 quant plan 与 X2 定点参考。 |
| C TinySPAN RTL 导出 | `PASS` | TinySPAN W8A8 RTL 导出和 manifest 已归档。 | X2 freeze 后复用同一入口生成 X2 RTL manifest。 |
| D TinySPAN RTL 仿真 | `PASS` | RTL gate summary `artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_d_rtl_gate_rerun_20260618\tinyspan_w8a8_rtl_gate_summary.json`。 | 保持 RTL 仿真作为后续 X2/X4 回归门禁。 |
| E TinySPAN 实现与资源约束 | `PASS` | X4 bitstream/resource/timing PASS；WNS `0.074ns`，理论 throughput `31.0015fps`。 | X2 完成后补 X2 bitstream/resource/timing 证据。 |
| F TinySPAN 板卡冒烟测试 | `PASS` | X4 32x32 上板 smoke PASS；perf-only `1831.14409883295fps`，mismatch `0/49152`。 | 保留 32x32 smoke 作为小图回归门禁。 |
| G TinySPAN 图像一致性可视化验证 | `PASS` | X4 32x32 board-vs-fixed byte-exact，并已生成整帧 tile64 固定点预览/heatmap。 | 展示材料可继续补 board PNG、显示输出或 SD 写回图。 |
| H TinySPAN X4 最终 720p30 验收 | `PASS_X4` | X4 整帧上板验收闭合：`30.409639424076744fps`，mismatch `0/2764800`，max diff `0`。 | X4 子任务可交付；整赛题继续补 X2 独立证据。 |
| X2 X2 独立证据包 | `PARTIAL` | X2 正式训练运行中；epoch `33`，step `128163/198000`，progress `64.7288%`。 | 训练完成后冻结、量化、导出 RTL、生成 bitstream 并上板验证。 |

## X4 可交付边界

- X4 已具备冻结 checkpoint、量化计划、RTL/bitstream、真实板上整帧吞吐和完整帧一致性证据。
- X4 DDR 路线只调用板卡/AMD Xilinx IP：`zynq_ultra_ps_e`、PS DDR controller、HP/HPC、SmartConnect；不自研 DDR controller/PHY。
- 可选增强项：补充可直接展示的 board PNG、HDMI/display 输出或 SD 写回图。

## 未闭合项

- X2 独立冻结 checkpoint、量化计划、RTL、bitstream、真实板上输出和 `>=30fps` 证据仍未完成。

本文件由 `scripts/acceptance/update_workflow_status.py` 生成；该脚本只读 artifact，不启动 Vivado、JTAG、板卡或训练。
