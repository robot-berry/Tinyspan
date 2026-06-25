# TinySPAN 赛题交付包校验

生成时间：`2026-06-26T06:39:19`
总体状态：`PASS`
失败 required 项数：`0`

本校验只读取现有证据，不启动 Vivado、JTAG、板卡或训练流程。

## Required Checks

| ID | 状态 | 要求 | 当前证据 | 下一步 |
| --- | --- | --- | --- | --- |
| `docs` | `PASS` | README、工作流、模型/训练/量化/硬件/验证/PPA/状态审计文档均存在 | all required docs exist | 补齐缺失文档 |
| `source_tree` | `PASS` | 模型、训练、量化、RTL、转换工具和验收脚本均存在 | all required source roots exist | 补齐缺失源码或脚本 |
| `status_artifacts` | `PASS` | contest_completion_status、contest_delivery_audit、contest_delivery_index 均存在 | completion=True, audit=True, index=True | 运行 refresh_tinyspan_delivery_status.ps1 |
| `x4_gate_h` | `PASS` | X4 scale=4，1280x720，fps>=30，mismatch=0，max diff=0，同一 bitstream/quant/checkpoint | manifest=artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json, fps=30.409639424076744, mismatch=0/2764800, max_diff=0, bitstream=A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232 | 补齐 X4 Gate H manifest 或重新验收 X4 |
| `x4_images` | `PASS` | software_tiled_fixed_point_sr、comparison_preview、diff_heatmap 均存在 | software reference, preview, heatmap exist | 补生成 X4 可视化材料 |
| `x4_quality_metrics` | `PASS` | X4 student-vs-teacher、PyTorch-vs-tiled fixed 和 full-integer-vs-tiled fixed 的 PSNR/SSIM/MAE 指标存在 | metrics=artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_metrics_20260625/tinyspan_x4_quality_metrics.json, pairs=['student_vs_teacher', 'pytorch_vs_tiled_fixed', 'full_integer_vs_tiled_fixed', 'pytorch_vs_full_integer'], missing=[] | 运行 tools/image_validation/evaluate_sr_quality.py 生成 X4 画质指标 |
| `x4_reds_hr_quality` | `PASS` | X4 tile64 fixed-vs-REDS HR 与 bicubic baseline-vs-REDS HR 的 PSNR/SSIM/MAE 指标存在 | metrics=artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/reds_val_quality_x4_00000000_tile64_20260625/reds_hr_quality_metrics.json, pairs=['x4_tile64_fixed_vs_reds_hr', 'bicubic_lr_vs_reds_hr'], missing=[] | 用 REDS HR 或 SD 卡 HR 展示图作为 reference 运行 evaluate_sr_quality.py |
| `x2_training_freeze` | `PASS` | X2 gate=PASS，readiness=PASS，无量化/RTL manifest 缺口 | training=artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json, gate=PASS, readiness=READY, blockers=[] | 等待 X2 训练完成并运行 post-training prep |
| `x2_gate_h` | `PASS` | X2 scale=2，1280x720，fps>=30，mismatch=0，max diff=0，同一 bitstream/quant/checkpoint | manifest=artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/manifest.json, fps=32.86048226988138, mismatch=0/2764800, missing=[] | 生成 X2 bitstream 并完成真实板上输出、board-vs-fixed 和吞吐验收 |
| `final_audit` | `PASS` | contest_delivery_audit accepted=true | accepted=True, status=PASS | X2/X4 全部闭合后重新运行交付审计 |

## 边界说明

- 该校验只读取现有证据，不启动 Vivado/JTAG/板卡/训练。
- 当前如果返回 NOT_COMPLETE，是交付状态结论，不代表脚本失败。
- 只有所有 required check 为 PASS，才可把整赛题标为可交付。
