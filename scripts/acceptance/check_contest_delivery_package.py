"""Check whether the TinySPAN contest delivery package is complete.

This is a read-only final gate. It never starts Vivado, JTAG, XSCT, board
access, or training. By default it exits non-zero until both X2 and X4 have
complete evidence. Use --allow-incomplete when refreshing status during an
in-progress run.
"""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_ARTIFACT_DIR = Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe")


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def latest_json(repo_root: Path, pattern: str) -> tuple[dict[str, Any] | None, Path | None]:
    candidates = [path for path in repo_root.glob(pattern) if path.is_file()]
    if not candidates:
        return None, None
    latest = max(candidates, key=lambda path: path.stat().st_mtime)
    return read_json(latest), latest


def rel(repo_root: Path, path: Path | None) -> str:
    if path is None:
        return ""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return str(path)


def completion_gate_status(completion: dict[str, Any] | None, gate: str) -> str:
    if not completion:
        return ""
    for row in completion.get("gates", []):
        if row.get("gate") == gate:
            return str(row.get("status", ""))
    return ""


def row(
    req_id: str,
    name: str,
    status: str,
    evidence: str,
    expected: str,
    action: str,
    required: bool = True,
) -> dict[str, Any]:
    return {
        "id": req_id,
        "name": name,
        "status": status,
        "required": required,
        "evidence": evidence,
        "expected": expected,
        "action": action,
    }


def pass_if(condition: bool, fail_status: str = "FAIL") -> str:
    return "PASS" if condition else fail_status


def path_exists(repo_root: Path, item: str) -> bool:
    return (repo_root / item).exists()


def all_paths_exist(repo_root: Path, paths: list[str]) -> tuple[bool, list[str]]:
    missing = [item for item in paths if not path_exists(repo_root, item)]
    return not missing, missing


def manifest_acceptance(manifest: dict[str, Any] | None) -> dict[str, Any]:
    if not manifest:
        return {}
    summary = manifest.get("acceptance_summary", {})
    correctness = manifest.get("correctness", {})
    throughput = manifest.get("throughput", {})
    return {
        "scale": manifest.get("scale"),
        "output_width": (manifest.get("output_resolution") or {}).get("width"),
        "output_height": (manifest.get("output_resolution") or {}).get("height"),
        "fps": summary.get("measured_fps", throughput.get("fps")),
        "mismatch_bytes": summary.get("mismatch_bytes", correctness.get("mismatch_bytes")),
        "total_bytes": summary.get("total_bytes", correctness.get("total_bytes")),
        "max_channel_diff": summary.get("max_channel_diff", correctness.get("max_channel_diff")),
        "bitstream_sha256": (manifest.get("bitstream") or {}).get("sha256"),
        "no_custom_ddr": bool(manifest.get("no_custom_ddr_controller_or_phy")),
        "package_pass": bool(manifest.get("package_pass") or manifest.get("pass")),
    }


def as_float(value: Any, default: float = 0.0) -> float:
    if value is None:
        return default
    return float(value)


def as_int(value: Any, default: int = -1) -> int:
    if value is None:
        return default
    return int(value)


def find_x2_manifest(repo_root: Path, artifact_dir: Path) -> tuple[dict[str, Any] | None, Path | None]:
    patterns = [
        f"{artifact_dir.as_posix()}/gate_h_board_x2_*/manifest.json",
        f"{artifact_dir.as_posix()}/gate_*x2*/manifest.json",
        f"{artifact_dir.as_posix()}/**/*x2*manifest.json",
    ]
    candidates: list[Path] = []
    for pattern in patterns:
        candidates.extend(path for path in repo_root.glob(pattern) if path.is_file())
    unique = sorted(set(candidates), key=lambda path: path.stat().st_mtime)
    if not unique:
        return None, None
    latest = unique[-1]
    return read_json(latest), latest


