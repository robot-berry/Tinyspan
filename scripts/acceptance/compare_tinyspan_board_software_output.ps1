param(
  [string]$InputPng = "external\SPAN\test_scripts\data\baboon.png",
  [string]$InputRaw = "",
  [int]$InputWidth = 32,
  [int]$InputHeight = 32,
  [string]$SoftwarePng,
  [string]$FixedPng,
  [string]$BoardRaw = "",
  [string]$BoardPng = "",
  [int]$OutputWidth = 128,
  [int]$OutputHeight = 128,
  [string]$OutDir = "board_runs\tinyspan_board_software_compare\latest",
  [int]$DiffGain = 8,
  [int]$MaxAllowedDiff = 0,
  [int]$MaxAllowedMismatchBytes = 0
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  if ([string]::IsNullOrWhiteSpace($SoftwarePng)) { throw "SoftwarePng is required" }
  if ([string]::IsNullOrWhiteSpace($FixedPng)) { throw "FixedPng is required" }
  if ([string]::IsNullOrWhiteSpace($BoardRaw) -and [string]::IsNullOrWhiteSpace($BoardPng)) { throw "BoardRaw or BoardPng is required" }

  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

  $inputRawPath = $InputRaw
  if ([string]::IsNullOrWhiteSpace($inputRawPath)) {
    $inputRawPath = Join-Path $OutDir "input.rgb"
    python tools\convert_rgb_raw.py to-raw $InputPng $inputRawPath --width $InputWidth --height $InputHeight
    if ($LASTEXITCODE -ne 0) { throw "input png to raw conversion failed" }
  }

  $boardPngPath = $BoardPng
  if ([string]::IsNullOrWhiteSpace($boardPngPath)) {
    $boardPngPath = Join-Path $OutDir "board_output.png"
    python tools\convert_rgb_raw.py from-raw $BoardRaw $boardPngPath --width $OutputWidth --height $OutputHeight
    if ($LASTEXITCODE -ne 0) { throw "board raw to png conversion failed" }
  }

  $preview = Join-Path $OutDir "tinyspan_board_software_preview.png"
  python tools\make_sr_software_board_preview.py `
    --input-raw $inputRawPath `
    --input-width $InputWidth `
    --input-height $InputHeight `
    --software $SoftwarePng `
    --fixed $FixedPng `
    --board $boardPngPath `
    --out $preview `
    --title "TinySPAN board-vs-fixed comparison" `
    --diff-gain $DiffGain
  if ($LASTEXITCODE -ne 0) { throw "preview generation failed" }

  $metricsJson = Join-Path $OutDir "tinyspan_board_software_summary.json"
  $metricsMd = Join-Path $OutDir "tinyspan_board_software_summary.md"
  $diffHeatmap = Join-Path $OutDir "diff_heatmap.png"
  python tools\compare_tinyspan_board_software.py `
    --software $SoftwarePng `
    --fixed $FixedPng `
    --board $boardPngPath `
    --preview $preview `
    --diff-heatmap $diffHeatmap `
    --diff-gain $DiffGain `
    --summary-json $metricsJson `
    --summary-md $metricsMd `
    --max-allowed-diff $MaxAllowedDiff `
    --max-allowed-mismatch-bytes $MaxAllowedMismatchBytes
  if ($LASTEXITCODE -ne 0) { throw "metric generation failed" }

  $summary = Get-Content -Raw -Path $metricsJson | ConvertFrom-Json
  if (-not $summary.pass) {
    throw "TinySPAN board-vs-fixed comparison failed: mismatch=$($summary.mismatch_bytes), max_diff=$($summary.max_channel_diff)"
  }

  Write-Host "PASS compare_tinyspan_board_software_output"
  Write-Host "SUMMARY=$metricsMd"
  Write-Host "PREVIEW=$preview"
  Write-Host "DIFF_HEATMAP=$diffHeatmap"
} finally {
  Pop-Location
}

