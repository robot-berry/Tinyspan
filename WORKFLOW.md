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
- 最终验收不接受 PC 端提前切好的小块作为板卡输入
- 板上输出必须与同一 TinySPAN 冻结 checkpoint、同一 TinySPAN 量化方案生成的软件定点参考逐字节一致

## 4. 路线锁定

当前路线：

```text
TinySPAN frozen checkpoint
 -> TinySPAN quant plan
 -> TinySPAN fixed-point software reference
 -> TinySPAN RTL/export
 -> TinySPAN PS/DDR hardware tile scheduler
 -> TinySPAN bitstream on xczu19eg
 -> real board output
 -> board output == TinySPAN software fixed-point reference
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

硬件必须负责切块、halo 读取、边界处理和最终输出位置写回。软件可以准备原始完整输入帧，
也可以验证最终输出，但最终验收跑板时不能由 PC 端预先把图像切成推理小块。

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
- `board_sr.png`
- `diff_heatmap.png`
- `comparison_preview.png`
- `image_validation.json`
- `image_validation.md`
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

如果 JTAG target 数量为 `0`，应停止跑板流程，先检查板卡供电、USB-JTAG、JTAG 模式、
驱动、Vivado 硬件管理器占用情况，再重新运行。

### Gate G - TinySPAN 图像一致性可视化验证

输入：

- 冻结 TinySPAN checkpoint
- 同一张完整输入帧
- TinySPAN 训练/浮点模型超分输出
- TinySPAN 软件定点参考输出
- TinySPAN 板上输出

输出：

- `training_sr.png`：冻结 TinySPAN checkpoint 在训练/浮点推理路径下的超分结果
- `software_fixed_point_sr.png`：同一 checkpoint 和同一量化方案生成的软件定点参考图
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

### Gate H - TinySPAN 最终 720p30 验收

输入：

- 冻结 TinySPAN checkpoint
- TinySPAN 量化方案
- 同一张完整输入帧
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

截至 2026-06-18：

- TinySPAN 训练已经完成。
- 当前硬件安全基线已经确定为 `c32b4_30fps_frozen_20260613`。
- 该基线 checkpoint SHA256 为 `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`。
- 该基线已有 X4 软件 30fps 验收、W8A8 量化计划、整数参考和 RTL manifest 证据。
- `c32b4_final_20260615` 是质量更好的软件模型，并且软件侧已证明 `320x180 -> 1280x720 @ 30fps` 通过。
- `c32b4_final_20260615` 当前 fused/export 交接存在边界漂移，不能直接作为上板验收 checkpoint。
- `c32b4_30fps_frozen_20260613` 可以作为推进 TinySPAN RTL、bitstream 和板卡验证的硬件安全基线。
- 该基线目前仍缺真实 TinySPAN bitstream 和真实板上输出，不能宣告最终上板验收完成。
- W8A12 DDR tile writer 相关结果仅作为历史参考，不再作为本工作流主线。
- 2026-06-18 曾启动的 W8A12 `wf18d/wf18e` Vivado 已按路线修正停止，不能作为 TinySPAN 验收结果。
- 最终验收尚未完成；只有当同一 TinySPAN 冻结 checkpoint 与同一 TinySPAN 量化方案对应的真实板上输出与软件定点参考一致，并达到 720p30，才可以宣告完成。

## 10. 下一步

优先顺序：

1. 以 `c32b4_30fps_frozen_20260613` 作为 TinySPAN 上板安全基线，生成 `baseline_decision.md` 和 `baseline_manifest.json`。
2. 把该基线的 checkpoint、quant plan、整数参考、RTL manifest 和 readiness 摘要迁移或归档到 `Tinyspan/artifacts/...`。
3. 基于该基线继续 TinySPAN RTL/export 与 RTL 仿真，确保 manifest、定点参考、RTL 仿真来自同一个 checkpoint 和同一个 quant plan。
4. 生成真实 TinySPAN bitstream；bitstream 文件、utilization、timing、power 和 resource gate 报告必须进入同一个证据包。
5. 运行真实板卡 smoke，取得真实板上输出；selftest 或把软件图复制成 board 图不能替代真实板上输出。
6. 运行图像一致性验证，生成 `comparison_preview.png` 和 `diff_heatmap.png`。
7. 完成 X4 后补齐 X2 的独立证据包。
8. `c32b4_final_20260615` 暂时只作为质量提升候选；只有修复 fused/export 漂移并通过基线预检后，才能替换当前硬件基线。

## 11. 完成定义

只有当 X2 和 X4 所需模式都具备完整 TinySPAN 证据包，并满足以下条件时，任务才算完成：

```text
同一 TinySPAN 冻结 checkpoint
同一 TinySPAN 量化方案
同一完整输入帧
同一个 TinySPAN bitstream
TinySPAN 软件定点输出 == TinySPAN 板上输出，逐字节一致
训练/浮点超分图与板上超分图完成可视化一致性验证
comparison_preview.png 和 diff_heatmap.png 可查看
AI 模型、训练、量化、模型到硬件转换工具和硬件设计文档齐备
Vivado 仿真、综合/实现、bitstream 和 PPA 证据齐备
输出分辨率 == 1280x720
实测吞吐 >= 30fps
资源门限 == PASS
```
