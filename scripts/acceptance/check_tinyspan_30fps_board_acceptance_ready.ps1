param(
  [string]$HandoffSummary = "runs\tinyspan_realtime_handoff\c32b4_c32b4_30fps_frozen_20260613_summary.json",
  [string]$RtlManifest = "rtl\generated\tinyspan_c32b4_30fps_frozen_w8a8\tinyspan_w8a8_rtl_manifest.json",
  [string]$HeadFrontendDcp = "build\vivado_tinyspan_w8a8_head_frontend_synth\tinyspan_w8a8_head_frontend_synth.dcp",
  [string]$FinalRgb888Top = "rtl\span\span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v",
  [string]$BaseEquivCompareScript = "scripts\compare_tinyspan_base_equiv_reference.ps1",
  [string]$JtagBuildScript = "scripts\run_vivado_bitstream_jtag_tinyspan_w8a8_base_equiv.ps1",
  [string]$JtagSmokeScript = "scripts\run_jtag_tinyspan_w8a8_base_equiv_smoke.ps1",
  [string]$Board720pAcceptanceScript = "scripts\run_tinyspan_720p30_board_acceptance.ps1",
  [string]$Board720pPreflightScript = "scripts\check_tinyspan_720p30_acceptance_inputs.ps1",
  [string]$AcceptanceSummaryWriter = "tools\write_tinyspan_board_acceptance_summary.py",
  [string]$BoardResourceLogWriter = "tools\write_board_resource_log.py",
  [string]$VivadoIdleScript = "scripts\check_vivado_idle.ps1",
  [string]$VivadoCleanupScript = "scripts\cleanup_vivado_processes.ps1",
  [string]$Bitstream = "vivado\bitstreams\jfs_full_span_x4_320x180_f150m_tinyspan_w8a8_base_equiv_fast.bit",
  [string]$BoardOutput = "",
  [string]$OutDir = "board_runs\tinyspan_board_acceptance\readiness_c32b4_30fps_frozen_20260613"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Push-Location $root
try {
  New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
  $checks = New-Object System.Collections.Generic.List[object]

  function Add-Check([string]$Name, [bool]$Pass, [string]$Detail) {
    $script:checks.Add([ordered]@{ name = $Name; pass = $Pass; detail = $Detail }) | Out-Null
  }

  if (Test-Path $HandoffSummary) {
    $handoff = Get-Content -Raw -Path $HandoffSummary | ConvertFrom-Json
    Add-Check "handoff_summary_exists" $true $HandoffSummary
    Add-Check "handoff_passed" ([bool]$handoff.passed) "passed=$($handoff.passed)"
    foreach ($item in @(
      @("checkpoint", $handoff.checkpoint),
      @("manifest", $handoff.manifest),
      @("quant_plan", $handoff.quant_plan),
      @("integer_reference_summary", $handoff.integer_reference_summary),
      @("integer_reference_preview", $handoff.integer_reference_preview)
    )) {
      $path = [string]$item[1]
      Add-Check $item[0] (Test-Path $path) $path
    }
  } else {
    Add-Check "handoff_summary_exists" $false $HandoffSummary
  }

  if (Test-Path $RtlManifest) {
    $rtl = Get-Content -Raw -Path $RtlManifest | ConvertFrom-Json
    Add-Check "tinyspan_w8a8_rtl_manifest_exists" $true $RtlManifest
    Add-Check "tinyspan_w8a8_rtl_layer_count" ([int]$rtl.layers.Count -eq 15) "layers=$($rtl.layers.Count), expected=15"
    Add-Check "tinyspan_w8a8_rtl_postprocess_blocks" ([int]$rtl.postprocess.Count -eq 4) "blocks=$($rtl.postprocess.Count), expected=4"
    Add-Check "tinyspan_w8a8_rtl_channels" ([int]$rtl.channels -eq 32) "channels=$($rtl.channels), expected=32"
    if ($rtl.header) {
      Add-Check "tinyspan_w8a8_rtl_header" (Test-Path ([string]$rtl.header)) ([string]$rtl.header)
    } else {
      Add-Check "tinyspan_w8a8_rtl_header" $false "header missing from manifest"
    }
    $missingRtlRefs = 0
    foreach ($layer in $rtl.layers) {
      foreach ($field in @("group_weight_mem", "bias_i64_mem", "requant_q31_mem", "requant_shift_mem")) {
        $refPath = [string]$layer.$field
        if (-not (Test-Path $refPath)) {
          $missingRtlRefs += 1
        }
      }
    }
    foreach ($block in $rtl.postprocess) {
      foreach ($prop in $block.luts.PSObject.Properties) {
        if (-not (Test-Path ([string]$prop.Value))) {
          $missingRtlRefs += 1
        }
      }
    }
    Add-Check "tinyspan_w8a8_rtl_references_exist" ($missingRtlRefs -eq 0) "missing_refs=$missingRtlRefs"
  } else {
    Add-Check "tinyspan_w8a8_rtl_manifest_exists" $false $RtlManifest
  }

  Add-Check "tinyspan_w8a8_head_frontend_synth_dcp" (Test-Path $HeadFrontendDcp) $HeadFrontendDcp
  Add-Check "tinyspan_w8a8_final_rgb888_top" (Test-Path $FinalRgb888Top) $FinalRgb888Top
  Add-Check "tinyspan_base_equiv_compare_script" (Test-Path $BaseEquivCompareScript) $BaseEquivCompareScript
  Add-Check "tinyspan_jtag_build_script" (Test-Path $JtagBuildScript) $JtagBuildScript
  Add-Check "tinyspan_jtag_smoke_script" (Test-Path $JtagSmokeScript) $JtagSmokeScript
  Add-Check "tinyspan_720p30_acceptance_script" (Test-Path $Board720pAcceptanceScript) $Board720pAcceptanceScript
  Add-Check "tinyspan_720p30_preflight_script" (Test-Path $Board720pPreflightScript) $Board720pPreflightScript
  Add-Check "tinyspan_board_resource_log_writer" (Test-Path $BoardResourceLogWriter) $BoardResourceLogWriter
  Add-Check "vivado_idle_script" (Test-Path $VivadoIdleScript) $VivadoIdleScript
  Add-Check "vivado_cleanup_script" (Test-Path $VivadoCleanupScript) $VivadoCleanupScript
  if (Test-Path $AcceptanceSummaryWriter) {
    $summaryWriterText = Get-Content -Raw -Path $AcceptanceSummaryWriter
    Add-Check "tinyspan_acceptance_summary_resource_embed" ($summaryWriterText -match "board_resources") $AcceptanceSummaryWriter
    Add-Check "tinyspan_acceptance_summary_requires_resources" ($summaryWriterText -match "require-board-resources") $AcceptanceSummaryWriter
  } else {
    Add-Check "tinyspan_acceptance_summary_resource_embed" $false $AcceptanceSummaryWriter
    Add-Check "tinyspan_acceptance_summary_requires_resources" $false $AcceptanceSummaryWriter
  }
  if (Test-Path $Board720pAcceptanceScript) {
    $accept720pText = Get-Content -Raw -Path $Board720pAcceptanceScript
    Add-Check "tinyspan_720p30_acceptance_locks_720p" (($accept720pText -match "320x180") -and ($accept720pText -match "1280x720")) $Board720pAcceptanceScript
    Add-Check "tinyspan_720p30_acceptance_locks_tile32" ($accept720pText -match "32x32") $Board720pAcceptanceScript
    Add-Check "tinyspan_720p30_acceptance_requires_resource_json" ($accept720pText -match "require-board-resources") $Board720pAcceptanceScript
  } else {
    Add-Check "tinyspan_720p30_acceptance_locks_720p" $false $Board720pAcceptanceScript
    Add-Check "tinyspan_720p30_acceptance_locks_tile32" $false $Board720pAcceptanceScript
    Add-Check "tinyspan_720p30_acceptance_requires_resource_json" $false $Board720pAcceptanceScript
  }
  if (Test-Path $JtagBuildScript) {
    $jtagBuildText = Get-Content -Raw -Path $JtagBuildScript
    Add-Check "tinyspan_jtag_build_vivado_idle_precheck" ($jtagBuildText -match "check_vivado_idle") $JtagBuildScript
    Add-Check "tinyspan_jtag_build_vivado_cleanup" ($jtagBuildText -match "cleanup_vivado_processes") $JtagBuildScript
    Add-Check "tinyspan_jtag_build_rectangular_img_h" ($jtagBuildText -match "ImgH") $JtagBuildScript
    Add-Check "tinyspan_jtag_build_fast_base_equiv" ($jtagBuildText -match "Fast") $JtagBuildScript
  } else {
    Add-Check "tinyspan_jtag_build_vivado_idle_precheck" $false $JtagBuildScript
    Add-Check "tinyspan_jtag_build_vivado_cleanup" $false $JtagBuildScript
    Add-Check "tinyspan_jtag_build_rectangular_img_h" $false $JtagBuildScript
    Add-Check "tinyspan_jtag_build_fast_base_equiv" $false $JtagBuildScript
  }
  if (Test-Path $JtagSmokeScript) {
    $jtagSmokeText = Get-Content -Raw -Path $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_vivado_idle_precheck" ($jtagSmokeText -match "check_vivado_idle") $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_vivado_cleanup" ($jtagSmokeText -match "cleanup_vivado_processes") $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_rectangular_img_h" ($jtagSmokeText -match "ImgH") $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_fast_base_equiv" ($jtagSmokeText -match "Fast") $JtagSmokeScript
  } else {
    Add-Check "tinyspan_jtag_smoke_vivado_idle_precheck" $false $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_vivado_cleanup" $false $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_rectangular_img_h" $false $JtagSmokeScript
    Add-Check "tinyspan_jtag_smoke_fast_base_equiv" $false $JtagSmokeScript
  }

  Add-Check "tinyspan_trained_bitstream_exists" (Test-Path $Bitstream) $Bitstream

  if ([string]::IsNullOrWhiteSpace($BoardOutput)) {
    Add-Check "real_board_output_provided" $false "BoardOutput is empty"
  } else {
    Add-Check "real_board_output_exists" (Test-Path $BoardOutput) $BoardOutput
  }

  $passed = $true
  foreach ($check in $checks) {
    if (-not $check.pass) {
      $passed = $false
      break
    }
  }

  $summary = [ordered]@{
    ready = $passed
    handoff_summary = $HandoffSummary
    rtl_manifest = $RtlManifest
    head_frontend_dcp = $HeadFrontendDcp
    final_rgb888_top = $FinalRgb888Top
    base_equiv_compare_script = $BaseEquivCompareScript
    jtag_build_script = $JtagBuildScript
    jtag_smoke_script = $JtagSmokeScript
    board_720p_acceptance_script = $Board720pAcceptanceScript
    board_720p_preflight_script = $Board720pPreflightScript
    acceptance_summary_writer = $AcceptanceSummaryWriter
    board_resource_log_writer = $BoardResourceLogWriter
    vivado_idle_script = $VivadoIdleScript
    vivado_cleanup_script = $VivadoCleanupScript
    bitstream = $Bitstream
    board_output = $BoardOutput
    checks = $checks
  }
  $summaryJson = Join-Path $OutDir "tinyspan_720p30_board_acceptance_readiness.json"
  $summaryMd = Join-Path $OutDir "tinyspan_720p30_board_acceptance_readiness.md"
  $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJson -Encoding UTF8

  $lines = @(
    "# TinySPAN 720p30 Board Acceptance Readiness",
    "",
    "Ready: ``$passed``",
    "",
    "Handoff summary: ``$HandoffSummary``",
    "RTL manifest: ``$RtlManifest``",
    "Head frontend DCP: ``$HeadFrontendDcp``",
    "Final RGB888 top: ``$FinalRgb888Top``",
    "Base equivalence compare script: ``$BaseEquivCompareScript``",
    "JTAG build script: ``$JtagBuildScript``",
    "JTAG smoke script: ``$JtagSmokeScript``",
    "720p30 acceptance script: ``$Board720pAcceptanceScript``",
    "720p30 preflight script: ``$Board720pPreflightScript``",
    "Acceptance summary writer: ``$AcceptanceSummaryWriter``",
    "Board resource log writer: ``$BoardResourceLogWriter``",
    "Vivado idle script: ``$VivadoIdleScript``",
    "Vivado cleanup script: ``$VivadoCleanupScript``",
    "Expected bitstream: ``$Bitstream``",
    "Board output: ``$BoardOutput``",
    "",
    "| Check | Result | Detail |",
    "| --- | --- | --- |"
  )
  foreach ($check in $checks) {
    $status = if ($check.pass) { "PASS" } else { "FAIL" }
    $lines += "| ``$($check.name)`` | ``$status`` | ``$($check.detail)`` |"
  }
  $lines | Set-Content -Path $summaryMd -Encoding UTF8

  Write-Host "READY=$passed"
  Write-Host "SUMMARY=$summaryMd"
  if (-not $passed) {
    exit 1
  }
} finally {
  Pop-Location
}
