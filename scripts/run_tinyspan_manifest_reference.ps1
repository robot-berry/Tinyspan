param(
    [string]$Manifest = "rtl\generated\tinyspan_x4_c24_b4_fused_handoff_smoke\tinyspan_manifest.json",
    [string]$Checkpoint = "",
    [Alias("Input")]
    [string]$InputPath = "external\SPAN\test_scripts\data\baboon.png",
    [int]$Width = 32,
    [int]$Height = 32,
    [string]$OutDir = "runs\tinyspan_manifest_reference\latest",
    [ValidateSet("auto", "cuda", "cpu")]
    [string]$Device = "auto",
    [ValidateSet("weight-ref", "weight-activation")]
    [string]$Mode = "weight-ref",
    [string]$ActivationScales = "",
    [int]$ActivationBits = 8,
    [int]$Tile = 160
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$argsList = @(
    "tools\model_to_hardware\run_tinyspan_manifest_reference.py",
    "--manifest", $Manifest,
    "--input", $InputPath,
    "--width", $Width,
    "--height", $Height,
    "--out-dir", $OutDir,
    "--device", $Device,
    "--mode", $Mode,
    "--activation-bits", $ActivationBits,
    "--tile", $Tile
)

if ($Checkpoint -ne "") {
    $argsList += @("--checkpoint", $Checkpoint)
}
if ($ActivationScales -ne "") {
    $argsList += @("--activation-scales", $ActivationScales)
}

python @argsList
