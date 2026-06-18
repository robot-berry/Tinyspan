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
- resource/timing reports
- concise board logs
- throughput measurements

Avoid committing large temporary folders such as Vivado `.Xil`, run caches,
intermediate DCP forests, or oversized raw logs. Summarize them in
`run_summary.md` and keep only the acceptance evidence needed to reproduce the
result.
