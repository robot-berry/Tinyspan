# Tinyspan

This repository is the handoff and evidence space for the TinySPAN realtime
super-resolution workflow.

Target:

- Run on the existing `xczu19eg-ffvc1760-2-i` board.
- Treat ZC706 / XC7Z045 as the resource limit gate.
- Produce full 720p30 output for X2 and X4 super-resolution.
- Read the downsampled full image or video frame from SD/DDR, split tiles in
  hardware, and write the final 720p frame back to DDR.
- Accept only when board output is byte-exact against the software fixed-point
  reference from the same frozen checkpoint and quantization plan.

Current hardware-safe baseline:

- `c32b4_30fps_frozen_20260613`
- Checkpoint SHA256:
  `6A3AA4FE17CDF1027483F95BE8A99A5805BCDD61CC821074603DE65BF333D938`
- This baseline can drive RTL/bitstream/board work, but final acceptance still
  requires a real TinySPAN-trained bitstream, real board output, byte-exact
  board-vs-software comparison, and measured 720p30 throughput.

Main documents:

- [WORKFLOW.md](WORKFLOW.md): human-readable project workflow and acceptance
  gates.
- [docs/model_design.md](docs/model_design.md): TinySPAN model structure and
  frozen baseline.
- [docs/training_artifacts.md](docs/training_artifacts.md): training source,
  frozen checkpoints, quantization plans, and model-to-hardware handoff index.
- [docs/training_quantization.md](docs/training_quantization.md): REDS
  training, freezing, W8A8 quantization, and fixed-point reference flow.
- [docs/hardware_design.md](docs/hardware_design.md): hardware accelerator
  dataflow, current 32x32 board evidence, and full-frame tiling modules.
- [docs/verification_plan.md](docs/verification_plan.md): gate-by-gate
  verification plan and remaining full-frame/X2 tests.
- [docs/ppa_analysis.md](docs/ppa_analysis.md): resource, timing, power, and
  throughput evidence.
- [docs/contest_delivery_index.md](docs/contest_delivery_index.md): current
  contest delivery evidence index with SHA256 hashes.
- [docs/contest_delivery_package_check.md](docs/contest_delivery_package_check.md):
  read-only final delivery check; it must pass without `--allow-incomplete`
  before claiming full contest completion.
- [workflows/tinyspan_720p30_acceptance.yaml](workflows/tinyspan_720p30_acceptance.yaml):
  machine-readable workflow checklist.
- [artifacts/README.md](artifacts/README.md): where future generated outputs
  should be placed before upload.

Useful full-frame reference entry:

- `scripts/acceptance/make_tinyspan_tiled_fixed_reference.ps1` generates the
  hardware-tiled fixed-point reference for final board comparison:
  `software_tiled_fixed_point_sr.png`, `tile_manifest.json`,
  `comparison_preview.png`, and `diff_heatmap.png`.
