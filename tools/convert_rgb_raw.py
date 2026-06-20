import argparse
from pathlib import Path

from PIL import Image


def image_to_raw(src: Path, dst: Path, width: int, height: int) -> None:
    img = Image.open(src).convert("RGB").resize((width, height), Image.BICUBIC)
    dst.write_bytes(img.tobytes())


def raw_to_image(src: Path, dst: Path, width: int, height: int) -> None:
    data = src.read_bytes()
    expected = width * height * 3
    if len(data) != expected:
        raise SystemExit(f"raw size mismatch: got {len(data)}, expected {expected}")
    img = Image.frombytes("RGB", (width, height), data)
    img.save(dst)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert between RGB888 raw and common images.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p0 = sub.add_parser("to-raw")
    p0.add_argument("src", type=Path)
    p0.add_argument("dst", type=Path)
    p0.add_argument("--width", type=int, default=64)
    p0.add_argument("--height", type=int, default=64)

    p1 = sub.add_parser("from-raw")
    p1.add_argument("src", type=Path)
    p1.add_argument("dst", type=Path)
    p1.add_argument("--width", type=int, default=128)
    p1.add_argument("--height", type=int, default=128)

    args = parser.parse_args()
    if args.cmd == "to-raw":
        image_to_raw(args.src, args.dst, args.width, args.height)
    else:
        raw_to_image(args.src, args.dst, args.width, args.height)


if __name__ == "__main__":
    main()
