# Gate D Rerun Notes

状态：`PASS`

时间：2026-06-18 13:18-13:21

本次 Gate D 使用 `c32b4_30fps_frozen_20260613` 的同一 W8A8 quant plan 重新生成向量并运行 Vivado 行为仿真。

复验入口位于主工程 `G:\UESTC\feitengspan1\scripts\run_tinyspan_c32b4_w8a8_rtl_gate.ps1`，内部调用的 Vivado wrapper 已加入 fresh log 检查和最多 3 次重试，避免把历史 `simulate.log` 误判为本轮通过。

核心命令：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\run_tinyspan_c32b4_w8a8_rtl_gate.ps1 `
  -VivadoBat D:\software\2025.2\Vivado\bin\vivado.bat `
  -QuantPlan runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json `
  -OutDir G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_d_rtl_gate_rerun_20260618 `
  -GeneratedConvTbDir build\generated_tinyspan_w8a8_c32b4_frozen_conv_vector_tbs_20260618 `
  -GeneratedPostprocessTbDir build\generated_tinyspan_w8a8_c32b4_frozen_postprocess_tb_20260618 `
  -ConvRuntime 2ms `
  -PreviewTile 160
```

## 覆盖范围

- Conv vector：`head`
- Conv vector：`blocks.0.c1`
- Conv vector：`reconstruct`
- Postprocess：`blocks.0`
- Postprocess：`blocks.1`
- Postprocess：`blocks.2`
- Postprocess：`blocks.3`

## 结果

- `tinyspan_w8a8_rtl_gate_summary.json`：`PASS`
- `tinyspan_w8a8_rtl_gate_summary.md`：`PASS`
- 所有 conv preview 和 postprocess preview 已生成。

## 运行备注

Vivado 在 `blocks.2` 第一次启动时未生成 fresh `simulate.log` 并返回 `-1`；wrapper 已重试，第二次生成本轮 fresh log，包含 `PASS tinyspan_w8a8_postprocess_blocks_2`，且无 `Fatal`、`MISMATCH` 或 `ERROR:`。

这说明本次失败来自 Vivado 启动/环境的偶发问题，不是 TinySPAN RTL primitive mismatch。后续 Gate E 前仍需补齐 full-frame/tile-level RTL 仿真或更高层集成验证。
