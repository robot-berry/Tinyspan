param(
  [string]$InputPng = "external\SPAN\test_scripts\data\baboon.png",
  [string]$InputRaw = "",
  [int]$InputWidth = 32,
  [int]$InputHeight = 32,
  [Parameter(Mandatory = $true)]
  [string]$SoftwarePng,
  [Parameter(Mandatory = $true)]
  [string]$FixedPng,
  [string]$BoardRaw = "",
  [string]$BoardPng = "",
  [int]$OutputWidth = 128,
  [int]$OutputHeight = 128,
  [string]$OutDir = "board_runs\tinyspan_board_acceptance\latest",
  [ValidateSet(30, 60)]
  [int]$TargetFps = 30,
  [double]$MeasuredFps = -1.0,
  [string]$Checkpoint = "",
  [string]$QuantPlan = "",
  [string]$Bitstream = "",
  [string]$BoardLog = "",
  [string]$TargetName = "TinySPAN",
  [int]$DiffGain = 8,
  [int]$MaxAllowedDiff = 0,
  [int]$MaxAllowedMismatchBytes = 0
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  if ($MeasuredFps -lt 0) {
    throw "MeasuredFps is required for board acceptance. Pass the effective board throughput in fps."
  }
  if ($InputWidth -ne 32 -or $InputHeight -ne 32) {
    throw "This TinySPAN board acceptance gate is locked to 32x32 input. Got ${InputWidth}x${InputHeight}."
  }
  if ($OutputWidth -ne 128 -or $OutputHeight -ne 128) {
    throw "This TinySPAN board acceptance gate expects x4 output shape 128x128. Got ${OutputWidth}x${OutputHeight}."
  }
  foreach ($required in @(
      @("SoftwarePng", $SoftwarePng),
      @("FixedPng", $FixedPng),
      @("Checkpoint", $Checkpoint),
      @("QuantPlan", $QuantPlan),
      @("Bitstream", $Bitstream),
      @("BoardLog", $BoardLog)
    )) {
    $name = $required[0]
    $value = $required[1]
    if ([string]::IsNullOrWhiteSpace($value)) {
      throw "$name is required for TinySPAN 32x32 board acceptance."
    }
    if (-not (Test-Path $value)) {
      throw "$name not found: $value"
    }
  }

  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

  $compareArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\compare_tinyspan_board_software_output.ps1",
    "-InputPng", $InputPng,
    "-InputWidth", $InputWidth,
    "-InputHeight", $InputHeight,
    "-SoftwarePng", $SoftwarePng,
    "-FixedPng", $FixedPng,
    "-OutputWidth", $OutputWidth,
    "-OutputHeight", $OutputHeight,
    "-OutDir", $OutDir,
    "-DiffGain", $DiffGain,
    "-MaxAllowedDiff", $MaxAllowedDiff,
    "-MaxAllowedMismatchBytes", $MaxAllowedMismatchBytes
  )
  if (-not [string]::IsNullOrWhiteSpace($InputRaw)) {
    $compareArgs += @("-InputRaw", $InputRaw)
  }
  if (-not [string]::IsNullOrWhiteSpace($BoardRaw)) {
    $compareArgs += @("-BoardRaw", $BoardRaw)
  }
  if (-not [string]::IsNullOrWhiteSpace($BoardPng)) {
    $compareArgs += @("-BoardPng", $BoardPng)
  }

  powershell @compareArgs
  if ($LASTEXITCODE -ne 0) {
    throw "compare_tinyspan_board_software_output.ps1 failed with exit code $LASTEXITCODE"
  }

  $compareJson = Join-Path $OutDir "tinyspan_board_software_summary.json"
  $summaryJson = Join-Path $OutDir "tinyspan_board_acceptance_summary.json"
  $summaryMd = Join-Path $OutDir "tinyspan_board_acceptance_summary.md"

  $summaryArgs = @(
    "tools\write_tinyspan_board_acceptance_summary.py",
    "--compare-summary", $compareJson,
    "--summary-json", $summaryJson,
    "--summary-md", $summaryMd,
    "--target-fps", $TargetFps,
    "--measured-fps", $MeasuredFps,
    "--target-name", $TargetName
  )
  if (-not [string]::IsNullOrWhiteSpace($Checkpoint)) {
    $summaryArgs += @("--checkpoint", $Checkpoint)
  }
  if (-not [string]::IsNullOrWhiteSpace($QuantPlan)) {
    $summaryArgs += @("--quant-plan", $QuantPlan)
  }
  if (-not [string]::IsNullOrWhiteSpace($Bitstream)) {
    $summaryArgs += @("--bitstream", $Bitstream)
  }
  if (-not [string]::IsNullOrWhiteSpace($BoardLog)) {
    $summaryArgs += @("--board-log", $BoardLog)
  }

  python @summaryArgs
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN board acceptance failed. See $summaryMd"
  }

  Write-Host "PASS run_tinyspan_board_acceptance"
  Write-Host "SUMMARY=$summaryMd"
  Write-Host "PREVIEW=$(Join-Path $OutDir 'tinyspan_board_software_preview.png')"
} finally {
  Pop-Location
}
