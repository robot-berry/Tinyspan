# TinySPAN 720p30 X2/X4 上板验收工作流

## 1. 工程路径

当前工程存放路径：

```text
主工程根目录：G:\UESTC\feitengspan1
TinySPAN 工作流仓库：G:\UESTC\feitengspan1\Tinyspan
TinySPAN 验收产物目录：G:\UESTC\feitengspan1\Tinyspan\artifacts
GitHub 仓库：https://github.com/robot-berry/Tinyspan.git
GitHub 分支：main
```

所有后续 TinySPAN 上板验收相关的 workflow、记录、哈希、图片验证结果和可上传证据，
都优先放在 `G:\UESTC\feitengspan1\Tinyspan` 及其 `artifacts` 子目录下。

### 1.1 GitHub 工程文件布局

`robot-berry/Tinyspan` 仓库既是工作流记录仓库，也是后续 TinySPAN 工程交付文件的归档仓库。
后续生成或整理出来的工程文件按下面结构放置：

```text
Tinyspan/
├── README.md
├── WORKFLOW.md
├── workflows/
│   └── tinyspan_720p30_acceptance.yaml
├── docs/
│   ├── model_design.md
│   ├── training_quantization.md
│   ├── hardware_design.md
│   ├── verification_plan.md
│   └── ppa_analysis.md
├── model/
│   ├── configs/
│   ├── checkpoints/
│   └── export_manifest/
├── train/
│   ├── scripts/
│   └── logs/
├── quant/
│   ├── calibration/
│   ├── quant_plan/
│   └── fixed_point_reference/
├── tools/
│   ├── model_to_hardware/
│   └── image_validation/
├── rtl/
│   ├── tinyspan_core/
│   ├── board_wrapper/
│   └── generated_mem/
├── sim/
│   ├── testbench/
│   ├── vectors/
│   └── reports/
├── scripts/
│   ├── vivado/
│   ├── board/
│   └── acceptance/
└── artifacts/
    └── YYYYMMDD_scale_tinyspan_model_tile_freq_shorttag/
```

当前仓库里已经存在的文件：

- `README.md`
- `WORKFLOW.md`
- `workflows/tinyspan_720p30_acceptance.yaml`
- `artifacts/README.md`
- `artifacts/.gitkeep`

后续从主工程 `G:\UESTC\feitengspan1` 迁移或生成的 TinySPAN 工程文件，应先放入上述对应目录，
再提交并推送到 `robot-berry/Tinyspan`。大型临时文件、Vivado 缓存、`.Xil`、DCP 森林和过大的原始日志
不直接进入 Git；只保留可复现实验所需的摘要、哈希、脚本、报告和关键图片。

## 2. 赛题要求对齐

本工作流必须服务于赛题目标：面向端侧视频会议场景，设计专用 AI 超分硬件加速器，
在“清晰度、实时性、功耗/面积”之间取得平衡，并在 ZC706 或资源相当 FPGA 上完成
X2、X4 超分验证。

### 2.1 赛题目标

- 面向端侧场景实现专用 AI 超分硬件加速器。
- AI 模型、量化、稀疏化方法不做限制。
- 图像输入格式不限，可使用 RGB 或 YUV。
- AI 模型可参考 CVPR NTIRE 相关论文。
- 适配视频会议核心画面特征，重点关注人像、文档、屏幕共享等内容。
- 在实时性和高保真画质之间取得平衡。
- 基于 Xilinx ZC706 FPGA 或资源相当 FPGA，在 REDS 数据集上实现 X2、X4 超分。
- 在实际视频会议场景下验证画质与性能表现。

### 2.2 数据集与参考论文

- 参赛数据集：REDS。
- 数据集链接：`https://seungjunnah.github.io/Datasets/reds.html`
- 论文引用：S. Nah et al., "NTIRE 2019 Challenge on Video Deblurring and Super-Resolution: Dataset and Study"。
- 工作流中的训练、校准、量化和图像验证材料必须记录使用的数据子集、输入帧、降采样方式和哈希。

### 2.3 交付内容

最终交付材料必须覆盖以下内容：

- AI 模型结构说明。
- 训练说明文档及源代码。
- 量化说明文档及源代码。
- 如使用稀疏化，也必须提供稀疏化说明与可复现实验记录。
- 模型到硬件加速器指令、权重、参数或 RTL memory 的转换工具。
- 硬件加速器详细设计文档。
- 硬件加速器源代码。
- 可在 Xilinx Vivado 中进行仿真验证的工程、脚本和测试向量。
- 可在 Xilinx Vivado 中综合/实现并用于资源开销评估的脚本和报告。

### 2.4 评审要点

工作流中的证据包必须能支撑以下评分点：

| 评审项 | 分值 | 工作流证据 |
| --- | ---: | --- |
| 功能实现精准无误，与题目要求高度契合 | 10 | X2/X4 正确性、TinySPAN 软件定点参考与硬件输出一致、视频会议样例验证 |
| 设计方案文档表述清晰，模块功能划分科学合理 | 10 | 模型文档、硬件模块设计文档、数据流和接口说明 |
| 文档明确阐释模块内部量化指标及性能分析 | 20 | 量化方案、PSNR/SSIM/MAE、吞吐、延迟、资源、功耗/面积分析 |
| 具备完善的验证方案与验证用例 | 20 | REDS 验证集、会议场景样例、RTL 仿真、板上输出、图像一致性预览 |
| 同等性能约束下面积越小、功耗越低越好 | 40 | Vivado utilization、timing、power、资源门限、bitstream 与 PPA 汇总 |

注意：如果未通过正确性仿真验证以及未生成 bitstream，PPA 项按赛题规则不能作为有效得分证据。

### 2.5 对本工作流的硬约束

- 每个 TinySPAN 验收 run 都必须能追溯到 REDS 或视频会议验证输入。
- X2 和 X4 都必须保留独立证据包。
- 正确性优先级高于 PPA；没有正确性仿真和 bitstream，就不能宣告 PPA 有效。
- 资源评估必须按 ZC706 / XC7Z045 或资源相当 FPGA 的门限进行归一化说明。
- 图像一致性验证必须包含可查看的 `comparison_preview.png` 和 `diff_heatmap.png`。

## 3. 主线目标

本工作流的验收路线锁定为 **TinySPAN**，不是 W8A12。

最终目标是在现有 `xczu19eg-ffvc1760-2-i` 板卡上，实现对降采样图片或视频帧的
TinySPAN X2/X4 实时超分，并输出完整 `1280x720` 画面，吞吐达到 `30fps` 或更高。

资源约束仍按 ZC706 / XC7Z045 的资源规模作为上限门限，但实际上板目标仍是原板卡
`xczu19eg-ffvc1760-2-i`。

本工作流默认以下约束成立：

- 主线模型：TinySPAN
- 实际运行板卡：`xczu19eg-ffvc1760-2-i`
- 资源约束门限：XC7Z045 / ZC706
- X2 输入输出约定：`640x360 -> 1280x720`
- X4 输入输出约定：`320x180 -> 1280x720`
- 大图从 SD 卡或 DDR 输入，由硬件负责切块
- 当前上板验收 tile：`32x32` LR tile 作为正确性安全基线；`64x64` LR tile 作为当前完整帧吞吐候选
- 最终验收不接受 PC 端提前切好的小块作为板卡输入
- 最终验收不接受一次性整帧 TinySPAN 核直接处理 SD 卡完整 LR 帧来替代板端切块方案
- 板上输出必须与同一 TinySPAN 冻结 checkpoint、同一 TinySPAN 量化方案生成的软件定点参考逐字节一致

## 4. 路线锁定

当前路线：

```text
TinySPAN frozen checkpoint
 -> TinySPAN quant plan
 -> TinySPAN fixed-point software reference
 -> TinySPAN RTL/export
 -> TinySPAN PS/DDR hardware tile scheduler
 -> TinySPAN hardware-tiled fixed-point software reference
 -> TinySPAN bitstream on xczu19eg
 -> real board output
 -> board output == TinySPAN hardware-tiled fixed-point reference
 -> training/PyTorch SR output vs board SR output image validation
 -> 1280x720 >= 30fps
```

明确不作为验收路线：

- W8A12 DDR tile writer
- full SPAN JTAG 小图 smoke
- ZC706/PS7 实板切换路线
- PC 端预切 tile 后再送板卡推理

这些结果可以作为历史参考、资源估算或硬件接口经验，但不能替代 TinySPAN 的最终验收证据。

### 4.1 当前硬件安全基线

从 2026-06-18 起，TinySPAN 工作流使用下面这个 checkpoint 作为硬件安全基线继续推进：

```text
Baseline ID：c32b4_30fps_frozen_20260613
Checkpoint：G:\UESTC\feitengspan1\runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt
SHA256：6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938
模型：TinySPAN c32 b4
优先倍率：X4 first, then X2
优先量化：W8A8
```

选择它作为基线的原因：

- checkpoint 已冻结，`freeze_manifest.json` 中 source 与 frozen SHA256 一致。
- 已有 X4 `320x180 -> 1280x720` 软件实时验收，端到端 `36.079767 fps`，超过 30fps。
- 已有 TinySPAN W8A8 量化计划、整数参考、RTL manifest 和 readiness 检查记录。
- 相比 `c32b4_final_20260615`，这个基线没有当前已知的 fused/export 边界漂移阻塞。

