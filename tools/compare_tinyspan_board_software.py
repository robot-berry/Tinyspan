from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageStat


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare TinySPAN board output against software output.")
    parser.add_argument("--software", type=Path, required=True)
    parser.add_argument("--fixed", type=Path, required=True)
    parser.add_argument("--board", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--summary-json", type=Path, required=True)
    parser.add_argument("--summary-md", type=Path, required=True)
    parser.add_argument("--max-allowed-diff", type=int, default=0)
    parser.add_argument("--max-allowed-mismatch-bytes", type=int, default=0)
    args = parser.parse_args()

    software = Image.open(args.software).convert("RGB")
    board = Image.open(args.board).convert("RGB")
    size_match = board.size == software.size
    if size_match:
        diff = ImageChops.difference(software, board)
        stat = ImageStat.Stat(diff)
        max_diff = max(int(v) for channel in stat.extrema for v in channel)
        mismatch_bytes = sum(1 for b in diff.tobytes() if b)
    else:
        max_diff = 255
        mismatch_bytes = software.width * software.height * 3
    total_bytes = software.width * software.height * 3
    passed = (
        size_match
        and mismatch_bytes <= args.max_allowed_mismatch_bytes
        and max_diff <= args.max_allowed_diff
    )

    summary = {
        "software": str(args.software),
        "fixed": str(args.fixed),
        "board": str(args.board),
        "preview": str(args.preview),
        "mismatch_bytes": mismatch_bytes,
        "total_bytes": total_bytes,
        "max_channel_diff": max_diff,
        "software_size": list(software.size),
        "board_size": list(board.size),
        "size_match": size_match,
        "max_allowed_diff": args.max_allowed_diff,
        "max_allowed_mismatch_bytes": args.max_allowed_mismatch_bytes,
        "pass": passed,
    }

    args.summary_json.parent.mkdir(parents=True, exist_ok=True)
    args.summary_json.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    args.summary_md.write_text(
        "# TinySPAN Board-vs-Software Summary\n\n"
        f"- Status: {'PASS' if passed else 'FAIL'}\n"
        f"- mismatch bytes: {mismatch_bytes}/{total_bytes}\n"
        f"- max channel diff: {max_diff}\n"
        f"- software size: {software.size[0]}x{software.size[1]}\n"
        f"- board size: {board.size[0]}x{board.size[1]}\n"
        f"- size match: {size_match}\n"
        f"- max allowed mismatch bytes: {args.max_allowed_mismatch_bytes}\n"
        f"- max allowed diff: {args.max_allowed_diff}\n"
        f"- software: {args.software}\n"
        f"- fixed: {args.fixed}\n"
        f"- board: {args.board}\n"
        f"- preview: {args.preview}\n",
        encoding="utf-8",
    )
    print(json.dumps(summary, indent=2))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
