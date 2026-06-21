param(
  [string]$RunDir = "runs\tinyspan_distill\video_x4_c32_b4_reds_temporal",
  [string]$Checkpoint = "",
  [string]$Tag = "",
  [string]$OutRoot = "runs\tinyspan_frozen_candidates",
  [switch]$AllowRunning,
  [switch]$RunHandoff,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function ConvertTo-NormalizedPathText {
  param([string]$PathText)
  return ($PathText -replace "\\", "/")
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
    return [ordered]@{ raw = $last }
  }
  return [ordered]@{
    raw = $last
    epoch = [int]$cols[0]
    step = [int]$cols[1]
    loss = [double]::Parse($cols[2], [System.Globalization.CultureInfo]::InvariantCulture)
    student_psnr = [double]::Parse($cols[7], [System.Globalization.CultureInfo]::InvariantCulture)
    seconds = [double]::Parse($cols[9], [System.Globalization.CultureInfo]::InvariantCulture)
    steps_per_second = [double]::Parse($cols[10], [System.Globalization.CultureInfo]::InvariantCulture)
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if ($Checkpoint -eq "") {
    $Checkpoint = Join-Path $RunDir "student_latest.pt"
  }
  if ($Tag -eq "") {
    $Tag = "c32b4_final_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }
  $safeTag = $Tag -replace "[^A-Za-z0-9_.-]", "_"
  $outDir = Join-Path $OutRoot $safeTag
  $metrics = Join-Path $RunDir "metrics.csv"
  $preview = Join-Path $RunDir "video_distill_latest_preview.png"
  $frozenCheckpoint = Join-Path $outDir "student_final.pt"
  $frozenMetrics = Join-Path $outDir "metrics.csv"
  $frozenPreview = Join-Path $outDir "video_distill_latest_preview.png"
  $summaryJson = Join-Path $outDir "tinyspan_c32b4_frozen_checkpoint_summary.json"
  $summaryMd = Join-Path $outDir "tinyspan_c32b4_frozen_checkpoint_summary.md"

  $normalizedRunDir = ConvertTo-NormalizedPathText $RunDir
  $running = @(Get-CimInstance Win32_Process |
    Where-Object {
      $cmd = ConvertTo-NormalizedPathText ([string]$_.CommandLine)
      ($_.Name -eq "python.exe" -or $_.Name -eq "powershell.exe") -and
      ($cmd -match "distill_tinyspan_video|train_tinyspan_video_x4_c32_b4|tinyspan_distill") -and
      ($cmd -match [regex]::Escape($normalizedRunDir))
    } |
    Select-Object ProcessId, Name, CommandLine)

  if ($running.Count -gt 0 -and -not $AllowRunning) {
    throw "Training is still running for $RunDir. Refusing to freeze a moving checkpoint. Use -AllowRunning only for an explicit mid-run snapshot."
  }
  if (-not (Test-Path $Checkpoint)) {
    throw "Checkpoint not found: $Checkpoint"
  }
  if (-not (Test-Path $metrics)) {
    throw "Metrics not found: $metrics"
  }

  $latestMetric = Get-LatestMetric $metrics
  if (-not $latestMetric) {
    throw "No metric rows found in $metrics"
  }
  $checkpointHash = (Get-FileHash -Algorithm SHA256 -Path $Checkpoint).Hash
  $metricsHash = (Get-FileHash -Algorithm SHA256 -Path $metrics).Hash
  $previewHash = if (Test-Path $preview) { (Get-FileHash -Algorithm SHA256 -Path $preview).Hash } else { "" }

  $summary = [ordered]@{
    passed = $true
    dry_run = [bool]$DryRun
    tag = $safeTag
    run_dir = $RunDir
    source_checkpoint = $Checkpoint
    source_metrics = $metrics
    source_preview = $preview
    frozen_dir = $outDir
    frozen_checkpoint = $frozenCheckpoint
    frozen_metrics = $frozenMetrics
    frozen_preview = if (Test-Path $preview) { $frozenPreview } else { "" }
    source_checkpoint_sha256 = $checkpointHash
    source_metrics_sha256 = $metricsHash
    source_preview_sha256 = $previewHash
    latest_metric = $latestMetric
    training_processes = @($running)
    allow_running = [bool]$AllowRunning
    run_handoff = [bool]$RunHandoff
    handoff_summary = ""
  }

  if (-not $DryRun) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Copy-Item -Path $Checkpoint -Destination $frozenCheckpoint -Force
    Copy-Item -Path $metrics -Destination $frozenMetrics -Force
    if (Test-Path $preview) {
      Copy-Item -Path $preview -Destination $frozenPreview -Force
    }
    $summary.source_checkpoint_sha256 = (Get-FileHash -Algorithm SHA256 -Path $frozenCheckpoint).Hash
    $summary.source_metrics_sha256 = (Get-FileHash -Algorithm SHA256 -Path $frozenMetrics).Hash
    if (Test-Path $frozenPreview) {
      $summary.source_preview_sha256 = (Get-FileHash -Algorithm SHA256 -Path $frozenPreview).Hash
    }

    if ($RunHandoff) {
      powershell -ExecutionPolicy Bypass -File scripts\prepare_tinyspan_c32b4_realtime_handoff.ps1 `
        -Checkpoint $frozenCheckpoint `
        -Tag $safeTag
      if ($LASTEXITCODE -ne 0) {
        throw "prepare_tinyspan_c32b4_realtime_handoff.ps1 failed with exit code $LASTEXITCODE"
      }
      $summary.handoff_summary = "runs\tinyspan_realtime_handoff\c32b4_${safeTag}_summary.json"
    }

    $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8
    $lines = @(
      "# TinySPAN C32B4 Frozen Checkpoint",
      "",
      "Tag: ``$safeTag``",
      "",
      "Checkpoint: ``$frozenCheckpoint``",
      "",
      "Metrics: ``$frozenMetrics``",
      "",
      "Latest metric: epoch ``$($latestMetric.epoch)``, step ``$($latestMetric.step)``, student_psnr ``$($latestMetric.student_psnr)``",
      "",
      "Checkpoint SHA256: ``$($summary.source_checkpoint_sha256)``",
      "",
      "Run handoff: ``$RunHandoff``",
      "",
      "This script does not start Vivado."
    )
    $lines | Set-Content -Path $summaryMd -Encoding UTF8
  }

  Write-Host "PASS freeze_tinyspan_c32b4_training_checkpoint"
  Write-Host "DRY_RUN=$DryRun"
  Write-Host "TAG=$safeTag"
  Write-Host "FROZEN_DIR=$outDir"
  Write-Host "LATEST_EPOCH=$($latestMetric.epoch)"
  Write-Host "LATEST_STEP=$($latestMetric.step)"
  Write-Host "TRAINING_PROCESS_COUNT=$($running.Count)"
  Write-Host "SUMMARY=$summaryJson"
} finally {
  Pop-Location
}