对应的本地证据路径：

- 冻结记录：`G:\UESTC\feitengspan1\runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\freeze_manifest.json`
- 软件 30fps 验收：`G:\UESTC\feitengspan1\runs\tinyspan_acceptance\c32b4_x4_320x180_30f_rerun_20260613\summary.json`
- 量化计划：`G:\UESTC\feitengspan1\runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json`
- 整数参考：`G:\UESTC\feitengspan1\runs\tinyspan_integer_reference\c32b4_30fps_frozen_20260613_x4_c32_b4_32x32_w8a8\tinyspan_w8a8_integer_reference_summary.md`
- RTL manifest：`G:\UESTC\feitengspan1\rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8\tinyspan_w8a8_rtl_manifest.json`
- readiness：`G:\UESTC\feitengspan1\board_runs\tinyspan_board_acceptance\readiness_c32b4_30fps_frozen_20260613\tinyspan_30fps_board_acceptance_readiness.json`

必须特别注意：这个基线可以用于继续推进 RTL、bitstream、板卡和图像一致性验证，
但目前还不能宣告 TinySPAN 上板验收完成。readiness 记录显示，当前仍缺：

- 真实 TinySPAN-trained bitstream
- 真实板上输出
- 板上输出与同一软件定点参考的真实逐字节一致性证据
- 实测板上 720p30 throughput 证据

如果后续想把 `c32b4_final_20260615` 或其它 checkpoint 替换为新基线，必须先新增
`baseline_upgrade_report.md`，记录新旧 checkpoint 哈希、量化计划、定点参考、RTL manifest、
图像一致性指标和 fused/export 一致性结论。没有这份升级报告，不切换硬件基线。

### 4.2 当前 X4 训练软件基线

从 2026-06-25 起，当前 X4 云端训练结果作为后续工作流的 **X4 训练软件基线** 继续推进：

```text
Training baseline ID：x4_quality_hr060_edge006_20260625_current_baseline
Scale：X4
模型：TinySPAN c32 b4
训练 run：runs/tinyspan_distill/video_x4_c32_b4_quality_hr060_edge006_20260625
全量 REDS val 质量包：runs/tinyspan_quality/x4_quality_hr060_edge006_reds_val
本地证据包：G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\x4_quality_candidates\x4_quality_hr060_edge006_20260625_cloud_eval
验证集：REDS val，全量 3000 张
PSNR：26.3846905 dB
SSIM：0.7369068
MAE：0.02989517
Bicubic PSNR：26.2744630 dB
PSNR gain over bicubic：0.1102276 dB
```

这个节点的含义是：

- 它作为 X4 训练/画质路线的当前基线，后续报告、对比和改进都以它为参照。
- 它不再阻塞 X2 云端提升训练；X2 训练完成后继续独立冻结、量化、RTL 和上板闭环。
- 它没有达到 X4 `>=28dB` 质量提升目标，因此不能作为“28dB 画质达标”声明。
- 它不能自动替换 `c32b4_30fps_frozen_20260613` 硬件安全基线；若要把该 X4 训练基线送入硬件交付，
  仍必须重新完成 checkpoint 冻结、量化计划、定点参考、RTL/export、bitstream、真实板上
  board-vs-fixed 逐字节一致性和 `>=30fps` 吞吐证据。
- 当前赛题交付主线仍优先保留已经闭合的 X4 Gate H 硬件证据；后续重点补齐 X2 独立证据和最终交付索引。

## 5. 资源约束门限

工程实际运行在当前原板卡上，但最终实现报告必须不超过 XC7Z045 / ZC706 的资源规模：

| 资源 | 上限 |
| --- | ---: |
| DSP | 900 |
| BRAM Tile | 545 |
| URAM | 0 |
| I/O | 362 |
| Slice LUT | 218600 |
| Slice Register | 437200 |

判定规则：`实际值 <= 上限` 为通过；只要任一资源 `实际值 > 上限`，资源门限即失败。

## 6. 必须支持的数据流

```text
SD 卡或 DDR 中的完整输入帧
 -> PS 配置寄存器
 -> PL 侧 TinySPAN tile/halo 调度器
 -> DDR halo / tile 读取
 -> RGB 归一化与 TinySPAN 量化
 -> TinySPAN 计算核心
 -> TinySPAN tail 与 PixelShuffle X2 或 X4
 -> RGB888 输出写回
 -> DDR 中的 1280x720 输出帧
 -> PS 回读或显示通路
```

帧级输入仍然是 SD 卡或 DDR 中的完整 LR 图像/视频帧；TinySPAN 计算核心的实际推理粒度是
板端 tile。当前验收优先使用 `32x32` LR tile；如果后续资源、BRAM 和时序允许，可以补充
`64x64` LR tile 作为减少调度开销的备选实现。对于 X4，`32x32` LR tile 对应 `128x128`
SR tile，`64x64` LR tile 对应 `256x256` SR tile。

硬件必须负责 tile 坐标生成、halo 读取、边界处理、有效区域裁剪、输出地址映射和最终输出位置写回。
软件可以准备原始完整输入帧，也可以验证最终输出，但最终验收跑板时不能由 PC 端预先把图像切成
推理小块后再送板卡。

### 6.1 输入输出加速决策

从 2026-06-24 起，完整帧输入输出不再把 JTAG 逐像素寄存器读写作为正式验收路线。JTAG 只保留为
小图一致性、寄存器调试、状态诊断和应急 dump 手段；它不能代表赛题需要的实时图像/视频 I/O 能力。

当前 TinySPAN X4 `320x180 -> 1280x720` JTAG 全帧读回诊断 run：

```text
board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_fullread_diag2
```

已在 `204800 / 921600` 个输出像素处主动停止，未生成完整 `board_output.rgb`。该日志只证明输出端持续有
有效像素产生，不作为最终整帧图像一致性验收证据。按该 run 的日志时间粗算，JTAG 逐像素读完整个
`1280x720` RGB 输出帧需要数小时量级，因此对赛题评分和真实视频路线没有实用价值。

正式 I/O 加速路线改为：

```text
SD 卡或 PS 侧文件
 -> DDR 输入帧 buffer
 -> 板卡 ZynqMP PS DDR controller IP
 -> PL TinySPAN tile scheduler 通过标准 AXI / AXI DMA / HP-HPC 口读取 LR tile 与 halo
 -> TinySPAN W8A8/base-equiv 计算核心
 -> PL 通过标准 AXI / AXI DMA / HP-HPC 口写回 DDR 输出帧 buffer
 -> PS 批量校验、保存图片，或 VDMA/显示通路输出
```

预期收益是数量级变化：JTAG 逐像素寄存器访问通常只能用于调试；DDR burst / DMA 路线应把完整帧
I/O 从“小时级”压到“秒级到亚秒级”，并为后续视频流/显示链路提供基础。最终是否达到 30fps 仍以
板上实测 `frame_cycles`、DDR 读写带宽和端到端输出帧率为准。

后续不得自研 DDR 控制器、DDR PHY 或板级 DDR 时序逻辑。DDR 只通过 Vivado Block Design 中的
`zynq_ultra_ps_e` / 板卡 PS DDR controller IP 暴露给 PL；TinySPAN 侧只实现 AXI 用户逻辑或调用
Xilinx 标准 AXI DMA / VDMA / SmartConnect 等 IP。现有 `sr_ddr_tinyspan_x4_tile_writer_endpoint`
属于 TinySPAN AXI 用户逻辑，不替代板卡 DDR IP；后续性能优化优先把内部单像素 AXI 访问替换成
AXI burst 或 AXI DMA，而不是实现自定义 DDR 控制器。

执行约束：正式交付路线不得新增自研 DDR 控制器、DDR 仲裁器或 DDR 时序模块；帧输入/输出必须复用
板卡 PS DDR controller、HP/HPC 端口、AXI DMA/VDMA/DataMover/SmartConnect 等 AMD Xilinx IP。
当前 `sr_ddr_pixel_axi_master` 仅作为小图 smoke 与 mismatch 调试桥保留，不能作为 720p30 最终
I/O 性能实现。

从 2026-06-25 起，TinySPAN PS/DDR Block Design 必须默认应用 FACE-ZUSSD 参考工程中的 PS DDR
板卡配置。实现方式是在 `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl` 中创建
`zynq_ultra_ps_e` 后，从 `G:\UESTC\feitengspan1\docs\reference_face_zussd\zcu106_hpc0_dual_bd.tcl`
抽取 `PSU__DDRC__*`、`PSU__DDR*`、DDR 时钟和 `SUBPRESET1` 参数并应用到板卡 PS DDR controller IP。
该步骤仍然是调用板卡/厂商 IP，不是自研 DDR 控制器。生成新 bitstream 后，必须先运行 A53 DDR alias
probe；只有 DDR 地址别名消失后，才继续 TinySPAN board-vs-fixed 图像一致性验收。

注意：W8A12 当前仍有 mismatch 未闭环，不能作为 TinySPAN 正确性基线。后续最多复用 W8A12 路线里
关于 PS/DDR/AXI/DMA 搬运的工程经验，不复用 W8A12 计算核心、输出图像或验收结论。

