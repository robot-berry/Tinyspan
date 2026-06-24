param(
  [string]$QuantPlan = "runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json",
  [string]$OutDir = "rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8",
  [int]$OutLanes = 8,
  [int]$TapLanes = 16
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $QuantPlan)) {
    throw "QuantPlan not found: $QuantPlan"
  }
  python tools\model_to_hardware\export_tinyspan_w8a8_to_rtl.py `
    --quant-plan $QuantPlan `
    --out-dir $OutDir `
    --out-lanes $OutLanes `
    --tap-lanes $TapLanes
  if ($LASTEXITCODE -ne 0) {
    throw "export_tinyspan_w8a8_to_rtl.py failed with exit code $LASTEXITCODE"
  }
  Write-Host "PASS export_tinyspan_c32b4_30fps_w8a8_to_rtl"
  Write-Host "OUT_DIR=$OutDir"
} finally {
  Pop-Location
}
