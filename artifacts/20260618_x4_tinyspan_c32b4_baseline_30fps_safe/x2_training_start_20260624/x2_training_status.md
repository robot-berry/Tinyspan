# TinySPAN X2 Training Status

Status: `training_running`

This is not final X2 acceptance evidence. It records that the independent TinySPAN X2 route is running.

## Smoke

- Result: `PASS`
- Latest step: `2`
- Latest student PSNR: `25.689696`

## Formal Training

- Result: `RUNNING`
- Student: `TinySPAN X2 c32 b4`
- Teacher: `official SPAN X2`
- Teacher checkpoint SHA256: `E39A5FD89380CFABB01DAE44A487156030C3FA941C596A1CB5CDB36C3435D20C`
- Output: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal`
- Latest observed: epoch `1`, step `1568/198000`, speed `1.5026 step/s`, ETA `01.12:18:48`
- Recent error hints: `none`
- Processes: launcher PID `27940`, python PID `34236`

## Boundary

The X2 gate remains incomplete until a frozen X2 TinySPAN checkpoint, X2 W8A8 quant plan, X2 RTL simulation, X2 bitstream, real X2 board output, byte-exact comparison, and measured `>=30fps` are all available.