### 6.2 方法提升路线

这个整帧切块方法可以继续提升，但提升顺序必须围绕赛题交付证据来排，不能破坏已经闭合的
X4 `0 mismatch` 和 `>=30fps` 证据。每一次优化都必须重新经过 A53 DDR alias probe、完整帧
throughput、A53 in-DDR board-vs-fixed 比较和图像预览回归。

当前最值得优先提升的是 I/O 与调度余量，而不是盲目放大 TinySPAN compute core。X4 tile64 FIFO f155
已经在真实板上达到 `30.4096394240767fps`，但帧率余量只有约 `1.37%`，仍然偏紧；如果后续加入
显示、SD 写回、视频帧队列或 X2 独立链路，应该先把下面几项做成可回归的工程优化：

1. 把过渡性的单像素 AXI 调试桥逐步收敛为 AXI burst、AXI DataMover、AXI DMA 或 VDMA 路线。
2. 为 LR tile 读取、TinySPAN 计算和 SR tile 写回加入 ping-pong buffer，让读、算、写可以重叠。
3. 保持 `64x64` LR tile 作为 X4 当前吞吐候选；如果尝试更大 tile，必须先证明 BRAM、时序和边缘裁剪仍通过。
4. 对边缘 tile 的 padding/crop、地址映射和 tile manifest 做自动化回归，避免整帧拼接出现肉眼不明显但逐字节不一致的问题。
5. 用 PS/A53 从 DDR 批量导出 `board_sr.png`、`comparison_preview.png` 和 `diff_heatmap.png`，展示材料走 DDR/文件路径，不再走 JTAG 全帧读回。

X2 的提升路线不应复用 X4 结果直接宣告通过。训练完成后必须独立冻结 X2 checkpoint、导出 X2 quant plan、
生成 X2 RTL manifest 和 X2 hardware-tiled fixed reference，再按 X2 `640x360 -> 1280x720` 完整帧重新跑
bitstream、真实板上输出、逐字节一致性和 `>=30fps`。X2 若吞吐不足，优先复用 X4 已验证的 PS/DDR/tile64
调度经验；若画质不足，再考虑 `c32b4_final_20260615` 或新训练 checkpoint，但必须先通过
`baseline_upgrade_report.md` 修复 fused/export 漂移并重新做量化、定点参考、RTL 和图像一致性预检。

### 6.3 SD 卡图与 REDS 真值质量验证

训练主数据仍按赛题使用 REDS，当前 X2 训练输入为 `G:\REDS\train_sharp`。板子 SD 卡中的图片不替代
REDS 正式训练集，但应作为实际会议场景展示/验证输入：SD 卡或 PS 侧文件提供完整 LR 帧，PL/PS-DDR
路线负责板端切块、TinySPAN 推理、裁剪拼接和 DDR 输出。

对 SD 卡图和 REDS 验证图统一采用两类质量指标：

1. **硬件正确性**：真实板上输出必须与同一 checkpoint、同一 quant plan、同一 tile contract 生成的
   `software_tiled_fixed_point_sr.png` 逐字节一致。
2. **画质还原度**：用 `tools/image_validation/evaluate_sr_quality.py` 对 SR 图和 HR/teacher reference
   计算 PSNR、SSIM、MAE 和 max diff。若输入是 REDS HR 或 SD 卡 HR 展示图，先生成对应 LR 输入，再把
   SR 输出与原始 HR 图比较；同时保留 bicubic LR baseline 作为参照。

当前 X4 已补一个 REDS val 样例质量包：

```text
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/reds_val_quality_x4_00000000_tile64_20260625/
```

该样例使用 `G:\REDS\val_sharp\000\00000000.png` 作为 HR reference，按 X4 生成 `320x180` LR 输入，
再由 tile64 fixed reference 输出 `1280x720` SR，并生成 `reds_hr_quality_metrics.json/.md`。后续 SD 卡
会议图、人像图和文档图应按同一流程生成独立质量包。

板上 SD 卡已有图片的 X4 上板验证按 `docs/sd_card_x4_board_validation_plan.md` 执行。该任务必须等待
当前 W8A12 或其他板卡任务结束后再启动；若仍只使用 PC 文件写入 DDR，必须标注为 DDR 路径验证，
不能冒充为严格的板上 SD 卡读图验证。

X4 当前板上资源、时序、功耗、吞吐、正确性和画质指标已汇总到
`docs/x4_board_result_report_20260625.md`。

### 6.4 画质提升目标门槛

在当前赛题交付主线中，画质目标新增为：

- X4：在 TinySPAN 当前硬件安全拓扑或可重新闭合的替代 checkpoint 上，实现 REDS 验证平均 PSNR `>= 28dB`。
- X2：在 TinySPAN X2 独立训练、量化和上板链路上，实现 REDS 验证平均 PSNR `>= 30dB`。

判定规则：

- 指标以 REDS `val_sharp` 的多图平均结果为准；正式报告优先使用全量 `30` 个序列、`3000` 张图，若先用子集筛选，必须明确标注子集规模。
- 单张图结果和 `16` 张 smoke 结果只能作为链路检查，不能作为 `28dB/30dB` 达标声明。
- 质量报告必须同时记录 student-vs-HR、bicubic-vs-HR、PSNR gain、SSIM、MAE、max diff、输入降采样方式、边界裁剪 border 和 checkpoint/quant plan SHA256。
- 云端 full REDS val 评估允许“全量计算指标、只保存少量 PNG 预览图”以避免 50GB 数据盘耗尽；此时必须在质量 JSON/MD 中记录 `image_count`、`save_image_count` 和 `saved_image_count`，并保证 PSNR/SSIM/MAE 仍来自全量 `3000` 张统计。
- 达标 checkpoint 若要替换当前可提交硬件基线，仍必须重新通过量化、RTL/export、bitstream、真实板上 board-vs-fixed `0 mismatch` 和 `>=30fps` 吞吐；只达成软件 PSNR 不能替代硬件验收。

当前状态：

- X4 当前可提交基线重点是 `0 mismatch` 与 `30.4096fps`，REDS 单样例质量约 `25.85dB`，未达到新 `28dB` 画质提升目标。
- 执行顺序按 2026-06-25 最新要求调整为：当前优先完成 X2 云端训练和 X2 交付闭环；X2 训练完成、full-val 质量包下载完成、最终 checkpoint 已安全落地后，可以复用云端 GPU 启动 X4 画质提升训练支线。
- X4 提升训练支线目标是超过当前 X4 软件基线和 bicubic，再争取 REDS full-val `>=28dB`；但它不替换当前 `X4_SUBMIT_20260625_CURRENT_BASELINE`，除非重新完成冻结、量化、RTL/export、bitstream、真实板上 board-vs-fixed `0 mismatch` 和 `>=30fps` 吞吐。
- X4 训练后自动评估 watcher 已接入：`scripts/cloud/watch_x4_training_then_eval.py`。后续重新启动 X4 提升训练时，必须使用新的 run ID 和 candidate ID，并在训练完成后运行全量 REDS `val_sharp` 软件质量评估并打包候选证据，不启动 Vivado/JTAG/XSCT/板卡访问。
- X2 本地原训练保留在 epoch `38`、step `147107 / 198000`，其 `student_latest.pt` 只作为云端 X2 resume 起点；本地 X2 训练进程已按最新要求停止。
- 当前 X2 云端训练已经启动并由 X2 watcher 接管；后续不再等待新的 X4 候选包来启动 X2。
- X2 云端训练完成后的自动评估 watcher 已接入：`scripts/cloud/watch_x2_training_then_eval.py`。它可提前启动，等待 X2 run 出现并完成后运行全量 REDS `val_sharp` X2 软件质量评估并打包候选证据，不启动 Vivado/JTAG/XSCT/板卡访问。
- X2 full REDS val 评估默认使用 `--save-image-count 16`：全量 `3000` 张计算质量指标，只保存前 `16` 张 HR/LR/Bicubic/Student PNG 作为可视化预览，降低磁盘占用。
- X2 提升训练目标为约 `13` 个 epoch、`51480` step；完成后再用同一 checkpoint 闭合 X2 freeze/quant/RTL/board，并评估 REDS val 平均 PSNR 是否达到 `>=30dB`。

### 6.5 X4 当前方案提交节点

提交节点：`X4_SUBMIT_20260625_CURRENT_BASELINE`

该节点允许提交当前 X4 子任务方案：

- scale：X4
- 输入/输出：`320x180 -> 1280x720`
- tile：`64x64`
- checkpoint：`c32b4_30fps_frozen_20260613`
- bitstream SHA256：`A94DC9B1417B35D05C9D57176109155BCBAFB5939C5E9EA9DC570C8184FD8232`
- 吞吐：`30.409639424076744fps @155MHz`
- 正确性：A53 in-DDR compare `0 / 2764800` mismatch，max diff `0`
- 资源：LUT `6353`，Register `4647`，DSP `81`，BRAM Tile `27`，URAM `0`
- 边界：该提交节点只表示 X4 子任务可提交；整赛题仍等待 X2 独立闭合。

后续 X4 PSNR `>=28dB`、X2 PSNR `>=30dB` 的画质提升不阻塞该 X4 提交节点，按
`docs/x4_quality_improvement_plan.md` 作为独立候选推进。候选只有重新完成训练、量化、RTL、bitstream、
真实板卡 `0 mismatch` 和 `>=30fps` 后，才允许替换本 X4 提交基线。

