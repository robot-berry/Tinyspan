param(
  [string]$Output = "runs\tinyspan_distill\video_x4_c32_b4_reds_temporal",
  [int]$Tail = 20,
  [int]$TotalEpochs = 50,
  [int]$StepsPerEpoch = 5940,
  [switch]$IncludeLegacyLogs
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $normalizedOutput = ($Output -replace "\\", "/")
  $normalizedOutputLeaf = [System.IO.Path]::GetFileName($normalizedOutput.TrimEnd("/"))
  $running = Get-CimInstance Win32_Process |
    Where-Object {
      $cmd = ($_.CommandLine -replace "\\", "/")
      $isTrainProcess = (
        ($_.Name -eq "python.exe" -and $cmd -match "distill_tinyspan_video\.py") -or
        ($_.Name -eq "powershell.exe" -and $cmd -match "train_tinyspan_video_x[24]_c32_b4\.ps1")
      )
      $matchesOutput = ($cmd -match [regex]::Escape($normalizedOutput)) -or
        ($normalizedOutputLeaf -ne "" -and $cmd -match [regex]::Escape($normalizedOutputLeaf))
      $isTrainProcess -and
      $matchesOutput
    } |
    Select-Object ProcessId, Name, CommandLine

  Write-Host "Processes:"
  if ($running) {
    $running | Format-Table -AutoSize
  } else {
    Write-Host "  none found for $Output"
  }

  Write-Host ""
  Write-Host "GPU:"
  $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
  if ($nvidiaSmi) {
    & nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits
    $gpuApps = & nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits
    $interestingGpuApps = @($gpuApps | Where-Object { $_ -match "python|anaconda|64192" })
    if ($interestingGpuApps.Count -gt 0) {
      $interestingGpuApps
    } else {
      Write-Host "  no python compute app reported"
    }
  } else {
    Write-Host "  nvidia-smi not found"
  }

  Write-Host ""
  Write-Host "Artifacts:"
  foreach ($path in @(
      (Join-Path $Output "student_latest.pt"),
      (Join-Path $Output "student_last.pt"),
      (Join-Path $Output "video_distill_latest_preview.png"),
      (Join-Path $Output "video_distill_preview.png"),
      (Join-Path $Output "metrics.csv"),
      (Join-Path $Output "train_stdout.log"),
      (Join-Path $Output "train_stderr.log")
    )) {
    if (Test-Path $path) {
      $item = Get-Item $path
      Write-Host ("  {0}  {1} bytes  {2}" -f $path, $item.Length, $item.LastWriteTime)
    } else {
      Write-Host "  missing $path"
    }
  }

  $metrics = Join-Path $Output "metrics.csv"
  if (Test-Path $metrics) {
    Write-Host ""
    Write-Host "Latest metrics:"
    $latestMetrics = @(Get-Content -Path $metrics -Tail ([Math]::Max(1, $Tail)))
    $latestMetrics
    $lastMetric = $latestMetrics | Where-Object { $_ -match "^\d+," } | Select-Object -Last 1
    if ($lastMetric) {
      $cols = $lastMetric -split ","
      if ($cols.Count -ge 11) {
        $epoch = [int]$cols[0]
        $globalStep = [int]$cols[1]
        $stepsPerSecond = [double]::Parse($cols[10], [System.Globalization.CultureInfo]::InvariantCulture)
        $totalSteps = [Math]::Max(1, $TotalEpochs * $StepsPerEpoch)
        $remainingSteps = [Math]::Max(0, $totalSteps - $globalStep)
        $etaSeconds = if ($stepsPerSecond -gt 0) { [int]($remainingSteps / $stepsPerSecond) } else { 0 }
        $eta = [TimeSpan]::FromSeconds($etaSeconds)
        $etaText = $eta.ToString("dd\.hh\:mm\:ss")
        Write-Host ""
        Write-Host ("Training estimate: epoch={0}/{1}, global_step={2}/{3}, speed={4:F4} steps/s, remaining={5}" -f `
          $epoch, $TotalEpochs, $globalStep, $totalSteps, $stepsPerSecond, $etaText)
      }
    }
  }

  $logFiles = @()
  if (Test-Path $Output) {
    $logFiles = @(Get-ChildItem -Path $Output -File |
      Where-Object { $_.Name -match "(stdout|stderr)\.log$" } |
      Sort-Object LastWriteTime -Descending)
  }
  if ($logFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Latest log files:"
    $logFiles | Select-Object -First 8 Name, Length, LastWriteTime | Format-Table -AutoSize

    $latestErr = $logFiles | Where-Object { $_.Name -match "stderr\.log$" } | Select-Object -First 1
    if ($latestErr) {
      Write-Host ""
      Write-Host "Latest active stderr ($($latestErr.Name)):"
      $activeErrTail = @(Get-Content -Path $latestErr.FullName -Tail ([Math]::Max(1, $Tail)))
      $activeErrTail
      $errorHints = @($activeErrTail | Where-Object { $_ -match "Traceback|Exception|OSError|CUDA out of memory|failed|error" })
      Write-Host ""
      if ($errorHints.Count -gt 0) {
        Write-Host "Recent error hints:"
        $errorHints
      } else {
        Write-Host "Recent error hints: none"
      }
    }
  }

  if ($IncludeLegacyLogs) {
    $stdout = Join-Path $Output "train_stdout.log"
    if (Test-Path $stdout) {
      Write-Host ""
      Write-Host "Legacy train_stdout.log:"
      Get-Content -Path $stdout -Tail ([Math]::Max(1, $Tail))
    }

    $stderr = Join-Path $Output "train_stderr.log"
    if ((Test-Path $stderr) -and (Get-Item $stderr).Length -gt 0) {
      Write-Host ""
      Write-Host "Legacy train_stderr.log:"
      Get-Content -Path $stderr -Tail ([Math]::Max(1, $Tail))
    }
  }
} finally {
  Pop-Location
}
