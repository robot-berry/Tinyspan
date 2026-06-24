param(
  [string]$TrainFrames = "G:\REDS\train_sharp",
  [string]$Output = "runs\tinyspan_distill\video_x2_c32_b4_reds_temporal",
  [int]$PatchSize = 192,
  [int]$BatchSize = 6,
  [int]$Epochs = 50,
  [int]$MaxPairs = 24000,
  [int]$SaveEverySteps = 500,
  [string]$ResumeStudent = "",
  [switch]$NoAmp
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $TrainFrames)) {
    throw "TrainFrames path not found: $TrainFrames"
  }

  $existing = Get-CimInstance Win32_Process |
    Where-Object {
      $_.Name -eq "python.exe" -and
      $_.CommandLine -match "distill_tinyspan_video.py" -and
      $_.CommandLine -match [regex]::Escape($Output)
    }
  if ($existing) {
    $ids = ($existing | Select-Object -ExpandProperty ProcessId) -join ", "
    throw "C32B4 X2 training already appears to be running for ${Output}. PIDs: $ids"
  }

  New-Item -ItemType Directory -Force -Path $Output | Out-Null
  $stdout = Join-Path $Output "train_stdout.log"
  $stderr = Join-Path $Output "train_stderr.log"
  $commandTxt = Join-Path $Output "train_command.txt"

  $argList = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $root "scripts\train_tinyspan_video_x2_c32_b4.ps1"),
    "-TrainFrames", $TrainFrames,
    "-Output", $Output,
    "-PatchSize", [string]$PatchSize,
    "-BatchSize", [string]$BatchSize,
    "-Epochs", [string]$Epochs,
    "-MaxPairs", [string]$MaxPairs,
    "-SaveEverySteps", [string]$SaveEverySteps
  )
  if ($ResumeStudent -ne "") {
    $argList += @("-ResumeStudent", $ResumeStudent)
  }
  if ($NoAmp) {
    $argList += "-NoAmp"
  }

  $commandLine = "powershell " + (($argList | ForEach-Object {
    if ($_ -match "\s") { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
  }) -join " ")
  $commandLine | Set-Content -Path $commandTxt -Encoding UTF8

  $process = Start-Process `
    -FilePath "powershell" `
    -ArgumentList $argList `
    -WorkingDirectory $root `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -WindowStyle Hidden `
    -PassThru

  $summary = [ordered]@{
    status = "STARTED"
    pid = $process.Id
    output = (Resolve-Path $Output).Path
    stdout = (Resolve-Path $stdout).Path
    stderr = (Resolve-Path $stderr).Path
    command = (Resolve-Path $commandTxt).Path
  }
  Write-Host ($summary | ConvertTo-Json -Depth 3)
} finally {
  Pop-Location
}
