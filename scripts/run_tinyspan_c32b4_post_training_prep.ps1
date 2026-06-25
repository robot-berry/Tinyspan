param(
  [string]$RunDir = "runs\tinyspan_distill\video_x4_c32_b4_reds_temporal",
  [string]$Tag = "",
  [ValidateSet(2, 4)]
  [int]$Scale = 4,
  [switch]$DryRun,
  [switch]$SkipRtlExport,
  [switch]$SkipTiledReference,
  [string]$TiledReferenceInputPng = "G:\REDS\val_sharp\000\00000000.png",
  [int]$TiledReferenceTileWidth = 64,
  [int]$TiledReferenceTileHeight = 64,
  [string]$TiledReferenceOutDir = "",
  [switch]$SkipReadiness,
  [switch]$RequireReadinessPass
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
  $latestCheckpoint = Join-Path $RunDir "student_latest.pt"
  $finalCheckpoint = Join-Path $RunDir "student_last.pt"
  if (Test-Path $finalCheckpoint) {
    $checkpoint = $finalCheckpoint
    $checkpointSource = "student_last.pt"
  } elseif (Test-Path $latestCheckpoint) {
    $checkpoint = $latestCheckpoint
    $checkpointSource = "student_latest.pt"
  } else {
    throw "Checkpoint not found: $finalCheckpoint or $latestCheckpoint"
  }

  $latestMetric = Get-LatestMetric $metrics
  if ($Tag -eq "") {
    $Tag = "step$($latestMetric.step)_" + (Get-Date -Format "yyyyMMdd_HHmmss")
  }
  $safeTag = $Tag -replace "[^A-Za-z0-9_.-]", "_"
  $scaleTag = "x${Scale}"
  $frozenCheckpoint = "runs\tinyspan_frozen_candidates\${safeTag}\student_final.pt"

  $normalizedRunDir = ConvertTo-NormalizedPathText $RunDir
  $normalizedRunDirLeaf = [System.IO.Path]::GetFileName($normalizedRunDir.TrimEnd("/"))
  $running = @(Get-CimInstance Win32_Process |
    Where-Object {
      $cmd = ConvertTo-NormalizedPathText ([string]$_.CommandLine)
      $isTrainProcess = (
        ($_.Name -eq "python.exe" -and $cmd -match "distill_tinyspan_video\.py") -or
        ($_.Name -eq "powershell.exe" -and $cmd -match "train_tinyspan_video_x[24]_c32_b4\.ps1")
      )
      $matchesRunDir = ($cmd -match [regex]::Escape($normalizedRunDir)) -or
        ($normalizedRunDirLeaf -ne "" -and $cmd -match [regex]::Escape($normalizedRunDirLeaf))
      ($_.ProcessId -ne $PID) -and
      $isTrainProcess -and
      $matchesRunDir
    } |
    Select-Object ProcessId, Name, CommandLine)

  Write-Host "RUN_DIR=$RunDir"
  Write-Host "CHECKPOINT=$checkpoint"
  Write-Host "CHECKPOINT_SOURCE=$checkpointSource"
  Write-Host "FROZEN_CHECKPOINT=$frozenCheckpoint"
  Write-Host "TAG=$safeTag"
  Write-Host "SCALE=$Scale"
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
    "-Scale", $Scale,
    "-RunHandoff"
  )
  $handoffSummary = "runs\tinyspan_realtime_handoff\c32b4_${safeTag}_summary.json"
  $quantPlan = "runs\tinyspan_quant_plan\${safeTag}_${scaleTag}_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json"
  $rtlOutDir = "rtl\generated\tinyspan_c32b4_${safeTag}_${scaleTag}_w8a8"
  $rtlManifest = Join-Path $rtlOutDir "tinyspan_w8a8_rtl_manifest.json"
  $expectedBitstream = "vivado\bitstreams\tinyspan_${scaleTag}_c32b4_${safeTag}_board.bit"
  if ($Scale -eq 2) {
    $frameWidth = 640
    $frameHeight = 360
  } else {
    $frameWidth = 320
    $frameHeight = 180
  }
  if ([string]::IsNullOrWhiteSpace($TiledReferenceOutDir)) {
    $TiledReferenceOutDir = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_${scaleTag}_${frameWidth}x${frameHeight}_tile${TiledReferenceTileWidth}x${TiledReferenceTileHeight}_${safeTag}"
  }
  $rtlExportArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\export_tinyspan_c32b4_30fps_w8a8_to_rtl.ps1",
    "-QuantPlan", $quantPlan,
    "-OutDir", $rtlOutDir
  )
  $tiledReferenceArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\acceptance\make_tinyspan_tiled_fixed_reference.ps1",
    "-InputPng", $TiledReferenceInputPng,
    "-InputWidth", $frameWidth,
    "-InputHeight", $frameHeight,
    "-TileWidth", $TiledReferenceTileWidth,
    "-TileHeight", $TiledReferenceTileHeight,
    "-QuantPlan", $quantPlan,
    "-Checkpoint", $frozenCheckpoint,
    "-OutDir", $TiledReferenceOutDir
  )
  $readinessArgs = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\acceptance\check_tinyspan_30fps_board_acceptance_ready.ps1",
    "-HandoffSummary", $handoffSummary,
    "-RtlManifest", $rtlManifest,
    "-Bitstream", $expectedBitstream,
    "-OutDir", "board_runs\tinyspan_board_acceptance\readiness_${safeTag}_${scaleTag}"
  )

  if ($DryRun) {
    Write-Host "DRY_RUN=True"
    Write-Host "WOULD_RUN: powershell $($freezeArgs -join ' ')"
    if (-not $SkipRtlExport) {
      Write-Host "WOULD_RUN: powershell $($rtlExportArgs -join ' ')"
    }
    if (-not $SkipTiledReference) {
      Write-Host "WOULD_RUN: powershell $($tiledReferenceArgs -join ' ')"
    }
    if (-not $SkipReadiness) {
      Write-Host "WOULD_RUN: powershell $($readinessArgs -join ' ')"
      if (-not $RequireReadinessPass) {
        Write-Host "NOTE: readiness failures are recorded but non-fatal unless -RequireReadinessPass is set"
      }
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

  if (-not $SkipTiledReference) {
    & powershell @tiledReferenceArgs
    if ($LASTEXITCODE -ne 0) {
      throw "make_tinyspan_tiled_fixed_reference.ps1 failed with exit code $LASTEXITCODE"
    }
  }

  if (-not $SkipReadiness) {
    & powershell @readinessArgs
    $readinessExitCode = $LASTEXITCODE
    if ($readinessExitCode -ne 0 -and $RequireReadinessPass) {
      throw "check_tinyspan_30fps_board_acceptance_ready.ps1 failed with exit code $LASTEXITCODE"
    } elseif ($readinessExitCode -ne 0) {
      Write-Warning "Readiness check reported incomplete evidence with exit code $readinessExitCode. This is non-fatal for post-training prep; use -RequireReadinessPass to make it fatal."
    }
  }

  Write-Host "PASS run_tinyspan_c32b4_post_training_prep"
} finally {
  Pop-Location
}
