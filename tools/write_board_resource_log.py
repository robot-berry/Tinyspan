from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def first_match(pattern: str, text: str, *, group: int = 1, default: str = "") -> str:
    match = re.search(pattern, text, flags=re.MULTILINE)
    return match.group(group) if match else default


def parse_util_value(text: str, name: str) -> str:
    escaped = re.escape(name)
    patterns = [
        rf"\|\s*{escaped}\s*\|\s*([0-9.]+)",
        rf"^\s*{escaped}\s*[:|]\s*([0-9.]+)",
    ]
    for pattern in patterns:
        value = first_match(pattern, text)
        if value:
            return value
    return ""


def parse_timing(text: str) -> tuple[str, str]:
    wns = first_match(r"^\s*WNS\(ns\)\s+TNS\(ns\).*?\n\s*([-+]?\d+(?:\.\d+)?)", text)
    whs = first_match(r"^\s*WHS\(ns\)\s+THS\(ns\).*?\n\s*([-+]?\d+(?:\.\d+)?)", text)
    if wns or whs:
        return wns, whs

    row = re.search(
        r"(?m)^\s*([-+]?\d+(?:\.\d+)?)\s+[-+]?\d+(?:\.\d+)?\s+\d+\s+\d+\s+([-+]?\d+(?:\.\d+)?)",
        text,
    )
    if row:
        return row.group(1), row.group(2)
    return "", ""


def parse_jtag_perf(text: str) -> tuple[str, str, str]:
    frame_cycles = first_match(r"JTAG_FRAME_CYCLES=(\d+)", text)
    frame_done = first_match(r"JTAG_FRAME_DONE=(\d+)", text)
    e2e_cycles = first_match(r"JTAG_E2E_CYCLES=(\d+)", text)
    return frame_cycles, frame_done, e2e_cycles


def maybe_number(value: str) -> int | float | str:
    if value == "":
        return value
    if re.fullmatch(r"[-+]?\d+", value):
        return int(value)
    if re.fullmatch(r"[-+]?\d+(?:\.\d+)?", value):
        return float(value)
    return value


def main() -> None:
    parser = argparse.ArgumentParser(description="Write standardized board resource JSON for TinySPAN acceptance.")
    parser.add_argument("--utilization-report", type=Path, required=True)
    parser.add_argument("--timing-report", type=Path, required=True)
    parser.add_argument("--jtag-log", type=Path, required=True)
    parser.add_argument("--summary-json", type=Path, required=True)
    parser.add_argument("--measured-fps", type=float, required=True)
    parser.add_argument("--clock-mhz", type=float, default=0.0)
    parser.add_argument("--bitstream", default="")
    parser.add_argument("--note", default="")
    args = parser.parse_args()

    util_text = read_text(args.utilization_report)
    timing_text = read_text(args.timing_report)
    jtag_text = read_text(args.jtag_log)

    wns, whs = parse_timing(timing_text)
    perf_frame_cycles, perf_frame_done, perf_e2e_cycles = parse_jtag_perf(jtag_text)
    summary = {
        "utilization_report": str(args.utilization_report),
        "timing_report": str(args.timing_report),
        "jtag_log": str(args.jtag_log),
        "bitstream": args.bitstream,
        "clb_luts": maybe_number(parse_util_value(util_text, "CLB LUTs")),
        "clb_registers": maybe_number(parse_util_value(util_text, "CLB Registers")),
        "block_ram_tile": maybe_number(parse_util_value(util_text, "Block RAM Tile")),
        "dsps": maybe_number(parse_util_value(util_text, "DSPs")),
        "wns_ns": maybe_number(wns),
        "whs_ns": maybe_number(whs),
        "perf_frame_cycles": maybe_number(perf_frame_cycles),
        "perf_frame_done": maybe_number(perf_frame_done),
        "perf_e2e_cycles": maybe_number(perf_e2e_cycles),
        "measured_fps": args.measured_fps,
        "clock_mhz": args.clock_mhz,
        "note": args.note,
    }
    required = [
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
    missing = [key for key in required if summary.get(key) in ("", None)]
    summary["resource_log_pass"] = not missing
    summary["missing_fields"] = missing

    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
