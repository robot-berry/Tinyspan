param(
  [string]$Checkpoint = "",
  [string]$QuantPlan = "",
  [string]$Bitstream = "",
  [string]$BoardRaw = "",
  [string]$BoardPng = "",
  [string]$BoardLog = "",
  [double]$MeasuredFps = -1.0,
  [ValidateSet(2, 4)]
  [int]$Scale = 4,
  [int]$InputWidth = 320,
  [int]$InputHeight = 180,
  [int]$OutputWidth = 1280,
  [int]$OutputHeight = 720,
  [int]$TileWidth = 32,
  [int]$TileHeight = 32,
  [string]$OutDir = "board_runs\tinyspan_720p30_board_acceptance\preflight_latest"
)

$ErrorActionPreference = "Stop"

function Add-Check {
  param(
    [System.Collections.Generic.List[object]]$Checks,
    [string]$Name,
    [bool]$Pass,
    [string]$Detail
  )
  $Checks.Add([ordered]@{ name = $Name; pass = $Pass; detail = $Detail }) | Out-Null
}

function Get-ExistingFullPath {
  param([string]$PathText)
  if ([string]::IsNullOrWhiteSpace($PathText) -or -not (Test-Path $PathText)) {
    return ""
  }
  return (Resolve-Path $PathText).Path
}

function Get-OptionalSha256 {
  param([string]$PathText)
  if ([string]::IsNullOrWhiteSpace($PathText) -or -not (Test-Path $PathText)) {
    return ""
  }
  return (Get-FileHash -Algorithm SHA256 -Path $PathText).Hash
}