路线决策记录：

- 2026-06-21：主线确认采用完整 LR 帧板端切块拼接，最终 X4 目标为 `320x180 -> 1280x720`。
- `160x90 -> 640x360` 只作为完整帧切块调度 smoke，不作为最终赛题验收尺寸。
- 具体执行说明见 `docs/full_frame_tiling_route.md`。
- 2026-06-24：停止 TinySPAN X4 JTAG 全帧逐像素读回，正式转向 TinySPAN 专用 DDR/PS/DMA 输入输出路线。
- 2026-06-25：后续 DDR 访问继续直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP、
  HP/HPC 端口和 Xilinx AXI DMA/VDMA/DataMover/SmartConnect 等标准 IP；不得新增自研 DDR 控制器、
  DDR PHY 或板级 DDR 时序逻辑。TinySPAN 侧只允许实现 AXI 用户逻辑、tile scheduler、计算核心和调试桥。

## 7. 工程产物放置规则

后续这个工作流产生的 TinySPAN 验收材料统一放到：

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts
```

每一次独立运行使用一个目录：

```text
artifacts/YYYYMMDD_scale_tinyspan_model_tile_freq_shorttag/
```

示例：

```text
artifacts/20260618_x4_tinyspan_c32b4_tile32_h21_f50_origboard/
```

每个运行目录建议至少包含：

- `manifest.json`
- `run_summary.md`
- `checkpoint.sha256`
- `quant_plan.sha256`
- `input.sha256`
- `software_reference.sha256`
- `board_output.sha256`
- `resource_gate.json`
- `timing.rpt`
- `utilization.rpt`
- `board.log`
- `throughput.json`
- `training_sr.png`
- `software_fixed_point_sr.png`
- `software_tiled_fixed_point_sr.png`
- `board_sr.png`
- `diff_heatmap.png`
- `comparison_preview.png`
- `tile_manifest.json`
- `tinyspan_tiled_fixed_reference_summary.json`
- `tinyspan_tiled_fixed_reference_summary.md`
- `image_validation.json`
- `image_validation.md`
- `tinyspan_x4_quality_metrics.json`
- `tinyspan_x4_quality_metrics.md`
- `reds_hr_quality_metrics.json`
- `reds_hr_quality_metrics.md`
- `model_design.md`
- `training_quantization.md`
- `hardware_design.md`
- `model_to_hardware_tool.md`
- `vivado_simulation.md`
- `ppa_summary.json`
- `ppa_summary.md`

Vivado 临时目录、`.Xil`、中间构建目录和过大的原始日志不建议直接上传到 Git；
需要时在 `run_summary.md` 中摘要说明，并保留可复现实验结论所需的关键证据。

## 8. 分阶段工作流

### Gate A0 - TinySPAN 硬件安全基线预检

输入：

- `c32b4_30fps_frozen_20260613` frozen checkpoint
- `freeze_manifest.json`
- X4 30fps 软件实时验收 `summary.json`
- TinySPAN W8A8 量化计划
- TinySPAN 整数参考摘要
- TinySPAN RTL manifest
- TinySPAN readiness 记录

输出：

- `baseline_decision.md`
- `baseline_manifest.json`
- `handoff_readiness.json`
- `handoff_readiness.md`

通过条件：

- checkpoint SHA256 固定为 `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- quant plan 的 `source_checkpoint` 指向同一 frozen checkpoint
- 软件 X4 `320x180 -> 1280x720` 30fps 验收通过
- 整数参考和 RTL manifest 均来自同一 checkpoint 与同一量化计划
- readiness 明确列出尚未完成的 bitstream 与真实板上输出，避免误宣告完成

### Gate A - 冻结 TinySPAN 模型

输入：

- TinySPAN 最终训练 checkpoint
- 最终 `metrics.csv`
- TinySPAN 模型配置文件

输出：

- 冻结后的 TinySPAN checkpoint 副本
- SHA256 哈希
- 最后一行训练指标

通过条件：

- checkpoint 已固定用于本次 TinySPAN 验收
- 没有训练进程继续修改该 checkpoint
- 记录 checkpoint 哈希和最终指标

### Gate B - TinySPAN 量化与软件定点参考

输入：

- 冻结 TinySPAN checkpoint
- 校准集
- 目标倍率：X2 或 X4

输出：

- TinySPAN 量化方案
- TinySPAN 整数/定点软件参考
- 参考输出图片或帧

通过条件：

- 量化方案和软件定点参考来自同一个冻结 TinySPAN checkpoint
- 记录量化方案与软件参考输出的 SHA256 哈希
- final checkpoint 如果发生 fused/export 边界漂移，不得直接进入上板
- 板卡逐字节一致性的“软件定点参考”必须采用 RTL 同构整数语义；PyTorch/训练浮点
  bicubic 或浮点 TinySPAN 输出只能作为画质可视化参考，不能作为 byte-exact 硬门限
- 对完整帧板端切块路线，`software_fixed_point_sr.png` 必须由
  `scripts/acceptance/make_tinyspan_tiled_fixed_reference.ps1` 生成，内部按硬件合同执行
  tile 枚举、边缘零填充、TinySPAN 定点参考、有效 SR 区域裁剪和整帧拼接

### Gate C - TinySPAN RTL 导出

输入：

- 冻结 TinySPAN checkpoint
- TinySPAN 量化方案

输出：

- TinySPAN RTL 使用的权重/参数内存文件
- TinySPAN RTL manifest
- 导出摘要

通过条件：

- RTL manifest 明确记录 checkpoint 哈希
- RTL manifest 明确记录量化方案哈希
- 没有使用仍在变化的训练 checkpoint 或旧缓存
- 导出结果必须与 TinySPAN 软件定点参考一致

### Gate D - TinySPAN RTL 仿真

输入：

- TinySPAN RTL 导出结果
- TinySPAN 软件定点向量
- tile 参数

输出：

- 层级仿真日志
- tile 级仿真日志
- 输出对比报告

通过条件：

- TinySPAN RTL tile 输出与 TinySPAN 软件定点参考逐字节一致
- 有效输出中没有未解析的 `X` / `Z`

### Gate E - TinySPAN 实现与资源约束

输入：

- TinySPAN RTL 计算核心
- TinySPAN PS/DDR tile scheduler/wrapper
- tile 参数

当前 TinySPAN 优先候选方向：

```text
Model=c32b4
Scale=X4 first, then X2
Input=320x180 for X4 720p
Tile=32x32 or resource-safe fallback
Halo=TinySPAN receptive field requirement
Board=xczu19eg-ffvc1760-2-i
Resource gate=XC7Z045 / ZC706 limits
```

通过条件：

- 为 `xczu19eg-ffvc1760-2-i` 生成 TinySPAN bitstream
- 时序通过
- XC7Z045 / ZC706 资源门限通过
- Vivado 正常退出，且没有残留的 Vivado helper 进程

### Gate F - TinySPAN 板卡冒烟测试

输入：

- 已通过实现阶段的 TinySPAN bitstream
- SD/DDR 格式的完整输入帧
- PS/PL 运行脚本

通过条件：

- 能检测到硬件目标
- TinySPAN bitstream 成功下载
- PS 初始化 DDR buffer
- PL 完成硬件切块 TinySPAN 推理
- TinySPAN 板上输出可以回读
- 板上输出对应同一完整输入帧和同一套 board-side tile 调度参数

如果 JTAG target 数量为 `0`，应停止跑板流程，先检查板卡供电、USB-JTAG、JTAG 模式、
驱动、Vivado 硬件管理器占用情况，再重新运行。

### Gate G - TinySPAN 图像一致性可视化验证

输入：

- 冻结 TinySPAN checkpoint
- 同一张完整输入帧和同一套 board-side tile 调度参数
- TinySPAN 训练/浮点模型超分输出
- TinySPAN 软件定点参考输出
- TinySPAN 板上输出

输出：

- `training_sr.png`：冻结 TinySPAN checkpoint 在训练/浮点推理路径下的超分结果
- `software_fixed_point_sr.png`：同一 checkpoint 和同一量化方案生成的软件定点参考图
- `software_tiled_fixed_point_sr.png`：按板端 tile/padding/crop 合同生成的完整帧定点参考图；
  最终验收时它是 `software_fixed_point_sr.png` 的来源
- `board_sr.png`：板卡回读的 TinySPAN 超分图
- `diff_heatmap.png`：硬件输出与训练/浮点输出的差异热力图
- `comparison_preview.png`：输入图、训练/浮点输出、软件定点输出、硬件输出、差异图的并排预览
- `image_validation.json`：机器可读指标
- `image_validation.md`：中文可读验证摘要

通过条件：

- `training_sr.png`、`software_fixed_point_sr.png`、`board_sr.png` 的尺寸一致，且目标输出为 `1280x720`
- `board_sr.png` 与 `software_fixed_point_sr.png` 对应的原始 RGB 数据逐字节一致
- `board_sr.png` 与 `training_sr.png` 的 PSNR、SSIM、MAE、最大通道差值已记录
- 默认视觉一致性门限：PSNR `>= 45 dB`、SSIM `>= 0.99`、MAE `<= 1.0` RGB level、最大通道差值 `<= 4`
- `comparison_preview.png` 和 `diff_heatmap.png` 已生成，可直接打开查看
- 如果视觉指标未达门限，必须在 `image_validation.md` 中说明原因，且不得宣告最终验收完成

