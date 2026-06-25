#!/usr/bin/env python3
"""Audit TinySPAN X2 hardware-readiness without running Vivado or board flows."""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def latest_file(root: Path, pattern: str) -> Path | None:
    candidates = [path for path in root.glob(pattern) if path.is_file()]
    if not candidates:
        return None
    return max(candidates, key=lambda path: path.stat().st_mtime)


def rel(path: Path | None, root: Path) -> str:
    if path is None:
        return ""
    try:
        return str(path.relative_to(root)).replace("\\", "/")
    except ValueError:
        return str(path)


def check(check_id: str, status: str, detail: str, required: bool = True) -> dict[str, Any]:
    return {"id": check_id, "status": status, "detail": detail, "required": required}


def exists_check(repo: Path, check_id: str, path: str, required: bool = True) -> dict[str, Any]:
    full = repo / path
    return check(check_id, "PASS" if full.exists() else "FAIL", path, required)


def contains_check(
    repo: Path,
    check_id: str,
    path: str,
    needle: str,
    required: bool = True,
    invert: bool = False,
) -> dict[str, Any]:
    text = read_text(repo / path)
    found = needle in text
    passed = (not found) if invert else found
    mode = "does not contain" if invert else "contains"
    return check(check_id, "PASS" if passed else "FAIL", f"{path} {mode} {needle!r}", required)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument(
        "--json-out",
        type=Path,
        default=Path("artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/x2_hardware_readiness.json"),
    )
    parser.add_argument(
        "--md-out",
        type=Path,
        default=Path("docs/x2_hardware_readiness.md"),
    )
    args = parser.parse_args()

    repo = args.repo_root.resolve()
    x2_status = latest_file(
        repo / "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe",
        "x2_training_*/x2_training_status.json",
    ) or latest_file(
        repo / "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe",
        "x2_training_start_*/x2_training_status.json",
    )
    x2_quant = latest_file(repo, "runs/tinyspan_quant_plan/*_x2_c32_b4_w8a8/tinyspan_w8a8_quant_plan.json")
    x2_rtl = latest_file(repo, "rtl/generated/*_x2_w8a8/tinyspan_w8a8_rtl_manifest.json")

    checks: list[dict[str, Any]] = []
    checks.append(check("x2_training_status_artifact", "PASS" if x2_status else "FAIL", rel(x2_status, repo), False))
    checks.append(check("x2_quant_plan_exists", "PASS" if x2_quant else "FAIL", rel(x2_quant, repo), True))
    checks.append(check("x2_rtl_manifest_exists", "PASS" if x2_rtl else "FAIL", rel(x2_rtl, repo), True))
    checks.append(exists_check(repo, "x2_bicubic_base_rtl_exists", "rtl/tinyspan_core/span_tinyspan_w8a8_bicubic_base_x2_streamed.v", True))
    checks.append(
        contains_check(
            repo,
            "board_shell_scale_parameterized",
            "rtl/board_wrapper/sr_tile_tinyspan_x4_writer_shell.v",
            "parameter integer SCALE",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "ddr_endpoint_scale_parameterized",
            "rtl/board_wrapper/sr_ddr_tinyspan_x4_tile_writer_endpoint.v",
            "parameter integer SCALE",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "bd_script_accepts_scale_env",
            "scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl",
            "PS_TINYSPAN_DDR_X4_SCALE scale",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "bd_script_scale_not_hardcoded_4",
            "scripts/vivado/create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl",
            "CONFIG.SCALE {4}",
            True,
            invert=True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "bd_wrapper_exposes_scale_parameter",
            "scripts/vivado/run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1",
            "[int]$Scale = 4",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "full_stream_top_selects_x2_scale",
            "rtl/tinyspan_core/span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v",
            "SCALE == 2",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "full_stream_top_instantiates_x2_base",
            "rtl/tinyspan_core/span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v",
            "span_tinyspan_w8a8_bicubic_base_x2_streamed",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "integer_reference_uses_q14_x2",
            "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
            "rtl_fixed_q14_bicubic_x2",
            True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "acceptance_preflight_supports_scale",
            "scripts/acceptance/check_tinyspan_720p30_acceptance_inputs.ps1",
            "expectedInputWidth",
            True,
        )
    )

    required_failures = [item for item in checks if item["required"] and item["status"] != "PASS"]
    status = "READY" if not required_failures else "PARTIAL"
    blockers = [item["id"] for item in required_failures]
    expected_tag = "x2_frozen_auto_YYYYMMDD"
    expected_frozen_checkpoint = f"runs/tinyspan_frozen_candidates/{expected_tag}/student_final.pt"
    expected_quant_plan = (
        f"runs/tinyspan_quant_plan/{expected_tag}_x2_c32_b4_w8a8/"
        "tinyspan_w8a8_quant_plan.json"
    )
    expected_rtl_manifest = (
        f"rtl/generated/tinyspan_c32b4_{expected_tag}_x2_w8a8/"
        "tinyspan_w8a8_rtl_manifest.json"
    )
    expected_tiled_reference_dir = (
        "artifacts/20260618_x4_tinyspan_c32b4_baseline_30fps_safe/"
        f"full_frame_tiled_reference_x2_640x360_tile64x64_{expected_tag}"
    )
    expected_pytorch_sr_png = f"{expected_tiled_reference_dir}/pytorch_training_sr.png"
    expected_tiled_fixed_png = f"{expected_tiled_reference_dir}/software_tiled_fixed_point_sr.png"
    expected_bitstream = f"vivado/bitstreams/tinyspan_x2_c32b4_{expected_tag}_board.bit"
    post_training_gate_order = [
        {
            "gate": "freeze_handoff_quant_rtl",
            "command": (
                "powershell -NoProfile -ExecutionPolicy Bypass -File "
                ".\\scripts\\run_tinyspan_c32b4_post_training_prep.ps1 "
                "-RunDir ..\\runs\\tinyspan_distill\\video_x2_c32_b4_reds_temporal "
                f"-Scale 2 -Tag {expected_tag}"
            ),
            "starts_vivado_or_board": False,
            "expected": [
                f"frozen X2 checkpoint and SHA256 manifest at {expected_frozen_checkpoint}",
                f"X2 W8A8 quant plan at {expected_quant_plan}",
                f"X2 RTL manifest at {expected_rtl_manifest}",
                f"X2 hardware-tiled fixed reference at {expected_tiled_fixed_png}",
                "readiness report that remains incomplete until the X2 bitstream and board output exist",
            ],
        },
        {
            "gate": "x2_bitstream",
            "command": (
                "powershell -NoProfile -ExecutionPolicy Bypass -File "
                ".\\scripts\\vivado\\run_vivado_bitstream_ps_tinyspan_ddr_x4.ps1 "
                "-Scale 2 -ImgW 640 -ImgH 360 -TileW 64 -TileH 64 -PlFreqMhz 155 "
                "-RequireVivadoIdle"
            ),
            "starts_vivado_or_board": True,
            "expected": [
                f"X2 bitstream copied or recorded as {expected_bitstream}",
                "timing, utilization, power, and resource-gate evidence under the XC7Z045/ZC706 limits",
            ],
        },
        {
            "gate": "x2_board_acceptance",
            "command": (
                "powershell -NoProfile -ExecutionPolicy Bypass -File "
                ".\\scripts\\acceptance\\run_tinyspan_720p30_board_acceptance.ps1 "
                "-Scale 2 -InputWidth 640 -InputHeight 360 -TileWidth 64 -TileHeight 64 "
                f"-SoftwarePng {expected_pytorch_sr_png} "
                f"-FixedPng {expected_tiled_fixed_png} "
                "-BoardRaw REPLACE_WITH_X2_BOARD_OUTPUT.rgb "
                "-MeasuredFps REPLACE_WITH_MEASURED_FPS "
                f"-Checkpoint {expected_frozen_checkpoint} "
                "-QuantPlan REPLACE_WITH_X2_QUANT_PLAN.json "
                "-Bitstream REPLACE_WITH_X2_BITSTREAM.bit "
                "-BoardLog REPLACE_WITH_X2_BOARD_RESOURCE_OR_RUN_LOG.json "
                "-OutDir artifacts\\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\\gate_h_board_x2_640x360_tile64x64"
            ),
            "starts_vivado_or_board": True,
            "expected": [
                "real X2 board output from the same frozen checkpoint and quant plan",
                "A53/DDR or board-side compare mismatch 0 and max channel diff 0",
                "measured full-frame throughput >=30fps",
                "board_sr.png, comparison_preview.png, and diff_heatmap.png for visual review",
            ],
        },
    ]

    audit = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "status": status,
        "repo_root": str(repo),
        "x2_training_status": rel(x2_status, repo),
        "x2_quant_plan": rel(x2_quant, repo),
        "x2_rtl_manifest": rel(x2_rtl, repo),
        "expected_x2_frozen_checkpoint_after_freeze": expected_frozen_checkpoint,
        "expected_x2_quant_plan_after_freeze": expected_quant_plan,
        "expected_x2_rtl_manifest_after_freeze": expected_rtl_manifest,
        "expected_x2_tiled_reference_after_freeze": expected_tiled_reference_dir,
        "expected_x2_bitstream_after_vivado": expected_bitstream,
        "post_training_gate_order": post_training_gate_order,
        "blockers": blockers,
        "checks": checks,
        "notes": [
            "This audit is source/artifact only and does not start Vivado, JTAG, XSCT, board access, or training.",
            "X2 must not reuse the X4-only bicubic base core as delivery evidence.",
            "The DDR route must continue to use the board PS DDR controller IP and AXI interconnect, not a custom DDR controller or PHY.",
        ],
    }

    json_out = (repo / args.json_out).resolve() if not args.json_out.is_absolute() else args.json_out
    md_out = (repo / args.md_out).resolve() if not args.md_out.is_absolute() else args.md_out
    json_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.parent.mkdir(parents=True, exist_ok=True)
    json_out.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# TinySPAN X2 Hardware Readiness",
        "",
        f"- status: `{status}`",
        f"- generated at: `{audit['generated_at']}`",
        f"- X2 training status: `{audit['x2_training_status']}`",
        f"- X2 quant plan: `{audit['x2_quant_plan']}`",
        f"- X2 RTL manifest: `{audit['x2_rtl_manifest']}`",
        "",
        "## Blockers",
        "",
    ]
    if blockers:
        for blocker in blockers:
            lines.append(f"- `{blocker}`")
    else:
        lines.append("- none")
    lines.extend(["", "## Checks", "", "| Check | Required | Status | Detail |", "| --- | --- | --- | --- |"])
    for item in checks:
        lines.append(f"| `{item['id']}` | `{item['required']}` | `{item['status']}` | `{item['detail']}` |")
    lines.extend(
        [
            "",
            "## Post-Training Gate Order",
            "",
            "训练仍在运行时只允许刷新状态，不启动 Vivado/JTAG/板卡流程。训练达到目标 step 且进程退出后，按下面顺序推进：",
            "",
        ]
    )
    for index, gate in enumerate(post_training_gate_order, start=1):
        lines.extend(
            [
                f"{index}. `{gate['gate']}`",
                "",
                "```powershell",
                gate["command"],
                "```",
                "",
                f"- starts Vivado/board flow: `{gate['starts_vivado_or_board']}`",
            ]
        )
        for expected in gate["expected"]:
            lines.append(f"- expected: {expected}")
        lines.append("")
    lines.extend(
        [
            "## Boundary",
            "",
            "- This is a static readiness audit only.",
            "- It does not prove X2 correctness, bitstream generation, board output, or throughput.",
            "- X2 delivery still requires frozen checkpoint, W8A8 quant plan, X2 RTL/top, bitstream, real board output, board-vs-software equality, and `>=30fps` evidence.",
        ]
    )
    md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, "json": str(json_out), "md": str(md_out), "blockers": blockers}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
