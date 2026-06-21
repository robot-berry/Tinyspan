param(
  [Parameter(Mandatory = $true)]
  [string]$Checkpoint,
  [string]$Tag = "latest",
  [string]$PreviewInput = "external\SPAN\test_scripts\data\baboon.png",
  [string]$CalibrationInput = "G:\REDS\train_sharp",
  [int]$Width = 32,
  [int]$Height = 32,
  [int]$CalibrationImages = 4,
  [ValidateSet("auto", "cuda", "cpu")]
  [string]$Device = "auto",
  [int]$Tile = 160,
  [int]$MaxManifestMismatchBytes = 0,
  [int]$MaxManifestChannelDiff = 0,
  [double]$MinIntegerPsnrDb = 45.0,
  [int]$MaxIntegerChannelDiff = 4
)

$ErrorActionPreference = "Stop"

function Convert-ToDoubleOrInfinity {
  param(
    $Value
  )
  if ($null -eq $Value) {
    throw "Missing numeric value"
  }
  $text = "$Value"
  if ($text -eq ([string][char]0x221E) -or $text -eq "Infinity") {
    return [double]::PositiveInfinity
  }
  return [double]$Value
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if (-not (Test-Path $Checkpoint)) {
    throw "Checkpoint not found: $Checkpoint"
  }
  if (-not (Test-Path $PreviewInput)) {
    throw "PreviewInput not found: $PreviewInput"
  }
  if (-not (Test-Path $CalibrationInput)) {
    throw "CalibrationInput not found: $CalibrationInput"
  }
  if ($Width -lt 1 -or $Height -lt 1) {
    throw "Width and Height must be positive"
  }
  if ($CalibrationImages -lt 1) {
    throw "CalibrationImages must be positive"
  }

  $safeTag = $Tag -replace '[^A-Za-z0-9_.-]', '_'
  $fusionDir = "runs\tinyspan_fusion\${safeTag}_x4_c32_b4"
  $handoffDir = "rtl\generated\tinyspan_x4_c32_b4_${safeTag}_fused"
  $manifestRefDir = "runs\tinyspan_manifest_reference\${safeTag}_x4_c32_b4_${Width}x${Height}"
  $calibDir = "runs\tinyspan_calibration\${safeTag}_x4_c32_b4_reds${CalibrationImages}_${Width}x${Height}"
  $quantDir = "runs\tinyspan_quant_plan\${safeTag}_x4_c32_b4_w8a8"
  $integerDir = "runs\tinyspan_integer_reference\${safeTag}_x4_c32_b4_${Width}x${Height}_w8a8"
  $summaryDir = "runs\tinyspan_realtime_handoff"
  New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null

  Write-Host "C32B4_TAG=$safeTag"
  Write-Host "C32B4_CHECKPOINT=$Checkpoint"

  python tools\fuse_tinyspan_conv3xc.py `
    --checkpoint $Checkpoint `
    --scale 4 `
    --channels 32 `
    --num-blocks 4 `
    --width $Width `
    --height $Height `
    --device $Device `
    --out-dir $fusionDir
  if ($LASTEXITCODE -ne 0) {
    throw "fuse_tinyspan_conv3xc.py failed with exit code $LASTEXITCODE"
  }
  $fusedCheckpoint = Join-Path $fusionDir "student_fused_conv3xc.pt"
  $fusionReport = Join-Path $fusionDir "fusion_check.md"

  powershell -ExecutionPolicy Bypass -File scripts\prepare_tinyspan_hardware_handoff.ps1 `
    -Checkpoint $Checkpoint `
    -Scale 4 `
    -Channels 32 `
    -Blocks 4 `
    -OutputDir $handoffDir `
    -FuseConv3XC
  if ($LASTEXITCODE -ne 0) {
    throw "prepare_tinyspan_hardware_handoff.ps1 failed with exit code $LASTEXITCODE"
  }
  $manifest = Join-Path $handoffDir "tinyspan_manifest.json"

  python tools\run_tinyspan_manifest_reference.py `
    --manifest $manifest `
    --checkpoint $Checkpoint `
    --input $PreviewInput `
    --width $Width `
    --height $Height `
    --out-dir $manifestRefDir `
    --device $Device `
    --mode weight-ref `
    --tile $Tile
  if ($LASTEXITCODE -ne 0) {
    throw "run_tinyspan_manifest_reference.py failed with exit code $LASTEXITCODE"
  }
  $manifestRefSummary = Join-Path $manifestRefDir "tinyspan_manifest_reference_summary.md"
  $manifestRefPreview = Join-Path $manifestRefDir "tinyspan_manifest_reference_preview.png"
  $manifestRefSummaryJson = Join-Path $manifestRefDir "tinyspan_manifest_reference_summary.json"

  $activationScales = Join-Path $calibDir "activation_scales.json"
  python tools\calibrate_tinyspan_activation_scales.py `
    --manifest $manifest `
    --checkpoint $Checkpoint `
    --input $CalibrationInput `
    --width $Width `
    --height $Height `
    --out $activationScales `
    --device $Device `
    --max-images $CalibrationImages `
    --activation-bits 8
  if ($LASTEXITCODE -ne 0) {
    throw "calibrate_tinyspan_activation_scales.py failed with exit code $LASTEXITCODE"
  }

  powershell -ExecutionPolicy Bypass -File scripts\export_tinyspan_w8a8_quant_plan.ps1 `
    -Manifest $manifest `
    -ActivationScales $activationScales `
    -OutDir $quantDir `
    -ActivationBits 8 `
    -WeightBits 8
  if ($LASTEXITCODE -ne 0) {
    throw "export_tinyspan_w8a8_quant_plan.ps1 failed with exit code $LASTEXITCODE"
  }
  $quantPlan = Join-Path $quantDir "tinyspan_w8a8_quant_plan.json"

  python tools\check_tinyspan_w8a8_quant_plan.py --quant-plan $quantPlan
  if ($LASTEXITCODE -ne 0) {
    throw "check_tinyspan_w8a8_quant_plan.py failed with exit code $LASTEXITCODE"
  }

  powershell -ExecutionPolicy Bypass -File scripts\run_tinyspan_w8a8_integer_reference.ps1 `
    -QuantPlan $quantPlan `
    -InputPath $PreviewInput `
    -Width $Width `
    -Height $Height `
    -OutDir $integerDir `
    -Checkpoint $Checkpoint `
    -Device $Device `
    -Tile $Tile
  if ($LASTEXITCODE -ne 0) {
    throw "run_tinyspan_w8a8_integer_reference.ps1 failed with exit code $LASTEXITCODE"
  }
  $integerSummary = Join-Path $integerDir "tinyspan_w8a8_integer_reference_summary.md"
  $integerPreview = Join-Path $integerDir "tinyspan_w8a8_integer_reference_preview.png"
  $integerSummaryJson = Join-Path $integerDir "tinyspan_w8a8_integer_reference_summary.json"

  foreach ($path in @($fusedCheckpoint, $fusionReport, $manifest, $manifestRefSummary, $manifestRefPreview, $manifestRefSummaryJson, $activationScales, $quantPlan, $integerSummary, $integerPreview, $integerSummaryJson)) {
    if (-not (Test-Path $path)) {
      throw "Expected artifact not found: $path"
    }
  }

  $manifestRefData = Get-Content -Raw $manifestRefSummaryJson | ConvertFrom-Json
  $manifestMetrics = $manifestRefData.metrics.image_pytorch_vs_manifest
  $integerRefData = Get-Content -Raw $integerSummaryJson | ConvertFrom-Json
  $integerMetrics = $integerRefData.metrics.pytorch_vs_integer

  $manifestMismatchBytes = [int]$manifestMetrics.mismatch_bytes
  $manifestMaxChannelDiff = [int]$manifestMetrics.max_channel_diff
  $manifestPsnrDb = Convert-ToDoubleOrInfinity $manifestMetrics.psnr_db
  $integerMismatchBytes = [int]$integerMetrics.mismatch_bytes
  $integerMaxChannelDiff = [int]$integerMetrics.max_channel_diff
  $integerPsnrDb = Convert-ToDoubleOrInfinity $integerMetrics.psnr_db

  $gates = [ordered]@{
    manifest_matches_software = ($manifestMismatchBytes -le $MaxManifestMismatchBytes) -and ($manifestMaxChannelDiff -le $MaxManifestChannelDiff)
    integer_psnr_ok = $integerPsnrDb -ge $MinIntegerPsnrDb
    integer_channel_diff_ok = $integerMaxChannelDiff -le $MaxIntegerChannelDiff
  }
  $passed = ($gates.Values | Where-Object { -not $_ } | Measure-Object).Count -eq 0

  $summaryJson = Join-Path $summaryDir ("c32b4_${safeTag}_summary.json")
  $summaryMd = Join-Path $summaryDir ("c32b4_${safeTag}_summary.md")
  $summary = [ordered]@{
    passed = $passed
    tag = $safeTag
    checkpoint = $Checkpoint
    branch = (git branch --show-current)
    width = $Width
    height = $Height
    preview_input = $PreviewInput
    calibration_input = $CalibrationInput
    calibration_images = $CalibrationImages
    fusion_report = $fusionReport
    fused_checkpoint = $fusedCheckpoint
    handoff_dir = $handoffDir
    manifest = $manifest
    manifest_reference_summary = $manifestRefSummary
    manifest_reference_summary_json = $manifestRefSummaryJson
    manifest_reference_preview = $manifestRefPreview
    manifest_reference_metrics = [ordered]@{
      mismatch_bytes = $manifestMismatchBytes
      max_channel_diff = $manifestMaxChannelDiff
      psnr_db = $manifestPsnrDb
    }
    activation_scales = $activationScales
    quant_plan = $quantPlan
    integer_reference_summary = $integerSummary
    integer_reference_summary_json = $integerSummaryJson
    integer_reference_preview = $integerPreview
    integer_reference_metrics = [ordered]@{
      mismatch_bytes = $integerMismatchBytes
      max_channel_diff = $integerMaxChannelDiff
      psnr_db = $integerPsnrDb
    }
    gates = $gates
  }
  $summary | ConvertTo-Json -Depth 4 | Set-Content -Path $summaryJson -Encoding UTF8

  $result = if ($passed) { "PASS" } else { "FAIL" }
  $lines = @(
    "# TinySPAN C32B4 Realtime Handoff",
    "",
    "Result: ``$result``",
    "",
    "Tag: ``$safeTag``",
    "Checkpoint: ``$Checkpoint``",
    "Preview input: ``$PreviewInput``",
    "Calibration input: ``$CalibrationInput``",
    "",
    "## Gates",
    "",
    "| Gate | Result |",
    "| --- | --- |",
    "| ``manifest_matches_software`` | ``$($gates.manifest_matches_software)`` |",
    "| ``integer_psnr_ok`` | ``$($gates.integer_psnr_ok)`` |",
    "| ``integer_channel_diff_ok`` | ``$($gates.integer_channel_diff_ok)`` |",
    "",
    "## Metrics",
    "",
    "- manifest mismatch bytes: ``$manifestMismatchBytes``",
    "- manifest max channel diff: ``$manifestMaxChannelDiff``",
    "- manifest PSNR vs software: ``$manifestPsnrDb`` dB",
    "- integer mismatch bytes: ``$integerMismatchBytes``",
    "- integer max channel diff: ``$integerMaxChannelDiff``",
    "- integer PSNR vs software: ``$integerPsnrDb`` dB",
    "",
    "## Artifacts",
    "",
    "- fusion report: ``$fusionReport``",
    "- fused checkpoint: ``$fusedCheckpoint``",
    "- handoff manifest: ``$manifest``",
    "- manifest reference: ``$manifestRefSummary``",
    "- manifest preview: ``$manifestRefPreview``",
    "- activation scales: ``$activationScales``",
    "- W8A8 quant plan: ``$quantPlan``",
    "- integer reference: ``$integerSummary``",
    "- integer preview: ``$integerPreview``",
    "",
    "## Next",
    "",
    "Only use this checkpoint for RTL/board parity if every gate above passes."
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "C32B4_REALTIME_HANDOFF_SUMMARY_JSON=$summaryJson"
  Write-Host "C32B4_REALTIME_HANDOFF_SUMMARY_MD=$summaryMd"
  Write-Host "C32B4_MANIFEST_PREVIEW=$manifestRefPreview"
  Write-Host "C32B4_INTEGER_PREVIEW=$integerPreview"
  Write-Host "$result prepare_tinyspan_c32b4_realtime_handoff"
  if (-not $passed) {
    throw "TinySPAN realtime handoff parity gate failed for checkpoint: $Checkpoint"
  }
}
finally {
  Pop-Location
}