说明：最终硬件正确性的硬门限仍然是“板上输出与 TinySPAN 软件定点参考逐字节一致”；
训练/浮点超分结果用于可视化和量化质量一致性检查，帮助人工确认硬件输出没有肉眼可见的异常。
其中 `software_fixed_point_sr.png` 必须由和 RTL 相同的整数 bicubic/base-add、量化、舍入与饱和规则生成。
对于最终整帧路线，还必须使用硬件同构的 tile 参考：边缘 tile 先补零到固定 tile 尺寸，
TinySPAN 输出固定 SR tile 后只裁剪左上角有效区域，再拼接回 `1280x720`。

### Gate H - TinySPAN 最终 720p30 验收

输入：

- 冻结 TinySPAN checkpoint
- TinySPAN 量化方案
- 同一张完整输入帧和同一套 board-side tile 调度参数
- 同一个 TinySPAN bitstream
- TinySPAN 板上输出

通过条件：

- 输出帧尺寸为 `1280x720`
- 板上输出 SHA256 等于 TinySPAN 软件定点参考 SHA256
- 图像一致性可视化验证通过，且 `comparison_preview.png` 可查看
- 实测吞吐不低于 `30fps`
- 资源报告通过 XC7Z045 / ZC706 门限
- 所有证据已复制到 `Tinyspan/artifacts/...`

## 9. 当前已知状态

截至 2026-06-24：

- TinySPAN 训练已经完成。
- 当前硬件安全基线已经确定为 `c32b4_30fps_frozen_20260613`。
- 该基线 checkpoint SHA256 为 `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`。
- 该基线已有 X4 软件 30fps 验收、W8A8 量化计划、整数参考和 RTL manifest 证据。
- 2026-06-18 已新增 RTL 同构 X4 软件定点参考生成路径，`320x180 -> 1280x720`
  证据位于 `Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_b_integer_reference_rtl_fixed_base_320x180_20260618`。
- `c32b4_final_20260615` 是质量更好的软件模型，并且软件侧已证明 `320x180 -> 1280x720 @ 30fps` 通过。
- `c32b4_final_20260615` 当前 fused/export 交接存在边界漂移，不能直接作为上板验收 checkpoint。
- `c32b4_30fps_frozen_20260613` 作为推进 TinySPAN RTL、bitstream 和板卡验证的硬件安全基线。
- 2026-06-20 已完成 X4 `320x180 @ 150MHz` Gate E bitstream/timing/resource 核心证据：
  `Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_e_bitstream_x4_320x180_f150_prew_20260620`。
- Gate E 最新 bitstream SHA256 为
  `B2C2F3A8571EA3FFFE596C804528AF955C19B8A56077DA879727C1AEAE91DDF2`。
- Gate E timing 通过：`clk_pl_0` period `7.000ns`，`142.857MHz`，WNS `0.074ns`。
- Gate E resource gate 通过：LUT `7371`，Register `5437`，DSP `94`，BRAM Tile `330.5`，URAM `0`，均在 ZC706 等效资源门限内。
- Gate E power report 已归档：Total On-Chip Power `3.646W`，Dynamic `2.433W`，
  Device Static `1.213W`，Confidence `Medium`。
- Gate E 理论 X4 720p 吞吐通过：RTL 仿真稳态 `5 cycles/output pixel`，
  `142.857MHz / (1280*720*5) = 31.0015fps`。
- 最终 SD 卡图片/视频帧路线必须是板端切块拼接：完整 LR 帧在 SD/DDR 中保存，PL/PS wrapper
  按 `32x32` LR tile 优先、`64x64` LR tile 备选进行读取、halo、推理、裁剪和写回。
- 2026-06-21 已完成 X4 `32x32 -> 128x128 @ 150MHz` 真实板卡 smoke 和图像一致性验证：
  `Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_f_board_x4_32x32_f150_tile32_20260621`。
- X4 32x32 board-vs-fixed 通过：mismatch bytes `0 / 49152`，max channel diff `0`，
  perf-only `81916` cycles，`1831.144098832951 fps`。
- 2026-06-24 已新增完整帧板端切块 RTL 骨架：
  `rtl/board_wrapper/sr_stream_dynamic_cropper.v` 与
  `rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v`。
- `sr_stream_dynamic_cropper` 已通过基础 Vivado/xsim，报告见
  `Tinyspan\sim\reports\sr_stream_dynamic_cropper_sim_20260624.md`。
- 已新增 `scripts/acceptance/make_tinyspan_tiled_fixed_reference.ps1` 和
  `tools/image_validation/make_tinyspan_tiled_fixed_reference.py`，用于生成
  `software_tiled_fixed_point_sr.png`、`tile_manifest.json`、`comparison_preview.png`
  和 `diff_heatmap.png`；`8x6` 小图 smoke 已通过。
- 已生成 X4 `320x180 -> 1280x720`、tile `32x32` 的 hardware-tiled fixed reference：
  `Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624`。
  该 run 包含 `60` 个 tile，checkpoint SHA256 为
  `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`，
  quant-plan SHA256 为 `EB6EEDDDE9360F61E6FC30141B2A1E6539E519CB226AC18B8C219B9E40092C9D`。
  其中 `software_tiled_fixed_point_sr.png` 是后续 X4 完整帧上板验收的 FixedPng 候选。
- `sr_tile_tinyspan_x4_writer_shell` 小帧 xsim 已通过，报告见
  `sim/reports/sr_tile_tinyspan_x4_writer_shell_sim_20260624.md`：
  `PASS sr_tile_tinyspan_x4_writer_shell tiles=4 writes=480 frame_cycles=17941`。
  该结果只证明 shell 级多 tile 仿真通过；后续 posted-write 和 tile64 FIFO bitstream、SKIP-read 上板证据已补齐，
  但仍不能替代完整输出读回和 board-vs-fixed 实测验收。
- 2026-06-24 已新增 TinySPAN 专用 DDR/PS endpoint 骨架：
  `rtl/board_wrapper/sr_ddr_tinyspan_x4_tile_writer_endpoint.v`。
  该 endpoint 通过 AXI-Lite 暴露 `start/clear`、图像尺寸、DDR 输入/输出 base、
  status、tiles_done、frame_cycles 和 error 寄存器，并把
  `sr_tile_tinyspan_x4_writer_shell` 连接到 `sr_ddr_pixel_axi_master`。
  轻量 RTL elaboration 已通过，报告见
  `sim/reports/sr_ddr_tinyspan_x4_tile_writer_endpoint_elab_20260624.md`。
  该结果证明 TinySPAN DDR endpoint 可展开，但还不是最终 burst/DMA I/O 性能证据。
- 2026-06-24 已新增并验证 TinySPAN PS/DDR X4 Block Design 创建脚本：
  `scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl` 和
  `scripts/vivado/run_vivado_create_ps_tinyspan_ddr_x4_bd.ps1`。
  该 BD 直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR 控制器或 DDR PHY；
  控制路径为 `PS M_AXI_HPM0_FPD -> sr0/s_axi`，数据路径为
  `sr0/m_axi -> PS S_AXI_HP0_FPD -> DDR`，控制基址 `0xA0000000`。
  BD 创建验证已通过，报告见 `sim/reports/ps_tinyspan_ddr_x4_bd_create_20260624.md`。
- 2026-06-25 已将 TinySPAN PS/DDR X4 BD 脚本改为默认应用 FACE-ZUSSD 参考工程的 PS DDR 配置。
  临时 BD 创建验证已通过，Vivado 日志显示 `PS_TINYSPAN_DDR_X4_DDR_REF_STATUS=applied`，
  共应用 109 对 DDR 相关属性；报告见
  `sim/reports/ps_tinyspan_ddr_x4_ddr_reference_bd_20260625.md`。该修改仍然只调用
  `zynq_ultra_ps_e` / PS DDR controller IP，不新增自研 DDR 控制器。
