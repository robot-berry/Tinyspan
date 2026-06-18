# Artifacts

Put future generated TinySPAN workflow outputs here before committing to
`robot-berry/Tinyspan`.

Recommended run directory:

```text
artifacts/YYYYMMDD_scale_model_tile_freq_shorttag/
```

Keep final evidence:

- manifests
- hashes
- fixed-point software references
- board output hashes
- training/float SR images
- board SR images
- side-by-side image previews
- difference heatmaps
- image validation summaries
- resource/timing reports
- concise board logs
- throughput measurements

For each TinySPAN board run, keep a directly viewable `comparison_preview.png`
that places the training/float SR output beside the board SR output, plus a
`diff_heatmap.png` and `image_validation.md` explaining the numeric metrics.

Avoid committing large temporary folders such as Vivado `.Xil`, run caches,
intermediate DCP forests, or oversized raw logs. Summarize them in
`run_summary.md` and keep only the acceptance evidence needed to reproduce the
result.
