# TinySPAN X4 320x180 Base-Equivalence Gap

Status: `FAIL`

This run compares the TinySPAN base-equivalent RTL fixed-point X4 bicubic path
against the PyTorch quantized bicubic base output for the same input frame and
the same `c32b4_30fps_frozen_20260613` quant plan.

## Result

- Input: `external\SPAN\test_scripts\data\baboon.png`
- Resized LR input: `320x180`
- Output size: `1280x720`
- Mismatch bytes: `6 / 2764800`
- Max channel difference: `2`
- `base_q31`: `2007717611`
- PyTorch quantized output: `pytorch_base_equiv.png`
- RTL fixed-point output: `rtl_base_equiv.png`
- Difference image: `diff.png`

## Mismatch Details

| y | x | channel | PyTorch RGB | RTL fixed RGB | diff | PyTorch q_base | RTL fixed q_base | PyTorch q_out | RTL fixed q_out |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 247 | 687 | 0 | 236 | 238 | -2 | 118 | 119 | 110 | 111 |
| 257 | 905 | 0 | 88 | 90 | -2 | 44 | 45 | 41 | 42 |
| 462 | 27 | 1 | 148 | 146 | 2 | 74 | 73 | 69 | 68 |
| 465 | 638 | 0 | 230 | 228 | 2 | 114 | 113 | 107 | 106 |
| 480 | 1065 | 1 | 88 | 86 | 2 | 44 | 43 | 41 | 40 |
| 598 | 1071 | 2 | 118 | 120 | -2 | 59 | 60 | 55 | 56 |

## Conclusion

The current Q14 RTL fixed-point bicubic path is internally deterministic, but it
does not match PyTorch floating bicubic byte-for-byte on every boundary
rounding point. A Q15-Q20 coefficient precision scan did not remove these six
differences because the X4 phase coefficients are already exactly represented
by Q14.

For final board acceptance, the byte-exact gate must compare real board output
against the RTL-isomorphic fixed-point software reference. PyTorch or training
floating output remains a visual/quality reference and must not be used as the
byte-exact hardware gate.

This artifact must not be reported as a TinySPAN board acceptance pass.
