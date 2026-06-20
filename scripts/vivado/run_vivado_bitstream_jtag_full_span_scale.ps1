param(
  [ValidateSet(2, 4)]
  [int]$Scale = 2,
  [int]$ImgW = 1,
  [int]$ImgH = 0,
  [ValidateRange(1, 300)]
  [int]$PlFreqMhz = 25,
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$Checkpoint = "",
  [string]$ExportTag = "",
  [double]$BestPsnr = 28.3118,
  [switch]$UseW8A12,
  [switch]$UseW8A10,
  [ValidateRange(1, 64)]
  [int]$W8A12OutLanes = 8,
  [ValidateRange(1, 128)]
  [int]$W8A12TapLanes = 16,
  [ValidateRange(1, 16)]
  [int]$W8A12ScaleLanes = 2,
  [switch]$UseTinyspanW8A8BaseEquiv,
  [switch]$UseTinyspanW8A8BaseEquivFast,
  [int]$MinAvailablePageFileMb = 0,
  [switch]$RequireVivadoIdle,
  [int]$WaitForVivadoIdleSeconds = 0,
  [int]$StableVivadoIdleSeconds = 0,
  [ValidateRange(1, 16)]
  [int]$VivadoMaxThreads = 2,
  [string]$AttemptLabel = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($ImgH -le 0) {
  $ImgH = $ImgW
}

function Clear-VivadoProcesses {
  foreach ($name in @("vivado.exe", "vivado_lab.exe", "parallel_synth_helper.exe", "rdi_xsdb.exe", "hw_server.exe", "cs_server.exe", "xelab.exe", "xsim.exe", "xvlog.exe", "xvhdl.exe")) {
    cmd.exe /c "taskkill /IM $name /F /T >nul 2>nul" | Out-Null
  }
  Get-Process vivado,vivado_lab,parallel_synth_helper,rdi_xsdb,hw_server,cs_server,xelab,xsim,xvlog,xvhdl -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
  $remaining = Get-Process vivado,vivado_lab,parallel_synth_helper,rdi_xsdb,hw_server,cs_server,xelab,xsim,xvlog,xvhdl -ErrorAction SilentlyContinue |
    Select-Object Id,ProcessName,StartTime
  if ($remaining) {
    Write-Warning "Residual Vivado processes remain after cleanup:"
    $remaining | Format-Table -AutoSize | Out-Host
  } else {
    Write-Host "VIVADO_PROCESS_CLEAN=1"
  }
}

Push-Location $root
try {
  if (($UseW8A12 -or $UseW8A10 -or $UseTinyspanW8A8BaseEquiv) -and $Scale -ne 4) {
    throw "UseW8A12, UseW8A10, and UseTinyspanW8A8BaseEquiv currently support only Scale 4"
  }
  if ((@($UseW8A12, $UseW8A10, $UseTinyspanW8A8BaseEquiv) | Where-Object { $_ }).Count -gt 1) {
    throw "UseW8A12, UseW8A10, and UseTinyspanW8A8BaseEquiv are mutually exclusive"
  }
  if ($UseTinyspanW8A8BaseEquivFast -and -not $UseTinyspanW8A8BaseEquiv) {
    throw "UseTinyspanW8A8BaseEquivFast requires UseTinyspanW8A8BaseEquiv"
  }

  if ($RequireVivadoIdle -or $WaitForVivadoIdleSeconds -gt 0) {
    powershell -ExecutionPolicy Bypass -File scripts\check_vivado_idle.ps1 -WaitSeconds $WaitForVivadoIdleSeconds -StableIdleSeconds $StableVivadoIdleSeconds
    if ($LASTEXITCODE -ne 0) {
      throw "Vivado idle preflight failed with exit code $LASTEXITCODE"
    }
  }
  if ($MinAvailablePageFileMb -gt 0) {
    powershell -ExecutionPolicy Bypass -File scripts\check_vivado_host_memory.ps1 -MinAvailablePageFileMb $MinAvailablePageFileMb
  } else {
    powershell -ExecutionPolicy Bypass -File scripts\check_vivado_host_memory.ps1
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado host memory preflight failed with exit code $LASTEXITCODE"
  }

  if ($UseTinyspanW8A8BaseEquiv) {
    Write-Host "SKIP_OFFICIAL_SPAN_EXPORT=1"
    Write-Host "TINYSPAN_W8A8_BASE_EQUIV_USES_FROZEN_PLAN=1"
  } elseif ($UseW8A10) {
    Write-Host "SKIP_OFFICIAL_SPAN_EXPORT=1"
    Write-Host "W8A10_BOARD_CANDIDATE_SHELL=1"
  } elseif ($UseW8A12) {
    powershell -ExecutionPolicy Bypass -File scripts\pack_w8a12_group_weights.ps1 `
      -OutLanes $W8A12OutLanes `
      -TapLanes $W8A12TapLanes
    if ($LASTEXITCODE -ne 0) {
      throw "pack_w8a12_group_weights.ps1 failed with exit code $LASTEXITCODE"
    }
  } elseif ($Scale -eq 2) {
    powershell -ExecutionPolicy Bypass -File scripts\export_official_span_x2_to_rtl.ps1
  } elseif ($Checkpoint -ne "") {
    $tag = if ($ExportTag -ne "") { $ExportTag } else { "reds_span_x${Scale}_f48" }
    powershell -ExecutionPolicy Bypass -File scripts\prepare_reds_span_hardware_handoff.ps1 `
      -Checkpoint $Checkpoint `
      -Scale $Scale `
      -Channels 48 `
      -BestPsnr $BestPsnr `
      -Tag $tag
  } else {
    powershell -ExecutionPolicy Bypass -File scripts\export_official_span_x4_to_rtl.ps1
  }

  $attemptDir = Join-Path $root "board_runs\w8a12_jtag_build_attempts"
  New-Item -ItemType Directory -Path $attemptDir -Force | Out-Null
  $laneLogTag = if ($UseTinyspanW8A8BaseEquiv) { if ($UseTinyspanW8A8BaseEquivFast) { "tinyspan_w8a8_base_equiv_fast" } else { "tinyspan_w8a8_base_equiv" } } elseif ($UseW8A10) { "w8a10_candidate" } elseif ($UseW8A12) { "w8a12_ol${W8A12OutLanes}_tl${W8A12TapLanes}_sl${W8A12ScaleLanes}" } else { "official" }
  $imgTag = "{0}x{1}" -f $ImgW, $ImgH
  $vivadoLog = Join-Path $attemptDir ("jtag_full_span_x{0}_img{1}_{2}.log" -f $Scale, $imgTag, $laneLogTag)
  $vivadoJournal = Join-Path $attemptDir ("jtag_full_span_x{0}_img{1}_{2}.jou" -f $Scale, $imgTag, $laneLogTag)
  $effectiveAttemptLabel = if ($AttemptLabel -ne "") {
    $AttemptLabel
  } else {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    "x${Scale}_img${imgTag}_${laneLogTag}_mt${VivadoMaxThreads}_${stamp}"
  }
  $archiveRoot = Join-Path $attemptDir "archives"
  $archiveDir = Join-Path $archiveRoot $effectiveAttemptLabel
  New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null

  $env:JTAG_FULL_SPAN_IMG_W = [string]$ImgW
  $env:JTAG_FULL_SPAN_IMG_H = [string]$ImgH
  $env:JTAG_FULL_SPAN_SCALE = [string]$Scale
  $env:JTAG_FULL_SPAN_PL_FREQ_MHZ = [string]$PlFreqMhz
  $env:JTAG_FULL_SPAN_USE_W8A12 = if ($UseW8A12) { "1" } else { "0" }
  $env:JTAG_FULL_SPAN_USE_W8A10 = if ($UseW8A10) { "1" } else { "0" }
  $env:JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV = if ($UseTinyspanW8A8BaseEquiv) { "1" } else { "0" }
  $env:JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL = if ($UseTinyspanW8A8BaseEquivFast) { "0" } else { "1" }
  $env:JTAG_FULL_SPAN_W8A12_OUT_LANES = [string]$W8A12OutLanes
  $env:JTAG_FULL_SPAN_W8A12_TAP_LANES = [string]$W8A12TapLanes
  $env:JTAG_FULL_SPAN_W8A12_SCALE_LANES = [string]$W8A12ScaleLanes
  $env:JTAG_FULL_SPAN_MAX_THREADS = [string]$VivadoMaxThreads
  $vivadoExitCode = 0
  $vivadoLaunchTime = Get-Date
  & $VivadoBat -mode batch -source scripts\run_vivado_bitstream_jtag_full_span.tcl -log $vivadoLog -journal $vivadoJournal
  $vivadoExitCode = $LASTEXITCODE

  $projectDir = Join-Path $root "vivado\jfs"
  $archiveProjectDir = Join-Path $archiveDir "jfs"
  if (Test-Path $projectDir) {
    Copy-Item -LiteralPath $projectDir -Destination $archiveProjectDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $vivadoLog) {
    Copy-Item -LiteralPath $vivadoLog -Destination (Join-Path $archiveDir (Split-Path $vivadoLog -Leaf)) -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $vivadoJournal) {
    Copy-Item -LiteralPath $vivadoJournal -Destination (Join-Path $archiveDir (Split-Path $vivadoJournal -Leaf)) -Force -ErrorAction SilentlyContinue
  }
  Get-ChildItem -Path $root -Filter "hs_err_pid*.log" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $vivadoLaunchTime.AddMinutes(-1) } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5 |
    ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $archiveDir $_.Name) -Force -ErrorAction SilentlyContinue
    }

  Write-Host "FULL_SPAN_ATTEMPT_LABEL=$effectiveAttemptLabel"
  Write-Host "FULL_SPAN_ATTEMPT_ARCHIVE=$archiveDir"

  if ($vivadoExitCode -ne 0) {
    throw "Vivado bitstream flow failed with exit code $vivadoExitCode; archive: $archiveDir"
  }

  $bitDir = Join-Path $root "vivado\bitstreams"
  New-Item -ItemType Directory -Path $bitDir -Force | Out-Null
  $srcBit = Join-Path $root "vivado\jfs\jfs.runs\impl_1\jfs_wrapper.bit"
  $freqTag = if ($PlFreqMhz -eq 25) { "" } else { "_f${PlFreqMhz}m" }
  $laneTag = if ($UseW8A12 -and (($W8A12OutLanes -ne 8) -or ($W8A12TapLanes -ne 16) -or ($W8A12ScaleLanes -ne 2))) {
    "_ol${W8A12OutLanes}_tl${W8A12TapLanes}_sl${W8A12ScaleLanes}"
  } else {
    ""
  }
  $coreTag = if ($UseTinyspanW8A8BaseEquiv) { if ($UseTinyspanW8A8BaseEquivFast) { "_tinyspan_w8a8_base_equiv_fast" } else { "_tinyspan_w8a8_base_equiv" } } elseif ($UseW8A10) { "_w8a10_candidate" } elseif ($UseW8A12) { "_w8a12$laneTag" } else { "" }
  $dstBit = Join-Path $bitDir ("jfs_full_span_x{0}_{1}{2}{3}.bit" -f $Scale, $imgTag, $freqTag, $coreTag)
  Copy-Item -LiteralPath $srcBit -Destination $dstBit -Force

  $reportDir = Join-Path $root "vivado\reports"
  New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
  $srcUtil = Join-Path $root "vivado\jfs\reports\jtag_full_span_utilization_impl.rpt"
  $srcTiming = Join-Path $root "vivado\jfs\reports\jtag_full_span_timing_impl.rpt"
  $srcPower = Join-Path $root "vivado\jfs\reports\jtag_full_span_power_impl.rpt"
  $dstUtil = Join-Path $reportDir ("jtag_full_span_x{0}_{1}{2}{3}_utilization_impl.rpt" -f $Scale, $imgTag, $freqTag, $coreTag)
  $dstTiming = Join-Path $reportDir ("jtag_full_span_x{0}_{1}{2}{3}_timing_impl.rpt" -f $Scale, $imgTag, $freqTag, $coreTag)
  $dstPower = Join-Path $reportDir ("jtag_full_span_x{0}_{1}{2}{3}_power_impl.rpt" -f $Scale, $imgTag, $freqTag, $coreTag)
  Copy-Item -LiteralPath $srcUtil -Destination $dstUtil -Force
  Copy-Item -LiteralPath $srcTiming -Destination $dstTiming -Force
  if (Test-Path -LiteralPath $srcPower) {
    Copy-Item -LiteralPath $srcPower -Destination $dstPower -Force
  }

  Write-Host "FULL_SPAN_SCALE=$Scale"
  Write-Host "FULL_SPAN_IMG_W=$ImgW"
  Write-Host "FULL_SPAN_IMG_H=$ImgH"
  Write-Host "FULL_SPAN_PL_FREQ_MHZ=$PlFreqMhz"
  Write-Host "FULL_SPAN_USE_W8A12=$([int][bool]$UseW8A12)"
  Write-Host "FULL_SPAN_USE_W8A10=$([int][bool]$UseW8A10)"
  Write-Host "FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV=$([int][bool]$UseTinyspanW8A8BaseEquiv)"
  Write-Host "FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_FAST=$([int][bool]$UseTinyspanW8A8BaseEquivFast)"
  if ($UseW8A12) {
    Write-Host "FULL_SPAN_W8A12_OUT_LANES=$W8A12OutLanes"
    Write-Host "FULL_SPAN_W8A12_TAP_LANES=$W8A12TapLanes"
    Write-Host "FULL_SPAN_W8A12_SCALE_LANES=$W8A12ScaleLanes"
  }
  Write-Host "FULL_SPAN_BIT=$dstBit"
  Write-Host "FULL_SPAN_UTIL=$dstUtil"
  Write-Host "FULL_SPAN_TIMING=$dstTiming"
  if (Test-Path -LiteralPath $dstPower) {
    Write-Host "FULL_SPAN_POWER=$dstPower"
  } else {
    Write-Host "FULL_SPAN_POWER=NOT_GENERATED"
  }
  Write-Host "FULL_SPAN_VIVADO_LOG=$vivadoLog"
}
finally {
  Remove-Item Env:\JTAG_FULL_SPAN_IMG_W -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_IMG_H -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_SCALE -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_PL_FREQ_MHZ -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_USE_W8A12 -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_USE_W8A10 -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_W8A12_OUT_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_W8A12_TAP_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_W8A12_SCALE_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\JTAG_FULL_SPAN_MAX_THREADS -ErrorAction SilentlyContinue
  Clear-VivadoProcesses
  Pop-Location
}
