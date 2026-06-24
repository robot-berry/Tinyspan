# TinySPAN DDR X4 Endpoint RTL Elaboration

Date: 2026-06-24

## Target

`sr_ddr_tinyspan_x4_tile_writer_endpoint`

## Purpose

Validate that the new TinySPAN DDR/PS endpoint can elaborate with the existing
TinySPAN tile shell, DDR pixel AXI master, and TinySPAN W8A8/base-equiv core.
This is a lightweight RTL elaboration check only; it does not run placement,
routing, bitstream generation, board programming, or board-vs-software image
validation.

## Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\vivado\run_vivado_check_sr_ddr_tinyspan_x4_endpoint.ps1 -RequireVivadoIdle
```

## Result

```text
PASS sr_ddr_tinyspan_x4_tile_writer_endpoint rtl_elaboration
PASS run_vivado_check_sr_ddr_tinyspan_x4_endpoint
0 Critical Warnings
0 Errors
```

## Log

```text
G:\UESTC\feitengspan1\Tinyspan\build\ddr_ttx4_elab_vivado.log
```

## Notes

- The endpoint exposes AXI-Lite control/status registers to PS.
- The endpoint connects `sr_tile_tinyspan_x4_writer_shell` to
  `sr_ddr_pixel_axi_master`.
- The first DDR bridge is single-pixel AXI4 access, intended to establish the
  correct DDR functional path before replacing it with AXI burst or AXI DMA for
  final throughput.
- This check does not prove full-frame DDR I/O performance or image equality.
