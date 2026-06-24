param(
  [string]$TrainFrames = "G:\REDS\train_sharp",
  [string]$Output = "runs\tinyspan_distill\video_x2_c32_b4_reds_temporal",
  [int]$PatchSize = 192,
  [int]$BatchSize = 6,
  [int]$Epochs = 50,
  [int]$MaxPairs = 24000,
  [int]$MaxSteps = 0,
  [int]$SaveEverySteps = 500,
  [string]$ResumeStudent = "",
  [switch]$Smoke,
  [switch]$NoAmp
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if ($Smoke) {
    $Output = "runs\tinyspan_distill\video_reds_smoke_x2_c32_b4"
    $PatchSize = 192
    $BatchSize = 1
    $Epochs = 1
    $MaxPairs = 24
    if ($MaxSteps -le 0) {
      $MaxSteps = 4
    }
  }

  if (-not (Test-Path $TrainFrames)) {
    throw "TrainFrames path not found: $TrainFrames"
  }

  $argsList = @(
    "train\distill_tinyspan_video.py",
    "--train-frames", $TrainFrames,
    "--scale", "2",
    "--channels", "32",
    "--num-blocks", "4",
    "--patch-size", [string]$PatchSize,
    "--batch-size", [string]$BatchSize,
    "--epochs", [string]$Epochs,
    "--max-steps", [string]$MaxSteps,
    "--max-pairs", [string]$MaxPairs,
    "--output", $Output
  )

  if ($SaveEverySteps -gt 0) {
    $argsList += @("--save-every-steps", [string]$SaveEverySteps)
  }
  if ($ResumeStudent -ne "") {
    if (-not (Test-Path $ResumeStudent)) {
      throw "ResumeStudent checkpoint not found: $ResumeStudent"
    }
    $argsList += @("--resume-student", $ResumeStudent)
  }
  if (-not $NoAmp) {
    $argsList += "--amp"
  }

  Write-Host "TINYSPAN_C32B4_X2_TRAIN_OUTPUT=$Output"
  Write-Host "TINYSPAN_C32B4_X2_TRAIN_COMMAND=python $($argsList -join ' ')"
  python @argsList
  if ($LASTEXITCODE -ne 0) {
    throw "C32B4 TinySPAN X2 video distillation failed with exit code $LASTEXITCODE"
  }

  $checkpoint = Join-Path $Output "student_last.pt"
  $preview = Join-Path $Output "video_distill_preview.png"
  if (-not (Test-Path $checkpoint)) {
    throw "Expected checkpoint not found: $checkpoint"
  }
  if (-not (Test-Path $preview)) {
    throw "Expected preview not found: $preview"
  }
  Write-Host "TINYSPAN_C32B4_X2_CHECKPOINT=$checkpoint"
  Write-Host "TINYSPAN_C32B4_X2_PREVIEW=$preview"
  Write-Host "PASS train_tinyspan_video_x2_c32_b4"
}
finally {
  Pop-Location
}
