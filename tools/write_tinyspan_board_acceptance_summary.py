from __future__ import annotations

import argparse
import json
from pathlib import Path


def optional_path(value: str) -> str:
    return value if value else ""


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Write TinySPAN board acceptance summary.")
    parser.add_argument("--compare-summary", type=Path, required=True)
    parser.add_argument("--summary-json", type=Path, required=True)
    parser.add_argument("--summary-md", type=Path, required=True)
    parser.add_argument("--target-fps", type=float, required=True)
    parser.add_argument("--measured-fps", type=float, required=True)
    parser.add_argument("--checkpoint", default="")
    parser.add_argument("--quant-plan", default="")
    parser.add_argument("--bitstream", default="")
    parser.add_argument("--board-log", default="")
    parser.add_argument("--require-board-resources", action="store_true")
    parser.add_argument("--target-name", default="TinySPAN")
    args = parser.parse_args()

    compare = read_json(args.compare_summary)
    board_resources = {}
    if args.board_log:
        board_log_path = Path(args.board_log)
        if board_log_path.exists() and board_log_path.suffix.lower() == ".json":
            board_resources = read_json(board_log_path)
    required_resource_fields = [
        "utilization_report",
        "timing_report",
        "clb_luts",
        "clb_registers",
        "block_ram_tile",
        "dsps",
        "wns_ns",
        "whs_ns",
        "perf_frame_cycles",
        "perf_e2e_cycles",
        "measured_fps",
    ]
    missing_resource_fields = [
        field
        for field in required_resource_fields
        if field not in board_resources or board_resources.get(field) in ("", None)
    ]
    compare_pass = bool(compare.get("pass", False))
    fps_pass = args.measured_fps >= args.target_fps
    resources_pass = not args.require_board_resources or not missing_resource_fields
    passed = compare_pass and fps_pass and resources_pass

    summary = {
        "target_name": args.target_name,
        "pass": passed,
        "compare_pass": compare_pass,
        "fps_pass": fps_pass,
        "resources_pass": resources_pass,
        "target_fps": args.target_fps,
        "measured_fps": args.measured_fps,
        "checkpoint": optional_path(args.checkpoint),
        "quant_plan": optional_path(args.quant_plan),
        "bitstream": optional_path(args.bitstream),
        "board_log": optional_path(args.board_log),
        "board_resources": board_resources,
        "required_resource_fields": required_resource_fields if args.require_board_resources else [],
        "missing_resource_fields": missing_resource_fields if args.require_board_resources else [],
        "compare_summary": str(args.compare_summary),
        "software": compare.get("software", ""),
        "fixed": compare.get("fixed", ""),
        "board": compare.get("board", ""),
        "preview": compare.get("preview", ""),
        "mismatch_bytes": compare.get("mismatch_bytes"),
        "total_bytes": compare.get("total_bytes"),
        "max_channel_diff": compare.get("max_channel_diff"),
        "max_allowed_diff": compare.get("max_allowed_diff"),
        "max_allowed_mismatch_bytes": compare.get("max_allowed_mismatch_bytes"),
    }

    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")

    status = "PASS" if passed else "FAIL"
    compare_status = "PASS" if compare_pass else "FAIL"
    fps_status = "PASS" if fps_pass else "FAIL"
    resources_status = "PASS" if resources_pass else "FAIL"
    resource_lines = ""
    if board_resources:
        resource_lines = (
            "## Implementation Resources\n\n"
            f"- utilization report: `{board_resources.get('utilization_report', '')}`\n"
            f"- timing report: `{board_resources.get('timing_report', '')}`\n"
            f"- CLB LUTs: `{board_resources.get('clb_luts', '')}`\n"
            f"- CLB Registers: `{board_resources.get('clb_registers', '')}`\n"
            f"- Block RAM Tile: `{board_resources.get('block_ram_tile', '')}`\n"
            f"- DSPs: `{board_resources.get('dsps', '')}`\n"
            f"- WNS ns: `{board_resources.get('wns_ns', '')}`\n"
            f"- WHS ns: `{board_resources.get('whs_ns', '')}`\n"
            f"- perf frame cycles: `{board_resources.get('perf_frame_cycles', '')}`\n"
            f"- perf E2E cycles: `{board_resources.get('perf_e2e_cycles', '')}`\n"
            f"- measured fps: `{board_resources.get('measured_fps', '')}`\n\n"
        )
    elif args.require_board_resources:
        resource_lines = "## Implementation Resources\n\n- missing required board resource JSON\n\n"
    args.summary_md.write_text(
        "# TinySPAN Board Acceptance Summary\n\n"
        f"- Status: `{status}`\n"
        f"- Target: `{args.target_name}`\n"
        f"- Board-vs-software compare: `{compare_status}`\n"
        f"- Throughput: `{fps_status}` ({args.measured_fps:.4f} fps / target {args.target_fps:.4f} fps)\n"
        f"- Resource evidence: `{resources_status}`\n"
        f"- missing resource fields: `{', '.join(summary['missing_resource_fields'])}`\n"
        f"- mismatch bytes: `{summary['mismatch_bytes']} / {summary['total_bytes']}`\n"
        f"- max channel diff: `{summary['max_channel_diff']}`\n"
        f"- checkpoint: `{summary['checkpoint']}`\n"
        f"- quant plan: `{summary['quant_plan']}`\n"
        f"- bitstream: `{summary['bitstream']}`\n"
        f"- board log: `{summary['board_log']}`\n"
        f"- software: `{summary['software']}`\n"
        f"- fixed: `{summary['fixed']}`\n"
        f"- board: `{summary['board']}`\n"
        f"- preview: `{summary['preview']}`\n"
        f"- compare summary: `{summary['compare_summary']}`\n\n"
        f"{resource_lines}",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
