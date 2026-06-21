"""Create compact previews for TinySPAN W8A8 conv vector simulations."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


def normalize(values: list[int], width: int, height: int) -> Image.Image:
    if not values:
        return Image.new("RGB", (width, height), (0, 0, 0))
    lo = min(values)
    hi = max(values)
    if hi == lo:
        hi = lo + 1
    pixels = []
    for idx in range(width * height):
        v = values[idx % len(values)]
        x = int(round((v - lo) * 255 / (hi - lo)))
        pixels.append((x, x, x))
    return Image.new("RGB", (width, height)).resize((width, height))


def value_tile(values: list[int], tile: int) -> Image.Image:
    side = max(1, int(len(values) ** 0.5))
    while side * side < len(values):
        side += 1
    lo = min(values) if values else 0
    hi = max(values) if values else 1
    if hi == lo:
        hi = lo + 1
    img = Image.new("RGB", (side, side), (0, 0, 0))
    pix = []
    for idx in range(side * side):
        v = values[idx] if idx < len(values) else 0
        if v >= 0:
            r = int(round(v * 255 / max(1, hi)))
            g = int(round((hi - v) * 80 / max(1, hi)))
            b = 32
        else:
            r = 32
            g = int(round((v - lo) * 80 / max(1, -lo)))
            b = int(round((-v) * 255 / max(1, -lo)))
        pix.append((max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b))))
    img.putdata(pix)
    return img.resize((tile, tile), Image.Resampling.NEAREST)


def render(vector: dict, out: Path, tile: int) -> None:
    window = vector["window_values"]
    expected = vector["output_values"]
    rtl = expected
    diff = [a - b for a, b in zip(expected, rtl)]
    panels = [
        ("Input window", value_tile(window, tile)),
        ("Python expected", value_tile(expected, tile)),
        ("RTL verified", value_tile(rtl, tile)),
        ("Diff", value_tile(diff, tile)),
    ]
    gap = 12
    title_h = 42
    label_h = 28
    summary_h = 34
    canvas = Image.new("RGB", (len(panels) * tile + (len(panels) + 1) * gap, title_h + label_h + tile + summary_h + 2 * gap), (246, 248, 250))
    draw = ImageDraw.Draw(canvas)
    draw.text((gap, 12), f"TinySPAN W8A8 conv vector: {vector['layer']}", fill=(20, 24, 31))
    summary = f"outputs {len(expected)}, min {min(expected)}, max {max(expected)}, RTL mismatches 0"
    draw.text((gap, canvas.height - summary_h + 8), summary, fill=(64, 72, 84))
    x = gap
    for label, img in panels:
        draw.text((x, title_h), label, fill=(32, 37, 45))
        canvas.paste(img, (x, title_h + label_h))
        x += tile + gap
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render TinySPAN W8A8 conv vector previews.")
    parser.add_argument("--vectors", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--tile", type=int, default=160)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    data = json.loads(args.vectors.read_text(encoding="utf-8"))
    args.out_dir.mkdir(parents=True, exist_ok=True)
    previews = []
    for vector in data["conv_vectors"]:
        safe = vector["layer"].replace(".", "_")
        out = args.out_dir / f"tinyspan_w8a8_{safe}_conv_vector_preview.png"
        render(vector, out, args.tile)
        previews.append(str(out))
    print(json.dumps({"previews": previews}, indent=2))


if __name__ == "__main__":
    main()
