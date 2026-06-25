# TinySPAN 赛题交付索引

生成时间：`2026-06-25T11:25:25`
索引生成前提交：`c9807764d97004e4c555a33d195f02160ced1b71`
总体状态：`NOT_COMPLETE`

本索引只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。

## 当前结论

- X4 子任务：`PASS_X4`，fps `30.409639424076744`，mismatch `0/2764800`。
- X2 训练：`training_running`，epoch `30`，step `118786/198000`，progress `59.9929%`。
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

- `PASS` `README.md`，2353 bytes，SHA256 `3EFC47BA4BCC3C8E85159A43F724FE825BD867BE06FF3ADCA7FE83145793CAEA`
- `PASS` `WORKFLOW.md`，43281 bytes，SHA256 `883AF4F15AC2D455530ACE259D95CA2AEB358DD485FE7529F3DF75A01FC3E0AF`
- `PASS` `docs/gate_status.md`，3188 bytes，SHA256 `A0F12642E60202307CD46B6CE3FCE321E024AD68266020C925F4124B24E4CF9F`
- `PASS` `docs/contest_delivery_audit.md`，5981 bytes，SHA256 `80943B506CC1EA72C598B5B1A06C9E901FCA5595891AEA2969B053234609338B`
- `PASS` `docs/x2_hardware_readiness.md`，2558 bytes，SHA256 `84091819E1C7DCBDB5F64B3B64AAF75484B1FAE4160B5DA0D8C39D3FEA4BF003`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_completion_status.json`，3566 bytes，SHA256 `5D7EFD9938C85A8BF27E2A25E71D399982E6545C5078022EBBF15C68E096797C`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_delivery_audit.json`，10572 bytes，SHA256 `DBBB035549BEA2DD8EB86F2CBCD94840418DCC056012104CA89AFD65071BC680`
- `PASS` `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_hardware_readiness.json`，3498 bytes，SHA256 `D42E50E03D020446F71A007B10D6DFB5DD56166C56923C46D8A3A8BC8BEDC427`

### AI 模型、训练和量化

状态：`PASS`

- `PASS` `docs/model_design.md`，1866 bytes，SHA256 `21B7163453E5588556C97FFE035FFEF88FC91720F927A206CD07A5BF9C3D73A1`
- `PASS` `docs/training_quantization.md`，2228 bytes，SHA256 `76CC65D423D7AAE83EC0486D12F7E0B51DAC2CB431F072D2ACB23590830E67DA`
- `PASS` `train/span_model.py`，3870 bytes，SHA256 `034353C807431D883D65D6C002B7C91A7D34CDC8127232F0C4E1F245EBF7302C`
- `PASS` `train/distill_tinyspan_video.py`，18318 bytes，SHA256 `FC1BFAF8CAE4A6511DB2F9C8D505D5F47BFAC10BE1D08009653E6252E015B187`
- `PASS` `configs/distill_tinyspan_video_x2_c32_b4.json`，3128 bytes，SHA256 `EDEF41ED2C4634AB25D51A5D4A185BCF42D07675FCFC1219E1F3FF1BF1B9B6D5`
- `PASS` `scripts/train_tinyspan_video_x2_c32_b4.ps1`，2254 bytes，SHA256 `E08FE2B3A344D2BA0E2AA8E608686CD68818AF41009071B7C960B12FDDA93D4F`
- `PASS` `scripts/start_tinyspan_c32b4_x2_training.ps1`，2440 bytes，SHA256 `4B378D9C4DAC6595C821144DFDF4A8CA0E822CCCA0F376B815E0CD81CF9A17B8`
- `PASS` `scripts/run_tinyspan_c32b4_post_training_prep.ps1`，5499 bytes，SHA256 `ADB34740499951980CB93017E8F2C5C14DB576C4CF73892DD354EFAE19244F97`
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`，14483 bytes，SHA256 `3ADAADB344053C0D9AB6DB109B875F599AAD5A3964B63891E90F2B86E8D66358`
- `PASS` `tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py`，19055 bytes，SHA256 `0652BC0A22FE45230009C9B923BA77A25B21BD1493FA732321A91FAF2F121A52`

### 硬件设计与模型到 RTL 转换

状态：`PASS`

- `PASS` `docs/hardware_design.md`，5321 bytes，SHA256 `41E60E7F9077F501C131BF9DE7DAE6C642AB37F673453A10E79FD094BD11A8CF`
- `PASS` `rtl/tinyspan_core`，8 files，55763 bytes
- `PASS` `rtl/board_wrapper`，10 files，96604 bytes
- `PASS` `tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py`，10636 bytes，SHA256 `8CEFA6FAF2A059EEF2E9E7F7FF99E5DCF2D5FDB6CE970228764DA0850CF6243E`
- `PASS` `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl`，10078 bytes，SHA256 `10B9D844359430FEB96845C107A6910E12AEC1D4D8D667651D3DF0951A8773E3`
- `PASS` `scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1`，3507 bytes，SHA256 `5E5677F33CC2066CA6591F8BD6AF7699F663BEC08AD6AB68A109E930C6D2806A`

### 验证方案与 PPA

状态：`PASS`

- `PASS` `docs/verification_plan.md`，7033 bytes，SHA256 `995B065632A195B4D6C32DA2B5DE3670CD0EF771F82EC03C7A85741EFF9A20A9`
- `PASS` `docs/ppa_analysis.md`，4287 bytes，SHA256 `21BAAFCDCA899A30644700B6DCFC73902EF418E366BAD97EA048DEDE97EFB947`
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
