param(
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$Gcc = "D:\software\2025.2\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-gcc.exe",
  [string]$PsuInitTcl = "",
  [string]$OutputDir = "",
  [int]$XsctWallTimeoutSeconds = 300
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$srcDir = Join-Path $root "software\ps_a53_ddr_alias_probe"

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
  if (-not (Test-Path $XsctBat)) { throw "XSCT executable not found: $XsctBat" }
  if (-not (Test-Path $Gcc)) { throw "AArch64 GCC not found: $Gcc" }
  if ([string]::IsNullOrWhiteSpace($PsuInitTcl)) {
    $PsuInitTcl = Get-LatestPsuInitTcl
  }
  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\a53_ddr_alias_probe\probe_$stamp"
  }
  $outDirAbs = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    [System.IO.Path]::GetFullPath($OutputDir)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputDir))
  }
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null

  $elf = Join-Path $outDirAbs "a53_ddr_alias_probe.elf"
  $linker = Join-Path $srcDir "linker.ld"
  & $Gcc -mcpu=cortex-a53 -ffreestanding -fno-builtin -nostdlib "-Wl,-T,$linker" `
    (Join-Path $srcDir "startup.S") (Join-Path $srcDir "main.c") -o $elf
  if ($LASTEXITCODE -ne 0) {
    throw "A53 DDR alias probe ELF build failed"
  }

  $xsctLog = Join-Path $outDirAbs "a53_ddr_alias_probe.log"
  $stdout = [System.IO.Path]::ChangeExtension($xsctLog, ".stdout.log")
  $stderr = [System.IO.Path]::ChangeExtension($xsctLog, ".stderr.log")
  $proc = Start-Process -FilePath $XsctBat `
    -ArgumentList @("scripts\board\run_xsct_a53_ddr_alias_probe.tcl", $PsuInitTcl, $elf) `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr `
    -PassThru `
    -WindowStyle Hidden
  $deadline = (Get-Date).AddSeconds($XsctWallTimeoutSeconds)
  while (-not $proc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $proc.Refresh()
  }
  if (-not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw "A53 DDR alias probe timed out after $XsctWallTimeoutSeconds seconds"
  }
  if (Test-Path $stdout) { Get-Content -Path $stdout | Set-Content -Path $xsctLog -Encoding UTF8 }
  if (Test-Path $stderr) {
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "A53_DDR_ALIAS_STDERR_BEGIN"
    Get-Content -Path $stderr | Add-Content -Path $xsctLog -Encoding UTF8
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "A53_DDR_ALIAS_STDERR_END"
  }
  $text = Get-Content -Path $xsctLog -Raw
  $xsctExitCode = $proc.ExitCode
  if ($null -eq $xsctExitCode) {
    $xsctExitCode = if ($text -match "A53_DDR_ALIAS_PASS=1") { 0 } else { -1 }
  }
  if ($xsctExitCode -ne 0 -or $text -notmatch "A53_DDR_ALIAS_PASS=1") {
    throw "A53 DDR alias probe failed with exit code $xsctExitCode. See $xsctLog"
  }
  Write-Host "A53_DDR_ALIAS_PROBE_LOG=$xsctLog"
  Write-Host "PASS run_a53_ddr_alias_probe"
} finally {
  Pop-Location
}
