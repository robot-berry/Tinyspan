param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$ProjectDir = "",
  [int]$ImgW = 320,
  [int]$ImgH = 180,
  [int]$TileW = 32,
  [int]$TileH = 32,
  [ValidateSet(2, 4)]
  [int]$Scale = 4,
  [int]$PlFreqMhz = 150,
  [string]$InputBase = "0x10000000",
  [string]$OutputBase = "0x11000000",
  [int]$MDataWidth = 32,
  [int]$MaxThreads = 1,
  [string]$SynthDirective = "RuntimeOptimized",
  [string]$PlaceDirective = "Default",
  [string]$PhysOptDirective = "Default",
  [string]$RouteDirective = "Default",
  [string]$PostRoutePhysOptDirective = "Default",
  [switch]$UseSerialBase,
  [switch]$RequireVivadoIdle,
  [int]$WaitForVivadoIdleSeconds = 0,
  [int]$StableVivadoIdleSeconds = 0
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
if ((Split-Path $scriptDir -Leaf) -ieq "vivado") {
  $root = Resolve-Path (Join-Path $scriptDir "..\..")
} else {
  $root = Resolve-Path (Join-Path $scriptDir "..")
}

Push-Location $root
try {
  if (-not (Test-Path $VivadoBat)) {
    throw "Vivado batch executable not found: $VivadoBat"
  }
  if ($RequireVivadoIdle -or $WaitForVivadoIdleSeconds -gt 0) {
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check_vivado_idle.ps1 `
      -WaitSeconds $WaitForVivadoIdleSeconds `
      -StableIdleSeconds $StableVivadoIdleSeconds
    if ($LASTEXITCODE -ne 0) {
      throw "Vivado idle preflight failed with exit code $LASTEXITCODE"
    }
  }

  if ($ProjectDir -ne "") {
    $env:PS_TINYSPAN_DDR_X4_PROJECT_DIR = $ProjectDir
  }
  $env:PS_TINYSPAN_DDR_X4_IMG_W = "$ImgW"
  $env:PS_TINYSPAN_DDR_X4_IMG_H = "$ImgH"
  $env:PS_TINYSPAN_DDR_X4_TILE_W = "$TileW"
  $env:PS_TINYSPAN_DDR_X4_TILE_H = "$TileH"
  $env:PS_TINYSPAN_DDR_X4_SCALE = "$Scale"
  $env:PS_TINYSPAN_DDR_X4_PL_FREQ_MHZ = "$PlFreqMhz"
  $env:PS_TINYSPAN_DDR_X4_INPUT_BASE = "$InputBase"
  $env:PS_TINYSPAN_DDR_X4_OUTPUT_BASE = "$OutputBase"
  $env:PS_TINYSPAN_DDR_X4_M_AXI_DATA_W = "$MDataWidth"
  $env:PS_TINYSPAN_DDR_X4_USE_SERIAL_BASE = if ($UseSerialBase) { "1" } else { "0" }
  $env:PS_TINYSPAN_DDR_X4_MAX_THREADS = "$MaxThreads"
  $env:PS_TINYSPAN_DDR_X4_SYNTH_DIRECTIVE = "$SynthDirective"
  $env:PS_TINYSPAN_DDR_X4_PLACE_DIRECTIVE = "$PlaceDirective"
  $env:PS_TINYSPAN_DDR_X4_PHYS_OPT_DIRECTIVE = "$PhysOptDirective"
  $env:PS_TINYSPAN_DDR_X4_ROUTE_DIRECTIVE = "$RouteDirective"
  $env:PS_TINYSPAN_DDR_X4_POST_ROUTE_PHYS_OPT_DIRECTIVE = "$PostRoutePhysOptDirective"

  $buildDir = Join-Path $root "build"
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  $logPath = Join-Path $buildDir "ps_tinyspan_ddr_x4_bitstream_vivado.log"
  $tcl = Join-Path $scriptDir "run_vivado_bitstream_ps_tinyspan_ddr_x4.tcl"
  $runStarted = Get-Date
  & $VivadoBat -mode batch -source $tcl -log $logPath
  $vivadoExitCode = $LASTEXITCODE

  if (-not (Test-Path $logPath)) {
    throw "Vivado log not found: $logPath"
  }
  if ((Get-Item $logPath).LastWriteTime -lt $runStarted) {
    throw "Vivado log is stale: $logPath"
  }
  $logText = Get-Content -Raw -Path $logPath
  if ($logText -notmatch "PASS run_vivado_bitstream_ps_tinyspan_ddr_x4" -or
      $logText -match "(?m)(ERROR:|Fatal:)") {
    throw "TinySPAN PS/DDR bitstream run did not pass; see $logPath"
  }
  if ($vivadoExitCode -ne 0) {
    Write-Warning "Vivado returned exit code $vivadoExitCode, but the fresh log contains the expected PASS marker."
  }

  Write-Host "BITSTREAM_LOG=$logPath"
  Write-Host "PASS run_vivado_bitstream_ps_tinyspan_ddr_x4"
} finally {
  Pop-Location
}
