# Gate H X4 整帧 tiled-reference 等待实测记录

状态更新：`2026-06-25` 起，本记录中的 JTAG 全帧等待任务已作为历史路线保留，不再作为 TinySPAN
最终 Gate H 主线。正式路线改为 TinySPAN PS/DDR X4：直接调用板卡 `zynq_ultra_ps_e` / PS DDR
controller IP、HP/HPC 端口和 Xilinx 标准 AXI/DMA IP，不自研 DDR controller/PHY。当前 PS/DDR
posted-write 中间版本已跑通 `320x180 -> 1280x720` SKIP-read，吞吐 `22.1776304000312fps @150MHz`；
最终仍需完整输出读回、board-vs-fixed 一致性和 `>=30fps`。

## 目标

本记录对应 TinySPAN X4 Gate H 最终 720p30 验收的当前等待任务。

验收目标：

- 输入：`320x180` LR RGB 图像；
- 输出：`1280x720` SR 图像；
- tile：`32x32` LR tile，硬件侧按整帧切块路线执行；
- checkpoint：`c32b4_30fps_frozen_20260613`；
- 量化方案：TinySPAN W8A8 quant plan；
- 正确性硬门禁：真实板上输出必须与 hardware-tiled fixed-point software reference 逐字节一致；
- 吞吐硬门禁：真实板上 measured fps 必须 `>=30fps`。

## 当前运行状态

2026-06-24 已启动根工程后台等待任务：

```text
PID: 29736
Workspace: G:\UESTC\feitengspan1
Run dir: G:\UESTC\feitengspan1\board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref
Wait log dir: G:\UESTC\feitengspan1\board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref_waitrun
```

该任务当时只等待 Vivado 空闲，原计划在 Vivado 进程结束并稳定空闲后自动启动 TinySPAN JTAG 上板和
720p30 验收。该计划现已被 PS/DDR 主线取代，不再作为当前正式执行入口。

## 可复现实测入口

Tinyspan 仓库提供镜像侧入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File G:\UESTC\feitengspan1\Tinyspan\scripts\board\run_tinyspan_gate_h_tiledref_waitrun.ps1 `
  -WorkspaceRoot G:\UESTC\feitengspan1 `
  -WaitSeconds 43200 `
  -PollSeconds 300 `
  -StableIdleSeconds 30
```

根工程实际执行脚本：

```text
G:\UESTC\feitengspan1\scripts\run_tinyspan_gate_h_tiledref_waitrun.ps1
```

## 验收参考

训练视觉参考：

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\pytorch_training_sr.png
```

硬门禁 FixedPng：

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\software_tiled_fixed_point_sr.png
```

注意：最终验收比较必须使用 `software_tiled_fixed_point_sr.png`，不能用一次性 full-frame fixed reference 代替。

## 预期输出

等待任务完成后，至少应产生：

```text
board_output_x4_320x180_tinyspan_w8a8_base_equiv.rgb
board_output_x4_320x180_tinyspan_w8a8_base_equiv.png
implementation_resources.json
acceptance_tiled_fixed\tinyspan_720p30_board_acceptance_summary.json
acceptance_tiled_fixed\tinyspan_720p30_board_acceptance_summary.md
acceptance_tiled_fixed\tinyspan_board_software_summary.json
acceptance_tiled_fixed\tinyspan_board_software_preview.png
acceptance_tiled_fixed\diff_heatmap.png
```

只有 summary 同时满足：

- `pass = true`
- `compare_pass = true`
- `fps_pass = true`
- board-vs-fixed mismatch bytes = `0`
- board-vs-fixed max channel diff = `0`

才可以把 Gate H 记为通过。

## 证据归档

Gate H 真实上板验收完成后，用下面的脚本把结果整理到 Tinyspan artifact 目录：

```powershell
python G:\UESTC\feitengspan1\Tinyspan\scripts\acceptance\package_gate_h_tiledref_board_run.py `
  --tinyspan-root G:\UESTC\feitengspan1\Tinyspan `
  --workspace-root G:\UESTC\feitengspan1
```

默认输出：

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x4_320x180_f150_tiledref_20260624
```

该脚本默认不复制 `.rgb` 原始帧，只在 `manifest.json` 中记录输入 raw 和板上输出 raw 的 SHA256。
如确实需要把 raw 帧一并归档，可显式添加 `--include-raw`。

归档前可先做只读硬门禁检查：

```powershell
python G:\UESTC\feitengspan1\Tinyspan\scripts\acceptance\check_gate_h_tiledref_board_run.py `
  --tinyspan-root G:\UESTC\feitengspan1\Tinyspan `
  --workspace-root G:\UESTC\feitengspan1
```

当前 Gate H 还未完成时，该脚本应报告 `INCOMPLETE_OR_FAIL`；只有真实板上输出、summary、
preview、diff heatmap 和资源 JSON 齐全，且 board-vs-fixed 与 fps 硬门禁通过后才会报告 `PASS`。

也可以挂一个只读收尾 watcher，等 Gate H summary 出现后自动检查、打包并刷新状态/审计：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File G:\UESTC\feitengspan1\Tinyspan\scripts\acceptance\watch_gate_h_tiledref_postpack.ps1 `
  -TinyspanRoot G:\UESTC\feitengspan1\Tinyspan `
  -WorkspaceRoot G:\UESTC\feitengspan1
```

该 watcher 只等待和读取文件，不会启动 Vivado、JTAG 或板卡流程。

## 当前边界

该等待任务尚未证明赛题完成。它只是把真实上板实测排队到当前 Vivado 之后。

赛题交付仍需要：

- Gate H X4 整帧实测通过；
- X2 独立训练完成后冻结、量化、RTL/bitstream、上板和图像一致性证据；
- 最终 PPA 汇总和交付审计更新。
