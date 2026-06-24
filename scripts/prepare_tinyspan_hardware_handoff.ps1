param(
  [Parameter(Mandatory = $true)]
  [string]$Checkpoint,
  [ValidateSet(2, 4)]
  [int]$Scale = 4,
  [int]$Channels = 16,
  [int]$Blocks = 3,
  [string]$OutputDir = "",
  [switch]$FuseConv3XC,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Push-Location $root
try {
  if ($OutputDir -eq "") {
    $OutputDir = "rtl\generated\tinyspan_x${Scale}_c${Channels}_b${Blocks}_candidate"
  }
  $outputAbs = Join-Path $root $OutputDir
  $summaryDir = Join-Path $root "runs\tinyspan_hardware_handoff"
  New-Item -ItemType Directory -Path $summaryDir -Force | Out-Null
  $tag = "x${Scale}_c${Channels}_b${Blocks}"
  if ($FuseConv3XC) {
    $tag = "${tag}_fused"
  }
  $summaryJson = Join-Path $summaryDir ("handoff_${tag}.json")
  $summaryMd = Join-Path $summaryDir ("handoff_${tag}.md")

  $checkpointExists = Test-Path $Checkpoint
  $fuseArg = if ($FuseConv3XC) { " --fuse-conv3xc" } else { "" }
  $plannedExport = "python train\export_tinyspan_to_rtl.py --checkpoint `"$Checkpoint`" --scale $Scale --channels $Channels --num-blocks $Blocks --output-dir `"$OutputDir`"$fuseArg"
  Write-Host "TINYSPAN_HANDOFF_CHECKPOINT=$Checkpoint"
  Write-Host "TINYSPAN_HANDOFF_OUTPUT_DIR=$OutputDir"
  Write-Host "TINYSPAN_HANDOFF_PLAN=$plannedExport"
  Write-Host "TINYSPAN_HANDOFF_CHECKPOINT_EXISTS=$checkpointExists"

  if (-not $checkpointExists) {
    throw "Checkpoint not found: $Checkpoint"
  }

  if ($DryRun) {
    Write-Host "DRY_RUN=1"
  } else {
    $exportArgs = @(
      "train\export_tinyspan_to_rtl.py",
      "--checkpoint", $Checkpoint,
      "--scale", $Scale,
      "--channels", $Channels,
      "--num-blocks", $Blocks,
      "--output-dir", $OutputDir
    )
    if ($FuseConv3XC) {
      $exportArgs += "--fuse-conv3xc"
    }
    python @exportArgs
    if ($LASTEXITCODE -ne 0) {
      throw "export_tinyspan_to_rtl.py failed with exit code $LASTEXITCODE"
    }
  }

  $manifest = Join-Path $outputAbs "tinyspan_manifest.json"
  $config = Join-Path $outputAbs "tinyspan_model_config.vh"
  $manifestExists = Test-Path $manifest
  $configExists = Test-Path $config
  $weightFiles = @()
  if (Test-Path (Join-Path $outputAbs "weights")) {
    $weightFiles = @(Get-ChildItem -Path (Join-Path $outputAbs "weights") -Filter "*.mem" -File)
  }

  $manifestInfo = $null
  if ($manifestExists) {
    $manifestInfo = Get-Content -Raw $manifest | ConvertFrom-Json
  }

  $checks = [ordered]@{
    checkpoint_exists = [bool]$checkpointExists
    manifest_exists = [bool]$manifestExists
    config_exists = [bool]$configExists
    weights_exist = [bool]($weightFiles.Count -gt 0)
    scale_matches = if ($manifestInfo) { [bool]([int]$manifestInfo.scale -eq $Scale) } else { $false }
    channels_matches = if ($manifestInfo) { [bool]([int]$manifestInfo.channels -eq $Channels) } else { $false }
    blocks_matches = if ($manifestInfo) { [bool]([int]$manifestInfo.num_blocks -eq $Blocks) } else { $false }
  }
  $passed = $checks.checkpoint_exists -and (
    $DryRun -or (
      $checks.manifest_exists -and
      $checks.config_exists -and
      $checks.weights_exist -and
      $checks.scale_matches -and
      $checks.channels_matches -and
      $checks.blocks_matches
    )
  )

  $branch = ""
  $git = Get-Command git -ErrorAction SilentlyContinue
  if ($git) {
    $branch = (git branch --show-current)
  }
  $summary = [ordered]@{
    passed = [bool]$passed
    dry_run = [bool]$DryRun
    branch = $branch
    checkpoint = $Checkpoint
    checkpoint_full_path = (Resolve-Path $Checkpoint).Path
    scale = $Scale
    channels = $Channels
    blocks = $Blocks
    conv3xc_fused = [bool]$FuseConv3XC
    output_dir = $OutputDir
    output_full_path = $outputAbs
    manifest = $manifest
    config = $config
    weight_file_count = $weightFiles.Count
    total_weight_bytes = if ($weightFiles.Count -gt 0) { ($weightFiles | Measure-Object -Property Length -Sum).Sum } else { 0 }
    checks = $checks
    planned_export = $plannedExport
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJson -Encoding UTF8

  $result = if ($passed) { "PASS" } else { "FAIL" }
  $lines = @(
    "# TinySPAN hardware handoff",
    "",
    "Result: ``$result``",
    "",
    "Checkpoint: ``$Checkpoint``",
    "Output dir: ``$OutputDir``",
    "Model: X$Scale C$Channels B$Blocks",
    "Conv3XC fused: ``$([bool]$FuseConv3XC)``",
    "",
    "## Checks",
    "",
    "| Check | Result |",
    "| --- | --- |"
  )
  foreach ($key in $checks.Keys) {
    $lines += "| ``$key`` | ``$($checks[$key])`` |"
  }
  $lines += @(
    "",
    "## Export",
    "",
    "- manifest: ``$manifest``",
    "- config: ``$config``",
    "- weight files: ``$($weightFiles.Count)``",
    "- total weight bytes: ``$($summary.total_weight_bytes)``",
    "",
    "Planned/export command:",
    "",
    '```powershell',
    $plannedExport,
    '```'
  )
  Set-Content -Path $summaryMd -Value $lines -Encoding UTF8

  Write-Host "TINYSPAN_HANDOFF_SUMMARY_JSON=$summaryJson"
  Write-Host "TINYSPAN_HANDOFF_SUMMARY_MD=$summaryMd"
  Write-Host "TINYSPAN_HANDOFF_PASS=$([int]$passed)"
  if (-not $passed) {
    throw "TinySPAN hardware handoff failed"
  }
}
finally {
  Pop-Location
}
