# TinySPAN X2 Training Start

Status: `training_running`

This is not final X2 acceptance evidence. It records that the independent TinySPAN X2 route has started.

## Smoke

- Result: `PASS`
- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\train_tinyspan_video_x2_c32_b4.ps1 -TrainFrames .\external\SPAN\test_scripts\data\baboon.png -Smoke -MaxSteps 2`
- Output: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_reds_smoke_x2_c32_b4`
- Checkpoint: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_reds_smoke_x2_c32_b4\student_last.pt`
- Preview: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_reds_smoke_x2_c32_b4\video_distill_preview.png`
- Latest step: `2`
- Latest student PSNR: `25.689696`

## Formal Training

- Result: `RUNNING`
- Started at: `2026-06-24T15:54:01+08:00`
- Student: `TinySPAN X2 c32 b4`
- Teacher: `official SPAN X2`
- Teacher checkpoint SHA256: `E39A5FD89380CFABB01DAE44A487156030C3FA941C596A1CB5CDB36C3435D20C`
- Output: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal`
- Metrics: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal\metrics.csv`
- Latest observed: epoch `1`, step `217`, speed `1.3944 step/s`
- Recent error hints: `none`

## Boundary

The X2 gate remains incomplete until a frozen X2 TinySPAN checkpoint, X2 W8A8 quant plan, X2 RTL simulation, X2 bitstream, real X2 board output, byte-exact comparison, and measured `>=30fps` are all available.
