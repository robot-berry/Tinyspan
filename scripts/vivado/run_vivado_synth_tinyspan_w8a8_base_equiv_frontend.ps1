param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [int]$ImgW = 4,
  [int]$ImgH = 4,
  [double]$ClockMhz = 100.0,
  [switch]$Fast
)

$ErrorActionPreference = "Stop"
$modeTag = if ($Fast) { "fast" } else { "serial" }
$tag = "tinyspan_base_equiv_rgb888_${modeTag}_${ImgW}x${ImgH}_${ClockMhz}mhz".Replace(".", "p")
& (Join-Path $PSScriptRoot "run_vivado_synth_tinyspan_w8a8_block0_partition.ps1") `
  -Top span_tinyspan_w8a8_full_streamed_rgb888_base_equiv `
  -Tag $tag `
  -ClockMhz $ClockMhz `
  -ImgW $ImgW `
  -ImgH $ImgH `
  -OutLanes 1 `
  -TapLanes 1 `
  -UseSerialBase $(if ($Fast) { 0 } else { 1 }) `
  -VivadoBat $VivadoBat
