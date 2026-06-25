# TinySPAN X2 Quality Candidate Package

- candidate: `x2_quality_after_x4_20260625`
- status: `PASS_SOFTWARE_QUALITY_GATE`
- scale: `X2`
- generated at: `2026-06-25T23:08:59`
- checkpoint SHA256: `B06E66FA8FEA066F111B94CF5629919BEA05D5465F913B36851CBA92BED4A9EB`
- image count: `3000`
- student PSNR mean: `31.121459919373763`
- bicubic PSNR mean: `30.853986135469682`
- PSNR gain over bicubic: `0.26747378390408016`
- meets exploratory gate: `True`
- meets 30dB stretch gate: `True`

## Copied Evidence

- `student_last.pt`: `B06E66FA8FEA066F111B94CF5629919BEA05D5465F913B36851CBA92BED4A9EB` (2156280 bytes)
- `metrics.csv`: `6193B7E7EDF2FCC9DA52210B1F9393611CB95AF46D317BEBF8F9B92867AF7DB5` (5165212 bytes)
- `args.json`: `681CAC6B33EABA8CCCFC5F8B19D0730F89CA94994D7EE64B34EB546B07CBBAB4` (644 bytes)
- `video_distill_preview.png`: `6DE2498C7B058832C4577C58600202B0F21A20CC41A634856D70BD3855A6504C` (178677 bytes)
- `video_distill_latest_preview.png`: `6DE2498C7B058832C4577C58600202B0F21A20CC41A634856D70BD3855A6504C` (178677 bytes)
- `tinyspan_checkpoint_reds_hr_quality.json`: `57D6076F69A1E1D69D781200E82FDBE240F28C2AA7C9F9A1DEE3ADA727F90B53` (2707992 bytes)
- `tinyspan_checkpoint_reds_hr_quality.md`: `F4055A79AC25E44A6E5483DBD1BAB09D3371BAE4E34DC9C632CCF6C807F040C3` (928 bytes)
- `tinyspan_checkpoint_reds_hr_quality.csv`: `625B1D0EDBCCAA35239BB6216C828FA80032DAA2B1BFAF7837751F34968E11F6` (359011 bytes)
- `tinyspan_checkpoint_reds_hr_quality_preview.png`: `E1F39DE20FFC97FF77752E31F90AD0D19E13B0CA56C3D93968BDD99EBD6A5BBB` (459332 bytes)

## Boundary

- This package is only an X2 software quality candidate gate.
- It does not replace an accepted hardware submission baseline by itself.
- Replacing or accepting the X2 baseline still requires matching quantization, RTL/export checks, bitstream, real board-vs-fixed equality, and >=30fps evidence.
- This script is file-only and does not start training, Vivado, JTAG, XSCT, board access, quantization, or RTL export.
