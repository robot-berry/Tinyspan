# TinySPAN X4 Gate H 板上验收证据

状态：`PASS_X4`

这份 artifact 固化 X4 `320x180 -> 1280x720` 整帧切块上板证据，原始运行文件保留在本地
`board_runs`，仓库中只提交可审计的精简 manifest 和报告索引。

## 结论

- 吞吐：`30.409639424076744 fps @155MHz`
- 正确性：A53 在 PS DDR 中比较完整 `1280x720` SR 帧，`0 / 2764800` 字节 mismatch
- tile：`64x64` LR tile，共 `15` 个 tile
- bitstream SHA256：`A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232`
- DDR 路线：直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC 和标准 AXI 互联
- 自研 DDR controller/PHY：`无`

## 证据来源

- 吞吐 run：`board_runs/tinyspan_ps_ddr_x4_smoke/x4_320x180_tile64_fifo_f155_skipread_20260625_0412`
- 正确性 run：`board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`
- 固定点参考图：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png`
- 报告：`sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`
- 报告：`sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`

## 边界

这只关闭 X4 Gate H。赛题完整交付仍需要 X2 独立冻结、量化、RTL、bitstream、真实板上输出和
`>=30fps` 证据。
