# TinySPAN 720p30 X2/X4 上板验收工作流

## 1. 主线目标

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

## 2. 路线锁定

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
 -> 1280x720 >= 30fps
```

明确不作为验收路线：

- W8A12 DDR tile writer
- full SPAN JTAG 小图 smoke
- ZC706/PS7 实板切换路线
- PC 端预切 tile 后再送板卡推理

这些结果可以作为历史参考、资源估算或硬件接口经验，但不能替代 TinySPAN 的最终验收证据。

## 3. 资源约束门限

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

## 4. 必须支持的数据流

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

## 5. 工程产物放置规则

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

Vivado 临时目录、`.Xil`、中间构建目录和过大的原始日志不建议直接上传到 Git；
需要时在 `run_summary.md` 中摘要说明，并保留可复现实验结论所需的关键证据。

## 6. 分阶段工作流

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

### Gate G - TinySPAN 最终 720p30 验收

输入：

- 冻结 TinySPAN checkpoint
- TinySPAN 量化方案
- 同一张完整输入帧
- 同一个 TinySPAN bitstream
- TinySPAN 板上输出

通过条件：

- 输出帧尺寸为 `1280x720`
- 板上输出 SHA256 等于 TinySPAN 软件定点参考 SHA256
- 实测吞吐不低于 `30fps`
- 资源报告通过 XC7Z045 / ZC706 门限
- 所有证据已复制到 `Tinyspan/artifacts/...`

## 7. 当前已知状态

截至 2026-06-18：

- TinySPAN 训练已经完成。
- `c32b4_final_20260615` 是质量更好的软件模型，并且软件侧已证明 `320x180 -> 1280x720 @ 30fps` 通过。
- `c32b4_final_20260615` 当前 fused/export 交接存在边界漂移，不能直接作为上板验收 checkpoint。
- `c32b4_30fps_frozen_20260613` 是目前已证明 TinySPAN fused manifest 与软件输出逐字节一致的硬件安全候选。
- W8A12 DDR tile writer 相关结果仅作为历史参考，不再作为本工作流主线。
- 2026-06-18 曾启动的 W8A12 `wf18d` Vivado 已按路线修正停止，不能作为 TinySPAN 验收结果。
- 最终验收尚未完成；只有当同一 TinySPAN 冻结 checkpoint 与同一 TinySPAN 量化方案对应的真实板上输出与软件定点参考一致，并达到 720p30，才可以宣告完成。

## 8. 下一步

优先顺序：

1. 以 `c32b4_30fps_frozen_20260613` 作为 TinySPAN 上板安全基线，整理 checkpoint、quant plan、软件定点参考的哈希证据。
2. 或者先修复 `c32b4_final_20260615` 的 fused/export 边界漂移，再把它提升为上板候选。
3. 生成 TinySPAN RTL/export，确保 manifest、定点参考、RTL 仿真来自同一个 TinySPAN checkpoint 和同一个 quant plan。
4. 再进入 TinySPAN bitstream、板卡 smoke 和最终 720p30 验收。

## 9. 完成定义

只有当 X2 和 X4 所需模式都具备完整 TinySPAN 证据包，并满足以下条件时，任务才算完成：

```text
同一 TinySPAN 冻结 checkpoint
同一 TinySPAN 量化方案
同一完整输入帧
同一个 TinySPAN bitstream
TinySPAN 软件定点输出 == TinySPAN 板上输出，逐字节一致
输出分辨率 == 1280x720
实测吞吐 >= 30fps
资源门限 == PASS
```
