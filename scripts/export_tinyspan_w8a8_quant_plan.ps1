param(
    [string]$Manifest = "rtl\generated\tinyspan_x4_c24_b4_fused_handoff_smoke\tinyspan_manifest.json",
    [string]$ActivationScales = "runs\tinyspan_manifest_reference\activation_scales_reds4_32x32.json",
    [string]$OutDir = "runs\tinyspan_quant_plan\latest",
    [int]$ActivationBits = 8,
    [int]$WeightBits = 8
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

python tools\export_tinyspan_w8a8_quant_plan.py `
    --manifest $Manifest `
    --activation-scales $ActivationScales `
    --out-dir $OutDir `
    --activation-bits $ActivationBits `
    --weight-bits $WeightBits
