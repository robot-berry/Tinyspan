param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [int]$WaitForVivadoIdleSeconds = 0,
  [int]$StableVivadoIdleSeconds = 10
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
  $cropperScript = Join-Path $scriptDir "run_vivado_sim_sr_stream_dynamic_cropper.ps1"
  $writerScript = Join-Path $scriptDir "run_vivado_sim_sr_tile_tinyspan_x4_writer_shell.ps1"
  foreach ($script in @($cropperScript, $writerScript)) {
    if (-not (Test-Path $script)) {
      throw "required simulation script not found: $script"
    }
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File $cropperScript `
    -VivadoBat $VivadoBat `
    -RequireVivadoIdle `
    -WaitForVivadoIdleSeconds $WaitForVivadoIdleSeconds `
    -StableVivadoIdleSeconds $StableVivadoIdleSeconds
  if ($LASTEXITCODE -ne 0) {
    throw "dynamic cropper simulation failed with exit code $LASTEXITCODE"
  }

  powershell -NoProfile -ExecutionPolicy Bypass -File $writerScript `
    -VivadoBat $VivadoBat `
    -RequireVivadoIdle `
    -WaitForVivadoIdleSeconds 0 `
    -StableVivadoIdleSeconds $StableVivadoIdleSeconds
  if ($LASTEXITCODE -ne 0) {
    throw "TinySPAN full-frame tile writer simulation failed with exit code $LASTEXITCODE"
  }

  Write-Host "PASS run_tinyspan_full_frame_tiling_sims"
} finally {
  Pop-Location
}
