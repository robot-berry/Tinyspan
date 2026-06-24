param(
  [string]$InputPng = "G:\UESTC\feitengspan1\external\SPAN\test_scripts\data\baboon.png",
  [int]$InputWidth = 320,
  [int]$InputHeight = 180,
  [int]$TileWidth = 32,
  [int]$TileHeight = 32,
  [string]$QuantPlan = "quant\quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json",
  [string]$Checkpoint = "model\checkpoints\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt",
  [string]$OutDir = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_latest",
  [ValidateSet("auto", "cuda", "cpu")]
  [string]$Device = "auto",
  [int]$PreviewTile = 180,
  [int]$DiffGain = 8,
  [switch]$SkipPytorch,
  [switch]$SkipFullInteger
)

$ErrorActionPreference = "Stop"
$launchRoot = (Get-Location).Path
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Resolve-WorkflowPath {
  param(
    [string]$PathText,
    [switch]$AllowMissing
  )
  if ([string]::IsNullOrWhiteSpace($PathText)) {
    return ""
  }
  if ([System.IO.Path]::IsPathRooted($PathText)) {
    return [System.IO.Path]::GetFullPath($PathText)
  }
  $fromLaunch = Join-Path $launchRoot $PathText
  if (Test-Path $fromLaunch) {
    return (Resolve-Path $fromLaunch).Path
  }
  $fromWorkflow = Join-Path $root $PathText
  if ((Test-Path $fromWorkflow) -or $AllowMissing) {
    return [System.IO.Path]::GetFullPath($fromWorkflow)
  }
  return [System.IO.Path]::GetFullPath($fromLaunch)
}

$InputPng = Resolve-WorkflowPath $InputPng
$QuantPlan = Resolve-WorkflowPath $QuantPlan
if (-not [string]::IsNullOrWhiteSpace($Checkpoint)) {
  $Checkpoint = Resolve-WorkflowPath $Checkpoint
}
$OutDir = Resolve-WorkflowPath $OutDir -AllowMissing

Push-Location $root
try {
  if (-not (Test-Path $InputPng)) {
    throw "InputPng not found: $InputPng"
  }
  if (-not (Test-Path $QuantPlan)) {
    throw "QuantPlan not found: $QuantPlan"
  }

  $argsList = @(
    "tools\image_validation\make_tinyspan_tiled_fixed_reference.py",
    "--quant-plan", $QuantPlan,
    "--input", $InputPng,
    "--width", $InputWidth,
    "--height", $InputHeight,
    "--tile-width", $TileWidth,
    "--tile-height", $TileHeight,
    "--out-dir", $OutDir,
    "--device", $Device,
    "--preview-tile", $PreviewTile,
    "--diff-gain", $DiffGain
  )

  if (-not [string]::IsNullOrWhiteSpace($Checkpoint)) {
    if (-not (Test-Path $Checkpoint)) {
      throw "Checkpoint not found: $Checkpoint"
    }
    $argsList += @("--checkpoint", $Checkpoint)
  }
  if ($SkipPytorch) {
    $argsList += "--skip-pytorch"
  }
  if ($SkipFullInteger) {
    $argsList += "--skip-full-integer"
  }

  python @argsList
  if ($LASTEXITCODE -ne 0) {
    throw "make_tinyspan_tiled_fixed_reference.py failed with exit code $LASTEXITCODE"
  }

  Write-Host "PASS make_tinyspan_tiled_fixed_reference"
  Write-Host "SUMMARY=$(Join-Path $OutDir 'tinyspan_tiled_fixed_reference_summary.md')"
  Write-Host "FIXED_PNG=$(Join-Path $OutDir 'software_tiled_fixed_point_sr.png')"
  Write-Host "PREVIEW=$(Join-Path $OutDir 'comparison_preview.png')"
  Write-Host "DIFF_HEATMAP=$(Join-Path $OutDir 'diff_heatmap.png')"
} finally {
  Pop-Location
}
