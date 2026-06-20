param(
  [int]$ImgW = 32,
  [int]$ImgH = 0,
  [int]$PlFreqMhz = 100,
  [switch]$Fast,
  [string]$InputPng = "external\SPAN\test_scripts\data\baboon.png",
  [string]$Checkpoint = "runs\tinyspan_frozen_candidates\c32b4_30fps_frozen_20260613\student_30fps_candidate.pt",
  [string]$QuantPlan = "runs\tinyspan_quant_plan\c32b4_30fps_frozen_20260613_x4_c32_b4_w8a8\tinyspan_w8a8_quant_plan.json",
  [string]$Bitstream = "",
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$OutDir = "board_runs\tinyspan_w8a8_base_equiv_jtag\latest",
  [switch]$NoProgram,
  [double]$MeasuredFps = -1.0,
  [switch]$SkipAcceptance
)

$ErrorActionPreference = "Stop"
if ($ImgH -le 0) {
  $ImgH = $ImgW
}

function Get-UtilValue {
  param(
    [string]$Path,
    [string]$Name
  )
  if (-not (Test-Path $Path)) { return $null }
  $escaped = [regex]::Escape($Name)
  $match = Select-String -Path $Path -Pattern "\|\s*$escaped\s*\|\s*([0-9]+(?:\.[0-9]+)?)\s*\|" | Select-Object -First 1
  if ($null -eq $match) { return $null }
  return $match.Matches[0].Groups[1].Value
}

function Get-TimingValue {
  param(
    [string]$Path,
    [string]$Label
  )
  if (-not (Test-Path $Path)) { return $null }
  foreach ($line in Get-Content -Path $Path) {
    if ($line -match "^\s*([-+]?[0-9]+(?:\.[0-9]+)?)\s+[-+]?[0-9]+(?:\.[0-9]+)?\s+\d+\s+\d+\s+([-+]?[0-9]+(?:\.[0-9]+)?)\s+") {
      if ($Label -eq "WNS") { return $Matches[1] }
      if ($Label -eq "WHS") { return $Matches[2] }
    }
  }
  return $null
}

