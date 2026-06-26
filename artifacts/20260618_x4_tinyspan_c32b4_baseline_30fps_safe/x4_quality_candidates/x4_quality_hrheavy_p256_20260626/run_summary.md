# TinySPAN X4 Quality Candidate Package

- candidate: `x4_quality_hrheavy_p256_20260626`
- status: `INCOMPLETE_OR_REJECTED`
- scale: `X4`
- generated at: `2026-06-26T09:54:55`
- checkpoint SHA256: `5B9D0E8D4B1A5CEB3AEDEE9AF80B23AE0D76ACE67037F6A400E7CBA4970F25F3`
- image count: `3000`
- student PSNR mean: `26.384690521945394`
- bicubic PSNR mean: `26.274462962942643`
- PSNR gain over bicubic: `0.11022755900275172`
- meets exploratory gate: `False`
- meets 30dB stretch gate: `False`

## Copied Evidence

- `student_last.pt`: `5B9D0E8D4B1A5CEB3AEDEE9AF80B23AE0D76ACE67037F6A400E7CBA4970F25F3` (2322424 bytes)
- `metrics.csv`: `F817365DBE0019EBBEC39A615AF2234687B67CA0A34CE7FD207D29F39AEB5550` (16111431 bytes)
- `args.json`: `D3B12C5594975379023A032A6E18F5716AB5BF1E3019F089D1D9034DE8861901` (666 bytes)
- `train_command_linux.txt`: `68A9816FAC8F0D91D6EC9E4D135FD242FD50F927BB2DF1E9925233BCD827DB85` (556 bytes)
- `video_distill_preview.png`: `4685E67CC3E31E98688A3CF423FB53333A3807BD89348A7EC050ED0E1681B47D` (210191 bytes)
- `video_distill_latest_preview.png`: `4685E67CC3E31E98688A3CF423FB53333A3807BD89348A7EC050ED0E1681B47D` (210191 bytes)
- `tinyspan_checkpoint_reds_hr_quality.json`: `4C1D3FB1C0A344BE5E88A483DF45C45CAEA9C46648656A26FC8F999FF39FEC49` (2706736 bytes)
- `tinyspan_checkpoint_reds_hr_quality.md`: `4C1A6584083560549916FEC51729715833F836A9876D5DD9A711BBE696679846` (932 bytes)
- `tinyspan_checkpoint_reds_hr_quality.csv`: `A6D957C983FA24F6EC073D2C8FD9DBE9A78645D134F2B7CFA31CF71CCE368B35` (359011 bytes)
- `tinyspan_checkpoint_reds_hr_quality_preview.png`: `E2A5783D2DE63FC31EFB6094F9500471EEFD740781EC671C6E2E1587ED72BC43` (487123 bytes)

## Boundary

- This package is only an X4 software quality candidate gate.
- It does not replace an accepted hardware submission baseline by itself.
- Replacing or accepting the X4 baseline still requires matching quantization, RTL/export checks, bitstream, real board-vs-fixed equality, and >=30fps evidence.
- This script is file-only and does not start training, Vivado, JTAG, XSCT, board access, quantization, or RTL export.
