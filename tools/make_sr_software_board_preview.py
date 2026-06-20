import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat


def load_rgb_raw(path: Path, width: int, height: int) -> Image.Image:
    data = path.read_bytes()
    expected = width * height * 3
    if len(data) != expected:
        raise SystemExit(f"raw size mismatch for {path}: got {len(data)}, expected {expected}")
    return Image.frombytes("RGB", (width, height), data)


def fit_tile(img: Image.Image, tile: int) -> Image.Image:
    fitted = img.copy()
    fitted.thumbnail((tile, tile), Image.Resampling.BICUBIC)
    canvas = Image.new("RGB", (tile, tile), (18, 22, 28))
    canvas.paste(fitted, ((tile - fitted.width) // 2, (tile - fitted.height) // 2))
    return canvas


def make_diff(ref: Image.Image, actual: Image.Image, gain: int) -> tuple[Image.Image, int, int]:
    if ref.size != actual.size:
        actual = actual.resize(ref.size, Image.Resampling.BICUBIC)
    diff = ImageChops.difference(ref, actual)
    stat = ImageStat.Stat(diff)
    max_diff = max(int(v) for channel in stat.extrema for v in channel)
    mismatch_bytes = sum(1 for b in diff.tobytes() if b)
    if gain != 1:
        diff = diff.point(lambda value: min(255, value * gain))
    return diff, max_diff, mismatch_bytes


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a software/fixed/board super-resolution comparison preview.")
    parser.add_argument("--input-raw", type=Path, required=True)
    parser.add_argument("--input-width", type=int, required=True)
    parser.add_argument("--input-height", type=int, required=True)
    parser.add_argument("--software", type=Path, required=True)
    parser.add_argument("--fixed", type=Path, required=True)
    parser.add_argument("--board", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--title", default="SPAN software/fixed/board comparison")
    parser.add_argument("--tile", type=int, default=180)
    parser.add_argument("--diff-gain", type=int, default=8)
    args = parser.parse_args()

    inp = load_rgb_raw(args.input_raw, args.input_width, args.input_height)
    software = Image.open(args.software).convert("RGB")
    fixed = Image.open(args.fixed).convert("RGB")
    board = Image.open(args.board).convert("RGB")
    diff, max_diff, mismatch_bytes = make_diff(software, board, args.diff_gain)

    panels = [
        (f"Input {inp.width}x{inp.height}", fit_tile(inp, args.tile)),
        (f"PyTorch {software.width}x{software.height}", fit_tile(software, args.tile)),
        (f"Fixed Ref {fixed.width}x{fixed.height}", fit_tile(fixed, args.tile)),
        (f"Board {board.width}x{board.height}", fit_tile(board, args.tile)),
        (f"Board-Software Diff x{args.diff_gain}", fit_tile(diff, args.tile)),
    ]

    label_h = 28
    title_h = 42
    summary_h = 30
    gap = 12
    width = len(panels) * args.tile + (len(panels) + 1) * gap
    height = title_h + label_h + args.tile + summary_h + 2 * gap
    canvas = Image.new("RGB", (width, height), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), args.title, fill=(20, 24, 31))
    summary = f"board-vs-software mismatch bytes: {mismatch_bytes}/{software.width * software.height * 3}, max channel diff: {max_diff}"
    draw.text((gap, height - summary_h + 5), summary, fill=(64, 72, 84))

    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += args.tile + gap

    args.out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(args.out)
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
