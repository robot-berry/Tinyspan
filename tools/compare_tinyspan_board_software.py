from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def compare_pair(ref: Image.Image, actual: Image.Image, diff_gain: int = 1) -> tuple[dict, Image.Image]:
    size_match = actual.size == ref.size
    if size_match:
        diff = ImageChops.difference(ref, actual)
        stat = ImageStat.Stat(diff)
        max_diff = max(int(v) for channel in stat.extrema for v in channel)
        mismatch_bytes = sum(1 for b in diff.tobytes() if b)
    else:
        max_diff = 255
        mismatch_bytes = ref.width * ref.height * 3
        diff = ImageChops.difference(ref, actual.resize(ref.size, Image.Resampling.BICUBIC))
    total_bytes = ref.width * ref.height * 3
    metric = {
        "mismatch_bytes": mismatch_bytes,
        "total_bytes": total_bytes,
        "max_channel_diff": max_diff,
        "ref_size": list(ref.size),
        "actual_size": list(actual.size),
        "size_match": size_match,
    }
    if diff_gain != 1:
        diff = diff.point(lambda value: min(255, value * diff_gain))
    return metric, diff


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare TinySPAN board output against software output.")
    parser.add_argument("--software", type=Path, required=True)
    parser.add_argument("--fixed", type=Path, required=True)
    parser.add_argument("--board", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--diff-heatmap", type=Path)
    parser.add_argument("--diff-gain", type=int, default=8)
    parser.add_argument("--summary-json", type=Path, required=True)
    parser.add_argument("--summary-md", type=Path, required=True)
    parser.add_argument("--max-allowed-diff", type=int, default=0)
    parser.add_argument("--max-allowed-mismatch-bytes", type=int, default=0)
    args = parser.parse_args()

    software = Image.open(args.software).convert("RGB")
    fixed = Image.open(args.fixed).convert("RGB")
    board = Image.open(args.board).convert("RGB")

    board_vs_fixed, fixed_diff = compare_pair(fixed, board, args.diff_gain)
    board_vs_training, _ = compare_pair(software, board)
    fixed_vs_training, _ = compare_pair(software, fixed)
    passed = (
        board_vs_fixed["size_match"]
        and board_vs_fixed["mismatch_bytes"] <= args.max_allowed_mismatch_bytes
        and board_vs_fixed["max_channel_diff"] <= args.max_allowed_diff
    )

    diff_heatmap = ""
    if args.diff_heatmap:
        args.diff_heatmap.parent.mkdir(parents=True, exist_ok=True)
        fixed_diff.save(args.diff_heatmap)
        diff_heatmap = str(args.diff_heatmap)

    summary = {
        "software": str(args.software),
        "fixed": str(args.fixed),
        "board": str(args.board),
        "preview": str(args.preview),
        "diff_heatmap": diff_heatmap,
        "mismatch_bytes": board_vs_fixed["mismatch_bytes"],
        "total_bytes": board_vs_fixed["total_bytes"],
        "max_channel_diff": board_vs_fixed["max_channel_diff"],
        "software_size": list(software.size),
        "fixed_size": list(fixed.size),
        "board_size": list(board.size),
        "size_match": board_vs_fixed["size_match"],
        "max_allowed_diff": args.max_allowed_diff,
        "max_allowed_mismatch_bytes": args.max_allowed_mismatch_bytes,
        "board_vs_fixed": board_vs_fixed,
        "board_vs_training": board_vs_training,
        "fixed_vs_training": fixed_vs_training,
        "board_vs_fixed_pass": passed,
        "pass": passed,
    }

    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    args.summary_md.write_text(
        "# TinySPAN Board-vs-Fixed Summary\n\n"
        f"- Status: {'PASS' if passed else 'FAIL'}\n"
        f"- hard gate: board output must match the fixed-point tiled reference\n"
        f"- board-vs-fixed mismatch bytes: {board_vs_fixed['mismatch_bytes']}/{board_vs_fixed['total_bytes']}\n"
        f"- board-vs-fixed max channel diff: {board_vs_fixed['max_channel_diff']}\n"
        f"- board-vs-training mismatch bytes: {board_vs_training['mismatch_bytes']}/{board_vs_training['total_bytes']}\n"
        f"- board-vs-training max channel diff: {board_vs_training['max_channel_diff']}\n"
        f"- fixed-vs-training mismatch bytes: {fixed_vs_training['mismatch_bytes']}/{fixed_vs_training['total_bytes']}\n"
        f"- fixed-vs-training max channel diff: {fixed_vs_training['max_channel_diff']}\n"
        f"- software size: {software.size[0]}x{software.size[1]}\n"
        f"- fixed size: {fixed.size[0]}x{fixed.size[1]}\n"
        f"- board size: {board.size[0]}x{board.size[1]}\n"
        f"- board-vs-fixed size match: {board_vs_fixed['size_match']}\n"
        f"- max allowed mismatch bytes: {args.max_allowed_mismatch_bytes}\n"
        f"- max allowed diff: {args.max_allowed_diff}\n"
        f"- software: {args.software}\n"
        f"- fixed: {args.fixed}\n"
        f"- board: {args.board}\n"
        f"- preview: {args.preview}\n"
        + (f"- diff heatmap: {diff_heatmap}\n" if diff_heatmap else ""),
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