- 2026-06-24 已新增并跑通 TinySPAN PS/DDR X4 bitstream 生成脚本：
  `scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.tcl` 和
  `scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1`。bitstream 路线仍直接调用
  `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR 控制器或 DDR PHY。
  本次实现 `WNS=0.224ns`、`TNS=0.000ns`、`WHS=0.015ns`、`THS=0.000ns`；
  资源为 `CLB LUTs 6665 (1.28%)`、`CLB Registers 4673 (0.45%)`、
  `Block RAM Tile 9 (0.91%)`、`DSP 81 (4.12%)`；bitstream SHA256 为
  `3E4EEFCD9225A6B7BB3B6CB413FB10A891249E87D2157D9EF3D553465AD6FF7C`。
  报告见 `sim/reports/ps_tinyspan_ddr_x4_bitstream_20260624.md`。
  该结果证明 PS/DDR IP 路线已具备可下载 bitstream；仍不代表真实板上输出或 720p30 已完成。
- 2026-06-24 已新增 TinySPAN PS/DDR X4 上板 smoke 脚本：
  `scripts/board/program_tinyspan_ps_ddr_bitstream.tcl`、
  `scripts/board/run_xsct_ps_tinyspan_ddr_x4_smoke.tcl` 和
  `scripts/board/run_ps_tinyspan_ddr_x4_smoke.ps1`。该脚本链路使用 Vivado 下载 bitstream，
  XSCT/PS 写入 DDR 输入帧、配置 AXI-Lite 寄存器、启动 TinySPAN、轮询 done/error，并可从 DDR
  读回 `FULL/SAMPLE/SKIP` 输出。
- 2026-06-24 已完成 TinySPAN PS/DDR X4 `32x32 -> 128x128` 真实上板 smoke：
  `board_runs/tinyspan_ps_ddr_x4_smoke/x4_32x32_20260624_230920`。该 run 证明 bitstream 可下载、
  PS 可写入 DDR 输入、PL 可启动 TinySPAN 并写回 DDR 输出、PS/XSCT 可读回真实板上图片；
  `status=0x00000009`、`error=0x00000000`、`tiles_done=1`、`frame_cycles=430346`，
  小图单 tile 折算 `348.56fps @ 150MHz`。但 board-vs-fixed 仍失败：
  `24138 / 49152` bytes mismatch、最大通道差 `215`，观察到 32 行块重复/错位。因此它是
  上板 smoke 证据，不是正确性验收通过证据。报告见
  `sim/reports/ps_tinyspan_ddr_x4_board_smoke_32x32_20260624.md`。
- 2026-06-24 已新增并通过三层 mismatch 隔离仿真：
  `tb_span_tinyspan_w8a8_fast_backpressure`、`tb_sr_tile_tinyspan_x4_writer_shell_data`、
  `tb_sr_ddr_tinyspan_x4_endpoint_data`。这些结果说明 TinySPAN parallel core、tile shell、
  AXI-Lite endpoint 与单 beat AXI debug bridge 在行为级模型中均可逐像素对齐；下一步应重建
  当前 RTL 对应 bitstream，并复测实际 PS HP0/DDR 集成链路。
- 2026-06-25 通过 A53 baremetal DDR alias probe 证明当前旧 PS DDR 配置存在真实地址别名：
  以 `0x4000` 为间隔写入 DDR 时，读回呈现 `[1,1,3,3,5,5,7,7]` 型覆盖，说明 bit14 附近地址未正确区分。
  旧 bitstream 的 TinySPAN board-vs-fixed mismatch 与该 DDR 别名一致；后续必须先用参考 PS DDR
  配置重建 bitstream，并让 A53 alias probe 通过，再继续图像验收。
- 2026-06-25 已用 FACE-ZUSSD 参考 PS DDR 配置重建 TinySPAN PS/DDR X4 bitstream：
  SHA256 `54787AF743B84741B53C2CAF69AB52081284735F905B6A0AB379E4D0183F3F45`；
  timing 通过，`WNS=0.224ns`、`TNS=0.000ns`、`WHS=0.015ns`、`THS=0.000ns`。
- 2026-06-25 新 bitstream 的 A53 DDR alias probe 已通过：
  `A53_DDR_ALIAS_MISMATCHES=0`，`A53_DDR_ALIAS_PASS=1`。
- 2026-06-25 新 bitstream 的 TinySPAN PS/DDR X4 `32x32 -> 128x128` 真实板上 smoke 已通过：
  board-vs-fixed mismatch bytes `0 / 49152`、max channel diff `0`，小图单 tile 折算
  `381.809573747792fps @ 150MHz`。报告见
  `sim/reports/ps_tinyspan_ddr_x4_refddr_board_smoke_32x32_20260625.md`。
- 2026-06-25 已完成 TinySPAN PS/DDR X4 posted-write AXI 用户逻辑优化：
  `sr_ddr_pixel_axi_master` 的输出写路径改为 posted single-beat AXI write，并让 endpoint 等待写响应 drain
  后再上报 frame done。该改动仍直接调用板卡 PS DDR controller IP，不实现 DDR 控制器、PHY 或时序逻辑。
  行为级仿真通过：`PASS sr_ddr_tinyspan_x4_endpoint_data pixels=16384 writes=16384`。
  新 bitstream SHA256 为
  `3B7C4EEF6E2F0428ED442E06A2D5910A4156C8AAAF3F5534D605E5C15CDCCFC0`，
  timing 通过：`WNS=0.075ns`、`TNS=0.000ns`、`WHS=0.019ns`、`THS=0.000ns`；
  资源为 `CLB LUTs 6169`、`CLB Registers 4667`、`Block RAM Tile 9`、`DSP 81`。
- 2026-06-25 posted-write bitstream 的 A53 DDR alias probe 已通过；随后
  TinySPAN PS/DDR X4 `32x32 -> 128x128` 真实板上 FULL readback smoke 再次通过：
  board-vs-fixed mismatch bytes `0 / 49152`、max channel diff `0`，frame cycles `114230`，
  小图单 tile 折算 `1313.14015582597fps @ 150MHz`。
- 2026-06-25 posted-write bitstream 的完整帧 SKIP-read board smoke 已通过：
  `320x180 -> 1280x720`、tile `32x32`、`tiles_done=60`、`frame_cycles=6763572`，
  折算 `22.1776304000312fps @ 150MHz`。该结果证明板端完整帧切块与 DDR 写回能跑通，
  但因为没有读回完整输出并做 board-vs-fixed 比较，且吞吐仍低于 `30fps`，不能宣告 Gate H 完成。
  报告见 `sim/reports/ps_tinyspan_ddr_x4_posted_write_full_frame_20260625.md`。
- 2026-06-25 tile64 FIFO f155 bitstream 的完整帧 SKIP-read board smoke 已通过：
  `320x180 -> 1280x720`、tile `64x64`、`tiles_done=15`、`frame_cycles=5097068`，
  折算 `30.4096394240767fps @ 155MHz`。该结果是真实板卡完整帧吞吐过 `30fps` 的证据，
  路线仍直接调用板卡 `zynq_ultra_ps_e` / PS DDR controller IP，不自研 DDR 控制器或 PHY。
  单独看该 SKIP-read run，因为 readback mode 为 `SKIP`，不能替代完整 SR 帧 board-vs-fixed 逐字节比较。
  报告见 `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md`。
- 2026-06-25 tile64 FIFO f155 bitstream 的完整帧 A53 in-DDR compare 已通过：
  `board_runs/tinyspan_ps_ddr_x4_a53_compare/x4_320x180_tile64_fifo_f155_20260625_0559`。
  该 run 将 LR input、tile64 FixedPng reference 和 poison output buffer 放入 PS DDR，启动 TinySPAN 后固定等待，
  再由 A53 在 DDR 内部比较完整 `1280x720` SR frame。结果为 mismatch `0 / 2764800`、max diff `0`。
  该证据与上面的 SKIP-read 吞吐证据来自同一 bitstream、checkpoint、quant plan 和 tile64 contract，
  因此 X4 Gate H 的完整帧正确性与 `>=30fps` 吞吐已经闭合。报告见
  `sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md`。
- 2026-06-24 已主动停止 X4 `320x180 -> 1280x720` JTAG 全帧逐像素读回诊断 run：
  `board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_fullread_diag2`。
  停止前读到 `204800 / 921600` 个输出像素，`status=0x00000080`，说明输出端持续有效；
  但未生成完整 `board_output.rgb`，不能作为最终整帧一致性验收。该 run 证明 JTAG 全量读回耗时过高，
  后续完整帧输入输出必须改走 TinySPAN 专用 DDR/PS/DMA 路线。
- 当前仍缺 X2 独立证据和可展示 board PNG/显示/SD 写回材料；X4 完整帧吞吐已有
  tile64 FIFO f155 SKIP-read `30.4096394240767fps @155MHz` 真实板卡证据，完整帧一致性已有
  A53 in-DDR compare `0 / 2764800` mismatch 证据，
  因此 X4 子任务已经达到可交付状态。X4 Gate H 的精简可审计 manifest 已归档到
  `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`。
  X4 提交节点已归档到
  `artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_submission_node_20260625/manifest.json`，
  对应说明文档为 `docs/x4_submission_node_20260625.md`。该节点集中记录 X4 的
  `30.409639424076744fps`、`0 / 2764800` mismatch、资源/时序/功耗和可查看图像材料。
  但整赛题仍不能宣告最终完成，因为 X2 独立冻结、量化、RTL、bitstream、真实板上输出和
  `>=30fps` 证据尚未闭合。
- W8A12 DDR tile writer 相关结果仅作为历史参考，不再作为本工作流主线。
- 2026-06-18 曾启动的 W8A12 `wf18d/wf18e` Vivado 已按路线修正停止，不能作为 TinySPAN 验收结果。
- 2026-06-18 Gate E bitstream 重试已修复 TinySPAN source-list 问题；旧 fast base 的 16 读口全帧 RAM 在 `320x180` 综合时无法推断为 BRAM。
- 2026-06-20 TinySPAN fast base 已改为 XPM BRAM 显式帧缓存、预计算双线性权重、并加入量化流水线；`320x180 @ 150MHz` 实现已通过 timing/resource。
- 最终验收尚未完成；只有当同一 TinySPAN 冻结 checkpoint 与同一 TinySPAN 量化方案对应的真实板上输出与软件定点参考一致，并达到 720p30，才可以宣告完成。

## 10. 下一步

优先顺序：

1. 保持 X2 训练和 cloud quality watcher 运行；训练完成前只刷新状态，不启动 Vivado/JTAG/板卡流程。
2. X2 训练结束后运行 `run_tinyspan_c32b4_post_training_prep.ps1`，冻结 checkpoint、导出 X2 quant plan、
   X2 RTL manifest 和 readiness 报告。
3. 用 X2 独立证据补齐 RTL 仿真、bitstream、真实板上输出、board-vs-fixed 逐字节一致性、
   可视化预览和 `>=30fps` 吞吐。
4. X4 完整帧正确性与吞吐已闭合，X4 子任务可交付；X4 submission node 已归档，后续只做展示增强和回归保护，不再把 X4 当作阻塞项。
5. FACE-ZUSSD 参考 PS DDR 配置 bitstream、A53 DDR alias probe 和 X4 `32x32 -> 128x128`
   board-vs-fixed smoke 已通过；后续每次修改 PS/DDR/BD 后仍需把 alias probe 作为回归门禁。
6. 在不自研 DDR 控制器的前提下继续优化 I/O：保留板卡 PS DDR controller IP、HP/HPC 端口和
   SmartConnect，正式交付优先调用 Xilinx AXI DMA/DataMover/VDMA 等标准 IP；当前
   `sr_ddr_pixel_axi_master` 只作为 AXI 用户逻辑/调试桥，不作为最终高性能 I/O 方案。
7. X4 `1280x720` 输出已由 A53 in-DDR comparator 完成完整帧 board-vs-fixed 比较；
   后续继续补 board PNG/显示/SD 写回展示材料。
8. JTAG 后续只用于寄存器调试、小图 smoke 或应急 dump，不再作为完整帧输出读回主路径。
9. 先用 `make_tinyspan_tiled_fixed_reference.ps1` 为完整帧生成硬件同构 FixedPng、
   `tile_manifest.json`、`comparison_preview.png` 和 `diff_heatmap.png`。
10. 对 DDR 输出完整帧运行图像一致性验证；当前 A53 in-DDR compare 已证明 byte-exact，
    若需要展示，再补最终板上 `board_sr.png`、`comparison_preview.png` 和 `diff_heatmap.png`。
11. 记录完整帧实测板上 throughput，并与理论吞吐、32x32 tile throughput 分开标注。
12. 按 `check_contest_delivery_package.py` 的失败项推进，当前主缺口是 `x2_training_freeze`、`x2_gate_h`
    和 `final_audit`。
13. `c32b4_final_20260615` 暂时只作为质量提升候选；只有修复 fused/export 漂移并通过基线预检后，才能替换当前硬件基线。

### 10.1 训练完成后的固定入口

X2/X4 训练完成后，统一使用 `run_tinyspan_c32b4_post_training_prep.ps1` 推进冻结、handoff、量化计划导出、
RTL 常量导出和 readiness 预检。该脚本默认拒绝冻结仍在运行的训练 checkpoint；需要先预览命令时使用 `-DryRun`。

训练仍在运行时，只做状态刷新，不启动 Vivado/JTAG/板卡流程。状态刷新统一使用顺序入口，避免并行刷新造成
`docs\gate_status.md` 读取旧的 X2 训练进度：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\acceptance\refresh_tinyspan_delivery_status.ps1
```

