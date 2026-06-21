param(
  [string]$RunDir = "runs\tinyspan_distill\video_x4_c32_b4_reds_temporal",
  [string]$Tag = "",
  [switch]$DryRun,
  [switch]$SkipRtlExport,
  [switch]$SkipReadiness
)

$ErrorActionPreference = "Stop"

function ConvertTo-NormalizedPathText {
  param([string]$PathText)
  return ($PathText -replace "\\", "/")
}

function Get-LatestMetric {
  param([string]$MetricsPath)
  if (-not (Test-Path $MetricsPath)) {
    throw "Metrics not found: $MetricsPath"
  }
  $last = Get-Content -Path $MetricsPath -Tail 200 |
    Where-Object { $_ -match "^\d+," } |
    Select-Object -Last 1
  if (-not $last) {
    throw "No metric rows found in $MetricsPath"
  }
  $cols = $last -split ","
  if ($cols.Count -lt 11) {
    throw "Unexpected metric row shape: $last"
  }
  return [ordered]@{
    raw = $last
    epoch = [int]$cols[0]
    step = [int]$cols[1]
    student_psnr = [double]::Parse($cols[7], [System.Globalization.CultureInfo]::InvariantCulture)
    steps_per_second = [double]::Parse($cols[10], [System.Globalization.CultureInfo]::InvariantCulture)
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $metrics = Join-Path $RunDir "metrics.csv"
  $checkpoint = Join-Path $RunDir "student_latest.pt"
  if (-not (Test-Path $checkpoint)) {
    throw "Checkpoint not found: $checkpoint"
  }

  $latestMetric = Get-LatestMetric $metrics
  if ($Tag -eq "") {
    $Tag = "c32b4_step$($latestMetric.step)_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }
  $safeTag = $Tag -replace "[^A-Za-z0-9_.-]", "_"

  $normalizedRunDir = ConvertTo-NormalizedPathText $RunDir
  $running = @(Get-CimInstance Win32_Process |
    Where-Object {
      $cmd = ConvertTo-NormalizedPathText ([string]$_.CommandLine)
      ($_.Name -eq "python.exe" -or $_.Name -eq "powershell.exe") -and
      ($cmd -match "distill_tinyspan_video|train_tinyspan_video_x4_c32_b4|tinyspan_distill") -and
      ($cmd -match [regex]::Escape($normalizedRunDir))
    } |
    Select-Object ProcessId, Name, CommandLine)

  Write-Host "RUN_DIR=$RunDir"
  Write-Host "CHECKPOINT=$checkpoint"
  Write-Host "TAG=$safeTag"
  Write-Host "LATEST_EPOCH=$($latestMetric.epoch)"
  Write-Host "LATEST_STEP=$($latestMetric.step)"
  Write-Host "LATEST_STUDENT_PSNR=$($latestMetric.student_psnr)"
  Write-Host "TRAINING_PROCESS_COUNT=$($running.Count)"

  $freezeArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\freeze_tinyspan_c32b4_training_checkpoint.ps1",
    "-RunDir", $RunDir,
    "-Checkpoint", $checkpoint,
    "-Tag", $safeTag,
    "-RunHandoff"
  )
  $handoffSummary = "runs\tinyspan_realtime_handoff\c32b4_${safeTag}_summary.json"
  $quantPlan = "runs\tinyspan_quant_plan\${safeTag}_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json"
  $rtlOutDir = "rtl\generated\tinyspan_c32b4_${safeTag}_w8a8"
  $rtlManifest = Join-Path $rtlOutDir "tinyspan_w8a8_rtl_manifest.json"
  $rtlExportArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\export_tinyspan_c32b4_30fps_w8a8_to_rtl.ps1",
    "-QuantPlan", $quantPlan,
    "-OutDir", $rtlOutDir
  )
  $readinessArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\check_tinyspan_30fps_board_acceptance_ready.ps1",
    "-HandoffSummary", $handoffSummary,
    "-RtlManifest", $rtlManifest
  )

  if ($DryRun) {
    Write-Host "DRY_RUN=True"
    Write-Host "WOULD_RUN: powershell $($freezeArgs -join ' ')"
    if (-not $SkipRtlExport) {
      Write-Host "WOULD_RUN: powershell $($rtlExportArgs -join ' ')"
    }
    if (-not $SkipReadiness) {
      Write-Host "WOULD_RUN: powershell $($readinessArgs -join ' ')"
    }
    Write-Host "PASS post_training_prep_dry_run"
    return
  }

  if ($running.Count -gt 0) {
    throw "Training is still running. Refusing post-training prep until checkpoint is stable. Use -DryRun to preview commands."
  }

  & powershell @freezeArgs
  if ($LASTEXITCODE -ne 0) {
    throw "freeze_tinyspan_c32b4_training_checkpoint.ps1 failed with exit code $LASTEXITCODE"
  }

  if (-not $SkipRtlExport) {
    & powershell @rtlExportArgs
    if ($LASTEXITCODE -ne 0) {
      throw "export_tinyspan_c32b4_30fps_w8a8_to_rtl.ps1 failed with exit code $LASTEXITCODE"
    }
  }

  if (-not $SkipReadiness) {
    & powershell @readinessArgs
    if ($LASTEXITCODE -ne 0) {
      throw "check_tinyspan_30fps_board_acceptance_ready.ps1 failed with exit code $LASTEXITCODE"
    }
  }

  Write-Host "PASS run_tinyspan_c32b4_post_training_prep"
} finally {
  Pop-Location
}
