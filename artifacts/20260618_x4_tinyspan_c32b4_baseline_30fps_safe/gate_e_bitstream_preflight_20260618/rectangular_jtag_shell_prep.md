# Gate E 矩形输入 Shell 准备记录

生成时间：`2026-06-18T13:35:27+08:00`

状态：`PARTIAL_PREP`

本记录不表示 Gate E 通过；本步骤没有启动 Vivado，没有运行 JTAG，也没有产生 bitstream。

## 目的

现有 JTAG/full-span smoke 路线只能表达 `IMG_W x IMG_W` 的正方形输入，这不适合 X4 720p30 的真实输入合同：`320x180 -> 1280x720`。本地根工程已做矩形输入 shell 准备，让后续中间 bitstream 构建可以显式传入 `ImgW=320`、`ImgH=180`。

## 本地改动范围

- `rtl/board/sr_sd_axi_lite_accel.v`：新增 `IMG_H` 参数，输出像素计数改为 `IMG_W*IMG_H*SCALE*SCALE`，并把 `IMG_H` 传给 TinySPAN/W8A10/W8A12 streaming 分支。
- `rtl/board/sr_jtag_rgb_transfer_endpoint.v`：新增 `IMG_H` 参数并传入 `sr_sd_axi_lite_accel`。
- `scripts/create_vivado_jtag_full_span_bd_project.tcl`：支持 `JTAG_FULL_SPAN_IMG_H` 环境变量，并给端点设置 `CONFIG.IMG_H`。
- `scripts/run_vivado_bitstream_jtag_full_span_scale.ps1`：新增 `-ImgH`，默认等于 `-ImgW`，bit/report 命名扩展为 `WxH`。
- `scripts/run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1`：新增 `-ImgH` 并透传。
- `scripts/run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1`：新增 `-ImgH`，raw 转换、JTAG transfer 和输出尺寸均改为矩形。

## 已做静态检查

- PowerShell parser 检查通过。
- `git diff --check` 未发现格式错误。
- 没有启动 Vivado、xsim、JTAG 或板卡流程。

## 仍未完成

- 还没有真实 TinySPAN-trained bitstream。
- 还没有 timing/utilization/power 和 ZC706/XC7Z045 资源门限报告。
- 矩形 JTAG shell 只是 full-frame 中间验证入口，不能替代最终 SD/DDR 硬件切块验收。
- Gate F/G/H 仍必须等待真实板上输出、软件定点逐字节一致和 >=30fps 证据。

候选中间构建命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1 `
  -ImgW 320 `
  -ImgH 180 `
  -PlFreqMhz 150 `
  -Fast
```

运行前需要确认 Vivado 空闲、主机内存足够，并明确该命令仍是中间 full-frame/JTAG 验证，不是最终 SD/DDR 硬件切块验收。
