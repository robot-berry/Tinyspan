param(
  [Parameter(Mandatory = $true)]
  [string]$Top,
  [string]$Tag = "",
  [double]$ClockMhz = 100.0,
  [int]$ImgW = 4,
  [int]$ImgH = 4,
  [int]$OutLanes = 8,
  [int]$TapLanes = 16,
  [int]$UseSerialBase = -1,
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
if ($Tag -eq "") {
  $Tag = $Top
}
$periodNs = 1000.0 / $ClockMhz

Push-Location $root
try {
  if (-not (Test-Path $VivadoBat)) {
    throw "Vivado batch executable not found: $VivadoBat"
  }
  $env:TINYSPAN_BLOCK0_PARTITION_TOP = $Top
  $env:TINYSPAN_BLOCK0_PARTITION_TAG = $Tag
  $env:TINYSPAN_BLOCK0_PARTITION_CLOCK_PERIOD_NS = ("{0:F3}" -f $periodNs)
  $env:TINYSPAN_BLOCK0_PARTITION_IMG_W = [string]$ImgW
  $env:TINYSPAN_BLOCK0_PARTITION_IMG_H = [string]$ImgH
  $env:TINYSPAN_BLOCK0_PARTITION_OUT_LANES = [string]$OutLanes
  $env:TINYSPAN_BLOCK0_PARTITION_TAP_LANES = [string]$TapLanes
  if ($UseSerialBase -ge 0) {
    $env:TINYSPAN_BLOCK0_PARTITION_USE_SERIAL_BASE = [string]$UseSerialBase
  }
  & $VivadoBat -mode batch -source scripts\run_vivado_synth_tinyspan_w8a8_block0_partition.tcl
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN W8A8 block0 partition synthesis failed with exit code $LASTEXITCODE"
  }
  Write-Host "PASS run_vivado_synth_tinyspan_w8a8_block0_partition"
  Write-Host "REPORT=build\vivado_tinyspan_w8a8_${Tag}_synth\${Tag}_utilization.rpt"
} finally {
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_TOP -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_TAG -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_CLOCK_PERIOD_NS -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_IMG_W -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_IMG_H -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_OUT_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_TAP_LANES -ErrorAction SilentlyContinue
  Remove-Item Env:\TINYSPAN_BLOCK0_PARTITION_USE_SERIAL_BASE -ErrorAction SilentlyContinue
  Pop-Location
}
