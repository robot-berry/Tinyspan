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

Main documents:

- [WORKFLOW.md](WORKFLOW.md): human-readable project workflow and acceptance
  gates.
- [workflows/tinyspan_720p30_acceptance.yaml](workflows/tinyspan_720p30_acceptance.yaml):
  machine-readable workflow checklist.
- [artifacts/README.md](artifacts/README.md): where future generated outputs
  should be placed before upload.
