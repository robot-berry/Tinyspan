param(
    [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
    [switch]$RequireVivadoIdle,
    [int]$StableVivadoIdleSeconds = 10,
    [int]$MaxAttempts = 2
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

    if ($RequireVivadoIdle) {
        $idleScript = Join-Path $root "scripts\check_vivado_idle.ps1"
        if (Test-Path $idleScript) {
            powershell -NoProfile -ExecutionPolicy Bypass -File $idleScript -StableIdleSeconds $StableVivadoIdleSeconds
            if ($LASTEXITCODE -ne 0) {
                throw "Vivado idle preflight failed with exit code $LASTEXITCODE"
            }
        } else {
            $vivado = @(Get-Process vivado,vivado_lab,parallel_synth_helper,rdi_xsdb,hw_server,cs_server,xelab,xsim,xvlog,xvhdl -ErrorAction SilentlyContinue)
            if ($vivado.Count -ne 0) {
                throw "Vivado is not idle; refusing to start TinySPAN fast-base simulation"
            }
            if ($StableVivadoIdleSeconds -gt 0) {
                Start-Sleep -Seconds $StableVivadoIdleSeconds
            }
        }
    }

    $env:TINYSPAN_FAST_BASE_PROJ = "vivado_tinyspan_w8a8_fast_base_equiv_sim"
    $env:TINYSPAN_FAST_BASE_TOP = "tb_span_tinyspan_w8a8_bicubic_base_x4_fast_vs_serial"
    $projDir = Join-Path $root "build\$($env:TINYSPAN_FAST_BASE_PROJ)"
    $simLog = Join-Path $projDir "$($env:TINYSPAN_FAST_BASE_PROJ).sim\sim_1\behav\xsim\simulate.log"
    $passMarker = "PASS tinyspan_w8a8_fast_base_equiv"
    $tcl = Join-Path $scriptDir "run_vivado_sim_tinyspan_w8a8_fast_base_equiv.tcl"
    $passedAttempt = $false
    $lastError = ""

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Warning "Retrying TinySPAN fast-base simulation, attempt $attempt of $MaxAttempts"
        }
        try {
            if ((Test-Path $projDir) -and ((Resolve-Path $projDir).Path.StartsWith((Join-Path $root "build")))) {
                Remove-Item -LiteralPath $projDir -Recurse -Force
            }
            $runStarted = Get-Date
            & $VivadoBat -mode batch -source $tcl
            $vivadoExitCode = $LASTEXITCODE

            if (-not (Test-Path $simLog)) {
                throw "simulation log not found; Vivado exit code $vivadoExitCode. Expected: $simLog"
            }
            $simLogItem = Get-Item $simLog
            if ($simLogItem.LastWriteTime -lt $runStarted) {
                throw "simulation log is stale; Vivado exit code $vivadoExitCode. Log: $simLog"
            }
            $simText = Get-Content -Raw -Path $simLog
            if ($simText -notmatch [regex]::Escape($passMarker)) {
                throw "expected PASS marker missing; Vivado exit code $vivadoExitCode. See $simLog"
            }
            if ($simText -match "(?m)(Fatal:|MISMATCH|ERROR:)") {
                throw "simulation log contains failure text; Vivado exit code $vivadoExitCode. See $simLog"
            }
            if ($vivadoExitCode -ne 0) {
                Write-Warning "Vivado returned exit code $vivadoExitCode, but the fresh simulation log contains the expected PASS marker and no failure text."
            }
            $passedAttempt = $true
            break
        } catch {
            $lastError = $_.Exception.Message
            Write-Warning "Attempt $attempt failed: $lastError"
        }
    }

    if (-not $passedAttempt) {
        throw "TinySPAN fast-base simulation failed after $MaxAttempts attempts. Last error: $lastError"
    }

    Write-Host "SIM_LOG=$simLog"
    Write-Host "PASS run_vivado_sim_tinyspan_w8a8_fast_base_equiv"
} finally {
    Remove-Item Env:\TINYSPAN_FAST_BASE_PROJ -ErrorAction SilentlyContinue
    Remove-Item Env:\TINYSPAN_FAST_BASE_TOP -ErrorAction SilentlyContinue
    Pop-Location
}
