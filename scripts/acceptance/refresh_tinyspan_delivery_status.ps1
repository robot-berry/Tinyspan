param(
  [string]$TinyspanRoot = "",
  [string]$WorkspaceRoot = "",
  [string]$ArtifactDir = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe",
  [string]$DocsGateStatus = "docs\gate_status.md",
  [string]$ContestStatusJson = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\contest_completion_status.json",
  [string]$ContestAuditJson = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\contest_delivery_audit.json",
  [string]$ContestAuditMd = "docs\contest_delivery_audit.md",
  [int]$TotalSteps = 198000,
  [switch]$SkipX2TrainingRefresh
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

Push-Location $TinyspanRoot
try {
  Write-Host "TINYSPAN_DELIVERY_REFRESH_START=$((Get-Date).ToString('o'))"
  Write-Host "TINYSPAN_ROOT=$TinyspanRoot"
  Write-Host "WORKSPACE_ROOT=$WorkspaceRoot"
  Write-Host "ARTIFACT_DIR=$ArtifactDir"

  if (-not $SkipX2TrainingRefresh) {
    python scripts\acceptance\refresh_x2_training_status.py `
      --workspace-root $WorkspaceRoot `
      --tinyspan-root $TinyspanRoot `
      --total-steps $TotalSteps
    if ($LASTEXITCODE -ne 0) {
      throw "refresh_x2_training_status.py failed with exit code $LASTEXITCODE"
    }
  }

  python scripts\acceptance\audit_tinyspan_x2_hardware_readiness.py `
    --repo-root $TinyspanRoot
  if ($LASTEXITCODE -ne 0) {
    throw "audit_tinyspan_x2_hardware_readiness.py failed with exit code $LASTEXITCODE"
  }

  python scripts\acceptance\update_workflow_status.py `
    --artifact-dir $ArtifactDir `
    --docs-out $DocsGateStatus `
    --json-out $ContestStatusJson
  if ($LASTEXITCODE -ne 0) {
    throw "update_workflow_status.py failed with exit code $LASTEXITCODE"
  }

  python scripts\acceptance\audit_contest_delivery.py `
    --repo-root $TinyspanRoot `
    --artifact-dir $ArtifactDir `
    --json-out $ContestAuditJson `
    --md-out $ContestAuditMd
  if ($LASTEXITCODE -ne 0) {
    throw "audit_contest_delivery.py failed with exit code $LASTEXITCODE"
  }

  Write-Host "TINYSPAN_DELIVERY_REFRESH_DONE=$((Get-Date).ToString('o'))"
} finally {
  Pop-Location
}
