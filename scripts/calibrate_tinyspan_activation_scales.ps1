param(
    [string]$Manifest = "rtl\generated\tinyspan_x4_c24_b4_fused_handoff_smoke\tinyspan_manifest.json",
    [string]$Checkpoint = "",
    [Alias("Input")]
    [string]$InputPath = "G:\REDS\train_sharp",
    [int]$Width = 32,
    [int]$Height = 32,
    [string]$Out = "runs\tinyspan_manifest_reference\activation_scales_latest.json",
    [ValidateSet("auto", "cuda", "cpu")]
    [string]$Device = "auto",
    [int]$MaxImages = 8,
    [int]$ActivationBits = 8
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$argsList = @(
    "tools\calibrate_tinyspan_activation_scales.py",
    "--manifest", $Manifest,
    "--input", $InputPath,
    "--width", $Width,
    "--height", $Height,
    "--out", $Out,
    "--device", $Device,
    "--max-images", $MaxImages,
    "--activation-bits", $ActivationBits
)

if ($Checkpoint -ne "") {
    $argsList += @("--checkpoint", $Checkpoint)
}

python @argsList
