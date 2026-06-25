# TinySPAN 赛题交付索引

生成时间：`2026-06-25T13:18:27`
索引生成前提交：`8252726e9efdd5fd92c33ccc38aa1a3169d4f6b0`
总体状态：`NOT_COMPLETE`

本索引只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。

## 当前结论

- X4 子任务：`PASS_X4`，fps `30.409639424076744`，mismatch `0/2764800`。
- X2 训练：`training_running`，epoch `33`，step `128884/198000`，progress `65.0929%`。
- X2 readiness：`PARTIAL`。

## X2 剩余缺口

- readiness blocker: `x2_quant_plan_exists`
- readiness blocker: `x2_rtl_manifest_exists`
- evidence missing: finished/frozen X2 TinySPAN checkpoint
- evidence missing: X2 W8A8 quant plan
- evidence missing: X2 fixed-point/tiled reference
- evidence missing: X2 RTL export and simulation
- evidence missing: X2 bitstream
- evidence missing: real X2 board output
- evidence missing: board-vs-software byte-exact comparison
- evidence missing: measured >=30fps throughput

## 证据分组

### 工作流与交付审计

状态：`PASS`

- `PASS` `README.md`，3086 bytes，SHA256 `BDC897F4BF2E060879D6C4FBAB7C6A3AC42A1E30DAB18F708CBECA567A10C36B`
- `PASS` `WORKFLOW.md`，49536 bytes，SHA256 `78A9591C0863CD7C5CFBD046C0DBBFCBC24DD5E65AEAC36FF08FC5E7833DF6DE`
- `PASS` `docs/gate_status.md`，3188 bytes，SHA256 `1DE8CAE48F909FFC3D5B1FF6A145FE915653532F9B94F4371A4314D9C4BB9E34`
- `PASS` `docs/contest_delivery_audit.md`，5981 bytes，SHA256 `E69D0BBC7A12C3E8963489602B4A0E9FF3D74B86BD787BDFC9580489A15B849B`
- `PASS` `docs/x2_hardware_readiness.md`，6501 bytes，SHA256 `59DEFC4A7CA3C5F14EFD584BA29B16178EEBEEB8688B1157B0874ACE05B26337`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_completion_status.json`，3566 bytes，SHA256 `1C722900ADCC5984F394A0BF2B650AC3A0B576ED9A9FD841A9EF13BF2F1E55C5`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_delivery_audit.json`，10572 bytes，SHA256 `0EB133397CD6CFF5A41E0F131B7A1CC6B7022C13B0BBB9DD8B31DBE1B3982A82`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_hardware_readiness.json`，8208 bytes，SHA256 `9354C040943B209FF2D50CDABD87F099E34E2CC88F22483E71D3F3C0DF29C1BB`

### AI 模型、训练和量化

状态：`PASS`

- `PASS` `docs/model_design.md`，1866 bytes，SHA256 `21B7163453E5588556C97FFE035FFEF88FC91720F927A206CD07A5BF9C3D73A1`
- `PASS` `docs/training_quantization.md`，2228 bytes，SHA256 `76CC65D423D7AAE83EC0486D12F7E0B51DAC2CB431F072D2ACB23590830E67DA`
- `PASS` `train/span_model.py`，3870 bytes，SHA256 `034353C807431D883D65D6C002B7C91A7D34CDC8127232F0C4E1F245EBF7302C`
- `PASS` `train/distill_tinyspan_video.py`，18318 bytes，SHA256 `FC1BFAF8CAE4A6511DB2F9C8D505D5F47BFAC10BE1D08009653E6252E015B187`
- `PASS` `configs/distill_tinyspan_video_x2_c32_b4.json`，3128 bytes，SHA256 `EDEF41ED2C4634AB25D51A5D4A185BCF42D07675FCFC1219E1F3FF1BF1B9B6D5`
- `PASS` `scripts/train_tinyspan_video_x2_c32_b4.ps1`，2254 bytes，SHA256 `E08FE2B3A344D2BA0E2AA8E608686CD68818AF41009071B7C960B12FDDA93D4F`
- `PASS` `scripts/start_tinyspan_c32b4_x2_training.ps1`，2440 bytes，SHA256 `4B378D9C4DAC6595C821144DFDF4A8CA0E822CCCA0F376B815E0CD81CF9A17B8`
- `PASS` `scripts/run_tinyspan_c32b4_post_training_prep.ps1`，7511 bytes，SHA256 `26A285D0E0D235AF7762D14FFFFD714FB0ADAD1BD880D06E3B2141A2C4E32140`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`，14483 bytes，SHA256 `3ADAADB344053C0D9AB6DB109B875F599AAD5A3964B63891E90F2B86E8D66358`
- `PASS` `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py`，19055 bytes，SHA256 `0652BC0A22FE45230009C9B923BA77A25B21BD1493FA732321A91FAF2F121A52`

