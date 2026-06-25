# TinySPAN X2 Post-Training Queue

Date: `2026-06-25`

## Current State

- Route: TinySPAN X2 independent delivery evidence.
- Original training run retained as recovery source: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal`
- Active quality-resume training run: `G:\UESTC\feitengspan1\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal_quality_resume_20260625`
- Watcher tag: `x2_quality_resume_20260625`
- Target steps: `51480`
- Latest observation after resume: step `1793`, epoch `1`, training process count `2`.
- Training is still running, so no freeze, Vivado, JTAG, XSCT, or board flow has been started from this queue.

## Dry-Run Verified Commands

Watcher dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\watch_tinyspan_x2_training_then_postprep.ps1 `
  -RunDir ..\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal_quality_resume_20260625 `
  -Tag x2_quality_resume_20260625 `
  -TotalSteps 51480 `
  -PollSeconds 3600 `
  -WaitSeconds 172800 `
  -DryRun
```

Expected watcher behavior:

- Wait until latest metric step is at least `51480`.
- Require training process count to remain `0` for the configured stopped-poll window.
- Fail if training exits before target steps.
- Then run post-training prep.

Post-training prep dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 `
  -RunDir ..\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal_quality_resume_20260625 `
  -Scale 2 `
  -Tag x2_quality_resume_20260625 `
  -DryRun
```

Expected post-training prep outputs after real completion:

```text
runs\tinyspan_frozen_candidates\x2_quality_resume_20260625\student_final.pt
runs\tinyspan_realtime_handoff\c32b4_x2_quality_resume_20260625_summary.json
runs\tinyspan_quant_plan\x2_quality_resume_20260625_x2_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json
rtl\generated\tinyspan_c32b4_x2_quality_resume_20260625_x2_w8a8\tinyspan_w8a8_rtl_manifest.json
artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x2_640x360_tile64x64_x2_quality_resume_20260625
board_runs\tinyspan_board_acceptance\readiness_x2_quality_resume_20260625_x2
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
