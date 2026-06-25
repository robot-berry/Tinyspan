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
            "full_stream_top_not_x4_only",
            "rtl/tinyspan_core/span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v",
            "bicubic_base_x4",
            True,
            invert=True,
        )
    )
    checks.append(
        contains_check(
            repo,
            "integer_reference_supports_x2_fallback",
            "tools/model_to_hardware/run_tinyspan_w8a8_integer_reference.py",
            "pytorch_bicubic_fallback",
            False,
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

    audit = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "status": status,
        "repo_root": str(repo),
        "x2_training_status": rel(x2_status, repo),
        "x2_quant_plan": rel(x2_quant, repo),
        "x2_rtl_manifest": rel(x2_rtl, repo),
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