function Get-PowerValue {
  param(
    [string]$Path,
    [string]$Name
  )
  if (-not (Test-Path $Path)) { return $null }
  $escaped = [regex]::Escape($Name)
  $match = Select-String -Path $Path -Pattern "\|\s*$escaped\s*\|\s*([-+]?[0-9]+(?:\.[0-9]+)?)" | Select-Object -First 1
  if ($null -eq $match) { return $null }
  return $match.Matches[0].Groups[1].Value
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  $outDirAbs = Join-Path $root $OutDir
  New-Item -ItemType Directory -Force -Path $outDirAbs | Out-Null
  $tag = "x4_${ImgW}x${ImgH}_tinyspan_w8a8_base_equiv"
  $outW = $ImgW * 4
  $outH = $ImgH * 4
  $inputRaw = Join-Path $outDirAbs "input_$tag.rgb"
  $outputRaw = Join-Path $outDirAbs "board_output_$tag.rgb"
  $outputPng = Join-Path $outDirAbs "board_output_$tag.png"
  $refDir = Join-Path $outDirAbs "software_reference"
  $jtagLog = Join-Path $outDirAbs "jtag_transfer.log"
  $jtagJournal = Join-Path $outDirAbs "jtag_transfer.jou"
  $perfLog = Join-Path $outDirAbs "jtag_perf_only.log"
  $perfJournal = Join-Path $outDirAbs "jtag_perf_only.jou"
  $perfOutputRaw = Join-Path $outDirAbs "perf_only_discarded.rgb"
  $vivadoIdleLog = Join-Path $outDirAbs "vivado_idle_precheck.log"
  $vivadoCleanupLog = Join-Path $outDirAbs "vivado_cleanup.log"

  if ([string]::IsNullOrWhiteSpace($Bitstream)) {
    $freqTag = if ($PlFreqMhz -eq 25) { "" } else { "_f${PlFreqMhz}m" }
    $coreTag = if ($Fast) { "tinyspan_w8a8_base_equiv_fast" } else { "tinyspan_w8a8_base_equiv" }
    $Bitstream = Join-Path $root ("vivado\bitstreams\jfs_full_span_x4_{0}x{1}{2}_{3}.bit" -f $ImgW, $ImgH, $freqTag, $coreTag)
  }
  $bitBase = [System.IO.Path]::GetFileNameWithoutExtension($Bitstream)
  $reportBase = $bitBase -replace "^jfs_full_span_", "jtag_full_span_"
  $utilReport = Join-Path $root ("vivado\reports\{0}_utilization_impl.rpt" -f $reportBase)
  $timingReport = Join-Path $root ("vivado\reports\{0}_timing_impl.rpt" -f $reportBase)
  $powerReport = Join-Path $root ("vivado\reports\{0}_power_impl.rpt" -f $reportBase)
  $resourceJson = Join-Path $outDirAbs "implementation_resources.json"
  $resources = [ordered]@{
    bitstream = $Bitstream
    utilization_report = $utilReport
    timing_report = $timingReport
    power_report = $powerReport
    vivado_idle_log = $vivadoIdleLog
    vivado_cleanup_log = $vivadoCleanupLog
    clb_luts = Get-UtilValue -Path $utilReport -Name "CLB LUTs"
    clb_registers = Get-UtilValue -Path $utilReport -Name "CLB Registers"
    block_ram_tile = Get-UtilValue -Path $utilReport -Name "Block RAM Tile"
    dsps = Get-UtilValue -Path $utilReport -Name "DSPs"
    wns_ns = Get-TimingValue -Path $timingReport -Label "WNS"
    whs_ns = Get-TimingValue -Path $timingReport -Label "WHS"
    total_on_chip_power_w = Get-PowerValue -Path $powerReport -Name "Total On-Chip Power (W)"
    dynamic_power_w = Get-PowerValue -Path $powerReport -Name "Dynamic (W)"
    device_static_power_w = Get-PowerValue -Path $powerReport -Name "Device Static (W)"
  }
  $resources | ConvertTo-Json -Depth 4 | Set-Content -Path $resourceJson -Encoding UTF8
  Write-Host "TINYSPAN_RESOURCE_JSON=$resourceJson"
  Write-Host "TINYSPAN_RESOURCE_UTIL=$utilReport"
  Write-Host "TINYSPAN_RESOURCE_TIMING=$timingReport"
  Write-Host "TINYSPAN_RESOURCE_POWER=$powerReport"
  Write-Host "TINYSPAN_RESOURCE_CLB_LUTS=$($resources.clb_luts)"
  Write-Host "TINYSPAN_RESOURCE_CLB_REGISTERS=$($resources.clb_registers)"
  Write-Host "TINYSPAN_RESOURCE_BRAM_TILE=$($resources.block_ram_tile)"
  Write-Host "TINYSPAN_RESOURCE_DSPS=$($resources.dsps)"
  Write-Host "TINYSPAN_TIMING_WNS_NS=$($resources.wns_ns)"
  Write-Host "TINYSPAN_TIMING_WHS_NS=$($resources.whs_ns)"
  Write-Host "TINYSPAN_POWER_TOTAL_W=$($resources.total_on_chip_power_w)"

  python tools\convert_rgb_raw.py to-raw $InputPng $inputRaw --width $ImgW --height $ImgH
  if ($LASTEXITCODE -ne 0) { throw "input PNG to raw conversion failed" }

  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\compare_tinyspan_base_equiv_reference.ps1 `
    -InputPng $InputPng `
    -Plan $QuantPlan `
    -Width $ImgW `
    -Height $ImgH `
    -OutDir $refDir
  $baseCompareExitCode = $LASTEXITCODE
  $baseCompareSummary = Join-Path $refDir "summary.json"
  $pytorchBasePng = Join-Path $refDir "pytorch_base_equiv.png"
  $rtlFixedBasePng = Join-Path $refDir "rtl_base_equiv.png"
  if ($baseCompareExitCode -ne 0) {
    if ((Test-Path $baseCompareSummary) -and (Test-Path $rtlFixedBasePng)) {
      Write-Warning "PyTorch-vs-RTL fixed base diagnostic failed; continuing with RTL fixed software reference for byte-exact board gate. Summary: $baseCompareSummary"
    } else {
      throw "TinySPAN base-equivalent software reference generation failed"
    }
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_idle.ps1 `
    -WaitSeconds 0 `
    -StableIdleSeconds 10 *> $vivadoIdleLog
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado precheck failed; refusing to start JTAG run. See $vivadoIdleLog"
  }
  Write-Host "TINYSPAN_VIVADO_IDLE_LOG=$vivadoIdleLog"

  $tclArgs = @(
    "-log", $jtagLog,
    "-journal", $jtagJournal,
    "-mode", "batch",
    "-source", "scripts\jtag_rgb_transfer.tcl",
    "-tclargs",
    "--input", $inputRaw,
    "--output", $outputRaw,
    "--width", [string]$ImgW,
    "--height", [string]$ImgH,
    "--scale", "4"
  )
  if (-not $NoProgram) {
    $tclArgs += @("--bitstream", $Bitstream)
  }
  & $VivadoBat @tclArgs
  if ($LASTEXITCODE -ne 0) { throw "JTAG RGB transfer failed with exit code $LASTEXITCODE" }

  $jtagFrameCycles = $null
  $jtagFrameDone = $null
  $jtagE2eCycles = $null
  if (Test-Path $jtagLog) {
    $cycleMatch = Select-String -Path $jtagLog -Pattern "JTAG_FRAME_CYCLES=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $cycleMatch) { $jtagFrameCycles = [int64]$cycleMatch.Matches[0].Groups[1].Value }
    $doneMatch = Select-String -Path $jtagLog -Pattern "JTAG_FRAME_DONE=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $doneMatch) { $jtagFrameDone = [int]$doneMatch.Matches[0].Groups[1].Value }
    $e2eMatch = Select-String -Path $jtagLog -Pattern "JTAG_E2E_CYCLES=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $e2eMatch) { $jtagE2eCycles = [int64]$e2eMatch.Matches[0].Groups[1].Value }
  }
  if ($jtagFrameDone -ne 1) {
    throw "Normal JTAG run did not report FRAME_DONE=1. Inspect $jtagLog."
  }

  $perfArgs = @(
    "-log", $perfLog,
    "-journal", $perfJournal,
    "-mode", "batch",
    "-source", "scripts\jtag_rgb_transfer.tcl",
    "-tclargs",
    "--input", $inputRaw,
    "--output", $perfOutputRaw,
    "--width", [string]$ImgW,
    "--height", [string]$ImgH,
    "--scale", "4",
    "--perf-only"
  )
  & $VivadoBat @perfArgs
  if ($LASTEXITCODE -ne 0) { throw "JTAG perf-only transfer failed with exit code $LASTEXITCODE" }

  $perfFrameCycles = $null
  $perfFrameDone = $null
  $perfE2eCycles = $null
  if (Test-Path $perfLog) {
    $perfCycleMatch = Select-String -Path $perfLog -Pattern "JTAG_FRAME_CYCLES=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $perfCycleMatch) { $perfFrameCycles = [int64]$perfCycleMatch.Matches[0].Groups[1].Value }
    $perfDoneMatch = Select-String -Path $perfLog -Pattern "JTAG_FRAME_DONE=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $perfDoneMatch) { $perfFrameDone = [int]$perfDoneMatch.Matches[0].Groups[1].Value }
    $perfE2eMatch = Select-String -Path $perfLog -Pattern "JTAG_E2E_CYCLES=([0-9]+)" | Select-Object -Last 1
    if ($null -ne $perfE2eMatch) { $perfE2eCycles = [int64]$perfE2eMatch.Matches[0].Groups[1].Value }
  }
  if ($perfFrameDone -ne 1) {
    throw "Perf-only JTAG run did not report FRAME_DONE=1. Inspect $perfLog."
  }
  if ($null -eq $perfFrameCycles -or $perfFrameCycles -le 0) {
    throw "Perf-only JTAG run did not report a positive FRAME_CYCLES value. Inspect $perfLog."
  }

  $effectiveFps = $MeasuredFps
  if ($effectiveFps -lt 0 -and $null -ne $perfFrameCycles -and $perfFrameCycles -gt 0) {
    $effectiveFps = ($PlFreqMhz * 1000000.0) / [double]$perfFrameCycles
  }
  $resources["jtag_log"] = $jtagLog
  $resources["jtag_frame_cycles"] = $jtagFrameCycles
  $resources["jtag_frame_done"] = $jtagFrameDone
  $resources["jtag_e2e_cycles"] = $jtagE2eCycles
  $resources["perf_log"] = $perfLog
  $resources["perf_frame_cycles"] = $perfFrameCycles
  $resources["perf_frame_done"] = $perfFrameDone
  $resources["perf_e2e_cycles"] = $perfE2eCycles
  $resources["measured_fps"] = $effectiveFps
  $resources | ConvertTo-Json -Depth 4 | Set-Content -Path $resourceJson -Encoding UTF8
  Write-Host "TINYSPAN_JTAG_LOG=$jtagLog"
  Write-Host "TINYSPAN_JTAG_FRAME_CYCLES=$jtagFrameCycles"
  Write-Host "TINYSPAN_JTAG_FRAME_DONE=$jtagFrameDone"
  Write-Host "TINYSPAN_JTAG_E2E_CYCLES=$jtagE2eCycles"
  Write-Host "TINYSPAN_PERF_LOG=$perfLog"
  Write-Host "TINYSPAN_PERF_FRAME_CYCLES=$perfFrameCycles"
  Write-Host "TINYSPAN_PERF_FRAME_DONE=$perfFrameDone"
  Write-Host "TINYSPAN_PERF_E2E_CYCLES=$perfE2eCycles"
  Write-Host "TINYSPAN_MEASURED_FPS=$effectiveFps"

  python tools\convert_rgb_raw.py from-raw $outputRaw $outputPng --width $outW --height $outH
  if ($LASTEXITCODE -ne 0) { throw "board raw to PNG conversion failed" }

  $softwarePng = $rtlFixedBasePng
  $fixedPng = $rtlFixedBasePng
  if (-not $SkipAcceptance) {
    if ($effectiveFps -lt 0) {
      throw "MeasuredFps could not be derived from JTAG perf-only log. Pass -MeasuredFps or inspect $perfLog."
    }
    if (($ImgW -eq 320) -and ($ImgH -eq 180)) {
      powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_tinyspan_720p30_board_acceptance.ps1 `
        -InputPng $InputPng `
        -InputRaw $inputRaw `
        -InputWidth $ImgW `
        -InputHeight $ImgH `
        -TileWidth 32 `
        -TileHeight 32 `
        -SoftwarePng $softwarePng `
        -FixedPng $fixedPng `
        -BoardRaw $outputRaw `
        -BoardPng $outputPng `
        -OutputWidth $outW `
        -OutputHeight $outH `
        -OutDir (Join-Path $outDirAbs "acceptance") `
        -MeasuredFps $effectiveFps `
        -Checkpoint $Checkpoint `
        -QuantPlan $QuantPlan `
        -Bitstream $Bitstream `
        -BoardLog $resourceJson `
        -TargetName "TinySPAN W8A8 base-equivalent 720p JTAG"
    } else {
      powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_tinyspan_board_acceptance.ps1 `
        -InputPng $InputPng `
        -InputRaw $inputRaw `
        -InputWidth $ImgW `
        -InputHeight $ImgH `
        -SoftwarePng $softwarePng `
        -FixedPng $fixedPng `
        -BoardRaw $outputRaw `
        -BoardPng $outputPng `
        -OutputWidth $outW `
        -OutputHeight $outH `
        -OutDir (Join-Path $outDirAbs "acceptance") `
        -TargetFps 30 `
        -MeasuredFps $effectiveFps `
        -Checkpoint $Checkpoint `
        -QuantPlan $QuantPlan `
        -Bitstream $Bitstream `
        -BoardLog $resourceJson `
        -TargetName "TinySPAN W8A8 base-equivalent JTAG"
    }
  }

  Write-Host "TINYSPAN_JTAG_INPUT_RAW=$inputRaw"
  Write-Host "TINYSPAN_JTAG_OUTPUT_RAW=$outputRaw"
  Write-Host "TINYSPAN_JTAG_OUTPUT_PNG=$outputPng"
  Write-Host "TINYSPAN_JTAG_SOFTWARE_PNG=$softwarePng"
  Write-Host "TINYSPAN_JTAG_FIXED_PNG=$fixedPng"
  Write-Host "TINYSPAN_JTAG_PYTORCH_VISUAL_PNG=$pytorchBasePng"
  Write-Host "TINYSPAN_JTAG_BITSTREAM=$Bitstream"
} finally {
  if ($null -ne $outDirAbs) {
    if ([string]::IsNullOrWhiteSpace($vivadoCleanupLog)) {
      $vivadoCleanupLog = Join-Path $outDirAbs "vivado_cleanup.log"
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\cleanup_vivado_processes.ps1 *> $vivadoCleanupLog
    $cleanupExit = $LASTEXITCODE
    Write-Host "TINYSPAN_VIVADO_CLEANUP_LOG=$vivadoCleanupLog"
    if ($cleanupExit -ne 0) {
      throw "Vivado cleanup failed with exit code $cleanupExit. See $vivadoCleanupLog"
    }
  }
  Pop-Location
}
