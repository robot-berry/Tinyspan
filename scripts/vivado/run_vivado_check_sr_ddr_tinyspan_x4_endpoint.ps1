param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
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

  $buildDir = Join-Path $root "build"
  New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
  $logPath = Join-Path $buildDir "ddr_ttx4_elab_vivado.log"
  $tcl = Join-Path $scriptDir "run_vivado_check_sr_ddr_tinyspan_x4_endpoint.tcl"
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
  if ($logText -notmatch "PASS sr_ddr_tinyspan_x4_tile_writer_endpoint rtl_elaboration" -or
      $logText -match "(?m)(ERROR:|Fatal:)") {
    throw "TinySPAN DDR endpoint RTL elaboration did not pass; see $logPath"
  }
  if ($vivadoExitCode -ne 0) {
    Write-Warning "Vivado returned exit code $vivadoExitCode, but the fresh log contains the expected PASS marker."
  }
  Write-Host "ELAB_LOG=$logPath"
  Write-Host "PASS run_vivado_check_sr_ddr_tinyspan_x4_endpoint"
} finally {
  Pop-Location
}
