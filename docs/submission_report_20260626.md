# TinySPAN 赛题提交报告

生成日期：`2026-06-26`

工程路径：`G:\UESTC\feitengspan1\Tinyspan`

提交路线：使用已有 TinySPAN C32/B4 W8A8 Gate H 硬件闭合方案提交；停止继续等待 X4/X2 画质提升训练支线。

## 1. 提交结论

本提交面向端侧视频会议超分场景，在 Xilinx Zynq UltraScale+ `xczu19eg` 板卡上实现 TinySPAN 专用超分硬件加速器，并按 ZC706 / XC7Z045 等效资源门线统计 PPA。当前提交包同时闭合 X2 和 X4 两个倍率的 720p30 输出证据：

| 倍率 | LR 输入 | SR 输出 | tile | 板上状态 | 实测吞吐 | 正确性 |
| --- | ---: | ---: | ---: | --- | ---: | --- |
| X4 | `320x180` | `1280x720` | `64x64` LR，15 tile | `PASS_X4` | `30.409639424076744fps @155MHz` | board-vs-fixed `0 / 2764800` mismatch，max diff `0` |
| X2 | `640x360` | `1280x720` | `64x64` LR，60 tile | `PASS_X2` | `32.86048226988138fps @187.512MHz` | board-vs-fixed `0 / 2764800` mismatch，max diff `0` |

最终提交采用“整帧切块上板超分”路线：输入帧先进入 PS DDR，PL 端按 `64x64` LR tile 取数、超分、裁剪边缘 tile，并写回完整 720p SR 帧。DDR 控制器不自研，直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、HP/HPC AXI 端口和 Xilinx 标准 AXI IP。

## 2. 赛题要求对应关系

| 赛题要求 | 本提交对应内容 | 状态 |
| --- | --- | --- |
| 提供 AI 模型结构、训练、量化说明文档及源代码 | `docs/model_design.md`、`docs/training_quantization.md`、`train/span_model.py`、`train/distill_tinyspan_video.py`、`configs/` | 已提供 |
| 提供模型到硬件加速器指令/参数转换工具 | `tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py`、`run_tinyspan_w8a8_integer_reference.py`、`export_tinyspan_w8a8_to_rtl.py` | 已提供 |
| 提供硬件加速器详细设计文档 | `docs/hardware_design.md`、`docs/full_frame_tiling_route.md`、`docs/verification_plan.md`、`docs/ppa_analysis.md` | 已提供 |
| 提供硬件加速器源代码，可 Vivado 仿真、综合、实现 | `rtl/tinyspan_core/`、`rtl/board_wrapper/`、`scripts/vivado/`、`sim/reports/` | 已提供 |
| REDS 数据集 X2/X4 超分 | X2 full REDS val 软件质量门禁已通过；X4 已完成硬件实时正确性基线，画质提升支线未替换提交基线 | 已闭合当前提交路线 |
| 实时性、功耗、面积平衡 | X2/X4 均满足 `>=30fps`；资源远低于 ZC706 等效门线；功耗约 `4W` | 已提供 PPA |

## 3. AI 模型与训练

当前硬件提交模型为 TinySPAN student：

- 模型结构：TinySPAN C32/B4，`32` 个特征通道，`4` 个 TinySPAN block。
- 输入格式：RGB888 LR frame / LR tile。
- 输出格式：RGB888 SR frame。
- 量化：W8A8，权重 INT8、激活 INT8，bias/requant 参数由 quant plan 固化。
- X4 硬件安全基线：`c32b4_30fps_frozen_20260613`。
- X2 提交 checkpoint：`runs/tinyspan_frozen_candidates/x2_quality_after_x4_20260625/student_final.pt`。

训练使用 REDS 数据集；仓库不包含 REDS 原始图片，训练脚本通过参数指定本地或云端数据路径。X2 当前提交模型完成 REDS `val_sharp` 全量 3000 张软件质量评估：

| 指标 | TinySPAN X2 | Bicubic X2 | 增益 |
| --- | ---: | ---: | ---: |
| PSNR mean | `31.121459919373763 dB` | `30.853986135469682 dB` | `+0.26747378390408016 dB` |
| SSIM mean | `0.9055147984822591` | `0.8999591733217239` | `+0.0055556252005352` |
| MAE/255 mean | `0.01739536935168629` | `0.01777845728242149` | 更低 |

X4 当前提交基线强调真实板上正确性、实时性和低资源。已尝试的 X4 画质提升候选 `QUALITY_X4_HRHEAVY_P256_20260626` 在 full REDS val 上为 `26.384690521945394dB`，未达到 `28dB` 提升目标，因此没有替换当前 X4 Gate H 提交基线。

## 4. 量化与模型到硬件转换

转换链路如下：

```text
frozen checkpoint
 -> fused TinySPAN checkpoint / manifest
 -> calibration / activation scale
 -> W8A8 quant plan
 -> software fixed-point reference
 -> RTL memory/config export
 -> Vivado simulation / implementation / bitstream
 -> board-vs-fixed acceptance
```

关键文件：