如果希望训练结束后自动进入冻结、handoff、量化和 RTL 常量导出准备阶段，可启动 watcher。该 watcher 会等待
X2 训练达到目标 step 且训练进程退出；如果训练提前停止会直接失败，不会冻结半成品 checkpoint：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\watch_tinyspan_x2_training_then_postprep.ps1 `
  -Tag x2_frozen_YYYYMMDD
```

X2 硬件链路在训练结束前先用静态审计锁定缺口，尤其要防止复用 X4-only `bicubic_base_x4`
作为 X2 交付证据：

```powershell
python .\scripts\acceptance\audit_tinyspan_x2_hardware_readiness.py
```

### 10.2 X2 训练完成后的直接交付动作

从 2026-06-25 起，X2 云端训练/评估完成后不再停在“训练完成”状态，而是直接推进 X2 交付闭环。
触发条件是同时满足：

- 云端 X2 训练进程退出，且训练步数达到目标 `51480`。
- `student_last.pt` 或等价最终 checkpoint 已生成。
- full REDS val 质量报告生成。
- 本地 watcher 下载完成 X2 candidate 包：
  `G:\UESTC\feitengspan1\Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\x2_quality_candidates\x2_quality_after_x4_20260625_cloud_eval\manifest.json`。

触发后按下面顺序直接推进，不再等待额外路线选择：

1. 冻结 X2 checkpoint，记录 checkpoint SHA256、训练参数、REDS val 指标和 teacher/student 对比。
2. 导出 X2 quant plan、hardware-tiled fixed reference、RTL manifest 和 readiness 报告。
3. 先跑 X2 RTL/仿真门禁，确认 X2 `640x360 -> 1280x720` tile contract、padding/crop、地址映射和定点参考一致。
4. 生成 X2 bitstream，资源按 ZC706/XC7Z045 门限记录，同时保留实际 `xczu19eg-ffvc1760-2-i` 实现资源、WNS 和频率。
5. 上板跑 X2 PS/DDR 完整帧切块验证，输出真实板上吞吐、A53 in-DDR board-vs-fixed mismatch/max diff。
6. 生成 X2 `board_sr.png`、`comparison_preview.png`、`diff_heatmap.png`、PSNR/SSIM/MAE 和交付 manifest。
7. 运行最终交付包 audit；只有 X2 与 X4 都闭合后，才把整赛题状态改为 complete。

执行期间仍保留硬边界：如果 X2 full-val 质量包缺失、checkpoint 未冻结、量化/RTL manifest 不一致、
bitstream 未生成、真实板上输出未通过 board-vs-fixed，或吞吐低于 `30fps`，则只记录当前失败项，
不能宣告 X2 交付完成。

X2 正式训练完成后的主工程入口：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_tinyspan_c32b4_post_training_prep.ps1 `
  -RunDir runs\tinyspan_distill\video_x2_c32_b4_quality_after_x4_20260625 `
  -Scale 2 `
  -Tag x2_quality_after_x4_20260625
```

X4 路线使用同一个入口，只把 `-Scale` 改为 `4`，并使用对应的 X4 训练输出目录。若 watcher 已把云端 run
下载到 `G:\UESTC\feitengspan1\Tinyspan\runs\...`，则 `-RunDir runs\...` 是正确写法；若训练 run 保留在
主工程 `G:\UESTC\feitengspan1\runs\...`，则应使用 `..\runs\...` 或绝对路径，避免误指向错误仓库副本。

### 10.3 X2 收尾后的 X4 画质提升支线

从 2026-06-25 起，X4 画质提升训练可以在 X2 云端训练完成后继续启动，但必须满足下面的前置条件：

- 云端 X2 训练已退出，且训练步数达到目标 `51480`。
- X2 最终 checkpoint 已生成并下载到本地，至少包含 `student_last.pt` 或等价最终 checkpoint。
- X2 full REDS val 质量报告和本地 X2 candidate manifest 已生成，避免 X4 新训练抢占 X2 full-val 评估 GPU。
- X2 post-training prep 已经开始或已完成，X2 冻结、量化、RTL 准备进入本地闭环阶段。

满足条件后，可以在同一云端服务器复用 GPU 启动新的 X4 提升训练 run。新 run 必须使用独立 ID，例如：

```text
runs/tinyspan_distill/video_x4_c32_b4_quality_after_x2_YYYYMMDD
artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x4_quality_candidates/x4_quality_after_x2_YYYYMMDD_cloud_eval
```

该支线的目标是争取 X4 full REDS val `>=28dB`，但它只属于画质提升候选；在重新完成冻结、量化、fixed reference、RTL/export、
bitstream、真实板上 board-vs-fixed `0 mismatch` 和 `>=30fps` 之前，不能替换当前 X4 提交节点
`X4_SUBMIT_20260625_CURRENT_BASELINE`。

720p30 图像验收入口 `scripts\acceptance\run_tinyspan_720p30_board_acceptance.ps1` 与
`scripts\acceptance\check_tinyspan_720p30_acceptance_inputs.ps1` 已改为 scale-aware：
`-Scale 2` 要求 `640x360 -> 1280x720`，`-Scale 4` 要求 `320x180 -> 1280x720`；
tile 尺寸不再锁死为 `32x32`，只要求是 LR 帧内的正尺寸，因此兼容 X4 tile64 和后续 X2 tile 方案。

720p30 板上验收通过后，统一用只读打包脚本生成 Gate H 交付 manifest。该脚本只整理已有
summary、图片预览、diff heatmap、checkpoint/quant/bitstream 哈希和吞吐/正确性结果，不启动
Vivado、JTAG、XSCT、板卡或训练流程：

```powershell
python .\scripts\acceptance\package_tinyspan_gate_h_board_acceptance.py `
  --repo-root . `
  --acceptance-dir artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x2_640x360_tile64x64 `
  --scale 2 `
  --input-width 640 `
  --input-height 360 `
  --tile-width 64 `
  --tile-height 64 `
  --tile-count 60 `
  --status PASS_X2 `
  --route "TinySPAN PS/DDR X2 via board zynq_ultra_ps_e / PS DDR controller IP"
```

