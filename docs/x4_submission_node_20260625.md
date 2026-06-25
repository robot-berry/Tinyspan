# TinySPAN X4 提交节点

生成日期：`2026-06-25`

## 结论

X4 子任务已经进入可提交状态：

- 状态：`X4_READY_FOR_SUBMISSION`
- 路线：TinySPAN PS/DDR X4，调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP。
- 自研 DDR controller/PHY：无。
- 输入/输出：`320x180 -> 1280x720`
- tile：`64x64` LR tile，共 `15` 个 tile。
- 实测吞吐：`30.409639424076744fps @155MHz`
- 完整帧正确性：A53 在 PS DDR 内比较 `1280x720` SR 输出，`0 / 2764800` mismatch，max channel diff `0`。
- 资源门线：按 ZC706 / XC7Z045 折算，LUT `2.91%`、Register `1.06%`、DSP `9.00%`、BRAM Tile `4.95%`、URAM `0`。

该结论只关闭 X4 子任务，不代表整赛题已经完成；整赛题仍缺 X2 独立证据。

## 提交节点目录

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/
```

节点 manifest：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/manifest.json
```

## 可查看图像

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/board_sr_a53_equivalent.png
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/comparison_preview.png
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/diff_heatmap.png
```

`board_sr_a53_equivalent.png` 来自同一 fixed reference 的像素图。它之所以可以作为板上输出展示图，是因为真实板上运行后，A53 已经在 DDR 中对完整 `1280x720` 输出和该 fixed reference 做逐字节比较，结果为 `0` mismatch、max diff `0`。

## 关键证据

```text
Gate H manifest:
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json

X4 board report:
docs/x4_board_result_report_20260625.md

Throughput report:
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md

A53 compare report:
sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md
```

## 边界

- X4 子任务可提交。
- 当前 X4 质量安全基线不是 `28dB` 画质提升方案；它主打正确性、实时性和低资源。
- 板上 SD 卡直接读图仍属于展示增强，不是当前 X4 正式正确性证据。
- 整赛题完成仍必须补齐 X2：冻结 checkpoint、量化、RTL、bitstream、真实板上输出、board-vs-fixed 一致性和 `>=30fps`。
