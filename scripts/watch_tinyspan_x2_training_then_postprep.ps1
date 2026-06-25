param(
  [string]$TinyspanRoot = "",
  [string]$WorkspaceRoot = "",
  [string]$RunDir = "..\runs\tinyspan_distill\video_x2_c32_b4_reds_temporal",
  [string]$Tag = "",
  [int]$TotalSteps = 198000,
  [int]$WaitSeconds = 86400,
  [int]$PollSeconds = 300,
  [int]$StableStoppedPolls = 2,
  [switch]$SkipRtlExport,
  [switch]$SkipTiledReference,
  [switch]$SkipReadiness,
  [switch]$RequireReadinessPass,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function ConvertTo-NormalizedPathText {
  param([string]$PathText)
  return ($PathText -replace "\\", "/")
}

function Resolve-Under {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $Root $Path
}

function Get-LatestMetric {
  param([string]$MetricsPath)
  if (-not (Test-Path $MetricsPath)) {
    return $null
  }
  $last = Get-Content -Path $MetricsPath -Tail 200 |
    Where-Object { $_ -match "^\d+," } |
    Select-Object -Last 1
  if (-not $last) {
    return $null
  }
  $cols = $last -split ","
  if ($cols.Count -lt 11) {
    return [ordered]@{ raw = $last; step = 0; epoch = 0 }
  }
  return [ordered]@{
    raw = $last
    epoch = [int]$cols[0]
    step = [int]$cols[1]
    student_psnr = [double]::Parse($cols[7], [System.Globalization.CultureInfo]::InvariantCulture)
    seconds = [double]::Parse($cols[9], [System.Globalization.CultureInfo]::InvariantCulture)
    steps_per_second = [double]::Parse($cols[10], [System.Globalization.CultureInfo]::InvariantCulture)
  }
}

function Get-TrainingProcesses {
  param([string]$RunDirAbs)
  $normalizedRunDir = ConvertTo-NormalizedPathText $RunDirAbs
  $normalizedRunDirLeaf = [System.IO.Path]::GetFileName($normalizedRunDir.TrimEnd("/"))
  return @(Get-CimInstance Win32_Process |
    Where-Object {
      $cmd = ConvertTo-NormalizedPathText ([string]$_.CommandLine)
      $isTrainProcess = (
        ($_.Name -eq "python.exe" -and $cmd -match "distill_tinyspan_video\.py") -or
        ($_.Name -eq "powershell.exe" -and $cmd -match "train_tinyspan_video_x[24]_c32_b4\.ps1")
      )
      $matchesRunDir = ($cmd -match [regex]::Escape($normalizedRunDir)) -or
        ($normalizedRunDirLeaf -ne "" -and $cmd -match [regex]::Escape($normalizedRunDirLeaf))
      ($_.ProcessId -ne $PID) -and $isTrainProcess -and $matchesRunDir
    } |
    Select-Object ProcessId, Name, CommandLine)
}

if ([string]::IsNullOrWhiteSpace($TinyspanRoot)) {
  $TinyspanRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
  $TinyspanRoot = Resolve-Path $TinyspanRoot
}
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = Resolve-Path (Join-Path $TinyspanRoot "..")
} else {
  $WorkspaceRoot = Resolve-Path $WorkspaceRoot
}

$runDirAbs = Resolve-Under -Root $TinyspanRoot -Path $RunDir
$metricsPath = Join-Path $runDirAbs "metrics.csv"
$latestCheckpointPath = Join-Path $runDirAbs "student_latest.pt"
$finalCheckpointPath = Join-Path $runDirAbs "student_last.pt"
if ([string]::IsNullOrWhiteSpace($Tag)) {
  $Tag = "x2_frozen_" + (Get-Date -Format "yyyyMMdd_HHmmss")
}
$safeTag = $Tag -replace "[^A-Za-z0-9_.-]", "_"

