# TinySPAN Fixed-Point Reference

This directory mirrors the TinySPAN W8A8 fixed-point software reference tools
used by the board-acceptance workflow.

Current live execution is still from the main workspace:

```powershell
G:\UESTC\feitengspan1\scripts\run_tinyspan_w8a8_integer_reference.ps1
```

The mirrored Python tools are archived here so the GitHub handoff contains the
software reference logic used to create `software_fixed_point_sr.png` /
`integer_w8a8_tinyspan.png` evidence.

For X4, `run_tinyspan_w8a8_integer_reference.py` generates the bicubic base
branch with the same Q14 integer coefficients, rounding, clamping and RGB888
source semantics as the RTL `span_tinyspan_w8a8_bicubic_base_x4_streamed`
modules. That output is the byte-exact board-comparison reference.

PyTorch/float TinySPAN output is kept as a visual-quality reference only. It is
not the byte-exact hardware gate.
