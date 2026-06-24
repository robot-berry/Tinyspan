param(
  [string]$WorkspaceRoot = "",
  [int]$WaitSeconds = 43200,
  [int]$PollSeconds = 300,
  [int]$StableIdleSeconds = 30,
  [string]$RunDir = "board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref",
  [string]$WaitLogDir = "board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref_waitrun",
  [string]$InputPng = "external\SPAN\test_scripts\data\baboon.png",
  [string]$Checkpoint = "runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt",
  [string]$QuantPlan = "runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json",
  [string]$Bitstream = "vivado\bitstreams\jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit",
  [string]$SoftwarePng = "Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\pytorch_training_sr.png",
  [string]$FixedPng = "Tinyspan\artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\software_tiled_fixed_point_sr.png"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
} else {
  $WorkspaceRoot = Resolve-Path $WorkspaceRoot
}

function Resolve-WorkspacePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $script:WorkspaceRootAbs $Path
}

$script:WorkspaceRootAbs = $WorkspaceRoot
Push-Location $script:WorkspaceRootAbs
try {
  $runDirAbs = Resolve-WorkspacePath $RunDir
  $waitLogDirAbs = Resolve-WorkspacePath $WaitLogDir
  New-Item -ItemType Directory -Force -Path $runDirAbs | Out-Null
  New-Item -ItemType Directory -Force -Path $waitLogDirAbs | Out-Null

  $vivadoWaitLog = Join-Path $waitLogDirAbs "vivado_idle_wait.log"
  $jtagWrapperLog = Join-Path $waitLogDirAbs "jtag_smoke_wrapper.log"
  $acceptanceWrapperLog = Join-Path $waitLogDirAbs "acceptance_tiled_fixed_wrapper.log"

  Write-Host "TINYSPAN_GATE_H_TILEDREF_WAITRUN_START=$((Get-Date).ToString('o'))"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_WORKSPACE_ROOT=$script:WorkspaceRootAbs"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_RUN_DIR=$runDirAbs"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_WAIT_LOG_DIR=$waitLogDirAbs"

  foreach ($required in @(
      @("InputPng", $InputPng),
      @("Checkpoint", $Checkpoint),
      @("QuantPlan", $QuantPlan),
      @("Bitstream", $Bitstream),
      @("SoftwarePng", $SoftwarePng),
      @("FixedPng", $FixedPng),
      @("JtagScript", "scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1"),
      @("AcceptanceScript", "scripts\run_tinyspan_720p30_board_acceptance.ps1"),
      @("VivadoIdleScript", "scripts\check_vivado_idle.ps1")
    )) {
    $name = $required[0]
    $path = $required[1]
    if (-not (Test-Path $path)) {
      throw "$name not found: $path"
    }
  }

  Write-Host "TINYSPAN_GATE_H_WAITING_FOR_VIVADO_IDLE=1"
  $idleArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\check_vivado_idle.ps1",
    "-WaitSeconds", $WaitSeconds,
    "-PollSeconds", $PollSeconds,
    "-StableIdleSeconds", $StableIdleSeconds
  )
  & powershell @idleArgs 2>&1 | Tee-Object -FilePath $vivadoWaitLog
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado idle wait failed with exit code $LASTEXITCODE. See $vivadoWaitLog"
  }
  Write-Host "TINYSPAN_GATE_H_VIVADO_IDLE_CONFIRMED=1"

  $jtagArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1",
    "-ImgW", "320",
    "-ImgH", "180",
    "-PlFreqMhz", "150",
    "-Fast",
    "-InputPng", $InputPng,
    "-Checkpoint", $Checkpoint,
    "-QuantPlan", $QuantPlan,
    "-Bitstream", $Bitstream,
    "-OutDir", $RunDir,
    "-SkipAcceptance"
  )
  Write-Host "TINYSPAN_GATE_H_JTAG_START=$((Get-Date).ToString('o'))"
  & powershell @jtagArgs 2>&1 | Tee-Object -FilePath $jtagWrapperLog
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN Gate H JTAG smoke failed with exit code $LASTEXITCODE. See $jtagWrapperLog"
  }
  Write-Host "TINYSPAN_GATE_H_JTAG_DONE=$((Get-Date).ToString('o'))"

  $resourceJson = Join-Path $runDirAbs "implementation_resources.json"
  if (-not (Test-Path $resourceJson)) {
    throw "JTAG run did not produce implementation_resources.json: $resourceJson"
  }
  $resources = Get-Content -Raw -Path $resourceJson | ConvertFrom-Json
  $measuredFps = [double]$resources.measured_fps
  if ($measuredFps -lt 0) {
    throw "JTAG run did not produce a valid measured_fps in $resourceJson"
  }

  $inputRaw = Join-Path $runDirAbs "input_x4_320x180_tinyspan_w8a8_base_equiv.rgb"
  $boardRaw = Join-Path $runDirAbs "board_output_x4_320x180_tinyspan_w8a8_base_equiv.rgb"
  $boardPng = Join-Path $runDirAbs "board_output_x4_320x180_tinyspan_w8a8_base_equiv.png"
  foreach ($requiredOutput in @($inputRaw, $boardRaw, $boardPng)) {
    if (-not (Test-Path $requiredOutput)) {
      throw "JTAG run did not produce required output: $requiredOutput"
    }
  }

  $acceptanceDir = Join-Path $runDirAbs "acceptance_tiled_fixed"
  $acceptanceArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_tinyspan_720p30_board_acceptance.ps1",
    "-InputPng", $InputPng,
    "-InputRaw", $inputRaw,
    "-InputWidth", "320",
    "-InputHeight", "180",
    "-TileWidth", "32",
    "-TileHeight", "32",
    "-SoftwarePng", $SoftwarePng,
    "-FixedPng", $FixedPng,
    "-BoardRaw", $boardRaw,
    "-BoardPng", $boardPng,
    "-OutputWidth", "1280",
    "-OutputHeight", "720",
    "-OutDir", $acceptanceDir,
    "-MeasuredFps", ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:R}", $measuredFps)),
    "-Checkpoint", $Checkpoint,
    "-QuantPlan", $QuantPlan,
    "-Bitstream", $Bitstream,
    "-BoardLog", $resourceJson,
    "-TargetName", "TinySPAN X4 720p tiled fixed Gate H"
  )
  Write-Host "TINYSPAN_GATE_H_TILEDREF_ACCEPTANCE_START=$((Get-Date).ToString('o'))"
  & powershell @acceptanceArgs 2>&1 | Tee-Object -FilePath $acceptanceWrapperLog
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN tiled fixed acceptance failed with exit code $LASTEXITCODE. See $acceptanceWrapperLog"
  }

  $summaryJson = Join-Path $acceptanceDir "tinyspan_720p30_board_acceptance_summary.json"
  $summaryMd = Join-Path $acceptanceDir "tinyspan_720p30_board_acceptance_summary.md"
  if (-not (Test-Path $summaryJson)) {
    throw "Acceptance summary missing: $summaryJson"
  }
  $summary = Get-Content -Raw -Path $summaryJson | ConvertFrom-Json
  Write-Host "TINYSPAN_GATE_H_TILEDREF_ACCEPTANCE_JSON=$summaryJson"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_ACCEPTANCE_MD=$summaryMd"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_PASS=$($summary.pass)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_COMPARE_PASS=$($summary.compare_pass)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_FPS_PASS=$($summary.fps_pass)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_MEASURED_FPS=$($summary.measured_fps)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_MISMATCH_BYTES=$($summary.mismatch_bytes)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_MAX_DIFF=$($summary.max_channel_diff)"
  Write-Host "TINYSPAN_GATE_H_TILEDREF_DONE=$((Get-Date).ToString('o'))"
} finally {
  Pop-Location
}
