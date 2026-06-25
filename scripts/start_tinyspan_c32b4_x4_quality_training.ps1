param(
  [string]$TrainFrames = "G:\REDS\train_sharp",
  [string]$Output = "runs\tinyspan_distill\video_x4_c32_b4_quality_hr060_edge006_20260625",
  [string]$ResumeStudent = "model\checkpoints\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt",
  [int]$PatchSize = 192,
  [int]$BatchSize = 6,
  [int]$Epochs = 20,
  [int]$MaxPairs = 24000,
  [int]$MaxSteps = 0,
  [int]$SaveEverySteps = 500,
  [double]$LearningRate = 0.00005,
  [double]$DistillWeight = 0.7,
  [double]$HrWeight = 0.6,
  [double]$EdgeWeight = 0.06,
  [double]$TemporalWeight = 0.2,
  [int]$NumWorkers = 4,
  [int]$Seed = 42,
  [switch]$NoAmp
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $ResumeStudent)) {
    throw "ResumeStudent checkpoint not found: $ResumeStudent"
  }
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start_tinyspan_c32b4_training.ps1 `
    -TrainFrames $TrainFrames `
    -Output $Output `
    -PatchSize $PatchSize `
    -BatchSize $BatchSize `
    -Epochs $Epochs `
    -MaxPairs $MaxPairs `
    -MaxSteps $MaxSteps `
    -SaveEverySteps $SaveEverySteps `
    -ResumeStudent $ResumeStudent `
    -LearningRate $LearningRate `
    -DistillWeight $DistillWeight `
    -HrWeight $HrWeight `
    -EdgeWeight $EdgeWeight `
    -TemporalWeight $TemporalWeight `
    -NumWorkers $NumWorkers `
    -Seed $Seed `
    -NoAmp:$NoAmp
  if ($LASTEXITCODE -ne 0) {
    throw "start_tinyspan_c32b4_training.ps1 failed with exit code $LASTEXITCODE"
  }
  Write-Host "PASS start_tinyspan_c32b4_x4_quality_training"
} finally {
  Pop-Location
}
