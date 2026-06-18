param(
    [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
    [string]$QuantPlan = "runs\tinyspan_quant_plan\video_smoke_x4_c24_b4_baboon_w8a8\tinyspan_w8a8_quant_plan.json",
    [string]$VectorJson = "runs\tinyspan_quant_plan\tinyspan_w8a8_conv_vectors.json",
    [string]$GeneratedTbDir = "build\generated_tinyspan_w8a8_conv_vector_tbs",
    [string[]]$Layers = @("head"),
    [int]$MaxAttempts = 3
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
    if (-not (Test-Path $VivadoBat)) {
        throw "Vivado batch executable not found: $VivadoBat"
    }

    python tools\generate_tinyspan_w8a8_conv_vector_tb.py `
        --quant-plan $QuantPlan `
        --vectors $VectorJson `
        --out-dir $GeneratedTbDir `
        --layers $Layers
    if ($LASTEXITCODE -ne 0) {
        throw "generate_tinyspan_w8a8_conv_vector_tb.py failed with exit code $LASTEXITCODE"
    }

    foreach ($name in $Layers) {
        $safe = $name -replace "\.", "_"
        $top = "tb_tinyspan_w8a8_${safe}_vector"
        $tb = Join-Path $GeneratedTbDir "$top.sv"
        if (-not (Test-Path $tb)) {
            throw "Generated testbench not found: $tb"
        }

        $env:W8A12_VECTOR_TOP = $top
        $env:W8A12_VECTOR_TB = (Resolve-Path $tb).Path
        $env:W8A12_VECTOR_PROJ = "vivado_tinyspan_w8a8_${safe}_vector_sim"
        $projDir = Join-Path $root "build\$($env:W8A12_VECTOR_PROJ)"
        $simLog = Join-Path $root "build\$($env:W8A12_VECTOR_PROJ)\$($env:W8A12_VECTOR_PROJ).sim\sim_1\behav\xsim\simulate.log"
        $passMarker = "PASS tinyspan_w8a8_${safe}_vector"
        $passedAttempt = $false
        $lastError = ""
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            if ($attempt -gt 1) {
                Write-Warning "Retrying $top simulation, attempt $attempt of $MaxAttempts"
            }
            try {
                if ((Test-Path $projDir) -and ((Resolve-Path $projDir).Path.StartsWith((Join-Path $root "build")))) {
                    Remove-Item -LiteralPath $projDir -Recurse -Force
                }
                $runStarted = Get-Date
                & $VivadoBat -mode batch -source scripts\run_vivado_sim_w8a12_conv_vector.tcl
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
                    Write-Warning "Vivado returned exit code $vivadoExitCode for $top, but the fresh simulation log contains the expected PASS marker and no failure text."
                }
                $passedAttempt = $true
                break
            } catch {
                $lastError = $_.Exception.Message
                Write-Warning "Attempt $attempt for $top failed: $lastError"
            }
        }
        if (-not $passedAttempt) {
            throw "Vivado TinySPAN W8A8 vector simulation failed for $top after $MaxAttempts attempts. Last error: $lastError"
        }
        Write-Host "PASS $top"
    }

    Remove-Item Env:\W8A12_VECTOR_TOP -ErrorAction SilentlyContinue
    Remove-Item Env:\W8A12_VECTOR_TB -ErrorAction SilentlyContinue
    Remove-Item Env:\W8A12_VECTOR_PROJ -ErrorAction SilentlyContinue

    Write-Host "PASS run_vivado_sim_tinyspan_w8a8_conv_vectors"
} finally {
    Pop-Location
}