训练完成后仍不能直接宣告通过；post-training prep 只补齐冻结、量化和 RTL 导出入口。后续仍需完成对应倍率的
RTL 仿真、bitstream、真实板上输出、board-vs-fixed 逐字节一致性、可视化预览和 `>=30fps` 实测吞吐。

最终交付前必须运行只读交付包校验。当前 X2 未闭合时可以使用 `-AllowIncomplete` 对应的脚本参数
`--allow-incomplete` 生成 `NOT_COMPLETE` 报告；真正提交赛题时必须去掉该参数，且脚本退出码为 `0`：

```powershell
python .\scripts\acceptance\check_contest_delivery_package.py `
  --repo-root . `
  --artifact-dir artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe
```

该校验只读取 `contest_completion_status.json`、`contest_delivery_audit.json`、`contest_delivery_index.json`、
X2/X4 Gate H manifest、图像验证材料和文档/源码索引，不启动 Vivado、JTAG、XSCT、板卡或训练流程。

## 11. 2026-06-26 当前状态节点

截至 2026-06-26 06:31，本轮 TinySPAN 赛题交付状态如下：

- X2 云端训练已完成：`runs/tinyspan_distill/video_x2_c32_b4_quality_after_x4_20260625`，最终 `epoch=13`、`step=51480 / 51480`，冻结 checkpoint 为 `runs/tinyspan_frozen_candidates/x2_quality_after_x4_20260625/student_final.pt`。
- X2 全量 REDS `val_sharp` 软件质量评估已完成：`3000` 张，student PSNR mean `31.121459919373763 dB`，bicubic PSNR mean `30.853986135469682 dB`，gain `0.26747378390408016 dB`，满足 X2 `>=30dB` 软件质量目标。
- X2 post-training prep 已完成：冻结 checkpoint、handoff、W8A8 quant plan、RTL export、`640x360 -> 1280x720` tile64 fixed reference 均已生成。
- X2 Gate H 上板验收已闭合：`artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x2_640x360_f188_div8_tile64_rgbpipe_20260626/manifest.json`，`PASS_X2`，`32.86048226988138fps @ 187.512MHz`，`mismatch=0 / 2764800`，`max_diff=0`。
- X2 bitstream：`vivado/bitstreams/tinyspan_x2_c32b4_x2_quality_after_x4_20260625_tile64_o16_wrpipe_rgbpipe_f188_div8_perf_board.bit`，SHA256 `2F9FA110D282D14D857777D10F83DDDB0124A14F059C434AFC9C442A3DF62B48`。
- X2 PPA：CLB LUT `6647`，CLB Register `5031`，DSP `100`，BRAM Tile `27`，URAM `0`，WNS `+0.002ns`，WHS `+0.014ns`，总功耗 `4.053W`。
- X2 正确性证明采用 A53 bare-metal DDR 内对比：PL 输出和同一冻结 checkpoint/quant plan 的 fixed reference 在 DDR 中逐字节一致；可查看图 `board_sr_a53_equal_to_fixed.png` 是在 `0 mismatch` 证明后复制 fixed reference 作为等价视图，不是慢速整帧 JTAG 读回图。
- X4 Gate H 仍采用当前可提交硬件安全基线：`gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json`，`30.409639424076744fps`，`mismatch=0 / 2764800`，`max_diff=0`。
- X4 后续画质提升可以在 X2 闭合后继续作为支线推进；已跑过的 `x4_quality_after_x2_20260625_cloud_eval` 未达到替换门槛，不替换当前 X4 submission baseline。新的 X4 提升训练只有重新完成冻结、量化、RTL/export、bitstream、真实板上 `0 mismatch` 和 `>=30fps` 后，才允许成为替代提交节点。
- 只读交付包校验已通过：`docs/contest_delivery_package_check.md` 显示 `STATUS PASS`，`required_failed_count=0`；`contest_delivery_audit.json` 的 `accepted=true`。

### 11.1 2026-06-26 X4/X2 画质提升节点

本节只描述画质提升分支，不覆盖已经可提交的 X4/X2 Gate H 硬件基线。提质候选必须先通过软件全量 REDS
`val_sharp` 质量门槛；只有软件候选达标后，才允许进入冻结、量化、RTL/export、bitstream 和真实上板替换流程。

| 节点 | 状态 | 目标 | 当前证据/路径 | 通过条件 |
| --- | --- | --- | --- | --- |
| `QUALITY_X4_HRHEAVY_P256_20260626` | `RUNNING` | 在保持 TinySPAN `c32/b4` 硬件拓扑不变的前提下，将 X4 full REDS val PSNR 从上一轮 `26.384690521945394dB` 提升到 `>=28dB`，并记录相对 bicubic 的 gain | 云端 run：`/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x4_c32_b4_quality_hrheavy_p256_20260626`；resume：`video_x4_c32_b4_quality_after_x2_20260625/student_last.pt`；参数：`scale=4`、`patch=256`、`batch=3`、`lr=2e-5`、`distill/hr/edge/temporal=0.25/1.20/0.03/0.05`；截至远端 `2026-06-26 06:59:26`，训练约 `epoch=2`、`step=8269`、stderr 为空 | 生成 `student_last.pt`，完成 `3000` 张 REDS `val_sharp` 全量评估；`student_psnr_mean_db >= 28.0` 且 `student_psnr_gain_over_bicubic_db > 0`；候选包写入 `artifacts/.../x4_quality_candidates/x4_quality_hrheavy_p256_20260626/manifest.json` |
| `QUALITY_X2_HRHEAVY_AFTER_X4_20260626` | `QUEUED_AFTER_X4` | 在当前 X2 已交付模型 `31.121459919373763dB` 基础上继续提升，至少保持 `>=30dB`，争取超过当前 X2 full-val PSNR | 云端待启动 run：`/root/autodl-tmp/Tinyspan/runs/tinyspan_distill/video_x2_c32_b4_quality_hrheavy_after_x4_20260626`；resume：`video_x2_c32_b4_quality_after_x4_20260625/student_last.pt`；由 `watch_x4_x2_hrheavy_20260626.sh` 在 X4 评估/打包后自动启动 | 生成 `student_last.pt`，完成 `3000` 张 REDS `val_sharp` 全量评估；`student_psnr_mean_db >= 30.0`，并与当前 X2 基线 `31.121459919373763dB` 比较是否真实提升；候选包写入 `artifacts/.../x2_quality_candidates/x2_quality_hrheavy_after_x4_20260626/manifest.json` |
| `QUALITY_PROMOTE_TO_BOARD_GATE` | `WAITING_FOR_SOFTWARE_PASS` | 把达标软件候选升级为可替换硬件提交节点 | 仅当上面某个候选 full-val PASS 后触发 | 重新冻结 checkpoint、导出 quant plan、生成硬件同构 fixed reference 和 RTL/export manifest；重新生成 bitstream；真实板上 `board-vs-fixed mismatch=0`、`max diff=0`、吞吐 `>=30fps`；资源/WNS/PPA 和可查看图像材料全部归档 |

远端 watcher：

- 主 watcher：`/root/autodl-tmp/Tinyspan/logs/cloud/watch_x4_x2_hrheavy_20260626.out.log`。职责：等待 X4
  训练完成，运行 X4 full-val 质量评估并打包，然后启动 X2 提质训练。
- X2 打包兜底 watcher：`/root/autodl-tmp/Tinyspan/logs/cloud/watch_x2_quality_package_20260626.out.log`。职责：等待 X2
  full-val JSON 和 `student_last.pt` 同时存在后，生成 X2 提质候选 manifest。

硬边界：

- `QUALITY_X4_HRHEAVY_P256_20260626` 即使软件 PSNR 提升，也不能自动替换
  `X4_SUBMIT_20260625_CURRENT_BASELINE`；替换必须经过 `QUALITY_PROMOTE_TO_BOARD_GATE`。
- `QUALITY_X2_HRHEAVY_AFTER_X4_20260626` 若只是保持 `>=30dB` 但没有超过当前 X2 `31.121459919373763dB`
  基线，只记录为回归候选，不作为“X2 提质成功”声明。
- 提质训练期间不启动 Vivado/JTAG/XSCT/板卡流程；只读状态、训练日志、质量 JSON 和候选 manifest。

## 12. 完成定义

只有当 X2 和 X4 所需模式都具备完整 TinySPAN 证据包，并满足以下条件时，任务才算完成：

```text
同一 TinySPAN 冻结 checkpoint
同一 TinySPAN 量化方案
同一完整输入帧
同一个 TinySPAN bitstream
TinySPAN 硬件同构 tile 软件定点输出 == TinySPAN 板上输出，逐字节一致
训练/浮点超分图与板上超分图完成可视化一致性验证
comparison_preview.png 和 diff_heatmap.png 可查看
AI 模型、训练、量化、模型到硬件转换工具和硬件设计文档齐备
Vivado 仿真、综合/实现、bitstream 和 PPA 证据齐备
输出分辨率 == 1280x720
实测吞吐 >= 30fps
资源门限 == PASS
```