def build_check(repo_root: Path, artifact_dir: Path) -> dict[str, Any]:
    artifact_abs = repo_root / artifact_dir
    completion = read_json(artifact_abs / "contest_completion_status.json")
    delivery_audit = read_json(artifact_abs / "contest_delivery_audit.json")
    delivery_index = read_json(artifact_abs / "contest_delivery_index.json")
    x2_readiness = read_json(artifact_abs / "x2_hardware_readiness.json")
    x2_training, x2_training_path = latest_json(
        repo_root, f"{artifact_dir.as_posix()}/x2_training*/x2_training_status.json"
    )
    if x2_training is None:
        x2_training, x2_training_path = latest_json(
            repo_root, f"{artifact_dir.as_posix()}/x2_training_start*/x2_training_status.json"
        )
    x4_manifest, x4_manifest_path = latest_json(
        repo_root, f"{artifact_dir.as_posix()}/gate_h_board_x4_320x180_*/manifest.json"
    )
    x4_quality, x4_quality_path = latest_json(
        repo_root, f"{artifact_dir.as_posix()}/x4_quality_metrics*/tinyspan_x4_quality_metrics.json"
    )
    x4_reds_quality, x4_reds_quality_path = latest_json(
        repo_root, f"{artifact_dir.as_posix()}/reds_val_quality_x4_*/reds_hr_quality_metrics.json"
    )
    x2_manifest, x2_manifest_path = find_x2_manifest(repo_root, artifact_dir)

    checks: list[dict[str, Any]] = []
    docs = [
        "README.md",
        "WORKFLOW.md",
        "docs/model_design.md",
        "docs/training_quantization.md",
        "docs/hardware_design.md",
        "docs/verification_plan.md",
        "docs/ppa_analysis.md",
        "docs/x4_board_result_report_20260625.md",
        "docs/x4_quality_improvement_plan.md",
        "docs/sd_card_x4_board_validation_plan.md",
        "docs/gate_status.md",
        "docs/contest_delivery_audit.md",
        "docs/contest_delivery_index.md",
        "docs/x2_hardware_readiness.md",
    ]
    docs_ok, docs_missing = all_paths_exist(repo_root, docs)
    checks.append(
        row(
            "docs",
            "交付文档齐备",
            pass_if(docs_ok, "MISSING"),
            "missing: " + ", ".join(docs_missing) if docs_missing else "all required docs exist",
            "README、工作流、模型/训练/量化/硬件/验证/PPA/状态审计文档均存在",
            "补齐缺失文档",
        )
    )

    sources = [
        "train/span_model.py",
        "train/distill_tinyspan_video.py",
        "tools/model_to_hardware/export_tinyspan_w8a8_quant_plan.py",
        "tools/model_to_hardware/export_tinyspan_w8a8_to_rtl.py",
        "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
        "rtl/tinyspan_core",
        "rtl/board_wrapper",
        "scripts/acceptance/refresh_tinyspan_delivery_status.ps1",
        "scripts/acceptance/make_contest_delivery_index.py",
        "tools/image_validation/evaluate_sr_quality.py",
    ]
    sources_ok, sources_missing = all_paths_exist(repo_root, sources)
    checks.append(
        row(
            "source_tree",
            "训练、量化、RTL 和验收源代码齐备",
            pass_if(sources_ok, "MISSING"),
            "missing: " + ", ".join(sources_missing) if sources_missing else "all required source roots exist",
            "模型、训练、量化、RTL、转换工具和验收脚本均存在",
            "补齐缺失源码或脚本",
        )
    )

    checks.append(
        row(
            "status_artifacts",
            "交付审计 artifact 齐备",
            pass_if(bool(completion and delivery_audit and delivery_index), "MISSING"),
            (
                f"completion={bool(completion)}, audit={bool(delivery_audit)}, "
                f"index={bool(delivery_index)}"
            ),
            "contest_completion_status、contest_delivery_audit、contest_delivery_index 均存在",
            "运行 refresh_tinyspan_delivery_status.ps1",
        )
    )

    x4 = manifest_acceptance(x4_manifest)
    x4_ok = bool(
        x4
        and x4.get("package_pass")
        and x4.get("scale") == 4
        and x4.get("output_width") == 1280
        and x4.get("output_height") == 720
        and as_float(x4.get("fps")) >= 30.0
        and as_int(x4.get("mismatch_bytes")) == 0
        and as_int(x4.get("max_channel_diff")) == 0
        and x4.get("bitstream_sha256")
        and x4.get("no_custom_ddr")
    )
    checks.append(
        row(
            "x4_gate_h",
            "X4 720p30 板上正确性与吞吐闭合",
            pass_if(x4_ok, "FAIL"),
            (
                f"manifest={rel(repo_root, x4_manifest_path)}, fps={x4.get('fps')}, "
                f"mismatch={x4.get('mismatch_bytes')}/{x4.get('total_bytes')}, "
                f"max_diff={x4.get('max_channel_diff')}, bitstream={x4.get('bitstream_sha256')}"
            ),
            "X4 scale=4，1280x720，fps>=30，mismatch=0，max diff=0，同一 bitstream/quant/checkpoint",
            "补齐 X4 Gate H manifest 或重新验收 X4",
        )
    )

    x4_images = [
        f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/software_tiled_fixed_point_sr.png",
        f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/comparison_preview.png",
        f"{artifact_dir.as_posix()}/full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625/diff_heatmap.png",
    ]
    x4_images_ok, x4_images_missing = all_paths_exist(repo_root, x4_images)
    checks.append(
        row(
            "x4_images",
            "X4 可视化验证材料齐备",
            pass_if(x4_images_ok, "MISSING"),
            "missing: " + ", ".join(x4_images_missing) if x4_images_missing else "software reference, preview, heatmap exist",
            "software_tiled_fixed_point_sr、comparison_preview、diff_heatmap 均存在",
            "补生成 X4 可视化材料",
        )
    )

    x4_quality_pairs = {
        str(item.get("label")): item for item in (x4_quality or {}).get("pairs", [])
    }
    required_x4_quality_pairs = [
        "student_vs_teacher",
        "pytorch_vs_tiled_fixed",
        "full_integer_vs_tiled_fixed",
    ]
    missing_x4_quality_pairs = [
        label
        for label in required_x4_quality_pairs
        if label not in x4_quality_pairs or x4_quality_pairs[label].get("psnr_db") is None
    ]
    x4_quality_ok = bool(x4_quality and not missing_x4_quality_pairs)
    checks.append(
        row(
            "x4_quality_metrics",
            "X4 画质指标证据齐备",
            pass_if(x4_quality_ok, "MISSING"),
            (
                f"metrics={rel(repo_root, x4_quality_path)}, "
                f"pairs={list(x4_quality_pairs)}, missing={missing_x4_quality_pairs}"
            ),
            "X4 student-vs-teacher、PyTorch-vs-tiled fixed 和 full-integer-vs-tiled fixed 的 PSNR/SSIM/MAE 指标存在",
            "运行 tools/image_validation/evaluate_sr_quality.py 生成 X4 画质指标",
        )
    )

    x4_reds_quality_pairs = {
        str(item.get("label")): item for item in (x4_reds_quality or {}).get("pairs", [])
    }
    required_x4_reds_pairs = [
        "x4_tile64_fixed_vs_reds_hr",
        "bicubic_lr_vs_reds_hr",
    ]
    missing_x4_reds_pairs = [
        label
        for label in required_x4_reds_pairs
        if label not in x4_reds_quality_pairs or x4_reds_quality_pairs[label].get("psnr_db") is None
    ]
    x4_reds_quality_ok = bool(x4_reds_quality and not missing_x4_reds_pairs)
    checks.append(
        row(
            "x4_reds_hr_quality",
            "X4 REDS HR 真值质量指标齐备",
            pass_if(x4_reds_quality_ok, "MISSING"),
            (
                f"metrics={rel(repo_root, x4_reds_quality_path)}, "
                f"pairs={list(x4_reds_quality_pairs)}, missing={missing_x4_reds_pairs}"
            ),
            "X4 tile64 fixed-vs-REDS HR 与 bicubic baseline-vs-REDS HR 的 PSNR/SSIM/MAE 指标存在",
            "用 REDS HR 或 SD 卡 HR 展示图作为 reference 运行 evaluate_sr_quality.py",
        )
    )

    x2_gate_pass = completion_gate_status(completion, "X2") == "PASS"
    x2_ready_pass = (x2_readiness or {}).get("status") == "PASS"
    x2_missing = list((x2_training or {}).get("acceptance_boundary", {}).get("missing", []))
    x2_blockers = list((x2_readiness or {}).get("blockers", []))
    x2 = manifest_acceptance(x2_manifest)
    x2_manifest_ok = bool(
        x2
        and x2.get("package_pass")
        and x2.get("scale") == 2
        and x2.get("output_width") == 1280
        and x2.get("output_height") == 720
        and as_float(x2.get("fps")) >= 30.0
        and as_int(x2.get("mismatch_bytes")) == 0
        and as_int(x2.get("max_channel_diff")) == 0
        and x2.get("bitstream_sha256")
        and x2.get("no_custom_ddr")
    )
    checks.append(
        row(
            "x2_training_freeze",
            "X2 独立训练冻结与量化/RTL 准备闭合",
            pass_if(x2_gate_pass and x2_ready_pass and not x2_blockers, "PARTIAL"),
            (
                f"training={rel(repo_root, x2_training_path)}, gate={completion_gate_status(completion, 'X2')}, "
                f"readiness={(x2_readiness or {}).get('status')}, blockers={x2_blockers}"
            ),
            "X2 gate=PASS，readiness=PASS，无量化/RTL manifest 缺口",
            "等待 X2 训练完成并运行 post-training prep",
        )
    )
    checks.append(
        row(
            "x2_gate_h",
            "X2 720p30 板上正确性与吞吐闭合",
            pass_if(x2_manifest_ok and not x2_missing, "MISSING"),
            (
                f"manifest={rel(repo_root, x2_manifest_path)}, fps={x2.get('fps')}, "
                f"mismatch={x2.get('mismatch_bytes')}/{x2.get('total_bytes')}, "
                f"missing={x2_missing}"
            ),
            "X2 scale=2，1280x720，fps>=30，mismatch=0，max diff=0，同一 bitstream/quant/checkpoint",
            "生成 X2 bitstream 并完成真实板上输出、board-vs-fixed 和吞吐验收",
        )
    )

    final_audit_pass = bool((delivery_audit or {}).get("accepted"))
    checks.append(
        row(
            "final_audit",
            "整赛题交付审计通过",
            pass_if(final_audit_pass, "NOT_COMPLETE"),
            f"accepted={(delivery_audit or {}).get('accepted')}, status={(delivery_audit or {}).get('acceptance_status')}",
            "contest_delivery_audit accepted=true",
            "X2/X4 全部闭合后重新运行交付审计",
        )
    )

    required_failed = [item for item in checks if item["required"] and item["status"] != "PASS"]
    return {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "repo_root": str(repo_root),
        "artifact_dir": artifact_dir.as_posix(),
        "status": "PASS" if not required_failed else "NOT_COMPLETE",
        "required_failed_count": len(required_failed),
        "failed_requirements": [item["id"] for item in required_failed],
        "checks": checks,
        "boundary": [
            "该校验只读取现有证据，不启动 Vivado/JTAG/板卡/训练。",
            "当前如果返回 NOT_COMPLETE，是交付状态结论，不代表脚本失败。",
            "只有所有 required check 为 PASS，才可把整赛题标为可交付。",
        ],
    }


