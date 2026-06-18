"""Generate the TinySPAN contest workflow status summary.

The script consumes the current baseline artifact and optional preflight JSON
files, then writes a human-readable gate table plus a machine-readable status
JSON. It does not start Vivado, JTAG, or board runs.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


GATES = [
    ("A0", "TinySPAN 硬件安全基线预检"),
    ("A", "冻结 TinySPAN 模型"),
    ("B", "TinySPAN 量化与软件定点参考"),
    ("C", "TinySPAN RTL 导出"),
    ("D", "TinySPAN RTL 仿真"),
    ("E", "TinySPAN 实现与资源约束"),
    ("F", "TinySPAN 板卡冒烟测试"),
    ("G", "TinySPAN 图像一致性可视化验证"),
    ("H", "TinySPAN 最终 720p30 验收"),
    ("X2", "X2 独立证据包"),
]


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def load_latest_json(root: Path, pattern: str) -> tuple[dict[str, Any] | None, Path | None]:
    candidates = [path for path in root.glob(pattern) if path.is_file()]
    if not candidates:
        return None, None
    latest = max(candidates, key=lambda path: path.stat().st_mtime)
    return load_json(latest), latest


def failed_checks(summary: dict[str, Any] | None) -> list[str]:
    if not summary:
        return ["summary_missing"]
    return [str(item.get("name", "unknown")) for item in summary.get("checks", []) if not item.get("pass")]


def pass_checks(summary: dict[str, Any] | None) -> list[str]:
    if not summary:
        return []
    return [str(item.get("name", "unknown")) for item in summary.get("checks", []) if item.get("pass")]


def status_from_inputs(
    baseline: dict[str, Any] | None,
    readiness: dict[str, Any] | None,
    input_preflight: dict[str, Any] | None,
    gate_c: dict[str, Any] | None,
    gate_d: dict[str, Any] | None,
    gate_d_current: bool,
) -> list[dict[str, str]]:
    baseline_locked = bool(baseline and baseline.get("status") == "baseline_locked_not_board_accepted")
    readiness_failed = failed_checks(readiness)
    input_failed = failed_checks(input_preflight)

    rows: list[dict[str, str]] = []
    for gate_id, name in GATES:
        status = "未开始"
        evidence = "尚无"
        next_action = "等待前序 gate"

        if gate_id == "A0":
            status = "PASS" if baseline_locked else "BLOCKED"
            evidence = "baseline_manifest.json / baseline_decision.md"
            next_action = "继续沿 c32b4_30fps_frozen_20260613 推进"
        elif gate_id == "A":
            status = "PASS" if baseline_locked else "BLOCKED"
            evidence = "frozen checkpoint SHA256 已固定"
            next_action = "禁止使用仍在变化的 checkpoint"
        elif gate_id == "B":
            status = "PASS" if baseline and baseline.get("quant_reference_evidence") else "BLOCKED"
            evidence = "W8A8 quant plan + integer reference summary"
            next_action = "后续 board 输出必须对齐同一软件定点参考"
        elif gate_id == "C":
            status = "PASS" if (gate_c or (baseline and baseline.get("rtl_evidence"))) else "BLOCKED"
            evidence = "Gate C re-export + TinySPAN W8A8 RTL manifest" if gate_c else "TinySPAN W8A8 RTL manifest"
            next_action = "进入 RTL 仿真与实现前检查"
        elif gate_id == "D":
            gate_d_pass = bool(gate_d and gate_d.get("status") == "PASS")
            sim_related = [
                name
                for name in pass_checks(readiness)
                if "rtl" in name or "frontend" in name or "script" in name
            ]
            if gate_d_pass and gate_d_current:
                status = "PASS"
                evidence = "当前 artifacts 中 Gate D RTL gate rerun PASS"
                next_action = "进入 Gate E bitstream 生成前检查"
            elif gate_d_pass:
                status = "HISTORICAL_PASS"
                evidence = "已归档历史 RTL gate PASS；当前未重跑"
                next_action = "运行/归档 TinySPAN RTL gate summary，补齐逐字节仿真报告"
            else:
                status = "PARTIAL" if sim_related else "未开始"
                evidence = "readiness 中 RTL manifest、引用、脚本检查已通过" if sim_related else "尚无 RTL 仿真汇总"
                next_action = "运行/归档 TinySPAN RTL gate summary，补齐逐字节仿真报告"
        elif gate_id == "E":
            status = "BLOCKED" if "tinyspan_trained_bitstream_exists" in readiness_failed else "未开始"
            evidence = "bitstream 缺失" if "tinyspan_trained_bitstream_exists" in readiness_failed else "尚无"
            next_action = "生成真实 TinySPAN bitstream 并归档 timing/utilization/power"
        elif gate_id == "F":
            board_missing = (
                "real_board_output_provided" in readiness_failed
                or "real_board_output_exists" in input_failed
            )
            status = "BLOCKED" if board_missing else "未开始"
            evidence = "真实板上输出缺失" if board_missing else "尚无"
            next_action = "bitstream 通过后运行真实板卡 smoke，回读 board output"
        elif gate_id == "G":
            status = "BLOCKED"
            evidence = "缺 board_sr.png / comparison_preview.png / diff_heatmap.png"
            next_action = "拿到真实 board output 后运行图像一致性验证"
        elif gate_id == "H":
            status = "BLOCKED"
            evidence = "缺 byte-exact board compare、board 720p30、resource gate"
            next_action = "等 E/F/G 通过后执行最终验收"
        elif gate_id == "X2":
            status = "BLOCKED"
            evidence = "当前主证据为 X4，X2 需独立证据包"
            next_action = "完成 X4 闭环后补齐 X2 量化/RTL/board 证据"

        rows.append(
            {
                "gate": gate_id,
                "name": name,
                "status": status,
                "evidence": evidence,
                "next_action": next_action,
            }
        )
    return rows


def write_markdown(path: Path, rows: list[dict[str, str]], baseline: dict[str, Any] | None) -> None:
    baseline_id = ""
    checkpoint_sha = ""
    measured_fps = ""
    if baseline:
        base = baseline.get("baseline", {})
        sw = baseline.get("software_realtime_evidence", {})
        baseline_id = str(base.get("id", ""))
        checkpoint_sha = str(base.get("checkpoint_sha256", ""))
        measured_fps = str(sw.get("measured_fps", ""))

    lines = [
        "# TinySPAN 赛题完成状态",
        "",
        f"更新时间：`{datetime.now().isoformat(timespec='seconds')}`",
        "",
        f"当前硬件安全基线：`{baseline_id}`",
        f"Checkpoint SHA256：`{checkpoint_sha}`",
        f"软件 X4 720p30 证据：`{measured_fps} fps`",
        "",
        "## Gate 状态",
        "",
        "| Gate | 状态 | 证据 | 下一步 |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['gate']} {row['name']} | `{row['status']}` | {row['evidence']} | {row['next_action']} |"
        )
    lines.extend(
        [
            "",
            "## 当前硬阻塞",
            "",
            "- 真实 TinySPAN-trained bitstream 尚未生成。",
            "- 真实板上输出尚未回读。",
            "- 板上输出与软件定点参考的逐字节一致性尚未完成。",
            "- 板上 720p30 throughput 和 resource gate 尚未完成。",
            "- X2 证据包尚未补齐。",
            "",
            "本文件由 `scripts/acceptance/update_workflow_status.py` 生成，不启动 Vivado、JTAG 或板卡流程。",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Update TinySPAN workflow status docs.")
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--docs-out", type=Path, default=Path("docs/gate_status.md"))
    parser.add_argument("--json-out", type=Path, default=None)
    args = parser.parse_args()

    artifact_dir = args.artifact_dir
    preflight_dir = artifact_dir / "preflight_current"
    baseline = load_json(artifact_dir / "baseline_manifest.json")
    readiness = load_json(preflight_dir / "tinyspan_720p30_board_acceptance_readiness.json")
    input_preflight = load_json(preflight_dir / "tinyspan_720p30_acceptance_input_preflight.json")
    gate_c = load_json(artifact_dir / "gate_c_rtl_export" / "tinyspan_c32b4_30fps_frozen_w8a8_reexport" / "tinyspan_w8a8_rtl_manifest.json")
    gate_d, gate_d_path = load_latest_json(artifact_dir, "gate_d_rtl_gate_rerun_*/tinyspan_w8a8_rtl_gate_summary.json")
    gate_d_current = gate_d is not None
    if gate_d is None:
        gate_d = load_json(artifact_dir / "gate_d_rtl_gate_existing" / "tinyspan_w8a8_rtl_gate_summary.json")

    rows = status_from_inputs(baseline, readiness, input_preflight, gate_c, gate_d, gate_d_current)
    write_markdown(args.docs_out, rows, baseline)

    json_out = args.json_out or artifact_dir / "contest_completion_status.json"
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(
        json.dumps(
            {
                "generated_at": datetime.now().isoformat(timespec="seconds"),
                "artifact_dir": str(artifact_dir),
                "gate_d_summary": str(gate_d_path) if gate_d_path else "",
                "gates": rows,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"WROTE {args.docs_out}")
    print(f"WROTE {json_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