- X4 checkpoint SHA256：`6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- X4 quant plan SHA256：`EB6EEDDDE9360F61E6FC30141B2A1E6539E519CB226AC18B8C219B9E40092C9D`
- X2 checkpoint SHA256：`B06E66FA8FEA066F111B94CF5629919BEA05D5465F913B36851CBA92BED4A9EB`
- X2 quant plan SHA256：`8BB154CC524B5CA00A1A3D81F0E343CF0A0BA1CF8E08AB5867656B0C53D37C2F`

量化和 RTL 导出工具均在 `tools/model_to_hardware/` 下。软件定点参考作为硬件验收黄金输出，所有上板结果均与同一 checkpoint、同一 quant plan、同一 tile contract 生成的 fixed reference 对齐。

## 5. 硬件加速器设计

硬件系统由三部分组成：

| 模块 | 功能 |
| --- | --- |
| PS/DDR 入口 | 通过板卡 PS DDR controller IP 和 AXI HP/HPC 端口访问输入/输出帧，不自研 DDR controller/PHY |
| TinySPAN tile pipeline | 按固定 `64x64` LR tile 读取 RGB，执行 W8A8 TinySPAN 卷积/激活/重排，输出 SR tile |
| 动态裁剪与写回 | 对边缘 tile 做 zero padding 输入和 valid region crop 输出，写回完整 720p SR frame |

整帧切块策略：

- X4：`320x180` LR 被切为 `5x3=15` 个 `64x64` LR tile，输出拼接为 `1280x720`。
- X2：`640x360` LR 被切为 `10x6=60` 个 `64x64` LR tile，输出拼接为 `1280x720`。
- 对右边界和下边界不足 `64x64` 的 tile 做 zero padding，写回时只保留有效区域。

该设计面向后续 SD 卡/视频输入工程化扩展；当前严格验收链路采用 host/XSCT 写入 PS DDR、PL 运行、A53 在 DDR 内逐字节比较输出与 reference，避免慢速 JTAG 全帧读回影响吞吐评估。

## 6. 验证方案与验证用例

验证分为五级：

| 层级 | 验证内容 | 证据 |
| --- | --- | --- |
| 软件训练质量 | REDS `val_sharp` PSNR/SSIM/MAE | X2 quality candidate manifest |
| 量化一致性 | PyTorch student、定点 reference、integer reference 比较 | `tools/image_validation/` 输出 |
| RTL/仿真 | tile wrapper、cropper、writer shell、PS/DDR wrapper | `sim/reports/` |
| Vivado 实现 | bitstream、timing、utilization、power | `vivado/` reports 与 Gate H manifest |
| 真实上板 | A53 in-DDR full-frame compare、frame cycles、fps | X2/X4 Gate H manifest |

核心上板证据：

- X4 Gate H：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`
- X2 Gate H：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/manifest.json`
- 交付包校验：`docs/contest_delivery_package_check.md`
- 交付审计：`docs/contest_delivery_audit.md`

## 7. PPA 指标

按 ZC706 / XC7Z045 等效资源门线：LUT `218600`、Register `437200`、DSP `900`、BRAM Tile `545`。

| 指标 | X4 Gate H | X4 占 ZC706 门线 | X2 Gate H | X2 占 ZC706 门线 |
| --- | ---: | ---: | ---: | ---: |
| CLB LUT | `6353` | `2.91%` | `6647` | `3.04%` |
| CLB Register | `4647` | `1.06%` | `5031` | `1.15%` |
| DSP | `81` | `9.00%` | `100` | `11.11%` |
| BRAM Tile | `27` | `4.95%` | `27` | `4.95%` |
| URAM | `0` | `0` | `0` | `0` |
| WNS | `+0.020ns` | PASS | `+0.002ns` | PASS |
| WHS | `+0.007ns` | PASS | `+0.014ns` | PASS |
| PL frequency | `155MHz` | - | `187.512MHz` | - |
| Total On-Chip Power | `3.969W` | - | `4.053W` | - |
| Dynamic Power | `2.755W` | - | `2.839W` | - |

在同等实时约束下，TinySPAN C32/B4 的优势是低 DSP、低 LUT、低 BRAM，并且定点/RTL/板上逐字节一致性容易闭合。

## 8. 可查看图像材料

X4：

- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png`
- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png`
- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png`

X2：

- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/board_sr_a53_equal_to_fixed.png`
- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/tinyspan_board_software_preview.png`
- `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/diff_heatmap.png`

说明：最终硬证据是 A53 in-DDR full-frame byte compare；部分可视化图是在 `0 mismatch` 证明后复制 fixed reference 作为等价视图，避免慢速全帧 JTAG 读回影响实时性判断。

## 9. 交付文件索引

| 类别 | 路径 |
| --- | --- |
| 工作流 | `WORKFLOW.md` |
| 模型结构 | `docs/model_design.md` |
| 训练与量化 | `docs/training_quantization.md` |
| 硬件设计 | `docs/hardware_design.md` |
| 验证方案 | `docs/verification_plan.md` |
| PPA 分析 | `docs/ppa_analysis.md` |
| 交付审计 | `docs/contest_delivery_audit.md` |
| 交付包校验 | `docs/contest_delivery_package_check.md` |
| 模型源码 | `train/` |
| 转换工具 | `tools/model_to_hardware/` |
| RTL 源码 | `rtl/tinyspan_core/`、`rtl/board_wrapper/` |
| Vivado 脚本 | `scripts/vivado/` |
| X4 上板证据 | `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/` |
| X2 上板证据 | `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/` |

## 10. 当前边界与提交说明

- 当前提交采用已有 X2/X4 Gate H 硬件闭合方案，不继续等待 X4/X2 画质提升训练支线。
- X4 当前基线满足真实板上 `>=30fps` 和 `0 mismatch`，但 full REDS val 画质提升有限；本次提交优先保证正确性、实时性和低资源。
- 当前严格验收没有把“板上 SD 卡直接读图”作为闭合证据；正式证据为 PS DDR 输入、PL 运行、A53 DDR 内比较。后续可将输入输出工程化升级为 AXI DMA/DataMover/VDMA 或 SD->DDR 流水，但不影响本提交的硬件 compute 与整帧切块验收结论。
- 若后续切换更高 PSNR 的 X4/X2 模型，必须重新完成 checkpoint 冻结、量化、RTL/export、bitstream、真实板上 `0 mismatch` 和 `>=30fps` 验收后，才能替换本提交基线。

