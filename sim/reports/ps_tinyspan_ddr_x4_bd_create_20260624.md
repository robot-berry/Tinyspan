# TinySPAN PS/DDR X4 Block Design Creation

Date: 2026-06-24

## Target

`pstinyspanx4ddr`

## Purpose

Create and validate a Vivado Block Design that uses the board ZynqMP PS DDR
controller IP for TinySPAN full-frame DDR I/O. This does not implement a custom
DDR controller or PHY.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vivado\run_vivado_create_ps_tinyspan_ddr_x4_bd.ps1 -RequireVivadoIdle
```

## Result

```text
PASS create_vivado_ps_tinyspan_ddr_x4_bd_project
PASS run_vivado_create_ps_tinyspan_ddr_x4_bd
```

## Key Connections

```text
PS M_AXI_HPM0_FPD -> AXI interconnect -> sr0/s_axi
sr0/m_axi -> AXI interconnect -> PS S_AXI_HP0_FPD
PS pl_clk0 -> endpoint and interconnect clocks
PS pl_resetn0 -> proc_sys_reset -> endpoint and interconnect resets
```

## Address Map

```text
TinySPAN control base: 0xA0000000
Input frame DDR base: 0x10000000
Output frame DDR base: 0x11000000
Image: 320x180 LR -> 1280x720 HR
Tile: 32x32 LR
PL clock target: 150 MHz
```

## DDR Policy

```text
Use ZynqMP PS DDR controller IP; no custom DDR controller or PHY.
```

## Log

```text
G:\UESTC\feitengspan1\Tinyspan\build\ps_tinyspan_ddr_x4_bd_vivado.log
```

## Notes

- This is a BD creation/validation step only.
- It does not run synthesis, implementation, bitstream generation, or board I/O.
- Warnings about AXI USER width adaptation are expected from the interconnect
  and PS interfaces in this draft BD.