Write-Host "TINYSPAN_X2_POSTPREP_WATCH_START=$((Get-Date).ToString('o'))"
Write-Host "TINYSPAN_ROOT=$TinyspanRoot"
Write-Host "WORKSPACE_ROOT=$WorkspaceRoot"
Write-Host "RUN_DIR=$RunDir"
Write-Host "RUN_DIR_ABS=$runDirAbs"
Write-Host "TAG=$safeTag"
Write-Host "TOTAL_STEPS=$TotalSteps"

if ($DryRun) {
  $metric = Get-LatestMetric -MetricsPath $metricsPath
  $running = Get-TrainingProcesses -RunDirAbs $runDirAbs
  Write-Host "DRY_RUN=True"
  Write-Host "LATEST_STEP=$($metric.step)"
  Write-Host "TRAINING_PROCESS_COUNT=$($running.Count)"
  Write-Host "WOULD_WAIT_UNTIL: step >= $TotalSteps and training process count is 0"
  $postArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", ".\scripts\run_tinyspan_c32b4_post_training_prep.ps1",
    "-RunDir", $RunDir,
    "-Scale", "2",
    "-Tag", $safeTag
  )
  if ($SkipRtlExport) { $postArgs += "-SkipRtlExport" }
  if ($SkipTiledReference) { $postArgs += "-SkipTiledReference" }
  if ($SkipReadiness) { $postArgs += "-SkipReadiness" }
  if ($RequireReadinessPass) { $postArgs += "-RequireReadinessPass" }
  Write-Host "WOULD_RUN: powershell $($postArgs -join ' ')"
  Write-Host "PASS watch_tinyspan_x2_training_then_postprep_dry_run"
  return
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
$stoppedPolls = 0
while ($true) {
  $metric = Get-LatestMetric -MetricsPath $metricsPath
  if ($null -eq $metric) {
    throw "No metrics available yet: $metricsPath"
  }
  $running = Get-TrainingProcesses -RunDirAbs $runDirAbs
  if ($running.Count -eq 0) {
    $stoppedPolls += 1
  } else {
    $stoppedPolls = 0
  }

  Write-Host ("TINYSPAN_X2_WATCH epoch={0} step={1}/{2} running={3} stopped_polls={4}" -f `
    $metric.epoch, $metric.step, $TotalSteps, $running.Count, $stoppedPolls)

  if ($metric.step -ge $TotalSteps -and $stoppedPolls -ge $StableStoppedPolls) {
    break
  }
  if ($running.Count -eq 0 -and $metric.step -lt $TotalSteps) {
    throw "Training stopped before target steps: step $($metric.step) / $TotalSteps"
  }
  if ((Get-Date) -ge $deadline) {
    throw "Timed out waiting for X2 training completion"
  }
  Start-Sleep -Seconds $PollSeconds
}

if ((-not (Test-Path $finalCheckpointPath)) -and (-not (Test-Path $latestCheckpointPath))) {
  throw "Checkpoint not found after training completion: $finalCheckpointPath or $latestCheckpointPath"
}

Push-Location $TinyspanRoot
try {
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\acceptance\refresh_tinyspan_delivery_status.ps1 `
    -TinyspanRoot $TinyspanRoot `
    -WorkspaceRoot $WorkspaceRoot
  if ($LASTEXITCODE -ne 0) {
    throw "refresh_tinyspan_delivery_status.ps1 failed with exit code $LASTEXITCODE"
  }

  $postArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", ".\scripts\run_tinyspan_c32b4_post_training_prep.ps1",
    "-RunDir", $RunDir,
    "-Scale", "2",
    "-Tag", $safeTag
  )
  if ($SkipRtlExport) { $postArgs += "-SkipRtlExport" }
  if ($SkipTiledReference) { $postArgs += "-SkipTiledReference" }
  if ($SkipReadiness) { $postArgs += "-SkipReadiness" }
  if ($RequireReadinessPass) { $postArgs += "-RequireReadinessPass" }
  & powershell @postArgs
  if ($LASTEXITCODE -ne 0) {
    throw "run_tinyspan_c32b4_post_training_prep.ps1 failed with exit code $LASTEXITCODE"
  }
  Write-Host "PASS watch_tinyspan_x2_training_then_postprep"
} finally {
  Pop-Location
}
