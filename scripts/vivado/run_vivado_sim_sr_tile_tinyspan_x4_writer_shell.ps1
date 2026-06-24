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

  $projDir = Join-Path $root "build\ttx4_sim"
  $simLog = Join-Path $projDir "ttx4_sim.sim\sim_1\behav\xsim\simulate.log"
  $tcl = Join-Path $scriptDir "run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.tcl"
  $runStarted = Get-Date
  & $VivadoBat -mode batch -source $tcl
  $vivadoExitCode = $LASTEXITCODE

  if (-not (Test-Path $simLog)) {
    throw "simulate.log not found: $simLog"
  }
  if ((Get-Item $simLog).LastWriteTime -lt $runStarted) {
    throw "simulate.log is stale: $simLog"
  }
  $simText = Get-Content -Raw -Path $simLog
  if ($simText -notmatch "PASS sr_tile_tinyspan_x4_writer_shell" -or
      $simText -match "(?m)(Fatal:|ERROR:|MISMATCH)") {
    throw "sr_tile_tinyspan_x4_writer_shell simulation did not pass; see $simLog"
  }
  if ($vivadoExitCode -ne 0) {
    Write-Warning "Vivado returned exit code $vivadoExitCode, but the fresh simulation log contains the expected PASS marker."
  }
  Write-Host "SIM_LOG=$simLog"
  Write-Host "PASS run_vivado_sim_sr_tile_tinyspan_x4_writer_shell"
} finally {
  Pop-Location
}
