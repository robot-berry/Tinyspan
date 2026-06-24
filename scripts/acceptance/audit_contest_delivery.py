"""Audit TinySPAN contest delivery evidence without running hardware flows.

The audit maps the contest requirements to concrete repository files and
artifact evidence. It is intentionally read-only: no Vivado, JTAG, board, or
training command is started here.
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


def exists(repo_root: Path, path: str) -> bool:
    return (repo_root / path).exists()


def evidence(repo_root: Path, paths: list[str]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in paths:
        full = repo_root / path
        rows.append(
            {
                "path": path,
                "exists": full.exists(),
                "kind": "dir" if full.is_dir() else "file" if full.is_file() else "missing",
            }
        )
    return rows


def status_from_required(repo_root: Path, paths: list[str], partial_if_missing: bool = True) -> str:
    present = [exists(repo_root, path) for path in paths]
    if all(present):
        return "PASS"
    if any(present) and partial_if_missing:
        return "PARTIAL"
    return "BLOCKED"


def gate_map(status: dict[str, Any] | None) -> dict[str, dict[str, Any]]:
    if not status:
        return {}
    return {str(row.get("gate")): row for row in status.get("gates", [])}


def make_item(
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


def build_audit(repo_root: Path, artifact_dir: Path) -> dict[str, Any]:
    completion = load_json(repo_root / artifact_dir / "contest_completion_status.json")
    x2_status = load_json(repo_root / artifact_dir / "x2_training_start_20260624" / "x2_training_status.json")
    gates = gate_map(completion)

    gate_h = gates.get("H", {})
    gate_x2 = gates.get("X2", {})
    gate_e = gates.get("E", {})
    gate_f = gates.get("F", {})
    gate_g = gates.get("G", {})

    items: list[dict[str, Any]] = []
    items.append(
        make_item(
            "model_structure",
            "AI 模型结构说明文档及源码",
            status_from_required(
                repo_root,
                [
                    "docs/model_design.md",
                    "train/span_model.py",
                    "configs/distill_tinyspan_video_x2_c32_b4.json",
                ],
            ),
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
            "X2 训练完成后补充冻结 checkpoint 的 SHA256 与最终模型状态。",
        )
    )
    items.append(
        make_item(
            "training",
            "训练说明文档及源代码",
            "PARTIAL" if x2_status and x2_status.get("status") == "training_running" else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/training_quantization.md",
                    "train/distill_tinyspan_video.py",
                    "scripts/train_tinyspan_video_x2_c32_b4.ps1",
                    "scripts/start_tinyspan_c32b4_x2_training.ps1",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_training_start_20260624/x2_training_status.json",
                ],
            ),
            "X4 训练/冻结材料已有基线；X2 独立训练已启动但尚未完成。",
            "等待 X2 训练完成后运行 post-training prep，生成冻结和量化证据。",
        )
    )
    items.append(
        make_item(
            "quantization",
            "量化说明文档、量化计划和定点参考",
            "PARTIAL",
            evidence(
                repo_root,
                [
                    "docs/training_quantization.md",
                    "quant/quant_plan/c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8",
                    "tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py",
                    "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/tinyspan_tiled_fixed_reference_summary.json",
                ],
            ),
            "X4 W8A8 量化计划、32x32 定点参考和整帧 tiled FixedPng 已有；X2 量化仍缺。",
            "X2 freeze 后导出 X2 W8A8 quant plan，并生成 X2 定点/切块参考。",
        )
    )
    items.append(
        make_item(
            "model_to_hardware",
            "模型到硬件加速器转换工具",
            status_from_required(
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
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_c_rtl_export/gate_c_summary.md",
                ],
            ),
            "X2/X4 通用 post-training handoff 入口已补齐，X4 RTL 导出证据已归档。",
            "X2 训练完成后用同一入口生成 X2 RTL manifest 与 readiness。",
        )
    )
    items.append(
        make_item(
            "hardware_design",
            "硬件加速器详细设计文档及源代码",
            "PARTIAL",
            evidence(
                repo_root,
                [
                    "docs/hardware_design.md",
                    "rtl/tinyspan_core",
                    "rtl/board_wrapper/sr_stream_dynamic_cropper.v",
                    "rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v",
                    "sim/testbench/tb_sr_tile_tinyspan_x4_writer_shell.sv",
                ],
            ),
            "TinySPAN core、32x32 board smoke 和完整帧切块 shell 已有；完整帧 shell xsim/bitstream 仍缺。",
            "Vivado 空闲后运行 full-frame tiling xsim，再推进完整帧 PS/DDR wrapper 和 bitstream。",
        )
    )
    items.append(
        make_item(
            "vivado",
            "Vivado 仿真、综合/实现和 bitstream 证据",
            "PARTIAL" if gate_e.get("status") == "PASS" else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/verification_plan.md",
                    "scripts/vivado/run_tinyspan_full_frame_tiling_sims.ps1",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_d_rtl_gate_rerun_20260618/tinyspan_w8a8_rtl_gate_summary.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json",
                ],
            ),
            f"Gate E 当前状态为 {gate_e.get('status', 'UNKNOWN')}；但 Gate H 仍为 {gate_h.get('status', 'UNKNOWN')}。",
            "补齐完整帧 shell xsim、真实整帧 bitstream、板上回读和吞吐。",
        )
    )
    items.append(
        make_item(
            "verification",
            "完善的验证方案与验证用例",
            "PARTIAL" if gate_f.get("status") == "PASS" and gate_g.get("status") == "PASS" else "BLOCKED",
            evidence(
                repo_root,
                [
                    "docs/verification_plan.md",
                    "docs/gate_status.md",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/comparison_preview.png",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/full_frame_tiled_reference_x4_320x180_tile32_20260624/diff_heatmap.png",
                ],
            ),
            "32x32 board-vs-fixed byte-exact 已通过，整帧 FixedPng 预览已准备；整帧真实板上验证仍缺。",
            "拿到整帧 board_sr 后运行 720p30 acceptance，生成 comparison_preview 和 diff_heatmap。",
        )
    )
    items.append(
        make_item(
            "ppa",
            "PPA 指标与资源门线分析",
            "PARTIAL",
            evidence(
                repo_root,
                [
                    "docs/ppa_analysis.md",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_e_bitstream_x4_320x180_f150_prew_20260620/manifest.json",
                    "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/gate_f_board_x4_32x32_f150_tile32_20260621/acceptance/tinyspan_board_acceptance_summary.json",
                ],
            ),
            "资源、时序、功耗和理论 X4 720p30 已有基线；最终 PPA 仍需真实整帧正确性和实测吞吐支撑。",
            "完整帧 Gate H PASS 后把最终 utilization/timing/power/throughput 汇总为最终 PPA。",
        )
    )

    blockers = [
        "X4 完整帧真实板上输出仍缺，Gate H 未通过。",
        "X4 完整帧实测 720p30 throughput 仍缺。",
        "X2 独立证据包仍为 PARTIAL，缺冻结、量化、RTL、bitstream、真实板上输出和吞吐。",
    ]
    accepted = (
        gate_h.get("status") == "PASS"
        and gate_x2.get("status") == "PASS"
        and all(item["status"] == "PASS" for item in items)
    )
    return {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "repo_root": str(repo_root),
        "artifact_dir": str(artifact_dir),
        "accepted": accepted,
        "acceptance_status": "PASS" if accepted else "NOT_COMPLETE",
        "items": items,
        "gate_h_status": gate_h,
        "x2_status": gate_x2,
        "blockers": blockers if not accepted else [],
        "next_commands": [
            {
                "when": "Vivado 空闲后",
                "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\vivado\\run_tinyspan_full_frame_tiling_sims.ps1 -RequireVivadoIdle",
            },
            {
                "when": "X2 训练完成后",
                "command": "powershell -NoProfile -ExecutionPolicy Bypass -File .\\scripts\\run_tinyspan_c32b4_post_training_prep.ps1 -RunDir runs\\tinyspan_distill\\video_x2_c32_b4_reds_temporal -Scale 2 -Tag c32b4_x2_frozen_YYYYMMDD",
            },
        ],
    }


def write_markdown(path: Path, audit: dict[str, Any]) -> None:
    status = audit["acceptance_status"]
    lines = [
        "# TinySPAN 赛题交付审计",
        "",
        f"生成时间：`{audit['generated_at']}`",
        "",
        f"总体结论：`{status}`",
        "",
        "本审计只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。",
        "",
        "## 交付项状态",
        "",
        "| 项目 | 状态 | 结论 | 下一步 |",
        "| --- | --- | --- | --- |",
    ]
    for item in audit["items"]:
        lines.append(f"| {item['name']} | `{item['status']}` | {item['conclusion']} | {item['next_action']} |")
    lines.extend(["", "## 当前阻塞项", ""])
    if audit["blockers"]:
        for blocker in audit["blockers"]:
            lines.append(f"- {blocker}")
    else:
        lines.append("- 无")
    lines.extend(["", "## 下一步命令", ""])
    for cmd in audit["next_commands"]:
        lines.extend([f"- {cmd['when']}：", "", "```powershell", cmd["command"], "```", ""])
    lines.extend(["## 证据索引", ""])
    for item in audit["items"]:
        lines.extend([f"### {item['name']}", ""])
        for row in item["evidence"]:
            mark = "PASS" if row["exists"] else "MISS"
            lines.append(f"- `{mark}` `{row['path']}`")
        lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit TinySPAN contest delivery evidence.")
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument(
        "--artifact-dir",
        type=Path,
        default=Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe"),
    )
    parser.add_argument("--json-out", type=Path, default=Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/contest_delivery_audit.json"))
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
