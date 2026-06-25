"""Build a curated TinySPAN contest delivery index.

This script is intentionally read-only with respect to hardware flows: it does
not start Vivado, JTAG, XSCT, board access, or training. It only reads committed
source/document files and curated artifact manifests, then writes an index that
can be submitted as the front door of the delivery package.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_ARTIFACT_DIR = Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe")


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def rel_path(repo_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return str(path)


def git_value(repo_root: Path, args: list[str]) -> str:
    try:
        completed = subprocess.run(
            ["git", *args],
            cwd=repo_root,
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError:
        return ""
    if completed.returncode != 0:
        return ""
    return completed.stdout.strip()


def evidence_file(repo_root: Path, item: str) -> dict[str, Any]:
    path = repo_root / item
    row: dict[str, Any] = {
        "path": item.replace("\\", "/"),
        "exists": path.exists(),
        "kind": "missing",
    }
    if path.is_file():
        stat = path.stat()
        row.update(
            {
                "kind": "file",
                "bytes": stat.st_size,
                "mtime": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
                "sha256": sha256_file(path),
            }
        )
    elif path.is_dir():
        files = [child for child in path.rglob("*") if child.is_file()]
        row.update(
            {
                "kind": "dir",
                "file_count": len(files),
                "bytes": sum(child.stat().st_size for child in files),
            }
        )
    return row


def section(repo_root: Path, name: str, paths: list[str]) -> dict[str, Any]:
    rows = [evidence_file(repo_root, item) for item in paths]
    exists = [row["exists"] for row in rows]
    if all(exists):
        status = "PASS"
    elif any(exists):
        status = "PARTIAL"
    else:
        status = "MISSING"
    return {"name": name, "status": status, "evidence": rows}


def latest_file(repo_root: Path, pattern: str) -> Path | None:
    candidates = [path for path in repo_root.glob(pattern) if path.is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def build_index(repo_root: Path, artifact_dir: Path) -> dict[str, Any]:
    artifact_dir_abs = repo_root / artifact_dir
    completion_path = artifact_dir_abs / "contest_completion_status.json"
    audit_path = artifact_dir_abs / "contest_delivery_audit.json"
    x2_readiness_path = artifact_dir_abs / "x2_hardware_readiness.json"
    x2_training_path = latest_file(repo_root, f"{artifact_dir.as_posix()}/x2_training*/x2_training_status.json")
    if x2_training_path is None:
        x2_training_path = latest_file(repo_root, f"{artifact_dir.as_posix()}/x2_training_start*/x2_training_status.json")
    x4_gate_h_path = latest_file(repo_root, f"{artifact_dir.as_posix()}/gate_h_board_x4_320x180_*/manifest.json")

    completion = read_json(completion_path) or {}
    audit = read_json(audit_path) or {}
    x2_readiness = read_json(x2_readiness_path) or {}
    x2_training = read_json(x2_training_path) if x2_training_path else {}
    x4_gate_h = read_json(x4_gate_h_path) if x4_gate_h_path else {}

    x4_pass = bool(x4_gate_h and (x4_gate_h.get("package_pass") or x4_gate_h.get("pass")))
    x2_training_observed = (
        (x2_training or {})
        .get("formal_training", {})
        .get("latest_observed", {})
    )
    x2_missing = list((x2_training or {}).get("acceptance_boundary", {}).get("missing", []))
    x2_blockers = list(x2_readiness.get("blockers", []))

    sections = [
        section(
            repo_root,
            "工作流与交付审计",
            [
                "README.md",
                "WORKFLOW.md",
                "docs/gate_status.md",
                "docs/contest_delivery_audit.md",
                "docs/x2_hardware_readiness.md",
                rel_path(repo_root, completion_path),
                rel_path(repo_root, audit_path),
                rel_path(repo_root, x2_readiness_path),
            ],
        ),
        section(
            repo_root,
            "AI 模型、训练和量化",
            [
                "docs/model_design.md",
                "docs/training_quantization.md",
                "train/span_model.py",
                "train/distill_tinyspan_video.py",
                "configs/distill_tinyspan_video_x2_c32_b4.json",
                "scripts/train_tinyspan_video_x2_c32_b4.ps1",
                "scripts/start_tinyspan_c32b4_x2_training.ps1",
                "scripts/run_tinyspan_c32b4_post_training_prep.ps1",
                "tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py",
                "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
            ],
        ),
        section(
            repo_root,
            "硬件设计与模型到 RTL 转换",
            [
                "docs/hardware_design.md",
                "rtl/tinyspan_core",
                "rtl/board_wrapper",
                "tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py",
                "scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl",
                "scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1",
            ],
        ),
        section(
            repo_root,
            "验证方案与 PPA",
            [
                "docs/verification_plan.md",
                "docs/ppa_analysis.md",
                "docs/x4_board_result_report_20260625.md",
                "docs/x4_quality_improvement_plan.md",
                "sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_20260625.md",
                "sim/reports/ps_tinyspan_ddr_x4_tile64_fifo_f155_a53_compare_20260625.md",
            ],
        ),
        section(
            repo_root,
            "X4 Gate H 已闭合证据",
            [
                rel_path(repo_root, x4_gate_h_path) if x4_gate_h_path else "",
                f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png",
                f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png",
                f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png",
                f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/tinyspan_tiled_fixed_reference_summary.json",
            ],
        ),
    ]

    return {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "repo_root": str(repo_root),
        "artifact_dir": artifact_dir.as_posix(),
        "git": {
            "branch": git_value(repo_root, ["branch", "--show-current"]),
            "commit": git_value(repo_root, ["rev-parse", "HEAD"]),
            "remote": git_value(repo_root, ["remote", "get-url", "origin"]),
        },
        "overall": {
            "status": completion.get("acceptance_status") or audit.get("acceptance_status") or "UNKNOWN",
            "ready_for_full_contest_delivery": bool(audit.get("accepted", False)),
            "x4_deliverable": x4_pass,
            "x2_deliverable": completion.get("gates", []) and any(
                row.get("gate") == "X2" and row.get("status") == "PASS"
                for row in completion.get("gates", [])
            ),
        },
        "x4": {
            "status": "PASS_X4" if x4_pass else "MISSING",
            "manifest": rel_path(repo_root, x4_gate_h_path) if x4_gate_h_path else "",
            "fps": (x4_gate_h or {}).get("acceptance_summary", {}).get("measured_fps"),
            "mismatch_bytes": (x4_gate_h or {}).get("acceptance_summary", {}).get("mismatch_bytes"),
            "total_bytes": (x4_gate_h or {}).get("acceptance_summary", {}).get("total_bytes"),
            "bitstream_sha256": (x4_gate_h or {}).get("bitstream", {}).get("sha256"),
        },
        "x2": {
            "status": (x2_training or {}).get("status", "UNKNOWN"),
            "training_status": rel_path(repo_root, x2_training_path) if x2_training_path else "",
            "latest_observed": x2_training_observed,
            "readiness": rel_path(repo_root, x2_readiness_path),
            "readiness_status": x2_readiness.get("status", "UNKNOWN"),
            "readiness_blockers": x2_blockers,
            "missing_acceptance_evidence": x2_missing,
        },
        "sections": sections,
        "boundary": [
            "本索引只证明当前已归档证据的存在性和哈希，不会启动 Vivado/JTAG/板卡/训练流程。",
            "X4 子任务已具备完整 720p30 板上吞吐和 board-vs-fixed 一致性证据。",
            "整赛题仍需 X2 独立冻结、量化、RTL、bitstream、真实板上输出和 >=30fps 证据后才能宣告完成。",
        ],
    }


def write_markdown(path: Path, index: dict[str, Any]) -> None:
    x2_obs = index["x2"].get("latest_observed") or {}
    lines = [
        "# TinySPAN 赛题交付索引",
        "",
        f"生成时间：`{index['generated_at']}`",
        f"索引生成前提交：`{index['git'].get('commit', '')}`",
        f"总体状态：`{index['overall']['status']}`",
        "",
        "本索引只读取现有文件和 artifact，不启动 Vivado、JTAG、板卡或训练流程。",
        "",
        "## 当前结论",
        "",
        f"- X4 子任务：`{index['x4']['status']}`，fps `{index['x4'].get('fps')}`，mismatch `{index['x4'].get('mismatch_bytes')}/{index['x4'].get('total_bytes')}`。",
        f"- X2 训练：`{index['x2']['status']}`，epoch `{x2_obs.get('epoch', '')}`，step `{x2_obs.get('step', '')}/{x2_obs.get('total_steps', '')}`，progress `{x2_obs.get('progress_percent', '')}%`。",
        f"- X2 readiness：`{index['x2']['readiness_status']}`。",
        "",
        "## X2 剩余缺口",
        "",
    ]
    for blocker in index["x2"].get("readiness_blockers", []):
        lines.append(f"- readiness blocker: `{blocker}`")
    for missing in index["x2"].get("missing_acceptance_evidence", []):
        lines.append(f"- evidence missing: {missing}")
    if not index["x2"].get("readiness_blockers") and not index["x2"].get("missing_acceptance_evidence"):
        lines.append("- 无")

    lines.extend(["", "## 证据分组", ""])
    for sec in index["sections"]:
        lines.extend([f"### {sec['name']}", "", f"状态：`{sec['status']}`", ""])
        for row in sec["evidence"]:
            if not row["path"]:
                continue
            mark = "PASS" if row["exists"] else "MISS"
            detail = ""
            if row["exists"] and row["kind"] == "file":
                detail = f"，{row.get('bytes', 0)} bytes，SHA256 `{row.get('sha256', '')}`"
            elif row["exists"] and row["kind"] == "dir":
                detail = f"，{row.get('file_count', 0)} files，{row.get('bytes', 0)} bytes"
            lines.append(f"- `{mark}` `{row['path']}`{detail}")
        lines.append("")

    lines.extend(["## 边界说明", ""])
    for item in index["boundary"]:
        lines.append(f"- {item}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--json-out", type=Path, default=DEFAULT_ARTIFACT_DIR / "contest_delivery_index.json")
    parser.add_argument("--md-out", type=Path, default=Path("docs/contest_delivery_index.md"))
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    index = build_index(repo_root, args.artifact_dir)

    json_out = repo_root / args.json_out
    md_out = repo_root / args.md_out
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(md_out, index)

    print(f"WROTE {json_out}")
    print(f"WROTE {md_out}")
    print(f"STATUS {index['overall']['status']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
