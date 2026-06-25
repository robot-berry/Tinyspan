# TinySPAN X4 Quality Candidate Package

- candidate: `x4_quality_hr060_edge006_20260625`
- status: `INCOMPLETE_OR_REJECTED`
- scale: `X4`
- generated at: `2026-06-25T20:40:28`
- checkpoint SHA256: ``
- image count: `3000`
- student PSNR mean: `26.384690521945394`
- bicubic PSNR mean: `26.274462962942643`
- PSNR gain over bicubic: `0.11022755900275172`
- meets exploratory gate: `False`
- meets 30dB stretch gate: `False`

## Copied Evidence

- `metrics.csv`: `B027979AF5204CA129B2FC384DCF4C88DD8A7E28DC56FDD57C60DA9F7E29757C` (8181502 bytes)
- `args.json`: `1C9A550AAA3BE2B755C21F56238DBA36EDAC42BCDE9F692D4A43C0996117A173` (658 bytes)
- `train_command_linux.txt`: `51B53A2E40AC5F7416A0EF14218E293FDE274345DC24795E7620945E524C5148` (526 bytes)
- `video_distill_preview.png`: `FC73C86CA72E61B7DAC4CF477AD82F560AF238EA899C56F22339E92F8E674F2F` (232348 bytes)
- `video_distill_latest_preview.png`: `FC73C86CA72E61B7DAC4CF477AD82F560AF238EA899C56F22339E92F8E674F2F` (232348 bytes)
- `tinyspan_checkpoint_reds_hr_quality.json`: `5AD814F9100B9CC1435303BB94D9B976BA0B551F5A17A0035B98EC75834E0AA9` (4010309 bytes)
- `tinyspan_checkpoint_reds_hr_quality.md`: `E6679DD939CE0D0D0491E76D323B4EFF10EDEA11908A4E86BF47CAA02953D200` (876 bytes)
- `tinyspan_checkpoint_reds_hr_quality.csv`: `A6D957C983FA24F6EC073D2C8FD9DBE9A78645D134F2B7CFA31CF71CCE368B35` (359011 bytes)
- `tinyspan_checkpoint_reds_hr_quality_preview.png`: `E2A5783D2DE63FC31EFB6094F9500471EEFD740781EC671C6E2E1587ED72BC43` (487123 bytes)

## Missing Required Evidence

- `/root/autodl-tmp/Tinyspan`

## Boundary

- This package is only an X4 software quality candidate gate.
- It does not replace an accepted hardware submission baseline by itself.
- Replacing or accepting the X4 baseline still requires matching quantization, RTL/export checks, bitstream, real board-vs-fixed equality, and >=30fps evidence.
- This script is file-only and does not start training, Vivado, JTAG, XSCT, board access, quantization, or RTL export.
