# TinySPAN X4 Quality Candidate Package

- candidate: `x4_quality_after_x2_20260625`
- status: `INCOMPLETE_OR_REJECTED`
- scale: `X4`
- generated at: `2026-06-26T02:00:59`
- checkpoint SHA256: ``
- image count: `3000`
- student PSNR mean: `26.384690521945394`
- bicubic PSNR mean: `26.274462962942643`
- PSNR gain over bicubic: `0.11022755900275172`
- meets exploratory gate: `False`
- meets 30dB stretch gate: `False`

## Copied Evidence

- `metrics.csv`: `32252C6CC233009198CC57403E0A4002DD893FB20F364619F9E52877E19A891B` (8006822 bytes)
- `args.json`: `91AC98DCC1FD3641C7CE1282306FCDF8A8C6659C5A1EF40FBE5A5A84FD9D183E` (653 bytes)
- `train_command_linux.txt`: `39B2D7BCC86A0673A513522E71B43BCCFEC39D1F2AF82CFC413A522BBAB7BB26` (542 bytes)
- `video_distill_preview.png`: `FC73C86CA72E61B7DAC4CF477AD82F560AF238EA899C56F22339E92F8E674F2F` (232348 bytes)
- `video_distill_latest_preview.png`: `FC73C86CA72E61B7DAC4CF477AD82F560AF238EA899C56F22339E92F8E674F2F` (232348 bytes)
- `tinyspan_checkpoint_reds_hr_quality.json`: `318798B5950CC4410BABAD407A6F5829BB7587948961F4E36168A4461E673FDD` (2712445 bytes)
- `tinyspan_checkpoint_reds_hr_quality.md`: `ACDE8EF0C9E150767152028DBF2D5CA6CE0B95473A48A740233BB62B0536978F` (930 bytes)
- `tinyspan_checkpoint_reds_hr_quality.csv`: `A6D957C983FA24F6EC073D2C8FD9DBE9A78645D134F2B7CFA31CF71CCE368B35` (359011 bytes)
- `tinyspan_checkpoint_reds_hr_quality_preview.png`: `E2A5783D2DE63FC31EFB6094F9500471EEFD740781EC671C6E2E1587ED72BC43` (487123 bytes)

## Missing Required Evidence

- `/root/autodl-tmp/Tinyspan`

## Boundary

- This package is only an X4 software quality candidate gate.
- It does not replace an accepted hardware submission baseline by itself.
- Replacing or accepting the X4 baseline still requires matching quantization, RTL/export checks, bitstream, real board-vs-fixed equality, and >=30fps evidence.
- This script is file-only and does not start training, Vivado, JTAG, XSCT, board access, quantization, or RTL export.
