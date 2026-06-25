# TinySPAN X2 Post-Training Queue

Date: `2026-06-25`

## Current State

- Route: TinySPAN X2 independent delivery evidence.
- Original training run retained as recovery source: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal`
- Local training policy: no training on the local PC after the latest workflow decision.
- Cloud quality-resume run after X4 package: `/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625`
- Local original `student_latest.pt` is only used as the cloud X2 resume checkpoint source.
- Cloud watcher: `scripts/cloud/watch_x4_package_then_start_x2_training.py`
- Watcher tag after freeze: `x2_quality_after_x4_20260625`
- Target steps: `51480`
- Local X2 resume training was stopped before completion per the no-local-training decision.
- X2 training should start only after the X4 cloud candidate package manifest exists.
- No freeze, Vivado, JTAG, XSCT, or board flow has been started from this queue.

## Dry-Run Verified Commands

Cloud X2 auto-start watcher:

```powershell
$env:SEETA_PASS = "<ssh-password>"
python scripts\cloud\watch_x4_package_then_start_x2_training.py `
  --host connect.westc.seetacloud.com `
  --port 48335 `
  --user root `
  --x4-artifact-dir artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_candidates/x4_quality_hr060_edge006_20260625 `
  --x2-run-dir runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625 `
  --local-resume-checkpoint ..\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal\student_latest.pt `
  --poll-seconds 600 `
  --wait-seconds 172800
Remove-Item Env:\SEETA_PASS -ErrorAction SilentlyContinue
```

Expected watcher behavior:

- Wait until the X4 cloud quality candidate package `manifest.json` exists.
- Upload the local X2 resume checkpoint to the cloud if the remote resume checkpoint is missing.
- Start cloud X2 training with `scale=2`, `channels=32`, `num_blocks=4`, `epochs=13`, `max_pairs=24000`.
- Exit after confirming the cloud X2 process has been launched.

Post-training prep dry-run after the cloud X2 run is copied/mirrored back locally:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 `
  -RunDir ..\runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625 `
  -Scale 2 `
  -Tag x2_quality_after_x4_20260625 `
  -DryRun
```

Expected post-training prep outputs after real completion:

```text
runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt
runs\tinyspan_realtime_handoff\c32b4_x2_quality_after_x4_20260625_summary.json
runs\tinyspan_quant_plan\x2_quality_after_x4_20260625_x2_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json
rtl\generated\tinyspan_c32b4_x2_quality_after_x4_20260625_x2_w8a8\tinyspan_w8a8_rtl_manifest.json
artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_after_x4_20260625
board_runs\tinyspan_board_acceptance\readiness_x2_quality_after_x4_20260625_x2
```

## Gate Order After Training

1. Freeze the completed X2 checkpoint and run TinySPAN handoff.
2. Export X2 W8A8 quant plan.
3. Export X2 RTL constants/manifest.
4. Generate X2 `640x360 -> 1280x720` hardware-tiled fixed reference with `64x64` LR tiles.
   The reference command may use a REDS HR PNG as the source image, but `make_tinyspan_tiled_fixed_reference.py`
   explicitly resizes it to the declared LR input size `640x360` before TinySPAN inference.
5. Run readiness precheck. Incomplete bitstream/board evidence is non-fatal at this stage.
6. Only after the above exists, start X2 Vivado bitstream and board acceptance.
7. Package the passing board acceptance into Gate H manifest with `package_tinyspan_gate_h_board_acceptance.py`.

## Boundary

This queue record is source/artifact preparation only. It does not claim X2 completion. X2 Gate H remains incomplete until the same frozen checkpoint and quant plan produce a real bitstream, real board output, board-vs-fixed byte equality, image preview evidence, and measured `>=30fps`.
