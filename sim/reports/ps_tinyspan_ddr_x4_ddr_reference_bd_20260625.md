# TinySPAN PS/DDR X4 BD DDR Reference Config Report

日期：2026-06-25

## 结论

TinySPAN PS/DDR X4 Block Design 已改为默认应用 FACE-ZUSSD 参考工程中的 PS DDR 配置。
该路线继续直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR 控制器、DDR PHY 或板级 DDR 时序逻辑。

## 修改点

- 脚本：`scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl`
- 默认参考配置：`G:\UESTC\feitengspan1\docs\reference_face_zussd\zcu106_hpc0_dual_bd.tcl`
- 抽取并应用的属性范围：
  - `CONFIG.PSU__DDRC__*`
  - `CONFIG.PSU__DDR*`
  - `CONFIG.PSU__CRF_APB__DDR*`
  - `CONFIG.PSU__USE__DDR*`
  - `CONFIG.SUBPRESET1`
- 可覆盖环境变量：
  - `PS_TINYSPAN_DDR_X4_PS_REF_BD_TCL`
  - `PS_TINYSPAN_DDR_X4_APPLY_PS_REF_DDR=0`

## 验证

临时 Vivado BD 创建验证已通过：

```text
ProjectDir: G:\UESTC\feitengspan1\Tinyspan\vivado\ps_tinyspan_ddr_x4_ddrref_check
Log:        G:\UESTC\feitengspan1\Tinyspan\build\ps_tinyspan_ddr_x4_bd_vivado.log
Result:     PASS run_vivado_create_ps_tinyspan_ddr_x4_bd
```

关键日志：

```text
PS_TINYSPAN_DDR_X4_DDR_REF_STATUS=applied
PS_TINYSPAN_DDR_X4_DDR_REF_TCL=G:/UESTC/feitengspan1/docs/reference_face_zussd/zcu106_hpc0_dual_bd.tcl
PS_TINYSPAN_DDR_X4_DDR_REF_PROPERTY_PAIRS=109
PASS create_vivado_ps_tinyspan_ddr_x4_bd_project
```

## 当前风险

旧 TinySPAN PS/DDR bitstream 的 32x32 X4 board smoke 仍存在 board-vs-fixed mismatch。
A53 baremetal DDR alias probe 已证明旧 PS DDR 配置存在真实地址别名：以 `0x4000` 为间隔写入 DDR 时，
读回呈现 `[1,1,3,3,5,5,7,7]` 型覆盖。该现象与板上图片 32 行重复/错位一致。

因此，本报告只证明 BD 创建阶段已正确应用参考 DDR 配置，不代表真实板上 DDR alias 已修复。

## 下一步门禁

1. 用参考 PS DDR 配置重建 TinySPAN PS/DDR X4 bitstream。
2. 下载新 bitstream 后先运行 A53 DDR alias probe。
3. 只有 alias probe 通过后，才继续 TinySPAN X4 `32x32 -> 128x128` board-vs-fixed smoke。
4. board-vs-fixed 逐字节一致后，再推进完整帧 `320x180 -> 1280x720` 板端切块与 `>=30fps` 验收。
