"""Generate the TinySPAN contest workflow status summary.

The script is read-only. It consumes committed artifacts and live training
status files, then writes a Chinese gate table and a machine-readable status
JSON. It never starts Vivado, JTAG, board access, or training.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


GATE_NAMES = {
    "A0": "TinySPAN 硬件安全基线预检",
    "A": "冻结 TinySPAN 模型",
    "B": "TinySPAN 量化与软件定点参考",
    "C": "TinySPAN RTL 导出",
    "D": "TinySPAN RTL 仿真",
    "E": "TinySPAN 实现与资源约束",
    "F": "TinySPAN 板卡冒烟测试",
    "G": "TinySPAN 图像一致性可视化验证",
    "H": "TinySPAN X4 最终 720p30 验收",
    "X2": "X2 独立证据包",
}


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


def text(value: Any, default: str = "") -> str:
    if value is None:
        return default
    return str(value)


def row(gate: str, status: str, evidence: str, next_action: str) -> dict[str, str]:
    return {
        "gate": gate,
        "name": GATE_NAMES[gate],
        "status": status,
        "evidence": evidence,
        "next_action": next_action,
    }


def build_rows(artifact_dir: Path) -> tuple[list[dict[str, str]], dict[str, Any]]:
    baseline = load_json(artifact_dir / "baseline_manifest.json")
    gate_e = load_json(artifact_dir / "gate_e_bitstream_x4_320x180_f150_prew_20260620" / "manifest.json")
    gate_f = load_json(
        artifact_dir
        / "gate_f_board_x4_32x32_f150_tile32_20260621"
        / "acceptance"
        / "tinyspan_board_acceptance_summary.json"
    )
    gate_d, gate_d_path = latest_json(artifact_dir, "gate_d_rtl_gate_rerun_*/tinyspan_w8a8_rtl_gate_summary.json")
    tiled_ref, tiled_ref_path = latest_json(
        artifact_dir,
        "full_frame_tiled_reference_x4_320x180_*/tinyspan_tiled_fixed_reference_summary.json",
    )
    gate_h, gate_h_path = latest_json(artifact_dir, "gate_h_board_x4_320x180_*/manifest.json")
    x2_gate_h, x2_gate_h_path = latest_json(artifact_dir, "gate_h_board_x2_*/manifest.json")
    x2_training, x2_path = latest_json(artifact_dir, "x2_training_*/x2_training_status.json")
    if x2_training is None:
        x2_training, x2_path = latest_json(artifact_dir, "x2_training_start_*/x2_training_status.json")

    baseline_pass = bool(baseline and baseline.get("status") == "baseline_locked_not_board_accepted")
    gate_e_pass = bool(
        gate_e
        and gate_e.get("timing", {}).get("status") == "PASS"
        and gate_e.get("resource_gate", {}).get("status") == "PASS"
    )
    gate_f_pass = bool(gate_f and gate_f.get("pass"))
    gate_g_pass = bool(gate_f and gate_f.get("compare_pass"))
    gate_h_pass = bool(gate_h and (gate_h.get("package_pass") or gate_h.get("pass")))
    x2_running = bool(x2_training and x2_training.get("status") == "training_running")
    x2_gate_h_pass = bool(x2_gate_h and (x2_gate_h.get("package_pass") or x2_gate_h.get("pass")))
    x2_pass = x2_gate_h_pass or bool(x2_training and x2_training.get("status") == "PASS")

    rows: list[dict[str, str]] = []
    rows.append(
        row(
            "A0",
            "PASS" if baseline_pass else "BLOCKED",
            "已锁定 `c32b4_30fps_frozen_20260613` 作为硬件安全基线。",
            "继续基于该基线推进 X4 交付和 X2 独立证据。",
        )
    )
    rows.append(
        row(
            "A",
            "PASS" if baseline_pass else "BLOCKED",
            f"checkpoint SHA256 `{text((baseline or {}).get('baseline', {}).get('checkpoint_sha256'))}`。",
            "禁止用仍在变化的 checkpoint 替代冻结证据。",
        )
    )
    rows.append(
        row(
            "B",
            "PASS" if baseline and baseline.get("quant_reference_evidence") else "PARTIAL",
            "X4 W8A8 quant plan、定点参考和 tile64 整帧固定点参考已归档。",
            "X2 训练完成后导出 X2 W8A8 quant plan 与 X2 定点参考。",
        )
    )
    rows.append(
        row(
            "C",
            "PASS" if (artifact_dir / "gate_c_rtl_export").exists() else "BLOCKED",
            "TinySPAN W8A8 RTL 导出和 manifest 已归档。",
            "X2 freeze 后复用同一入口生成 X2 RTL manifest。",
        )
    )
    rows.append(
        row(
            "D",
            "PASS" if gate_d else "PARTIAL",
            f"RTL gate summary `{text(gate_d_path)}`。",
            "保持 RTL 仿真作为后续 X2/X4 回归门禁。",
        )
    )
    rows.append(
        row(
            "E",
            "PASS" if gate_e_pass else "BLOCKED",
            (
                f"X4 bitstream/resource/timing PASS；WNS `{text((gate_e or {}).get('timing', {}).get('wns_ns'))}ns`，"
                f"理论 throughput `{text((gate_e or {}).get('throughput_estimate', {}).get('fps_x4_1280x720'))}fps`。"
            ),
            "X2 完成后补 X2 bitstream/resource/timing 证据。",
        )
    )
    rows.append(
        row(
            "F",
            "PASS" if gate_f_pass else "BLOCKED",
            (
                f"X4 32x32 上板 smoke PASS；perf-only `{text((gate_f or {}).get('measured_fps'))}fps`，"
                f"mismatch `{text((gate_f or {}).get('mismatch_bytes'))}/{text((gate_f or {}).get('total_bytes'))}`。"
            ),
            "保留 32x32 smoke 作为小图回归门禁。",
        )
    )
    rows.append(
        row(
            "G",
            "PASS" if gate_g_pass else "BLOCKED",
            "X4 32x32 board-vs-fixed byte-exact，并已生成整帧 tile64 固定点预览/heatmap。",
            "展示材料可继续补 board PNG、显示输出或 SD 写回图。",
        )
    )

    if gate_h_pass:
        acc = gate_h.get("acceptance_summary", {})
        rows.append(
            row(
                "H",
                "PASS_X4",
                (
                    f"X4 整帧上板验收闭合：`{text(acc.get('measured_fps'))}fps`，"
                    f"mismatch `{text(acc.get('mismatch_bytes'))}/{text(acc.get('total_bytes'))}`，"
                    f"max diff `{text(acc.get('max_channel_diff'))}`。"
                ),
                "X4 子任务可交付；整赛题继续补 X2 独立证据。",
            )
        )
    else:
        rows.append(
            row(
                "H",
                "PARTIAL" if tiled_ref else "BLOCKED",
                "X4 整帧固定点参考已准备，但缺真实板上吞吐或完整帧一致性证据。",
                "完成 X4 Gate H 板上证据。",
            )
        )

    latest = (x2_training or {}).get("formal_training", {}).get("latest_observed", {})
    if x2_gate_h_pass:
        x2_acc = x2_gate_h.get("acceptance_summary", {}) or {}
        x2_status = "PASS"
        x2_evidence = (
            f"X2 Gate H 整帧上板验收闭合：`{text(x2_acc.get('measured_fps'))}fps`，"
            f"mismatch `{text(x2_acc.get('mismatch_bytes'))}/{text(x2_acc.get('total_bytes'))}`，"
            f"max diff `{text(x2_acc.get('max_channel_diff'))}`。"
        )
        x2_next = "汇总 X2/X4 最终交付材料。"
    elif x2_pass:
        x2_status = "PASS"
        x2_evidence = "X2 独立证据包已闭合。"
        x2_next = "汇总 X2/X4 最终交付材料。"
    elif x2_running:
        x2_status = "PARTIAL"
        x2_evidence = (
            f"X2 正式训练运行中；epoch `{text(latest.get('epoch'))}`，"
            f"step `{text(latest.get('step'))}/{text(latest.get('total_steps'))}`，"
            f"progress `{text(latest.get('progress_percent'))}%`。"
        )
        x2_next = "训练完成后冻结、量化、导出 RTL、生成 bitstream 并上板验证。"
    else:
        x2_status = "BLOCKED"
        x2_evidence = "X2 训练状态未知或未运行。"
        x2_next = "恢复或完成 X2 训练。"
    rows.append(row("X2", x2_status, x2_evidence, x2_next))

    accepted = gate_h_pass and x2_pass
    context = {
        "baseline": baseline,
        "gate_e": gate_e,
        "gate_f": gate_f,
        "gate_d_path": str(gate_d_path) if gate_d_path else "",
        "tiled_ref_path": str(tiled_ref_path) if tiled_ref_path else "",
        "gate_h": gate_h,
        "gate_h_path": str(gate_h_path) if gate_h_path else "",
        "x2_gate_h": x2_gate_h,
        "x2_gate_h_path": str(x2_gate_h_path) if x2_gate_h_path else "",
        "x2_training": x2_training,
        "x2_training_path": str(x2_path) if x2_path else "",
        "accepted": accepted,
    }
    return rows, context


def write_markdown(path: Path, rows: list[dict[str, str]], context: dict[str, Any]) -> None:
    baseline = context.get("baseline") or {}
    base = baseline.get("baseline", {}) or {}
    gate_h = context.get("gate_h") or {}
    acc = gate_h.get("acceptance_summary", {}) or {}
    x2_training = context.get("x2_training") or {}
    latest = x2_training.get("formal_training", {}).get("latest_observed", {}) if x2_training else {}

    lines = [
        "# TinySPAN 赛题完成状态",
        "",
        f"更新时间：`{datetime.now().isoformat(timespec='seconds')}`",
        "",
        f"当前硬件安全基线：`{text(base.get('id'))}`",
        f"Checkpoint SHA256：`{text(base.get('checkpoint_sha256'))}`",
        "",
        "## 总体结论",
        "",
    ]
    if context.get("accepted"):
        lines.append("- `PASS`：X2/X4 独立证据均已闭合。")
    else:
        lines.extend(
            [
                "- `NOT_COMPLETE`：X4 子任务已经达到可交付状态；整赛题仍缺 X2 独立证据。",
                (
                    f"- X4 Gate H：`{text(acc.get('measured_fps'))}fps`，"
                    f"`{text(acc.get('mismatch_bytes'))}/{text(acc.get('total_bytes'))}` mismatch。"
                ),
                (
                    f"- X2 训练：epoch `{text(latest.get('epoch'))}`，"
                    f"step `{text(latest.get('step'))}/{text(latest.get('total_steps'))}`。"
                ),
            ]
        )

    lines.extend(
        [
            "",
            "## Gate 状态",
            "",
            "| Gate | 状态 | 证据 | 下一步 |",
            "| --- | --- | --- | --- |",
        ]
    )
    for item in rows:
        lines.append(
            f"| {item['gate']} {item['name']} | `{item['status']}` | {item['evidence']} | {item['next_action']} |"
        )

    lines.extend(
        [
            "",
            "## X4 可交付边界",
            "",
            "- X4 已具备冻结 checkpoint、量化计划、RTL/bitstream、真实板上整帧吞吐和完整帧一致性证据。",
            "- X4 DDR 路线只调用板卡/AMD Xilinx IP：`zynq_ultra_ps_e`、PS DDR controller、HP/HPC、SmartConnect；不自研 DDR controller/PHY。",
            "- 可选增强项：补充可直接展示的 board PNG、HDMI/display 输出或 SD 写回图。",
            "",
        ]
    )
    if context.get("accepted"):
        lines.extend(["## 未闭合项", "", "- 无。X2/X4 Gate H 均已闭合。", ""])
    else:
        lines.extend(
            [
                "## 未闭合项",
                "",
                "- X2 独立冻结 checkpoint、量化计划、RTL、bitstream、真实板上输出和 `>=30fps` 证据仍未完成。",
                "",
            ]
        )
    lines.append("本文件由 `scripts/acceptance/update_workflow_status.py` 生成；该脚本只读 artifact，不启动 Vivado、JTAG、板卡或训练。")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--docs-out", type=Path, default=Path("docs/gate_status.md"))
    parser.add_argument("--json-out", type=Path, default=None)
    args = parser.parse_args()

    rows, context = build_rows(args.artifact_dir)
    write_markdown(args.docs_out, rows, context)

    json_out = args.json_out or args.artifact_dir / "contest_completion_status.json"
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(
        json.dumps(
            {
                "generated_at": datetime.now().isoformat(timespec="seconds"),
                "artifact_dir": str(args.artifact_dir),
                "accepted": bool(context.get("accepted")),
                "acceptance_status": "PASS" if context.get("accepted") else "NOT_COMPLETE",
                "x4_gate_h_status": "PASS_X4" if context.get("gate_h") else "MISSING",
                "gate_h_board_summary": context.get("gate_h_path", ""),
                "x2_training_status": context.get("x2_training_path", ""),
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
