param(
  [string]$InputPng = "external\SPAN\test_scripts\data\baboon.png",
  [string]$InputRaw = "",
  [int]$InputWidth = 320,
  [int]$InputHeight = 180,
  [int]$TileWidth = 32,
  [int]$TileHeight = 32,
  [Parameter(Mandatory = $true)]
  [string]$SoftwarePng,
  [Parameter(Mandatory = $true)]
  [string]$FixedPng,
  [string]$BoardRaw = "",
  [string]$BoardPng = "",
  [int]$OutputWidth = 1280,
  [int]$OutputHeight = 720,
  [string]$OutDir = "board_runs\tinyspan_720p30_board_acceptance\latest",
  [double]$MeasuredFps = -1.0,
  [string]$Checkpoint = "",
  [string]$QuantPlan = "",
  [string]$Bitstream = "",
  [string]$BoardLog = "",
  [string]$PreflightScript = "scripts\check_tinyspan_720p30_acceptance_inputs.ps1",
  [string]$TargetName = "TinySPAN 720p30 tile32",
  [int]$DiffGain = 8,
  [int]$MaxAllowedDiff = 0,
  [int]$MaxAllowedMismatchBytes = 0
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if ($InputWidth -ne 320 -or $InputHeight -ne 180) {
    throw "TinySPAN 720p30 acceptance expects LR input 320x180. Got ${InputWidth}x${InputHeight}."
  }
  if ($OutputWidth -ne 1280 -or $OutputHeight -ne 720) {
    throw "TinySPAN 720p30 acceptance expects SR output 1280x720. Got ${OutputWidth}x${OutputHeight}."
  }
  if ($TileWidth -ne 32 -or $TileHeight -ne 32) {
    throw "TinySPAN 720p30 acceptance is locked to 32x32 board tiles. Got ${TileWidth}x${TileHeight}."
  }
  if ($MeasuredFps -lt 30.0) {
    throw "MeasuredFps must be >= 30.0 for TinySPAN 720p30 board acceptance. Got $MeasuredFps."
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
      throw "$name is required for TinySPAN 720p30 board acceptance."
    }
    if (-not (Test-Path $value)) {
      throw "$name not found: $value"
    }
  }
  if ([string]::IsNullOrWhiteSpace($BoardRaw) -and [string]::IsNullOrWhiteSpace($BoardPng)) {
    throw "BoardRaw or BoardPng is required for TinySPAN 720p30 board acceptance."
  }
  if (-not (Test-Path $PreflightScript)) {
    throw "PreflightScript not found: $PreflightScript"
  }

  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $preflightDir = Join-Path $OutDir "preflight"
  $preflightArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $PreflightScript,
    "-Checkpoint", $Checkpoint,
    "-QuantPlan", $QuantPlan,
    "-Bitstream", $Bitstream,
    "-BoardLog", $BoardLog,
    "-MeasuredFps", $MeasuredFps,
    "-InputWidth", $InputWidth,
    "-InputHeight", $InputHeight,
    "-OutputWidth", $OutputWidth,
    "-OutputHeight", $OutputHeight,
    "-TileWidth", $TileWidth,
    "-TileHeight", $TileHeight,
    "-OutDir", $preflightDir
  )
  if (-not [string]::IsNullOrWhiteSpace($BoardRaw)) {
    $preflightArgs += @("-BoardRaw", $BoardRaw)
  }
  if (-not [string]::IsNullOrWhiteSpace($BoardPng)) {
    $preflightArgs += @("-BoardPng", $BoardPng)
  }
  powershell @preflightArgs
  if ($LASTEXITCODE -ne 0) {
    throw "check_tinyspan_720p30_acceptance_inputs.ps1 failed with exit code $LASTEXITCODE"
  }
  $preflightJson = Join-Path $preflightDir "tinyspan_720p30_acceptance_input_preflight.json"
  $preflightMd = Join-Path $preflightDir "tinyspan_720p30_acceptance_input_preflight.md"

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
  $summaryJson = Join-Path $OutDir "tinyspan_720p30_board_acceptance_summary.json"
  $summaryMd = Join-Path $OutDir "tinyspan_720p30_board_acceptance_summary.md"

  python tools\write_tinyspan_board_acceptance_summary.py `
    --compare-summary $compareJson `
    --summary-json $summaryJson `
    --summary-md $summaryMd `
    --target-fps 30 `
    --measured-fps $MeasuredFps `
    --target-name $TargetName `
    --checkpoint $Checkpoint `
    --quant-plan $QuantPlan `
    --bitstream $Bitstream `
    --board-log $BoardLog `
    --require-board-resources
  $summaryWriterExitCode = $LASTEXITCODE

  $summary = Get-Content -Raw -Path $summaryJson | ConvertFrom-Json
  $summary | Add-Member -NotePropertyName input_width -NotePropertyValue $InputWidth -Force
  $summary | Add-Member -NotePropertyName input_height -NotePropertyValue $InputHeight -Force
  $summary | Add-Member -NotePropertyName output_width -NotePropertyValue $OutputWidth -Force
  $summary | Add-Member -NotePropertyName output_height -NotePropertyValue $OutputHeight -Force
  $summary | Add-Member -NotePropertyName tile_width -NotePropertyValue $TileWidth -Force
  $summary | Add-Member -NotePropertyName tile_height -NotePropertyValue $TileHeight -Force
  $summary | Add-Member -NotePropertyName preflight_summary_json -NotePropertyValue $preflightJson -Force
  $summary | Add-Member -NotePropertyName preflight_summary_md -NotePropertyValue $preflightMd -Force
  $preflightSummary = Get-Content -Raw -Path $preflightJson | ConvertFrom-Json
  $summary | Add-Member -NotePropertyName evidence_fingerprints -NotePropertyValue ([ordered]@{
      checkpoint_sha256 = $preflightSummary.checkpoint_sha256
      quant_plan_sha256 = $preflightSummary.quant_plan_sha256
      bitstream_sha256 = $preflightSummary.bitstream_sha256
      board_raw_sha256 = $preflightSummary.board_raw_sha256
      board_png_sha256 = $preflightSummary.board_png_sha256
      board_log_sha256 = $preflightSummary.board_log_sha256
    }) -Force
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8

  $extra = @(
    "",
    "## 720p30 Tile Contract",
    "",
    ("- LR input frame: ``{0}x{1}``" -f $InputWidth, $InputHeight),
    ("- SR output frame: ``{0}x{1}``" -f $OutputWidth, $OutputHeight),
    ("- board tile: ``{0}x{1}``" -f $TileWidth, $TileHeight),
    ("- effective throughput: ``{0}`` fps" -f $MeasuredFps),
    "",
    "## Evidence Preflight",
    "",
    "- preflight JSON: ``$preflightJson``",
    "- preflight Markdown: ``$preflightMd``",
    "- checkpoint SHA256: ``$($preflightSummary.checkpoint_sha256)``",
    "- quant plan SHA256: ``$($preflightSummary.quant_plan_sha256)``",
    "- bitstream SHA256: ``$($preflightSummary.bitstream_sha256)``",
    "- board raw SHA256: ``$($preflightSummary.board_raw_sha256)``",
    "- board png SHA256: ``$($preflightSummary.board_png_sha256)``",
    "- board log SHA256: ``$($preflightSummary.board_log_sha256)``"
  )
  Add-Content -Path $summaryMd -Value $extra -Encoding UTF8

  if ($summary.board_resources) {
    Write-Host "BOARD_RESOURCE_CLB_LUTS=$($summary.board_resources.clb_luts)"
    Write-Host "BOARD_RESOURCE_CLB_REGISTERS=$($summary.board_resources.clb_registers)"
    Write-Host "BOARD_RESOURCE_BLOCK_RAM_TILE=$($summary.board_resources.block_ram_tile)"
    Write-Host "BOARD_RESOURCE_DSPS=$($summary.board_resources.dsps)"
    Write-Host "BOARD_TIMING_WNS_NS=$($summary.board_resources.wns_ns)"
    Write-Host "BOARD_TIMING_WHS_NS=$($summary.board_resources.whs_ns)"
    Write-Host "BOARD_PERF_FRAME_CYCLES=$($summary.board_resources.perf_frame_cycles)"
    Write-Host "BOARD_PERF_E2E_CYCLES=$($summary.board_resources.perf_e2e_cycles)"
    Write-Host "BOARD_MEASURED_FPS=$($summary.board_resources.measured_fps)"
  }

  if ($summaryWriterExitCode -ne 0) {
    throw "TinySPAN 720p30 board acceptance failed. See $summaryMd"
  }

  Write-Host "PASS run_tinyspan_720p30_board_acceptance"
  Write-Host "SUMMARY=$summaryMd"
  Write-Host "PREVIEW=$(Join-Path $OutDir 'tinyspan_board_software_preview.png')"
  Write-Host "DIFF_HEATMAP=$(Join-Path $OutDir 'diff_heatmap.png')"
} finally {
  Pop-Location
}
