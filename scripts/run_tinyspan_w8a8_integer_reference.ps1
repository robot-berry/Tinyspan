param(
    [string]$QuantPlan = "runs\tinyspan_quant_plan\video_smoke_x4_c24_b4_reds4_w8a8\tinyspan_w8a8_quant_plan.json",
    [Alias("Input")]
    [string]$InputPath = "G:\REDS\train_sharp\000\00000000.png",
    [int]$Width = 32,
    [int]$Height = 32,
    [string]$OutDir = "runs\tinyspan_integer_reference\latest",
    [string]$Checkpoint = "",
    [ValidateSet("auto", "cuda", "cpu")]
    [string]$Device = "auto",
    [int]$Tile = 160
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$argsList = @(
    "tools\model_to_hardware\run_tinyspan_w8a8_integer_reference.py",
    "--quant-plan", $QuantPlan,
    "--input", $InputPath,
    "--width", $Width,
    "--height", $Height,
    "--out-dir", $OutDir,
    "--device", $Device,
    "--tile", $Tile
)

if ($Checkpoint -ne "") {
    $argsList += @("--checkpoint", $Checkpoint)
}

python @argsList
$exitCode = $LASTEXITCODE
exit $exitCode
