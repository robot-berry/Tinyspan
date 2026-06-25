#!/usr/bin/env bash
set -euo pipefail

# Linux/cloud entry for the X4 quality candidate. It keeps the c32/b4 hardware
# topology unchanged and only fine-tunes the training objective.

TRAIN_FRAMES="${TRAIN_FRAMES:-/data/REDS/train_sharp}"
OUTPUT="${OUTPUT:-runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625}"
RESUME_STUDENT="${RESUME_STUDENT:-model/checkpoints/c32b4_30fps_frozen_20260613/student_30fps_candidate.pt}"
PATCH_SIZE="${PATCH_SIZE:-192}"
BATCH_SIZE="${BATCH_SIZE:-6}"
EPOCHS="${EPOCHS:-20}"
MAX_PAIRS="${MAX_PAIRS:-24000}"
MAX_STEPS="${MAX_STEPS:-0}"
SAVE_EVERY_STEPS="${SAVE_EVERY_STEPS:-500}"
LR="${LR:-0.00005}"
DISTILL_WEIGHT="${DISTILL_WEIGHT:-0.7}"
HR_WEIGHT="${HR_WEIGHT:-0.6}"
EDGE_WEIGHT="${EDGE_WEIGHT:-0.06}"
TEMPORAL_WEIGHT="${TEMPORAL_WEIGHT:-0.2}"
NUM_WORKERS="${NUM_WORKERS:-4}"
SEED="${SEED:-42}"
NO_AMP="${NO_AMP:-0}"
PYTHON_BIN="${PYTHON_BIN:-python}"

if [[ ! -d "$TRAIN_FRAMES" ]]; then
  echo "TRAIN_FRAMES not found: $TRAIN_FRAMES" >&2
  echo "Set TRAIN_FRAMES=/path/to/REDS/train_sharp or mount REDS at /data/REDS." >&2
  exit 1
fi

if [[ ! -f "$RESUME_STUDENT" ]]; then
  echo "RESUME_STUDENT checkpoint not found: $RESUME_STUDENT" >&2
  exit 1
fi

"$PYTHON_BIN" - <<'PY'
import torch
print("TORCH_VERSION=" + torch.__version__)
print("TORCH_CUDA=" + str(torch.version.cuda))
print("CUDA_AVAILABLE=" + str(torch.cuda.is_available()))
if torch.cuda.is_available():
    print("CUDA_DEVICE=" + torch.cuda.get_device_name(0))
PY

mkdir -p "$OUTPUT"

cmd=(
  "$PYTHON_BIN" -u train/distill_tinyspan_video.py
  --train-frames "$TRAIN_FRAMES"
  --scale 4
  --channels 32
  --num-blocks 4
  --patch-size "$PATCH_SIZE"
  --batch-size "$BATCH_SIZE"
  --epochs "$EPOCHS"
  --max-steps "$MAX_STEPS"
  --max-pairs "$MAX_PAIRS"
  --save-every-steps "$SAVE_EVERY_STEPS"
  --lr "$LR"
  --distill-weight "$DISTILL_WEIGHT"
  --hr-weight "$HR_WEIGHT"
  --edge-weight "$EDGE_WEIGHT"
  --temporal-weight "$TEMPORAL_WEIGHT"
  --num-workers "$NUM_WORKERS"
  --seed "$SEED"
  --resume-student "$RESUME_STUDENT"
  --output "$OUTPUT"
)

if [[ "$NO_AMP" != "1" ]]; then
  cmd+=(--amp)
fi

printf '%q ' "${cmd[@]}" > "$OUTPUT/train_command_linux.txt"
printf '\n' >> "$OUTPUT/train_command_linux.txt"

echo "TINYSPAN_X4_QUALITY_OUTPUT=$OUTPUT"
echo "TINYSPAN_X4_QUALITY_COMMAND=$(cat "$OUTPUT/train_command_linux.txt")"

"${cmd[@]}" 2>&1 | tee "$OUTPUT/train_console.log"
exit "${PIPESTATUS[0]}"
