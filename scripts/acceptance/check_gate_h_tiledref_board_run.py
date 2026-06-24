"""Check TinySPAN Gate H tiled-reference board-run evidence.

This is a read-only post-run checker. It does not start Vivado, JTAG, board, or
training flows. It verifies that the queued Gate H run produced the expected
files and that the hard gates are satisfied:

- board-vs-fixed byte mismatch is 0
- board-vs-fixed max channel diff is 0
- measured fps is >= 30
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime
from pathlib import Path
from typing import Any


DEFAULT_RUN_DIR = Path(
    "board_runs/tinyspan_w8a8_base_equiv_jtag/"
    "gate_h_x4_320x180_f150_20260624_tiledref"
)
DEFAULT_WAIT_LOG_DIR = Path(
    "board_runs/tinyspan_w8a8_base_equiv_jtag/"
    "gate_h_x4_320x180_f150_20260624_tiledref_waitrun"
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8-sig"))


def evidence(path: Path, required: bool = True, hash_file: bool = False) -> dict[str, Any]:
    row: dict[str, Any] = {
        "path": str(path),
        "required": required,
        "exists": path.exists(),
    }
    if path.exists():
        row["bytes"] = path.stat().st_size
        row["mtime"] = datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds")
        if hash_file and path.is_file():
            row["sha256"] = sha256_file(path)
    return row


def bool_gate(name: str, passed: bool, detail: Any) -> dict[str, Any]:
    return {"name": name, "pass": bool(passed), "detail": detail}


def write_markdown(path: Path, result: dict[str, Any]) -> None:
    lines = [
        "# TinySPAN Gate H Tiled-Reference Board Run Check",
        "",
        f"- status: `{result['status']}`",
        f"- generated at: `{result['generated_at']}`",
        f"- run dir: `{result['run_dir']}`",
        f"- wait log dir: `{result['wait_log_dir']}`",
        "",
        "## Gates",
        "",
    ]
    for gate in result["gates"]:
        lines.append(f"- `{'PASS' if gate['pass'] else 'FAIL'}` {gate['name']}: `{gate['detail']}`")
    if result["missing_required"]:
        lines.extend(["", "## Missing Required Files", ""])
        for item in result["missing_required"]:
            lines.append(f"- `{item}`")
    lines.extend(["", "## Evidence Files", ""])
    for item in result["evidence"]:
        state = "PASS" if item["exists"] else "MISS"
        lines.append(f"- `{state}` `{item['path']}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace-root", type=Path, default=Path(".."))
    parser.add_argument("--tinyspan-root", type=Path, default=Path("."))
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--wait-log-dir", type=Path, default=DEFAULT_WAIT_LOG_DIR)
    parser.add_argument("--summary-json", type=Path, default=None)
    parser.add_argument("--summary-md", type=Path, default=None)
    parser.add_argument("--allow-incomplete", action="store_true")
    args = parser.parse_args()

    tinyspan_root = args.tinyspan_root.resolve()
    workspace_root = (tinyspan_root / args.workspace_root).resolve() if not args.workspace_root.is_absolute() else args.workspace_root.resolve()
    run_dir = (workspace_root / args.run_dir).resolve() if not args.run_dir.is_absolute() else args.run_dir.resolve()
    wait_log_dir = (workspace_root / args.wait_log_dir).resolve() if not args.wait_log_dir.is_absolute() else args.wait_log_dir.resolve()

    acceptance_dir = run_dir / "acceptance_tiled_fixed"
    acceptance_summary_path = acceptance_dir / "tinyspan_720p30_board_acceptance_summary.json"
    board_compare_path = acceptance_dir / "tinyspan_board_software_summary.json"
    resource_path = run_dir / "implementation_resources.json"
    required_paths = [
        resource_path,
        run_dir / "input_x4_320x180_tinyspan_w8a8_base_equiv.rgb",
        run_dir / "board_output_x4_320x180_tinyspan_w8a8_base_equiv.rgb",
        run_dir / "board_output_x4_320x180_tinyspan_w8a8_base_equiv.png",
        acceptance_summary_path,
        acceptance_dir / "tinyspan_720p30_board_acceptance_summary.md",
        board_compare_path,
        acceptance_dir / "tinyspan_board_software_summary.md",
        acceptance_dir / "tinyspan_board_software_preview.png",
        acceptance_dir / "diff_heatmap.png",
    ]
    optional_paths = [
        wait_log_dir / "waitrun_stdout.log",
        wait_log_dir / "waitrun_stderr.log",
        wait_log_dir / "jtag_smoke_wrapper.log",
        wait_log_dir / "acceptance_tiled_fixed_wrapper.log",
        run_dir / "jtag_transfer.log",
        run_dir / "jtag_perf_only.log",
    ]
    evidence_rows = [evidence(path, required=True, hash_file=path.suffix.lower() in {".json", ".png", ".rgb"}) for path in required_paths]
    evidence_rows.extend(evidence(path, required=False) for path in optional_paths)
    missing = [row["path"] for row in evidence_rows if row["required"] and not row["exists"]]

    acceptance = read_json(acceptance_summary_path)
    board_compare = read_json(board_compare_path)
    resources = read_json(resource_path)

    gates: list[dict[str, Any]] = []
    gates.append(bool_gate("required_files_present", not missing, f"missing={len(missing)}"))
    if acceptance:
        gates.extend(
            [
                bool_gate("acceptance_pass", bool(acceptance.get("pass")), acceptance.get("pass")),
                bool_gate("compare_pass", bool(acceptance.get("compare_pass")), acceptance.get("compare_pass")),
                bool_gate("fps_pass", bool(acceptance.get("fps_pass")), acceptance.get("fps_pass")),
                bool_gate("measured_fps_ge_30", float(acceptance.get("measured_fps", -1)) >= 30.0, acceptance.get("measured_fps")),
                bool_gate("mismatch_bytes_zero", int(acceptance.get("mismatch_bytes", -1)) == 0, acceptance.get("mismatch_bytes")),
                bool_gate("max_diff_zero", int(acceptance.get("max_channel_diff", -1)) == 0, acceptance.get("max_channel_diff")),
            ]
        )
    else:
        gates.append(bool_gate("acceptance_summary_present", False, str(acceptance_summary_path)))
    if board_compare:
        gates.append(bool_gate("board_vs_fixed_pass", bool(board_compare.get("board_vs_fixed_pass", board_compare.get("pass"))), board_compare.get("board_vs_fixed")))
    else:
        gates.append(bool_gate("board_compare_summary_present", False, str(board_compare_path)))
    if resources:
        gates.append(bool_gate("resource_measured_fps_ge_30", float(resources.get("measured_fps", -1)) >= 30.0, resources.get("measured_fps")))
        gates.append(bool_gate("resource_perf_cycles_present", int(resources.get("perf_frame_cycles") or 0) > 0, resources.get("perf_frame_cycles")))
    else:
        gates.append(bool_gate("resource_json_present", False, str(resource_path)))

    passed = all(gate["pass"] for gate in gates)
    status = "PASS" if passed else "INCOMPLETE_OR_FAIL"
    result = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "status": status,
        "pass": passed,
        "workspace_root": str(workspace_root),
        "tinyspan_root": str(tinyspan_root),
        "run_dir": str(run_dir),
        "wait_log_dir": str(wait_log_dir),
        "acceptance_summary": acceptance,
        "board_compare_summary": board_compare,
        "resources": resources,
        "gates": gates,
        "missing_required": missing,
        "evidence": evidence_rows,
    }

    if args.summary_json:
        summary_json = (tinyspan_root / args.summary_json).resolve() if not args.summary_json.is_absolute() else args.summary_json.resolve()
        summary_json.parent.mkdir(parents=True, exist_ok=True)
        summary_json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if args.summary_md:
        summary_md = (tinyspan_root / args.summary_md).resolve() if not args.summary_md.is_absolute() else args.summary_md.resolve()
        summary_md.parent.mkdir(parents=True, exist_ok=True)
        write_markdown(summary_md, result)

    print(json.dumps({"status": status, "pass": passed, "missing_required": missing, "gates": gates}, ensure_ascii=False, indent=2))
    if not passed and not args.allow_incomplete:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
