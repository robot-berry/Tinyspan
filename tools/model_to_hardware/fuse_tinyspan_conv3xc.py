"""Fuse TinySPAN Conv3XC blocks and measure equivalence.

TinySPAN trains each SPAB conv as Conv3XC:

    1x1 C->2C, 3x3 2C->2C, 1x1 2C->C, plus a 1x1 skip.

For FPGA deployment the intended datapath is one 3x3 C->C convolution. This
tool builds that fused kernel, replaces the PyTorch modules, and reports how
closely the fused model matches the original checkpoint.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

os.environ.setdefault("KMP_DUPLICATE_LIB_OK", "TRUE")

import torch
from torch import nn

def find_repo_root() -> Path:
    for parent in Path(__file__).resolve().parents:
        if (parent / "train" / "span_model.py").exists():
            return parent
    return Path(__file__).resolve().parents[2]


REPO_ROOT = find_repo_root()
TRAIN_DIR = REPO_ROOT / "train"
if str(TRAIN_DIR) not in sys.path:
    sys.path.insert(0, str(TRAIN_DIR))

from span_model import Conv3XC, TinySPAN, build_model  # noqa: E402


@dataclass(frozen=True)
class CompareStats:
    name: str
    values: int
    max_abs: float
    mae: float
    mse: float
    psnr_db: float


class FusedConv3XC(nn.Module):
    def __init__(self, weight: torch.Tensor, bias: torch.Tensor) -> None:
        super().__init__()
        channels = int(weight.shape[0])
        self.conv = nn.Conv2d(channels, channels, 3, 1, 1)
        with torch.no_grad():
            self.conv.weight.copy_(weight)
            self.conv.bias.copy_(bias)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.conv(x)


def stats(name: str, a: torch.Tensor, b: torch.Tensor) -> CompareStats:
    diff = (a - b).detach().float()
    mse = float(torch.mean(diff * diff).item())
    mae = float(torch.mean(diff.abs()).item())
    max_abs = float(diff.abs().max().item())
    psnr = 99.0 if mse <= 0 else float(10.0 * torch.log10(torch.tensor(1.0 / mse)).item())
    return CompareStats(name=name, values=diff.numel(), max_abs=max_abs, mae=mae, mse=mse, psnr_db=psnr)


def center_crop(x: torch.Tensor, border: int) -> torch.Tensor:
    if border <= 0:
        return x
    if x.shape[-1] <= 2 * border or x.shape[-2] <= 2 * border:
        return x
    return x[..., border:-border, border:-border]


def fuse_conv3xc(module: Conv3XC) -> tuple[torch.Tensor, torch.Tensor]:
    conv1 = module.conv1
    conv2 = module.conv2
    conv3 = module.conv3
    skip = module.skip

    w1 = conv1.weight.detach().float()[:, :, 0, 0]  # H, C
    b1 = conv1.bias.detach().float()
    w2 = conv2.weight.detach().float()  # H, H, 3, 3
    b2 = conv2.bias.detach().float()
    w3 = conv3.weight.detach().float()[:, :, 0, 0]  # C, H
    b3 = conv3.bias.detach().float()
    wsk = skip.weight.detach().float()[:, :, 0, 0]  # C, C
    bsk = skip.bias.detach().float()

    # Equivalent interior kernel for zero-padded Conv2d. Border pixels can still
    # differ when conv1 has a bias because padding hides part of that constant.
    fused_w = torch.einsum("oh,hmxy,mi->oixy", w3, w2, w1)
    center = fused_w.shape[-1] // 2
    fused_w[:, :, center, center] += wsk

    conv2_bias_interior = b2 + torch.einsum("hmxy,m->h", w2, b1)
    fused_b = b3 + torch.einsum("oh,h->o", w3, conv2_bias_interior) + bsk
    return fused_w, fused_b


def replace_conv3xc(model: TinySPAN) -> dict[str, dict[str, object]]:
    manifest: dict[str, dict[str, object]] = {}
    for block_idx, block in enumerate(model.blocks):
        for attr in ("c1", "c2", "c3"):
            original = getattr(block, attr)
            if not isinstance(original, Conv3XC):
                raise TypeError(f"expected Conv3XC at blocks.{block_idx}.{attr}")
            weight, bias = fuse_conv3xc(original)
            setattr(block, attr, FusedConv3XC(weight, bias))
            manifest[f"blocks.{block_idx}.{attr}"] = {
                "weight_shape": list(weight.shape),
                "bias_shape": list(bias.shape),
                "note": "Conv3XC fused to Conv2d 3x3 C->C using interior-bias formula",
            }
    return manifest


def compare_single_conv3xc(model: TinySPAN, fused: TinySPAN, channels: int, device: torch.device) -> list[CompareStats]:
    torch.manual_seed(123)
    x = torch.rand(1, channels, 32, 32, device=device) * 2.0 - 1.0
    rows: list[CompareStats] = []
    with torch.no_grad():
        for block_idx, (orig_block, fused_block) in enumerate(zip(model.blocks, fused.blocks)):
            for attr in ("c1", "c2", "c3"):
                y0 = getattr(orig_block, attr)(x)
                y1 = getattr(fused_block, attr)(x)
                name = f"blocks.{block_idx}.{attr}"
                rows.append(stats(f"{name}.full", y0, y1))
                rows.append(stats(f"{name}.crop1", center_crop(y0, 1), center_crop(y1, 1)))
    return rows


def write_markdown(path: Path, summary: dict) -> None:
    rows = summary["conv3xc_checks"]
    model_stats = summary["model_check"]
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# TinySPAN Conv3XC Fusion Check",
        "",
        f"Checkpoint: `{summary['checkpoint']}`",
        f"Model: X{summary['scale']} C{summary['channels']} B{summary['num_blocks']}",
        f"Fused checkpoint: `{summary['fused_checkpoint']}`",
        f"Fused manifest: `{summary['fused_manifest']}`",
        "",
        "## Model Output Check",
        "",
        "| Region | Values | Max abs | MAE | MSE | PSNR |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for item in model_stats:
        lines.append(
            f"| `{item['name']}` | `{item['values']}` | `{item['max_abs']:.8f}` | "
            f"`{item['mae']:.8f}` | `{item['mse']:.8e}` | `{item['psnr_db']:.3f}` |"
        )
    lines += [
        "",
        "## Conv3XC Layer Checks",
        "",
        "| Layer | Values | Max abs | MAE | MSE | PSNR |",
        "| --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    for item in rows:
        lines.append(
            f"| `{item['name']}` | `{item['values']}` | `{item['max_abs']:.8f}` | "
            f"`{item['mae']:.8f}` | `{item['mse']:.8e}` | `{item['psnr_db']:.3f}` |"
        )
    lines += [
        "",
        "## Interpretation",
        "",
        "The fused 3x3 kernel is algebraically exact for the interior of a single Conv3XC block. Full-frame differences can appear at padded borders when intermediate Conv3XC biases are nonzero. Hardware use should therefore validate the fused checkpoint against the PyTorch training checkpoint before treating it as the software target.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fuse TinySPAN Conv3XC blocks and compare against the source checkpoint.")
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--scale", type=int, choices=(2, 4), default=4)
    parser.add_argument("--channels", type=int, default=24)
    parser.add_argument("--num-blocks", type=int, default=4)
    parser.add_argument("--width", type=int, default=32, help="LR test width for model comparison.")
    parser.add_argument("--height", type=int, default=32, help="LR test height for model comparison.")
    parser.add_argument("--device", choices=("auto", "cuda", "cpu"), default="auto")
    parser.add_argument("--out-dir", type=Path, default=Path("runs/tinyspan_fusion/latest"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    device = torch.device("cuda" if args.device in ("auto", "cuda") and torch.cuda.is_available() else "cpu")
    args.out_dir.mkdir(parents=True, exist_ok=True)

    ckpt = torch.load(args.checkpoint, map_location="cpu")
    state = ckpt["model"] if isinstance(ckpt, dict) and "model" in ckpt else ckpt

    model = build_model(scale=args.scale, channels=args.channels, num_blocks=args.num_blocks)
    model.load_state_dict(state, strict=True)
    model.eval().to(device)

    fused = build_model(scale=args.scale, channels=args.channels, num_blocks=args.num_blocks)
    fused.load_state_dict(state, strict=True)
    fused_manifest = replace_conv3xc(fused)
    fused.eval().to(device)

    torch.manual_seed(456)
    lr = torch.rand(1, 3, args.height, args.width, device=device)
    with torch.no_grad():
        y0 = model(lr)
        y1 = fused(lr)
    model_rows = [
        asdict(stats("full", y0, y1)),
        asdict(stats("crop4", center_crop(y0, args.scale), center_crop(y1, args.scale))),
        asdict(stats("crop16", center_crop(y0, args.scale * 4), center_crop(y1, args.scale * 4))),
    ]
    conv_rows = [asdict(item) for item in compare_single_conv3xc(model, fused, args.channels, device)]

    fused_state = fused.state_dict()
    fused_ckpt = {
        "model": {k: v.detach().cpu() for k, v in fused_state.items()},
        "source_checkpoint": str(args.checkpoint),
        "scale": args.scale,
        "channels": args.channels,
        "num_blocks": args.num_blocks,
        "fusion": "Conv3XC to Conv2d 3x3",
    }
    fused_checkpoint = args.out_dir / "student_fused_conv3xc.pt"
    torch.save(fused_ckpt, fused_checkpoint)
    manifest_path = args.out_dir / "tinyspan_fused_manifest.json"
    manifest = {
        "source_checkpoint": str(args.checkpoint),
        "fused_checkpoint": str(fused_checkpoint),
        "scale": args.scale,
        "channels": args.channels,
        "num_blocks": args.num_blocks,
        "fused_layers": fused_manifest,
        "model_check": model_rows,
        "conv3xc_checks": conv_rows,
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    md_path = args.out_dir / "fusion_check.md"
    write_markdown(
        md_path,
        {
            **manifest,
            "checkpoint": str(args.checkpoint),
            "fused_manifest": str(manifest_path),
            "fused_checkpoint": str(fused_checkpoint),
        },
    )
    print(json.dumps(manifest, indent=2))
    print(f"FUSED_CHECKPOINT={fused_checkpoint}")
    print(f"FUSED_MANIFEST={manifest_path}")
    print(f"FUSION_REPORT={md_path}")


if __name__ == "__main__":
    main()
