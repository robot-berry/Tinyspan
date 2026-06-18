# TinySPAN 720p30 X2/X4 上板验收工作流

## 1. 目标

实现对降采样后的图片或视频帧进行实时 X2/X4 超分，最终在现有
`xczu19eg-ffvc1760-2-i` 板卡上运行，同时以 ZC706 / XC7Z045 的资源规模作为
约束门限。最终验收输出必须是完整 `1280x720` 画面，并且吞吐达到 `30fps` 或更高。

本工作流默认以下约束成立：

- 实际运行板卡：`xczu19eg-ffvc1760-2-i`
- 资源约束门限：XC7Z045 / ZC706
- X2 输入输出约定：`640x360 -> 1280x720`
- X4 输入输出约定：`320x180 -> 1280x720`
- 大图从 SD 卡或 DDR 输入，由硬件负责切块
- 最终验收不接受 PC 端提前切好的小块作为板卡输入
- 板上输出必须与同一冻结模型、同一量化方案生成的软件定点参考逐字节一致

## 2. 资源约束门限

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

## 3. 必须支持的数据流

```text
SD 卡或 DDR 中的完整输入帧
 -> PS 配置寄存器
 -> PL 侧切块调度器
 -> DDR halo / tile 读取
 -> RGB 归一化与量化
 -> TinySPAN / SPAN 计算核心
 -> tail 与 PixelShuffle X2 或 X4
 -> RGB888 输出写回
 -> DDR 中的 1280x720 输出帧
 -> PS 回读或显示通路
```

硬件必须负责切块、halo 读取、边界处理和最终输出位置写回。软件可以准备原始完整输入帧，
也可以验证最终输出，但最终验收跑板时不能由 PC 端预先把图像切成推理小块。

## 4. 工程产物放置规则

后续这个工作流产生的验收材料统一放到：

```text
G:\UESTC\feitengspan1\Tinyspan\artifacts
```

每一次独立运行使用一个目录：

```text
artifacts/YYYYMMDD_scale_model_tile_freq_shorttag/
```

示例：

```text
artifacts/20260618_x4_w8a12_tile20_h21_f50_origboard/
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

Vivado 临时目录、`.Xil`、中间构建目录和过大的原始日志不建议直接上传到 Git；
需要时在 `run_summary.md` 中摘要说明，并保留可复现实验结论所需的关键证据。

## 5. 分阶段工作流

### Gate A - 冻结模型

输入：

- 最终训练 checkpoint
- 最终 `metrics.csv`
- 模型配置文件

输出：

- 冻结后的 checkpoint 副本
- SHA256 哈希
- 最后一行训练指标

通过条件：

- checkpoint 已固定用于本次验收
- 没有训练进程继续修改该 checkpoint
- 记录 checkpoint 哈希和最终指标

### Gate B - 量化与软件定点参考

输入：

- 冻结 checkpoint
- 校准集
- 目标倍率：X2 或 X4

输出：

- 量化方案
- 整数/定点软件参考
- 参考输出图片或帧

通过条件：

- 量化方案和软件参考来自同一个冻结 checkpoint
- 记录量化方案与软件参考输出的 SHA256 哈希

### Gate C - RTL 导出

输入：

- 冻结 checkpoint
- 量化方案

输出：

- RTL 使用的权重/参数内存文件
- RTL manifest
- 导出摘要

通过条件：

- RTL manifest 明确记录 checkpoint 哈希
- RTL manifest 明确记录量化方案哈希
- 没有使用仍在变化的训练 checkpoint 或旧缓存

### Gate D - RTL 仿真

输入：

- RTL 导出结果
- 软件定点向量
- tile 参数

输出：

- 层级仿真日志
- tile 级仿真日志
- 输出对比报告

通过条件：

- RTL tile 输出与软件定点参考逐字节一致
- 有效输出中没有未解析的 `X` / `Z`

### Gate E - 实现与资源约束

输入：

- RTL 计算核心
- PS/DDR tile writer wrapper
- tile 参数

当前优先尝试的低并行候选参数：

```text
TileW=20
TileH=20
Halo=21
PL clock=50MHz
OutLanes=1
TapLanes=4
ScaleLanes=1
```

通过条件：

- 为 `xczu19eg-ffvc1760-2-i` 生成 bitstream
- 时序通过
- XC7Z045 / ZC706 资源门限通过
- Vivado 正常退出，且没有残留的 Vivado helper 进程

### Gate F - 板卡冒烟测试

输入：

- 已通过实现阶段的 bitstream
- SD/DDR 格式的完整输入帧
- PS/PL 运行脚本

通过条件：

- 能检测到硬件目标
- bitstream 成功下载
- PS 初始化 DDR buffer
- PL 完成硬件切块推理
- 板上输出可以回读

如果 JTAG target 数量为 `0`，应停止跑板流程，先检查板卡供电、USB-JTAG、JTAG 模式、
驱动、Vivado 硬件管理器占用情况，再重新运行。

### Gate G - 最终 720p30 验收

输入：

- 冻结 checkpoint
- 量化方案
- 同一张完整输入帧
- 同一个 bitstream
- 板上输出

通过条件：

- 输出帧尺寸为 `1280x720`
- 板上输出 SHA256 等于软件定点参考 SHA256
- 实测吞吐不低于 `30fps`
- 资源报告通过 XC7Z045 / ZC706 门限
- 所有证据已复制到 `Tinyspan/artifacts/...`

## 6. 当前已知状态

截至 2026-06-18：

- TinySPAN 训练已经完成。
- 面向原板卡的低并行 W8A12 DDR tile writer bitstream 已通过时序和 XC7Z045 资源门限。
- 最近一次板卡冒烟测试还没有进入 bitstream 下载阶段，因为 Vivado 检测到 `0` 个 JTAG target。
- 最终验收尚未完成；只有当同一冻结 checkpoint 与同一量化方案对应的真实板上输出
  与软件定点参考一致，并达到 720p30，才可以宣告完成。

## 7. 完成定义

只有当 X2 和 X4 所需模式都具备完整证据包，并满足以下条件时，任务才算完成：

```text
同一冻结 checkpoint
同一量化方案
同一完整输入帧
同一个 bitstream
软件定点输出 == 板上输出，逐字节一致
输出分辨率 == 1280x720
实测吞吐 >= 30fps
资源门限 == PASS
```
