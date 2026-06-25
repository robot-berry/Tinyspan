# TinySPAN X4 Quality Training Server Plan

Date: `2026-06-25`

## Recommended Rental Configuration

Use the rental page configuration as follows:

- GPU count: `1`
- GPU: `RTX 4090D 24GB` or `RTX 4090 24GB`
- CPU: `16 cores` is enough.
- RAM: `62GB` is enough.
- System disk: `30GB` is acceptable for the image and environment.
- Data disk: expand from `50GB` to at least `150GB`; `200GB` is recommended for REDS plus checkpoints, logs, previews, and temporary files.
- Image: choose a PyTorch image with `Python 3.10` and `CUDA 12.1` or `CUDA 12.4`.

Do not choose a bare CUDA-only image unless PyTorch is installed manually. The host driver can support CUDA 13.x, but the training environment should use a PyTorch-supported CUDA runtime.

## First Candidate

The first X4 quality candidate keeps the board-safe hardware topology unchanged:

```text
scale = 4
channels = 32
num_blocks = 4
resume checkpoint = model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt
```

It changes only the training objective:

```text
learning_rate = 0.00005
distill_weight = 0.7
hr_weight = 0.6
edge_weight = 0.06
temporal_weight = 0.2
```

This makes the model care more about REDS HR reconstruction and edge detail while still keeping teacher distillation and temporal stability.

## Start Command

After the Tinyspan repo and REDS data are available on the server:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start_tinyspan_c32b4_x4_quality_training.ps1 `
  -TrainFrames G:\REDS\train_sharp
```

If the server uses Linux paths, run the Python command directly:

```bash
python train/distill_tinyspan_video.py \
  --train-frames /data/REDS/train_sharp \
  --scale 4 \
  --channels 32 \
  --num-blocks 4 \
  --patch-size 192 \
  --batch-size 6 \
  --epochs 20 \
  --max-pairs 24000 \
  --save-every-steps 500 \
  --lr 0.00005 \
  --distill-weight 0.7 \
  --hr-weight 0.6 \
  --edge-weight 0.06 \
  --temporal-weight 0.2 \
  --num-workers 4 \
  --resume-student model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt \
  --output runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625 \
  --amp
```

## Cost Control

Start with this one candidate instead of training a larger model. A single RTX 4090D should be the lowest-cost fast option for this TinySPAN c32/b4 fine-tune. A100/H100 is not the first choice unless multiple candidates need to run in parallel.

## Replacement Gate

This candidate must not replace `X4_SUBMIT_20260625_CURRENT_BASELINE` until all of these are true:

1. REDS val multi-image PSNR/SSIM improves over the current X4 safe baseline and bicubic baseline.
2. If the report claims `30dB`, it is a multi-image REDS val average using the same HR reference path.
3. New W8A8 quant plan comes from this candidate checkpoint.
4. New hardware-tiled fixed reference comes from the same candidate checkpoint and quant plan.
5. RTL/export drift check passes.
6. Bitstream timing/resource/power passes.
7. Real board output is byte-exact against the new fixed reference.
8. Full-frame throughput remains `>=30fps`.