### 硬件设计与模型到 RTL 转换

状态：`PASS`

- `PASS` `docs/hardware_design.md`，5321 bytes，SHA256 `41E60E7F9077F501C131BF9DE7DAE6C642AB37F673453A10E79FD094BD11A8CF`
- `PASS` `rtl/tinyspan_core`，8 files，55763 bytes
- `PASS` `rtl/board_wrapper`，10 files，96604 bytes
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py`，10636 bytes，SHA256 `8CEFA6FAF2A059EEF2E9E7F7FF99E5DCF2D5FDB6CE970228764DA0850CF6243E`
- `PASS` `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl`，10078 bytes，SHA256 `10B9D844359430FEB96845C107A6910E12AEC1D4D8D667651D3DF0951A8773E3`
- `PASS` `scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1`，4404 bytes，SHA256 `AF615F66DB2F95938E31614D29C6E828EF8EE96D02F3E444ED001C2507B04632`

### 验证方案与 PPA

状态：`PASS`

- `PASS` `docs/verification_plan.md`，8624 bytes，SHA256 `324E90DD820ED923DD664007FBB767057E2CA62A11AFD822AB1F9A28CFA3E7D4`
- `PASS` `docs/ppa_analysis.md`，5666 bytes，SHA256 `FB98885028C750BB07EDE8336A82CA7D4D2CEC7C21B30512664D380C47C4C1E0`
- `PASS` `docs/x4_board_result_report_20260625.md`，4486 bytes，SHA256 `427D0C29BBEBE12B7D8A5D1A04C81649B791C114FD4A8FB418E5232FB891F3C9`
- `PASS` `docs/x4_quality_improvement_plan.md`，3531 bytes，SHA256 `54302D2717DCC2612ABF65274DBDBC460253FEA4DB87C4669EF3B9A16F880433`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`，4540 bytes，SHA256 `B4FC62FE70A103DA79C4857DC5A6010D59A928C289C1398537C9FEC569B8EA7C`
- `PASS` `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`，3429 bytes，SHA256 `1B793ECD6597A4DEA401AC9457AE686694E6870AA9E94FE835936DDEABACD910`

### X4 Gate H 已闭合证据

状态：`PASS`

- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`，3270 bytes，SHA256 `E58F651C3D5045F3BB8342A4CED6ED17C7F4FC3D172A1A8578406880FE367F9E`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png`，1066005 bytes，SHA256 `A1CEC8945B9231B95B0D8F78CFD9D65F0E862937E2292A3E60856C144F5A4074`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png`，139063 bytes，SHA256 `A53E1FE3F045327B1EBEB6E0717936EBE4E2AEB882A114814196A0FC5EE5E967`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png`，77108 bytes，SHA256 `8845F0B3CECDA6871AE1F7A98D704060CDDE4EDE06FC5500E37F87B9337AD668`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/tinyspan_tiled_fixed_reference_summary.json`，3400 bytes，SHA256 `D09912E23C3F21465359510946008554BCA31100B0B50F249C48A9482592A84A`

## 边界说明

- 本索引只证明当前已归档证据的存在性和哈希，不会启动 Vivado/JTAG/板卡/训练流程。
- X4 子任务已具备完整 720p30 板上吞吐和 board-vs-fixed 一致性证据。
- 整赛题仍需 X2 独立冻结、量化、RTL、bitstream、真实板上输出和 >=30fps 证据后才能宣告完成。
