param(
  [string]$WorkspaceRoot = "",
  [string]$TinyspanRoot = "",
  [int]$WaitSeconds = 43200,
  [int]$PollSeconds = 60,
  [string]$RunDir = "board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref",
  [string]$WaitLogDir = "board_runs\tinyspan_w8a8_base_equiv_jtag\gate_h_x4_320x180_f150_20260624_tiledref_waitrun",
  [string]$ArtifactDir = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\gate_h_board_x4_320x180_f150_tiledref_20260624"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TinyspanRoot)) {
  $TinyspanRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
} else {
  $TinyspanRoot = Resolve-Path $TinyspanRoot
}
if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
  $WorkspaceRoot = Resolve-Path (Join-Path $TinyspanRoot "..")
} else {
  $WorkspaceRoot = Resolve-Path $WorkspaceRoot
}

function Resolve-Under {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [Parameter(Mandatory = $true)]
    [string]$Path
  )
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }
  return Join-Path $Root $Path
}

$runDirAbs = Resolve-Under -Root $WorkspaceRoot -Path $RunDir
$summaryJson = Join-Path $runDirAbs "acceptance_tiled_fixed\tinyspan_720p30_board_acceptance_summary.json"
$artifactDirAbs = Resolve-Under -Root $TinyspanRoot -Path $ArtifactDir
$checkJsonRel = Join-Path $ArtifactDir "gate_h_check.json"
$checkMdRel = Join-Path $ArtifactDir "gate_h_check.md"
$deadline = (Get-Date).AddSeconds($WaitSeconds)

Write-Host "TINYSPAN_GATE_H_POSTPACK_WATCH_START=$((Get-Date).ToString('o'))"
Write-Host "TINYSPAN_GATE_H_POSTPACK_WORKSPACE_ROOT=$WorkspaceRoot"
Write-Host "TINYSPAN_GATE_H_POSTPACK_TINYSPAN_ROOT=$TinyspanRoot"
Write-Host "TINYSPAN_GATE_H_POSTPACK_WAITING_FOR=$summaryJson"

while (-not (Test-Path $summaryJson)) {
  if ((Get-Date) -ge $deadline) {
    throw "Timed out waiting for Gate H acceptance summary: $summaryJson"
  }
  Write-Host "TINYSPAN_GATE_H_POSTPACK_WAITING=1"
  Start-Sleep -Seconds $PollSeconds
}

Write-Host "TINYSPAN_GATE_H_POSTPACK_SUMMARY_FOUND=$summaryJson"
New-Item -ItemType Directory -Force -Path $artifactDirAbs | Out-Null

python (Join-Path $TinyspanRoot "scripts\acceptance\check_gate_h_tiledref_board_run.py") `
  --tinyspan-root $TinyspanRoot `
  --workspace-root $WorkspaceRoot `
  --summary-json $checkJsonRel `
  --summary-md $checkMdRel
if ($LASTEXITCODE -ne 0) {
  throw "Gate H post-run checker failed with exit code $LASTEXITCODE"
}

python (Join-Path $TinyspanRoot "scripts\acceptance\package_gate_h_tiledref_board_run.py") `
  --tinyspan-root $TinyspanRoot `
  --workspace-root $WorkspaceRoot `
  --artifact-dir $ArtifactDir
if ($LASTEXITCODE -ne 0) {
  throw "Gate H evidence packager failed with exit code $LASTEXITCODE"
}

python (Join-Path $TinyspanRoot "scripts\acceptance\update_workflow_status.py") `
  --artifact-dir (Join-Path $TinyspanRoot "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe") `
  --docs-out (Join-Path $TinyspanRoot "docs\gate_status.md") `
  --json-out (Join-Path $TinyspanRoot "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\contest_completion_status.json")
if ($LASTEXITCODE -ne 0) {
  throw "Workflow status refresh failed with exit code $LASTEXITCODE"
}

python (Join-Path $TinyspanRoot "scripts\acceptance\audit_contest_delivery.py") `
  --repo-root $TinyspanRoot `
  --artifact-dir "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe" `
  --json-out "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\contest_delivery_audit.json" `
  --md-out "docs\contest_delivery_audit.md"
if ($LASTEXITCODE -ne 0) {
  throw "Contest delivery audit refresh failed with exit code $LASTEXITCODE"
}

Write-Host "TINYSPAN_GATE_H_POSTPACK_DONE=$((Get-Date).ToString('o'))"
