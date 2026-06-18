param(
  [int]$ImgW = 32,
  [int]$ImgH = 0,
  [ValidateRange(1, 300)]
  [int]$PlFreqMhz = 100,
  [switch]$Fast,
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [int]$MinAvailablePageFileMb = 0,
  [switch]$RequireVivadoIdle,
  [int]$WaitForVivadoIdleSeconds = 0,
  [int]$StableVivadoIdleSeconds = 10,
  [ValidateRange(1, 16)]
  [int]$VivadoMaxThreads = 1,
  [string]$CleanLogDir = "board_runs\tinyspan_vivado_clean\bitstream_jtag_base_equiv"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($ImgH -le 0) {
  $ImgH = $ImgW
}
Push-Location $root
try {
  $cleanLogDirAbs = if ([System.IO.Path]::IsPathRooted($CleanLogDir)) {
    $CleanLogDir
  } else {
    Join-Path $root $CleanLogDir
  }
  New-Item -ItemType Directory -Force -Path $cleanLogDirAbs | Out-Null
  $vivadoIdleLog = Join-Path $cleanLogDirAbs "vivado_idle_precheck.log"
  $vivadoCleanupLog = Join-Path $cleanLogDirAbs "vivado_cleanup.log"

  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_idle.ps1 `
    -WaitSeconds $WaitForVivadoIdleSeconds `
    -StableIdleSeconds $StableVivadoIdleSeconds *> $vivadoIdleLog
  if ($LASTEXITCODE -ne 0) {
    throw "Vivado precheck failed; refusing to start bitstream build. See $vivadoIdleLog"
  }
  Write-Host "TINYSPAN_BITSTREAM_VIVADO_IDLE_LOG=$vivadoIdleLog"

  $args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", "scripts\run_vivado_bitstream_jtag_full_span_scale.ps1",
    "-Scale", "4",
    "-ImgW", [string]$ImgW,
    "-ImgH", [string]$ImgH,
    "-PlFreqMhz", [string]$PlFreqMhz,
    "-VivadoBat", $VivadoBat,
    "-UseTinyspanW8A8BaseEquiv",
    "-RequireVivadoIdle",
    "-VivadoMaxThreads", [string]$VivadoMaxThreads
  )
  if ($Fast) {
    $args += @("-UseTinyspanW8A8BaseEquivFast")
  }
  if ($MinAvailablePageFileMb -gt 0) {
    $args += @("-MinAvailablePageFileMb", [string]$MinAvailablePageFileMb)
  }
  if ($WaitForVivadoIdleSeconds -gt 0) {
    $args += @("-WaitForVivadoIdleSeconds", [string]$WaitForVivadoIdleSeconds)
  }
  if ($StableVivadoIdleSeconds -gt 0) {
    $args += @("-StableVivadoIdleSeconds", [string]$StableVivadoIdleSeconds)
  }
  powershell @args
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN W8A8 base-equivalent JTAG bitstream build failed with exit code $LASTEXITCODE"
  }

  $freqTag = if ($PlFreqMhz -eq 25) { "" } else { "_f${PlFreqMhz}m" }
  $imgTag = "{0}x{1}" -f $ImgW, $ImgH
  $coreTag = if ($Fast) { "tinyspan_w8a8_base_equiv_fast" } else { "tinyspan_w8a8_base_equiv" }
  $bit = Join-Path $root ("vivado\bitstreams\jfs_full_span_x4_{0}{1}_{2}.bit" -f $imgTag, $freqTag, $coreTag)
  $util = Join-Path $root ("vivado\reports\jtag_full_span_x4_{0}{1}_{2}_utilization_impl.rpt" -f $imgTag, $freqTag, $coreTag)
  $timing = Join-Path $root ("vivado\reports\jtag_full_span_x4_{0}{1}_{2}_timing_impl.rpt" -f $imgTag, $freqTag, $coreTag)
  Write-Host "TINYSPAN_W8A8_BASE_EQUIV_BIT=$bit"
  Write-Host "TINYSPAN_W8A8_BASE_EQUIV_UTIL=$util"
  Write-Host "TINYSPAN_W8A8_BASE_EQUIV_TIMING=$timing"
} finally {
  if ($null -ne $cleanLogDirAbs) {
    if ([string]::IsNullOrWhiteSpace($vivadoCleanupLog)) {
      $vivadoCleanupLog = Join-Path $cleanLogDirAbs "vivado_cleanup.log"
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\cleanup_vivado_processes.ps1 *> $vivadoCleanupLog
    $cleanupExit = $LASTEXITCODE
    Write-Host "TINYSPAN_BITSTREAM_VIVADO_CLEANUP_LOG=$vivadoCleanupLog"
    if ($cleanupExit -ne 0) {
      throw "Vivado cleanup failed with exit code $cleanupExit. See $vivadoCleanupLog"
    }
  }
  Pop-Location
}
