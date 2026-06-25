"""Audit TinySPAN contest delivery evidence without running hardware flows.

The audit maps the contest requirements to committed source files and curated
artifact evidence. It is read-only: no Vivado, JTAG, board access, or training
command is started here.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def latest_json(root: Path, pattern: str) -> tuple[dict[str, Any] | None, Path | None]:
    candidates = [path for path in root.glob(pattern) if path.is_file()]
    if not candidates:
        return None, None
    latest = max(candidates, key=lambda path: path.stat().st_mtime)
    return load_json(latest), latest


def evidence(repo_root: Path, paths: list[str]) -> list[dict[str, Any]]:
    rows = []
    for item in paths:
        full = repo_root / item
        rows.append(
            {
                "path": item,
                "exists": full.exists(),
                "kind": "dir" if full.is_dir() else "file" if full.is_file() else "missing",
            }
        )
    return rows


def status_from_paths(repo_root: Path, paths: list[str]) -> str:
    exists = [(repo_root / item).exists() for item in paths]
    if all(exists):
        return "PASS"
    if any(exists):
        return "PARTIAL"
    return "BLOCKED"


def item(
    item_id: str,
    name: str,
    status: str,
    evidence_rows: list[dict[str, Any]],
    conclusion: str,
    next_action: str,
) -> dict[str, Any]:
    return {
        "id": item_id,
        "name": name,
        "status": status,
        "evidence": evidence_rows,
        "conclusion": conclusion,
        "next_action": next_action,
    }


def gate_status(completion: dict[str, Any] | None, gate: str) -> str:
    if not completion:
        return ""
    for row in completion.get("gates", []):
        if row.get("gate") == gate:
            return str(row.get("status", ""))
    return ""


def build_audit(repo_root: Path, artifact_dir: Path) -> dict[str, Any]:
    completion = load_json(repo_root / artifact_dir / "contest_completion_status.json")
    gate_h, gate_h_path = latest_json(repo_root / artifact_dir, "gate_h_board_x4_320x180_*/manifest.json")
    x2_status, x2_status_path = latest_json(repo_root / artifact_dir, "x2_training_*/x2_training_status.json")
    if x2_status is None:
        x2_status, x2_status_path = latest_json(repo_root / artifact_dir, "x2_training_start_*/x2_training_status.json")

    x4_ready = bool(gate_h and (gate_h.get("package_pass") or gate_h.get("pass")))
    x2_ready = gate_status(completion, "X2") == "PASS"

    items: list[dict[str, Any]] = []
    items.append(
        item(
            "model_structure",
            "AI 模型结构说明文档及源代码",
            status_from_paths(repo_root, ["docs/model_design.md", "train/span_model.py", "configs/distill_tinyspan_video_x2_c32_b4.json"]),
            evidence(
                repo_root,
                [
                    "docs/model_design.md",
                    "train/span_model.py",
                    "configs/distill_tinyspan_video_x2_c32_b4.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/baseline_manifest.json",
                ],
            ),
            "TinySPAN C32/B4 主线模型结构、X4 硬件安全基线和 X2 训练配置已有归档。",
            "X2 训练完成后补充冻结 checkpoint SHA256 与最终模型状态。",
        )
    )
    items.append(
        item(
            "training",
            "训练说明文档及源代码",
            "PASS" if x2_ready else "PARTIAL" if x2_status and x2_status.get("status") == "training_running" else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/training_quantization.md",
                    "train/distill_tinyspan_video.py",
                    "scripts/train_tinyspan_video_x2_c32_b4.ps1",
                    "scripts/start_tinyspan_c32b4_x2_training.ps1",
                    str((x2_status_path or Path("")).relative_to(repo_root)) if x2_status_path else "",
                ],
            ),
            "X2 独立训练、冻结 checkpoint、量化和上板交付证据已按 Gate H manifest 闭合。" if x2_ready else "X4 训练/冻结材料已有基线；X2 独立训练正在运行但尚未完成。",
            "汇总 X2/X4 最终交付材料。" if x2_ready else "等待 X2 训练完成后运行 post-training prep，生成冻结和量化证据。",
        )
    )
    items.append(
        item(
            "quantization",
            "量化说明文档、量化计划和定点参考",
            "PARTIAL" if not x2_ready else "PASS",
            evidence(
                repo_root,
                [
                    "docs/training_quantization.md",
                    "quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8",
                    "tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py",
                    "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/tinyspan_tiled_fixed_reference_summary.json",
                ],
            ),
            "X4 W8A8 量化计划、定点参考和 tile64 整帧固定点参考已闭合；X2 量化仍缺。",
            "X2 freeze 后导出 X2 W8A8 quant plan，并生成 X2 定点/切块参考。",
        )
    )
    items.append(
        item(
            "model_to_hardware",
            "模型到硬件加速器转换工具",
            status_from_paths(
                repo_root,
                [
                    "scripts/prepare_tinyspan_c32b4_realtime_handoff.ps1",
                    "scripts/prepare_tinyspan_hardware_handoff.ps1",
                    "scripts/run_tinyspan_c32b4_post_training_prep.ps1",
                    "tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py",
                ],
            ),
            evidence(
                repo_root,
                [
                    "scripts/prepare_tinyspan_c32b4_realtime_handoff.ps1",
                    "scripts/prepare_tinyspan_hardware_handoff.ps1",
                    "scripts/run_tinyspan_c32b4_post_training_prep.ps1",
                    "tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py",
                ],
            ),
            "X2/X4 通用 post-training handoff 入口已补齐，X4 RTL 导出证据已归档。",
            "X2 训练完成后用同一入口生成 X2 RTL manifest 与 readiness。",
        )
    )
    items.append(
        item(
            "hardware_design",
            "硬件加速器详细设计文档及源代码",
            "PARTIAL" if not x2_ready else "PASS",
            evidence(
                repo_root,
                [
                    "docs/hardware_design.md",
                    "docs/x2_hardware_readiness.md",
                    "rtl/tinyspan_core",
                    "rtl/board_wrapper/sr_stream_dynamic_cropper.v",
                    "rtl/board_wrapper/sr_ddr_pixel_axi_master.v",
                    "rtl/board_wrapper/sr_tile_fetch_stream_shell.v",
                ],
            ),
            "X4 TinySPAN core、完整帧切块 shell、PS/DDR wrapper 和板卡 IP 路线已归档；X2 独立硬件证据仍缺。",
            "继续保持不自研 DDR，X2 完成后补齐 X2 RTL/bitstream/board evidence。",
        )
    )
    items.append(
        item(
            "vivado",
            "Vivado 仿真、综合/实现和 bitstream 证据",
            "PARTIAL" if x4_ready and not x2_ready else "PASS" if x4_ready and x2_ready else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/verification_plan.md",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json",
                    "sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md",
                    "sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md",
                    str((gate_h_path or Path("")).relative_to(repo_root)) if gate_h_path else "",
                ],
            ),
            "X4 已有 bitstream、timing/resource、真实板上 30fps 吞吐和完整帧一致性证据。",
            "继续补 X2 独立 bitstream 与上板证据。",
        )
    )
    items.append(
        item(
            "verification",
            "完善的验证方案与验证用例",
            "PARTIAL" if x4_ready and not x2_ready else "PASS" if x4_ready and x2_ready else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/verification_plan.md",
                    "docs/x2_hardware_readiness.md",
                    "docs/gate_status.md",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png",
                ],
            ),
            "X4 32x32 小图和 720p 整帧均已有正确性/吞吐验证；X2 独立验证仍缺。",
            "X2 完成后复用同一验证矩阵补齐证据。",
        )
    )
    items.append(
        item(
            "ppa",
            "PPA 指标与资源门线分析",
            "PARTIAL" if not x2_ready else "PASS",
            evidence(
                repo_root,
                [
                    "docs/ppa_analysis.md",
                    "sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_h_board_x4_320x180_f150_tiledref_tile64_fifo_f155_20260625/manifest.json",
                ],
            ),
            "X4 PPA 已可支撑子任务交付：低资源、WNS 过线、板上 `30.4096fps`。",
            "X2 完成后汇总 X2/X4 最终 PPA。",
        )
    )

    accepted = x4_ready and x2_ready and all(row["status"] == "PASS" for row in items)
    blockers = [] if accepted else [
        "X4 子任务已达到可交付状态，但整赛题不能宣告完成。",
        "X2 独立证据仍缺：冻结、量化、RTL、bitstream、真实板上输出和 >=30fps 吞吐。",
        "展示增强项可继续补：board PNG、HDMI/display 输出或 SD 写回图。",
    ]

    return {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "repo_root": str(repo_root),
        "artifact_dir": str(artifact_dir),
        "accepted": accepted,
        "acceptance_status": "PASS" if accepted else "NOT_COMPLETE",
        "x4_gate_h": {
            "status": "PASS_X4" if x4_ready else "MISSING",
            "manifest": str(gate_h_path) if gate_h_path else "",
        },
        "x2_status": {
            "status": (x2_status or {}).get("status", "UNKNOWN"),
            "artifact": str(x2_status_path) if x2_status_path else "",
        },
        "items": items,
        "blockers": blockers,
        "next_commands": [
            {
                "when": "X2 训练完成后",
                "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run_tinyspan_c32b4_post_training_prep.ps1 -RunDir ..\\runs\\tinyspan_distill\\video_x2_c32_b4_reds_temporal_quality_resume_20260625 -Scale 2 -Tag x2_quality_resume_YYYYMMDD",
            }
        ],
    }


def write_markdown(path: Path, audit: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN 赛题交付审计",
        "",
        f"生成时间：`{audit['generated_at']}`",
        f"总体结论：`{audit['acceptance_status']}`",
        "",
        "本审计只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。",
        "",
        "## 交付项状态",
        "",
        "| 项目 | 状态 | 结论 | 下一步 |",
        "| --- | --- | --- | --- |",
    ]
    for row in audit["items"]:
        lines.append(f"| {row['name']} | `{row['status']}` | {row['conclusion']} | {row['next_action']} |")

    lines.extend(["", "## 当前阻塞项", ""])
    for blocker in audit["blockers"]:
        lines.append(f"- {blocker}")
    if not audit["blockers"]:
        lines.append("- 无")

    lines.extend(["", "## 下一步命令", ""])
    for cmd in audit["next_commands"]:
        lines.extend([f"- {cmd['when']}：", "", "```powershell", cmd["command"], "```", ""])

    lines.extend(["## 证据索引", ""])
    for row in audit["items"]:
        lines.extend([f"### {row['name']}", ""])
        for ev in row["evidence"]:
            if not ev["path"]:
                continue
            mark = "PASS" if ev["exists"] else "MISS"
            lines.append(f"- `{mark}` `{ev['path']}`")
        lines.append("")

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe"),
    )
    parser.add_argument(
        "--json-out",
        type=Path,
        default=Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_delivery_audit.json"),
    )
    parser.add_argument("--md-out", type=Path, default=Path("docs/contest_delivery_audit.md"))
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    audit = build_audit(repo_root, args.artifact_dir)
    json_out = repo_root / args.json_out
    md_out = repo_root / args.md_out
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(md_out, audit)
    print(f"WROTE {json_out}")
    print(f"WROTE {md_out}")
    print(f"STATUS {audit['acceptance_status']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