def write_markdown(path: Path, check: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN 赛题交付包校验",
        "",
        f"生成时间：`{check['generated_at']}`",
        f"总体状态：`{check['status']}`",
        f"失败 required 项数：`{check['required_failed_count']}`",
        "",
        "本校验只读取现有证据，不启动 Vivado、JTAG、板卡或训练流程。",
        "",
        "## Required Checks",
        "",
        "| ID | 状态 | 要求 | 当前证据 | 下一步 |",
        "| --- | --- | --- | --- | --- |",
    ]
    for item in check["checks"]:
        evidence = str(item["evidence"]).replace("|", "\\|")
        expected = str(item["expected"]).replace("|", "\\|")
        action = str(item["action"]).replace("|", "\\|")
        lines.append(f"| `{item['id']}` | `{item['status']}` | {expected} | {evidence} | {action} |")

    lines.extend(["", "## 边界说明", ""])
    for item in check["boundary"]:
        lines.append(f"- {item}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--artifact-dir", type=Path, default=DEFAULT_ARTIFACT_DIR)
    parser.add_argument("--json-out", type=Path, default=DEFAULT_ARTIFACT_DIR / "contest_delivery_package_check.json")
    parser.add_argument("--md-out", type=Path, default=Path("docs/contest_delivery_package_check.md"))
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    check = build_check(repo_root, args.artifact_dir)
    json_out = repo_root / args.json_out
    md_out = repo_root / args.md_out
    json_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(json.dumps(check, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_markdown(md_out, check)
    print(f"WROTE {json_out}")
    print(f"WROTE {md_out}")
    print(f"STATUS {check['status']}")
    if check["status"] != "PASS" and not args.allow_incomplete:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
