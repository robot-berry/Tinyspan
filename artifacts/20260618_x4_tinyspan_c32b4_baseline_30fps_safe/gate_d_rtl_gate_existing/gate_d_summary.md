# Gate D - TinySPAN RTL Gate 归档摘要

状态：`PARTIAL / HISTORICAL PASS`

本目录归档 2026-06-13 已完成的 TinySPAN C32B4 W8A8 RTL gate 结果。当前时间点检测到 `hw_server` 和 `rdi_xsct` 仍在运行，因此没有叠加启动新的 Vivado 仿真。

## 已归档证据

- RTL gate summary JSON：`tinyspan_w8a8_rtl_gate_summary.json`
- RTL gate summary JSON SHA256：`2A49CEAE910FBEDBBF323346A0A3047297481E6D3967378559A392F50AEF45B8`
- RTL gate summary Markdown：`tinyspan_w8a8_rtl_gate_summary.md`
- RTL gate summary Markdown SHA256：`B145E67D44475F29BEFCC2C8D476229655FE083676B7B42F53EBCEDC767F8F0A`
- Conv vector previews：`conv_vector_previews`
- Postprocess previews：`postprocess_previews`

## 覆盖范围

- Representative convolution primitives：`head`、`blocks.0.c1`、`reconstruct`
- Postprocess primitives：`blocks.0`、`blocks.1`、`blocks.2`、`blocks.3`
- Quant plan：`G:\UESTC\feitengspan1\runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`

## 仍需补齐

- 在 Vivado 空闲后重跑 Gate D，并把新日志归档到当前 artifacts。
- 补齐更接近 full-frame/tile-level 的逐字节 RTL 仿真报告。
- Gate D 通过后才能进入真实 TinySPAN bitstream 生成。
