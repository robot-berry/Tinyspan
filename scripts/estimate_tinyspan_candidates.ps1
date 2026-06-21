param(
  [int]$Scale = 4,
  [string]$Channels = "8,12,16,20,24,32",
  [string]$Blocks = "1,2,3,4,5,6",
  [int]$DspTotal = 1968,
  [double]$MacsPerDsp = 2.0,
  [string]$OutJson = "runs\tinyspan_candidates\tinyspan_realtime_candidates.json",
  [string]$OutMd = "docs\design\tinyspan_realtime_candidate_sizing_2026_06_13.md"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  python tools\estimate_tinyspan_candidates.py `
    --scale $Scale `
    --channels $Channels `
    --blocks $Blocks `
    --dsp-total $DspTotal `
    --macs-per-dsp $MacsPerDsp `
    --out-json $OutJson `
    --out-md $OutMd
  if ($LASTEXITCODE -ne 0) {
    throw "estimate_tinyspan_candidates.py failed with exit code $LASTEXITCODE"
  }
  Write-Host "TINYSPAN_CANDIDATES_JSON=$OutJson"
  Write-Host "TINYSPAN_CANDIDATES_MD=$OutMd"
  Write-Host "PASS estimate_tinyspan_candidates"
}
finally {
  Pop-Location
}
