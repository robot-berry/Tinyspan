# Gate C - TinySPAN RTL 导出摘要

状态：`PASS`

本目录记录 `c32b4_30fps_frozen_20260613` 基线的 TinySPAN W8A8 RTL 导出复现结果。

## 输入

- Quant plan：`G:\UESTC\feitengspan1\runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- Quant plan SHA256：`EB6EEDDDE9360F61E6FC30141B2A1E6539E519CB226AC18B8C219B9E40092C9D`
- Check script：`G:\UESTC\feitengspan1\tools\check_tinyspan_w8a8_quant_plan.py`
- Export script：`G:\UESTC\feitengspan1\tools\export_tinyspan_w8a8_to_rtl.py`

## 输出

- Re-export directory：`tinyspan_c32b4_30fps_frozen_w8a8_reexport`
- RTL manifest：`tinyspan_c32b4_30fps_frozen_w8a8_reexport\tinyspan_w8a8_rtl_manifest.json`
- RTL manifest SHA256：`6D167C6C3A5B0EF2D0159A30631199494C0D14D16E367DA2FC4BDAEC2C6A2283`
- RTL header：`tinyspan_c32b4_30fps_frozen_w8a8_reexport\tinyspan_w8a8_layers.vh`
- RTL header SHA256：`A4282B7F2A34AF4EBED84284CBF45E428D60872B4BB3F2D23C0891552B21183F`
- Exported files：`31`
- Exported bytes：`405737`

## 结论

量化计划自检通过，并且可以从同一 W8A8 quant plan 重新导出 RTL manifest、header、weight memory 和 postprocess LUT。Gate C 可作为当前 TinySPAN 硬件基线的有效证据。
