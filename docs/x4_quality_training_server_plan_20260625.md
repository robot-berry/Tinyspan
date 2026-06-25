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

```bash
TRAIN_FRAMES=/data/REDS/train_sharp bash scripts/start_tinyspan_c32b4_x4_quality_training.sh
```

Current rented server layout:

```text
repo: /root/autodl-tmp/Tinyspan
data: /root/autodl-tmp/data/REDS
train: /root/autodl-tmp/data/REDS/train_sharp
val: /root/autodl-tmp/data/REDS/val_sharp
```

Use the resumable sync helper from the local Windows machine when the full REDS
copy is not already on the server. The SSH password must be supplied through an
environment variable, not written into the command or repository:

```powershell
$env:SEETA_PASS = "<server password>"
python scripts/cloud/sync_reds_and_start_x4_quality_training.py `
  --host connect.westc.seetacloud.com `
  --port 48335 `
  --user root `
  --local-reds-root G:/REDS `
  --remote-repo /root/autodl-tmp/Tinyspan `
  --remote-data /root/autodl-tmp/data/REDS `
  --sync-mode sequence-tar `
  --include-val `
  --start-training
Remove-Item Env:\SEETA_PASS
```

For a long unattended copy, prefer the retrying wrapper:

```powershell
$env:SEETA_PASS = "<server password>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cloud/run_x4_full_reds_sequence_tar_sync.ps1
Remove-Item Env:\SEETA_PASS
```

If single-stream upload is too slow, use the parallel range wrapper. It splits the 240 REDS train sequences
across independent workers, then runs one final full verification pass, uploads `val_sharp`, and starts training:

```powershell
$env:SEETA_PASS = "<server password>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cloud/run_x4_full_reds_parallel_sequence_tar_sync.ps1 `
  -Workers 4
Remove-Item Env:\SEETA_PASS
```

While the full `train_sharp` workers are still running, `val_sharp` can be pre-uploaded in parallel because it
uses a separate REDS split and the final full wrapper will skip already-matching remote sequences:

```powershell
$env:SEETA_PASS = "<server password>"
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/cloud/run_x4_val_reds_parallel_sequence_tar_sync.ps1 `
  -Workers 4
Remove-Item Env:\SEETA_PASS
```

This helper only syncs `val_sharp`; it does not start training by itself.

For a quick smoke test before a full run:

```bash
TRAIN_FRAMES=/data/REDS/train_sharp MAX_STEPS=20 bash scripts/start_tinyspan_c32b4_x4_quality_training.sh
```

Windows/PowerShell equivalent:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start_tinyspan_c32b4_x4_quality_training.ps1 `
  -TrainFrames G:\REDS\train_sharp
```

The Linux shell script expands to this Python command:

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

## Quality Evaluation After Training

After `student_last.pt` is written, run the REDS HR quality gate on the same server:

```bash
python tools/image_validation/evaluate_tinyspan_checkpoint_reds_hr.py \
  --checkpoint runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625/student_last.pt \
  --val-frames /data/REDS/val_sharp \
  --out-dir runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val \
  --scale 4 \
  --channels 32 \
  --num-blocks 4 \
  --max-images 16 \
  --border 4 \
  --amp
```

This writes:

```text
runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val/tinyspan_checkpoint_reds_hr_quality.json
runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val/tinyspan_checkpoint_reds_hr_quality.md
runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val/tinyspan_checkpoint_reds_hr_quality.csv
runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val/tinyspan_checkpoint_reds_hr_quality_preview.png
```

Only continue to quantization and board work if the multi-image `student_vs_hr` PSNR/SSIM improves over
`bicubic_vs_hr`. The X4 quality target is REDS val multi-image `student_vs_hr >= 28dB`; claiming an optional
`30dB` stretch result requires the same REDS HR metric, not a single-image result.

After copying the cloud run back into this repo, package the candidate evidence:

```bash
python scripts/acceptance/package_x4_quality_candidate.py \
  --candidate-id x4_quality_hr060_edge006_20260625 \
  --train-dir runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625 \
  --quality-dir runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val \
  --allow-incomplete
```

This package is only a software quality gate. It does not replace the current X4 submission baseline until the
candidate also passes quantization, RTL/export checks, bitstream generation, real board equality, and `>=30fps`.

## Current Cloud Smoke Result

The first cloud smoke used only `train_sharp/000..004` and `val_sharp/000..001` to prove that the rental
server, official X4 teacher, REDS path, AMP training, and quality evaluator all run end-to-end:

```text
GPU: NVIDIA GeForce RTX 4090 D 24GB
train subset: 500 frames
val subset: 16 evaluated images
student_vs_hr PSNR: 25.865854 dB
bicubic_vs_hr PSNR: 25.763312 dB
gain: +0.102542 dB
```

This smoke result is not a `28+dB` or `30dB` claim and does not replace `X4_SUBMIT_20260625_CURRENT_BASELINE`.
The full REDS sync/train run must finish before deciding whether this quality branch is worth exporting to
quantization and board validation.

## Cost Control

Start with this one candidate instead of training a larger model. A single RTX 4090D should be the lowest-cost fast option for this TinySPAN c32/b4 fine-tune. A100/H100 is not the first choice unless multiple candidates need to run in parallel.

## Replacement Gate

This candidate must not replace `X4_SUBMIT_20260625_CURRENT_BASELINE` until all of these are true:

1. REDS val multi-image PSNR/SSIM improves over the current X4 safe baseline and bicubic baseline.
2. If the report claims `28+dB` or `30dB`, it is a multi-image REDS val average using the same HR reference path.
3. New W8A8 quant plan comes from this candidate checkpoint.
4. New hardware-tiled fixed reference comes from the same candidate checkpoint and quant plan.
5. RTL/export drift check passes.
6. Bitstream timing/resource/power passes.
7. Real board output is byte-exact against the new fixed reference.
8. Full-frame throughput remains `>=30fps`.
