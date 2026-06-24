param(
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$PsuInitTcl = "",
  [string]$BaseAddr = "0x12000000",
  [int]$StrideBytes = 0x4000,
  [int]$Count = 8,
  [string]$OutputDir = "",
  [int]$XsctWallTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Get-LatestPsuInitTcl {
  $candidate = Get-ChildItem -Path (Join-Path $root "vivado\ps_tinyspan_ddr_x4") -Recurse -Filter "psu_init.tcl" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\pstinyspanx4ddr_ps_0\\psu_init\.tcl$" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw "Could not find TinySPAN PS DDR psu_init.tcl."
  }
  return $candidate.FullName
}

Push-Location $root
try {
  if (-not (Test-Path $XsctBat)) {
    throw "XSCT executable not found: $XsctBat"
  }
  if ([string]::IsNullOrWhiteSpace($PsuInitTcl)) {
    $PsuInitTcl = Get-LatestPsuInitTcl
  }
  if (-not (Test-Path $PsuInitTcl)) {
    throw "psu_init.tcl not found: $PsuInitTcl"
  }
  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\tinyspan_ps_ddr_alias_probe\probe_$stamp"
  }
  $outDirAbs = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    [System.IO.Path]::GetFullPath($OutputDir)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputDir))
  }
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  $xsctLog = Join-Path $outDirAbs "ps_ddr_alias_probe.log"
  $xsctStdoutLog = [System.IO.Path]::ChangeExtension($xsctLog, ".stdout.log")
  $xsctStderrLog = [System.IO.Path]::ChangeExtension($xsctLog, ".stderr.log")
  $xsctArgs = @(
    "scripts\board\run_xsct_ps_ddr_alias_probe.tcl",
    $PsuInitTcl,
    $BaseAddr,
    [string]$StrideBytes,
    [string]$Count
  )
  Remove-Item -Path $xsctLog,$xsctStdoutLog,$xsctStderrLog -Force -ErrorAction SilentlyContinue
  $proc = Start-Process -FilePath $XsctBat `
    -ArgumentList $xsctArgs `
    -RedirectStandardOutput $xsctStdoutLog `
    -RedirectStandardError $xsctStderrLog `
    -PassThru `
    -WindowStyle Hidden
  $deadline = (Get-Date).AddSeconds($XsctWallTimeoutSeconds)
  while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $proc.Refresh()
  }
  if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw "PS DDR alias probe timed out after $XsctWallTimeoutSeconds seconds"
  }
  if (Test-Path $xsctStdoutLog) {
    Get-Content -Path $xsctStdoutLog | Set-Content -Path $xsctLog -Encoding UTF8
  }
  if (Test-Path $xsctStderrLog) {
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "PS_DDR_ALIAS_STDERR_BEGIN"
    Get-Content -Path $xsctStderrLog | Add-Content -Path $xsctLog -Encoding UTF8
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "PS_DDR_ALIAS_STDERR_END"
  }
  $text = Get-Content -Path $xsctLog -Raw
  $xsctExitCode = $proc.ExitCode
  if ($null -eq $xsctExitCode) {
    $xsctExitCode = if ($text -match "PS_DDR_ALIAS_PASS=1") { 0 } else { -1 }
  }
  if ($xsctExitCode -ne 0 -or $text -notmatch "PS_DDR_ALIAS_PASS=1") {
    throw "PS DDR alias probe failed with exit code $xsctExitCode. See $xsctLog"
  }
  Write-Host "PS_DDR_ALIAS_PROBE_LOG=$xsctLog"
  Write-Host "PASS run_ps_ddr_alias_probe"
} finally {
  Pop-Location
}
