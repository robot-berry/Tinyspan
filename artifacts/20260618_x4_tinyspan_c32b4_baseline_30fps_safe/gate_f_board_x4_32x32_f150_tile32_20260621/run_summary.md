# TinySPAN X4 32x32 Board Acceptance Summary

Run：`gate_f_board_x4_32x32_f150_tile32_20260621`

目的：使用硬件安全基线 `c32b4_30fps_frozen_20260613`，验证 TinySPAN W8A8 base-equivalent X4 `32x32 -> 128x128` tile 在真实板卡上的输出正确性、吞吐和资源消耗。

## 结论

- Gate F 真实板卡 smoke：PASS
- Gate G board-vs-software 可视化/逐字节比较：PASS
- 真实板上输出：已回读，`board_output_x4_32x32_tinyspan_w8a8_base_equiv.rgb`
- 板上输出与软件参考：`0 / 49152` mismatch bytes，max channel diff `0`
- 训练/软件视图：`software_reference/pytorch_base_equiv.png`
- RTL-fixed 定点硬门限：`software_reference/rtl_base_equiv.png`
- 可查看预览：`acceptance/tinyspan_board_software_preview.png`
- 32x32 tile perf-only throughput：`1831.144098832951 fps`

## Bitstream

- Bitstream：`jfs_full_span_x4_32x32_f150m_tinyspan_w8a8_base_equiv_fast.bit`
- SHA256：`82066FFE79D61C2128C19A68E1F88FDB989294B21380B4E1546071076A1DA600`
- 时钟：`clk_pl_0` period `7.000ns`，`142.857MHz`
- Timing：WNS `0.091ns`，WHS `0.004ns`

## 资源与功耗

- Resource gate：PASS，见 `reports/resource_gate_xc7z045.json`
- CLB LUTs：`5943`
- CLB Registers：`5232`
- DSPs：`78`
- Block RAM Tile：`10.5`
- URAM：`0`
- Total On-Chip Power：`3.469W`
- Dynamic Power：`2.260W`
- Device Static Power：`1.209W`

## JTAG 证据

- JTAG input counter：`1024`
- JTAG output counter：`16384`
- JTAG error flags：`0x00000000`
- Normal run frame done：`1`
- Perf-only frame cycles：`81916`
- Perf-only frame done：`1`
- Perf-only measured fps：`1831.144098832951`

## 哈希

- Board RGB SHA256：`37A3F28A50777A0AA9A4504B02AAD764BA7AFBC6B0D8908DAA5673777FD3F55F`
- Board PNG SHA256：`0E463CBF5D9D0F325E883FD943726FEFC42E5B44F2ACA1A350D36C7C31360EA9`
- Acceptance summary JSON SHA256：`DC063B176C4B59B3E293FC69BBA98672FEE30C23E50F4126C9F19CF7772E1E17`
- Preview PNG SHA256：`BA3C7C4D3FD179F4FB19B11A7439CFE1A3A385C90F5FF5E1B5A86FD3888C9971`

## 边界

本证据包只证明 `32x32` LR tile 的真实板卡输出与同一 TinySPAN 软件参考逐字节一致，并且该 tile 模式吞吐超过 `30fps`。最终赛题路线仍必须继续完成 SD/DDR 完整 LR 帧的板端 tile scheduler、halo/边界处理、tile 裁剪拼接、完整帧输出，以及 X2 独立证据包。
