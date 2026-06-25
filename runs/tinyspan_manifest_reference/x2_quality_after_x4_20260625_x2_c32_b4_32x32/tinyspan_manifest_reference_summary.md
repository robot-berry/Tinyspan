# TinySPAN Manifest Reference

Input: `runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625\video_distill_latest_preview.png`
Checkpoint: `runs\tinyspan_frozen_candidates\x2_quality_after_x4_20260625\student_final.pt`
Manifest: `rtl\generated\tinyspan_x2_c32_b4_x2_quality_after_x4_20260625_fused\tinyspan_manifest.json`
Mode: `weight-ref`
Activation bits: `8`
Activation scales: `None`
Output directory: `runs\tinyspan_manifest_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32`
Preview: `runs\tinyspan_manifest_reference\x2_quality_after_x4_20260625_x2_c32_b4_32x32\tinyspan_manifest_reference_preview.png`

## Image Metrics

| Pair | mismatch bytes | max diff | MAE | PSNR |
| --- | ---: | ---: | ---: | ---: |
| `image_pytorch_vs_fused` | `0 / 12288` | `0` | `0.000000` | `inf dB` |
| `image_fused_vs_manifest` | `0 / 12288` | `0` | `0.000000` | `inf dB` |
| `image_pytorch_vs_manifest` | `0 / 12288` | `0` | `0.000000` | `inf dB` |

## Tensor Metrics

| Pair | region | values | max abs | MAE | PSNR |
| --- | --- | ---: | ---: | ---: | ---: |
| `tensor_pytorch_vs_fused` | `full` | `12288` | `0.00000000` | `0.00000000` | `inf dB` |
| `tensor_pytorch_vs_fused` | `crop8` | `6912` | `0.00000000` | `0.00000000` | `inf dB` |
| `tensor_fused_vs_manifest` | `full` | `12288` | `0.00000000` | `0.00000000` | `inf dB` |
| `tensor_fused_vs_manifest` | `crop8` | `6912` | `0.00000000` | `0.00000000` | `inf dB` |
| `tensor_pytorch_vs_manifest` | `full` | `12288` | `0.00000000` | `0.00000000` | `inf dB` |
| `tensor_pytorch_vs_manifest` | `crop8` | `6912` | `0.00000000` | `0.00000000` | `inf dB` |

## Interpretation

This reference consumes the fused TinySPAN handoff manifest and its exported int8 `.mem` weights, then dequantizes them with each tensor's exported `quant_scale`. In `weight-activation` mode it also applies symmetric fake-int activation quantization with optional calibrated activation scale overrides. It is still a PyTorch-level reference, but it fixes the scale names and quantization points needed for the integer RTL reference.