function ConvertTo-NormalizedFullPath {
  param([string]$PathText)
  if ([string]::IsNullOrWhiteSpace($PathText)) {
    return ""
  }
  $expanded = [Environment]::ExpandEnvironmentVariables($PathText)
  if ([System.IO.Path]::IsPathRooted($expanded)) {
    return ([System.IO.Path]::GetFullPath($expanded) -replace "\\", "/").ToLowerInvariant()
  }
  return ((Resolve-Path $expanded -ErrorAction SilentlyContinue).Path -replace "\\", "/").ToLowerInvariant()
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $checks = New-Object System.Collections.Generic.List[object]

  $expectedInputWidth = [int]($OutputWidth / $Scale)
  $expectedInputHeight = [int]($OutputHeight / $Scale)
  $scaleDividesOutput = (($OutputWidth % $Scale) -eq 0) -and (($OutputHeight % $Scale) -eq 0)
  Add-Check $checks "scale_contract" $scaleDividesOutput "scale=X$Scale, output=${OutputWidth}x${OutputHeight}"
  Add-Check $checks "lr_input_contract" ($scaleDividesOutput -and $InputWidth -eq $expectedInputWidth -and $InputHeight -eq $expectedInputHeight) "${InputWidth}x${InputHeight}, expected ${expectedInputWidth}x${expectedInputHeight} for X${Scale}"
  Add-Check $checks "sr_output_contract" ($OutputWidth -eq 1280 -and $OutputHeight -eq 720) "${OutputWidth}x${OutputHeight}, expected 1280x720"
  Add-Check $checks "tile_contract" ($TileWidth -gt 0 -and $TileHeight -gt 0 -and $TileWidth -le $InputWidth -and $TileHeight -le $InputHeight) "${TileWidth}x${TileHeight}, expected positive tile within ${InputWidth}x${InputHeight}"
  Add-Check $checks "measured_fps_ge_30" ($MeasuredFps -ge 30.0) "measured_fps=$MeasuredFps"

  foreach ($item in @(
      @("checkpoint_exists", $Checkpoint),
      @("quant_plan_exists", $QuantPlan),
      @("bitstream_exists", $Bitstream),
      @("board_log_exists", $BoardLog)
    )) {
    $name = [string]$item[0]
    $path = [string]$item[1]
    Add-Check $checks $name ((-not [string]::IsNullOrWhiteSpace($path)) -and (Test-Path $path)) $path
  }
  $bitstreamExtensionOk = (-not [string]::IsNullOrWhiteSpace($Bitstream)) -and ([System.IO.Path]::GetExtension($Bitstream).ToLowerInvariant() -eq ".bit")
  Add-Check $checks "bitstream_extension_is_bit" $bitstreamExtensionOk $Bitstream

  $hasBoardRaw = (-not [string]::IsNullOrWhiteSpace($BoardRaw)) -and (Test-Path $BoardRaw)
  $hasBoardPng = (-not [string]::IsNullOrWhiteSpace($BoardPng)) -and (Test-Path $BoardPng)
  Add-Check $checks "real_board_output_exists" ($hasBoardRaw -or $hasBoardPng) "BoardRaw=$BoardRaw; BoardPng=$BoardPng"

  $quantPlanSourceCheckpoint = ""
  $quantPlanCheckpointMatches = $false
  if ((-not [string]::IsNullOrWhiteSpace($QuantPlan)) -and (Test-Path $QuantPlan)) {
    $quant = Get-Content -Raw -Path $QuantPlan | ConvertFrom-Json
    $quantPlanSourceCheckpoint = [string]$quant.source_checkpoint
    $checkpointNorm = ConvertTo-NormalizedFullPath $Checkpoint
    $quantCheckpointNorm = ConvertTo-NormalizedFullPath $quantPlanSourceCheckpoint
    $quantPlanCheckpointMatches = ($checkpointNorm -ne "" -and $checkpointNorm -eq $quantCheckpointNorm)
    Add-Check $checks "quant_plan_source_checkpoint_matches" $quantPlanCheckpointMatches "quant=$quantPlanSourceCheckpoint; checkpoint=$Checkpoint"
  } else {
    Add-Check $checks "quant_plan_source_checkpoint_matches" $false "QuantPlan missing"
  }

  $boardResources = $null
  $missingResourceFields = @()
  $boardLogBitstreamMatches = $false
  $boardLogFpsMatches = $false
  if ((-not [string]::IsNullOrWhiteSpace($BoardLog)) -and (Test-Path $BoardLog)) {
    $boardResources = Get-Content -Raw -Path $BoardLog | ConvertFrom-Json
    $requiredResourceFields = @(
      "utilization_report",
      "timing_report",
      "clb_luts",
      "clb_registers",
      "block_ram_tile",
      "dsps",
      "wns_ns",
      "whs_ns",
      "perf_frame_cycles",
      "perf_e2e_cycles",
      "measured_fps"
    )
    foreach ($field in $requiredResourceFields) {
      if (-not ($boardResources.PSObject.Properties.Name -contains $field) -or $null -eq $boardResources.$field -or $boardResources.$field -eq "") {
        $missingResourceFields += $field
      }
    }
    Add-Check $checks "board_resource_fields_complete" ($missingResourceFields.Count -eq 0) ("missing=" + ($missingResourceFields -join ","))
    $boardLogBitstream = [string]$boardResources.bitstream
    if (-not [string]::IsNullOrWhiteSpace($boardLogBitstream)) {
      $boardLogBitstreamMatches = (ConvertTo-NormalizedFullPath $boardLogBitstream) -eq (ConvertTo-NormalizedFullPath $Bitstream)
    }
    Add-Check $checks "board_log_bitstream_matches" $boardLogBitstreamMatches "board_log_bitstream=$boardLogBitstream; bitstream=$Bitstream"
    if ($boardResources.PSObject.Properties.Name -contains "measured_fps") {
      $boardLogFps = [double]$boardResources.measured_fps
      $boardLogFpsMatches = ([Math]::Abs($boardLogFps - $MeasuredFps) -lt 0.000001)
      Add-Check $checks "board_log_measured_fps_matches" $boardLogFpsMatches "board_log_fps=$boardLogFps; measured_fps=$MeasuredFps"
    } else {
      Add-Check $checks "board_log_measured_fps_matches" $false "measured_fps missing from BoardLog"
    }
  } else {
    Add-Check $checks "board_resource_fields_complete" $false "BoardLog missing"
    Add-Check $checks "board_log_bitstream_matches" $false "BoardLog missing"
    Add-Check $checks "board_log_measured_fps_matches" $false "BoardLog missing"
  }

  $passed = $true
  foreach ($check in $checks) {
    if (-not $check.pass) {
      $passed = $false
      break
    }
  }

  $summary = [ordered]@{
    ready = $passed
    checkpoint = $Checkpoint
    checkpoint_full_path = Get-ExistingFullPath $Checkpoint
    checkpoint_sha256 = Get-OptionalSha256 $Checkpoint
    quant_plan = $QuantPlan
    quant_plan_full_path = Get-ExistingFullPath $QuantPlan
    quant_plan_sha256 = Get-OptionalSha256 $QuantPlan
    quant_plan_source_checkpoint = $quantPlanSourceCheckpoint
    bitstream = $Bitstream
    bitstream_full_path = Get-ExistingFullPath $Bitstream
    bitstream_sha256 = Get-OptionalSha256 $Bitstream
    board_raw = $BoardRaw
    board_raw_full_path = Get-ExistingFullPath $BoardRaw
    board_raw_sha256 = Get-OptionalSha256 $BoardRaw
    board_png = $BoardPng
    board_png_full_path = Get-ExistingFullPath $BoardPng
    board_png_sha256 = Get-OptionalSha256 $BoardPng
    board_log = $BoardLog
    board_log_full_path = Get-ExistingFullPath $BoardLog
    board_log_sha256 = Get-OptionalSha256 $BoardLog
    measured_fps = $MeasuredFps
    scale = $Scale
    input_width = $InputWidth
    input_height = $InputHeight
    output_width = $OutputWidth
    output_height = $OutputHeight
    tile_width = $TileWidth
    tile_height = $TileHeight
    missing_resource_fields = $missingResourceFields
    checks = $checks
  }
  $summaryJson = Join-Path $OutDir "tinyspan_720p30_acceptance_input_preflight.json"
  $summaryMd = Join-Path $OutDir "tinyspan_720p30_acceptance_input_preflight.md"
  $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# TinySPAN 720p30 Acceptance Input Preflight",
    "",
    "Ready: ``$passed``",
    "",
    "This preflight does not start Vivado, JTAG, or board runs.",
    "",
    "## Evidence Fingerprints",
    "",
    "- checkpoint SHA256: ``$($summary.checkpoint_sha256)``",
    "- quant plan SHA256: ``$($summary.quant_plan_sha256)``",
    "- bitstream SHA256: ``$($summary.bitstream_sha256)``",
    "- board raw SHA256: ``$($summary.board_raw_sha256)``",
    "- board png SHA256: ``$($summary.board_png_sha256)``",
    "- board log SHA256: ``$($summary.board_log_sha256)``",
    "",
    "## Checks",
    ""
  )
  foreach ($check in $checks) {
    $status = if ($check.pass) { "PASS" } else { "FAIL" }
    $lines += "- ``$status`` $($check.name): ``$($check.detail)``"
  }
  $lines | Set-Content -Path $summaryMd -Encoding UTF8

  if ($passed) {
    Write-Host "PASS check_tinyspan_720p30_acceptance_inputs"
  } else {
    Write-Host "FAIL check_tinyspan_720p30_acceptance_inputs"
  }
  Write-Host "SUMMARY=$summaryMd"
  if (-not $passed) {
    exit 1
  }
} finally {
  Pop-Location
}
