param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$Bitstream = "",
  [string]$PsuInitTcl = "",
  [string]$InputPng = "G:\UESTC\feitengspan1\external\SPAN\test_scripts\data\baboon.png",
  [int]$ImgW = 32,
  [int]$ImgH = 32,
  [int]$Scale = 4,
  [double]$PlFreqMhz = 150.0,
  [string]$CtrlBase = "0xA0000000",
  [string]$InputBase = "0x10000000",
  [string]$OutputBase = "0x11000000",
  [ValidateSet("FULL", "SAMPLE", "SKIP")]
  [string]$ReadbackMode = "FULL",
  [int]$ReadbackPixels = 0,
  [switch]$SkipOutputClear,
  [int]$TimeoutMs = 120000,
  [int]$XsctWallTimeoutSeconds = 0,
  [string]$OutputDir = "",
  [string]$PythonExe = "D:\software\anaconda\python.exe",
  [string]$FixedReferencePng = "",
  [string]$TrainingReferencePng = "",
  [switch]$RequireReferenceMatch,
  [switch]$NoProgram
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Resolve-WorkflowPath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) {
    return ""
  }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  $underTinyspan = [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
  if (Test-Path $underTinyspan) {
    return $underTinyspan
  }
  $underProject = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $root -Parent) $PathValue))
  return $underProject
}

function Get-LatestPsuInitTcl {
  $candidate = Get-ChildItem -Path (Join-Path $root "vivado\ps_tinyspan_ddr_x4") -Recurse -Filter "psu_init.tcl" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\pstinyspanx4ddr_ps_0\\psu_init\.tcl$" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw "Could not find TinySPAN PS DDR psu_init.tcl. Generate the PS DDR bitstream project first."
  }
  return $candidate.FullName
}

function Get-LogValue {
  param([string]$Text, [string]$Name)
  $m = [regex]::Match($Text, "TINYSPAN_PS_DDR_X4_$Name=([0-9]+)")
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

function Get-LogHexValue {
  param([string]$Text, [string]$Name)
  $m = [regex]::Match($Text, "TINYSPAN_PS_DDR_X4_$Name=(0x[0-9A-Fa-f]+)")
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

function Convert-HexPixelsToRaw {
  param(
    [string]$HexPath,
    [string]$RawPath,
    [int]$ExpectedPixels
  )
  $lines = Get-Content -Path $HexPath
  if ($ExpectedPixels -gt 0 -and $lines.Count -ne $ExpectedPixels) {
    throw "hex output pixel count mismatch: got $($lines.Count), expected $ExpectedPixels"
  }
  $bytes = New-Object byte[] ($lines.Count * 3)
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $hex = $lines[$i].Trim()
    if ($hex.Length -lt 6) {
      throw "invalid RGB hex at line $($i + 1): $hex"
    }
    $value = [Convert]::ToUInt32($hex.Substring($hex.Length - 6), 16)
    $bytes[$i * 3 + 0] = [byte](($value -shr 16) -band 0xff)
    $bytes[$i * 3 + 1] = [byte](($value -shr 8) -band 0xff)
    $bytes[$i * 3 + 2] = [byte]($value -band 0xff)
  }
  [System.IO.File]::WriteAllBytes($RawPath, $bytes)
}

function Convert-Rgb888RawToWordsBin {
  param([string]$RawPath, [string]$OutPath, [int]$Pixels)
  $raw = [System.IO.File]::ReadAllBytes($RawPath)
  if ($raw.Length -ne ($Pixels * 3)) {
    throw "RGB888 raw size mismatch for $RawPath`: got $($raw.Length), expected $($Pixels * 3)"
  }
  $words = New-Object byte[] ($Pixels * 4)
  for ($i = 0; $i -lt $Pixels; $i++) {
    $r = $raw[$i * 3 + 0]
    $g = $raw[$i * 3 + 1]
    $b = $raw[$i * 3 + 2]
    $words[$i * 4 + 0] = $b
    $words[$i * 4 + 1] = $g
    $words[$i * 4 + 2] = $r
    $words[$i * 4 + 3] = 0
  }
  [System.IO.File]::WriteAllBytes($OutPath, $words)
}

function Compare-FileBytes {
  param([string]$A, [string]$B)
  $aBytes = [System.IO.File]::ReadAllBytes($A)
  $bBytes = [System.IO.File]::ReadAllBytes($B)
  if ($aBytes.Length -ne $bBytes.Length) {
    return [ordered]@{ mismatch_bytes = [Math]::Max($aBytes.Length, $bBytes.Length); total_bytes = [Math]::Max($aBytes.Length, $bBytes.Length); max_channel_diff = 255 }
  }
  $mismatch = 0
  $maxDiff = 0
  for ($i = 0; $i -lt $aBytes.Length; $i++) {
    $diff = [Math]::Abs([int]$aBytes[$i] - [int]$bBytes[$i])
    if ($diff -ne 0) { $mismatch++ }
    if ($diff -gt $maxDiff) { $maxDiff = $diff }
  }
  return [ordered]@{ mismatch_bytes = $mismatch; total_bytes = $aBytes.Length; max_channel_diff = $maxDiff }
}

Push-Location $root
try {
  if (-not (Test-Path $VivadoBat)) { throw "Vivado batch executable not found: $VivadoBat" }
  if (-not (Test-Path $XsctBat)) { throw "XSCT executable not found: $XsctBat" }
  if (-not (Test-Path $PythonExe)) { throw "Python executable not found: $PythonExe" }

  if ([string]::IsNullOrWhiteSpace($Bitstream)) {
    $Bitstream = Join-Path $root "vivado\ps_tinyspan_ddr_x4\ps_tinyspan_ddr_x4.runs\impl_1\pstinyspanx4ddr_wrapper.bit"
  } else {
    $Bitstream = Resolve-WorkflowPath $Bitstream
  }
  if ([string]::IsNullOrWhiteSpace($PsuInitTcl)) {
    $PsuInitTcl = Get-LatestPsuInitTcl
  } else {
    $PsuInitTcl = Resolve-WorkflowPath $PsuInitTcl
  }
  $InputPng = Resolve-WorkflowPath $InputPng
  if (-not (Test-Path $Bitstream)) { throw "Bitstream not found: $Bitstream" }
  if (-not (Test-Path $PsuInitTcl)) { throw "psu_init.tcl not found: $PsuInitTcl" }
  if (-not (Test-Path $InputPng)) { throw "InputPng not found: $InputPng" }

  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\tinyspan_ps_ddr_x4_smoke\x4_${ImgW}x${ImgH}_$stamp"
  }
  $outDirAbs = if ([System.IO.Path]::IsPathRooted($OutputDir)) {
    [System.IO.Path]::GetFullPath($OutputDir)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $root $OutputDir))
  }
  New-Item -ItemType Directory -Path $outDirAbs -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $outDirAbs "program") -Force | Out-Null

  $outW = $ImgW * $Scale
  $outH = $ImgH * $Scale
  $inputRaw = Join-Path $outDirAbs "input_rgb888_${ImgW}x${ImgH}.rgb"
  $inputWords = Join-Path $outDirAbs "input_words_${ImgW}x${ImgH}.bin"
  $boardHex = Join-Path $outDirAbs "board_output_${outW}x${outH}.hex"
  $boardRaw = Join-Path $outDirAbs "board_output_${outW}x${outH}.rgb"
  $boardPng = Join-Path $outDirAbs "board_output_${outW}x${outH}.png"
  $summaryJson = Join-Path $outDirAbs "tinyspan_ps_ddr_x4_smoke_summary.json"
  $summaryMd = Join-Path $outDirAbs "tinyspan_ps_ddr_x4_smoke_summary.md"
  $programLog = Join-Path $outDirAbs "program\program_tinyspan_ps_ddr_bitstream.log"
  $programJournal = Join-Path $outDirAbs "program\program_tinyspan_ps_ddr_bitstream.jou"
  $xsctLog = Join-Path $outDirAbs "run_xsct_ps_tinyspan_ddr_x4_smoke.log"
  $xsctStdoutLog = [System.IO.Path]::ChangeExtension($xsctLog, ".stdout.log")
  $xsctStderrLog = [System.IO.Path]::ChangeExtension($xsctLog, ".stderr.log")

  & $PythonExe tools\convert_rgb_raw.py to-raw $InputPng $inputRaw --width $ImgW --height $ImgH
  if ($LASTEXITCODE -ne 0) {
    throw "input PNG to raw conversion failed"
  }
  Convert-Rgb888RawToWordsBin -RawPath $inputRaw -OutPath $inputWords -Pixels ($ImgW * $ImgH)

  if (-not $NoProgram) {
    Write-Host "TINYSPAN_PS_DDR_X4_PROGRAM_LOG=$programLog"
    & $VivadoBat -mode batch -log $programLog -journal $programJournal -source scripts\board\program_tinyspan_ps_ddr_bitstream.tcl -tclargs $Bitstream
    if ($LASTEXITCODE -ne 0) {
      throw "TinySPAN PS DDR bitstream programming failed with exit code $LASTEXITCODE"
    }
  }

  $xsctWallTimeoutEffective = $XsctWallTimeoutSeconds
  if ($xsctWallTimeoutEffective -le 0) {
    $xsctWallTimeoutEffective = [Math]::Max([int][Math]::Ceiling($TimeoutMs / 1000.0) + 300, 300)
  }
  $clearOutput = if ($SkipOutputClear) { "0" } else { "1" }
  $xsctArgs = @(
    "scripts\board\run_xsct_ps_tinyspan_ddr_x4_smoke.tcl",
    $PsuInitTcl,
    $CtrlBase,
    $inputRaw,
    $boardHex,
    [string]$ImgW,
    [string]$ImgH,
    [string]$Scale,
    $InputBase,
    $OutputBase,
    [string]$TimeoutMs,
    $ReadbackMode,
    [string]$ReadbackPixels,
    $clearOutput,
    $inputWords
  )
  Remove-Item -Path $xsctLog,$xsctStdoutLog,$xsctStderrLog -Force -ErrorAction SilentlyContinue
  Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_WRAPPER_XSCT_WALL_TIMEOUT_SECONDS=$xsctWallTimeoutEffective"
  $xsctProc = Start-Process -FilePath $XsctBat `
    -ArgumentList $xsctArgs `
    -RedirectStandardOutput $xsctStdoutLog `
    -RedirectStandardError $xsctStderrLog `
    -PassThru `
    -WindowStyle Hidden
  Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_WRAPPER_XSCT_PID=$($xsctProc.Id)"
  $deadline = (Get-Date).AddSeconds($xsctWallTimeoutEffective)
  while (-not $xsctProc.HasExited -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    $xsctProc.Refresh()
  }
  $xsctTimedOut = $false
  if (-not $xsctProc.HasExited) {
    $xsctTimedOut = $true
    Stop-Process -Id $xsctProc.Id -Force -ErrorAction SilentlyContinue
  }
  if (Test-Path $xsctStdoutLog) {
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_XSCT_STDOUT_BEGIN"
    Get-Content -Path $xsctStdoutLog | Add-Content -Path $xsctLog -Encoding UTF8
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_XSCT_STDOUT_END"
  }
  if (Test-Path $xsctStderrLog) {
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_XSCT_STDERR_BEGIN"
    Get-Content -Path $xsctStderrLog | Add-Content -Path $xsctLog -Encoding UTF8
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_PS_DDR_X4_XSCT_STDERR_END"
  }
  if ($xsctTimedOut) {
    throw "TinySPAN PS DDR XSCT smoke timed out after $xsctWallTimeoutEffective seconds. See $xsctLog"
  }

  $xsctText = Get-Content -Path $xsctLog -Raw
  $xsctExitCode = $xsctProc.ExitCode
  if ($null -eq $xsctExitCode) {
    $xsctExitCode = if ($xsctText -match "TINYSPAN_PS_DDR_X4_XSCT_PASS=1") { 0 } else { -1 }
  }
  if ($xsctExitCode -ne 0) {
    throw "TinySPAN PS DDR XSCT smoke failed with exit code $xsctExitCode. See $xsctLog"
  }
  if ($xsctText -notmatch "TINYSPAN_PS_DDR_X4_XSCT_PASS=1") {
    throw "TinySPAN PS DDR XSCT did not report pass. See $xsctLog"
  }

  $expectedOutPixels = $outW * $outH
  $readPixels = Get-LogValue $xsctText "OUTPUT_READ_PIXELS"
  $boardPngWritten = $false
  if ($ReadbackMode -ne "SKIP") {
    if (-not (Test-Path $boardHex)) {
      throw "XSCT did not produce board output hex: $boardHex"
    }
    $expectedPixelsForRaw = if ($ReadbackMode -eq "FULL") { $expectedOutPixels } else { [int]$readPixels }
    Convert-HexPixelsToRaw -HexPath $boardHex -RawPath $boardRaw -ExpectedPixels $expectedPixelsForRaw
    if ($ReadbackMode -eq "FULL") {
      & $PythonExe tools\convert_rgb_raw.py from-raw $boardRaw $boardPng --width $outW --height $outH
      if ($LASTEXITCODE -ne 0) {
        throw "board raw to PNG conversion failed"
      }
      $boardPngWritten = $true
    }
  }

  $compareSummary = $null
  if ($boardPngWritten -and -not [string]::IsNullOrWhiteSpace($FixedReferencePng)) {
    $FixedReferencePng = Resolve-WorkflowPath $FixedReferencePng
    $TrainingReferencePng = if ([string]::IsNullOrWhiteSpace($TrainingReferencePng)) { $FixedReferencePng } else { Resolve-WorkflowPath $TrainingReferencePng }
    $cmpJson = Join-Path $outDirAbs "board_vs_fixed_summary.json"
    $cmpMd = Join-Path $outDirAbs "board_vs_fixed_summary.md"
    $previewPng = Join-Path $outDirAbs "board_vs_fixed_preview.png"
    $diffPng = Join-Path $outDirAbs "board_vs_fixed_diff_heatmap.png"
    & $PythonExe tools\image_validation\compare_tinyspan_board_software.py `
      --software $TrainingReferencePng `
      --fixed $FixedReferencePng `
      --board $boardPng `
      --preview $previewPng `
      --diff-heatmap $diffPng `
      --summary-json $cmpJson `
      --summary-md $cmpMd
    $compareExit = $LASTEXITCODE
    $compareSummary = if (Test-Path $cmpJson) { Get-Content -Path $cmpJson -Raw | ConvertFrom-Json } else { $null }
    if ($RequireReferenceMatch -and $compareExit -ne 0) {
      throw "board-vs-fixed comparison failed. See $cmpMd"
    }
  }

  $frameCycles = Get-LogValue $xsctText "FRAME_CYCLES"
  $tilesDone = Get-LogValue $xsctText "TILES_DONE"
  $status = Get-LogHexValue $xsctText "STATUS"
  $errorReg = Get-LogHexValue $xsctText "ERROR"
  $fps = $null
  if (-not [string]::IsNullOrWhiteSpace($frameCycles) -and [int64]$frameCycles -gt 0) {
    $fps = ($PlFreqMhz * 1000000.0) / [double]$frameCycles
  }
  $summary = [ordered]@{
    status = "PASS"
    route = "TinySPAN PS DDR X4 via zynq_ultra_ps_e PS DDR controller IP"
    no_custom_ddr_controller_or_phy = $true
    bitstream = $Bitstream
    psu_init_tcl = $PsuInitTcl
    input_png = $InputPng
    input_raw = $inputRaw
    input_words = $inputWords
    board_hex = if (Test-Path $boardHex) { $boardHex } else { "" }
    board_raw = if (Test-Path $boardRaw) { $boardRaw } else { "" }
    board_png = if (Test-Path $boardPng) { $boardPng } else { "" }
    img_w = $ImgW
    img_h = $ImgH
    out_w = $outW
    out_h = $outH
    scale = $Scale
    pl_freq_mhz = $PlFreqMhz
    ctrl_base = $CtrlBase
    input_base = $InputBase
    output_base = $OutputBase
    readback_mode = $ReadbackMode
    output_read_pixels = $readPixels
    frame_cycles = $frameCycles
    fps_from_frame_cycles = $fps
    tiles_done = $tilesDone
    status_reg = $status
    error_reg = $errorReg
    program_log = if (Test-Path $programLog) { $programLog } else { "" }
    xsct_log = $xsctLog
    comparison = $compareSummary
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryJson -Encoding UTF8
  @(
    "# TinySPAN PS/DDR X4 smoke summary",
    "",
    "- Status: PASS",
    "- Route: TinySPAN PS DDR X4 via board PS DDR controller IP",
    "- Custom DDR controller/PHY: no",
    "- Image: ${ImgW}x${ImgH} -> ${outW}x${outH}",
    "- Readback mode: $ReadbackMode",
    "- Frame cycles: $frameCycles",
    "- FPS from frame cycles @ ${PlFreqMhz} MHz: $fps",
    "- Tiles done: $tilesDone",
    "- Status reg: $status",
    "- Error reg: $errorReg",
    "- Bitstream: $Bitstream",
    "- XSCT log: $xsctLog",
    "- Board PNG: $(if (Test-Path $boardPng) { $boardPng } else { '' })",
    "- Summary JSON: $summaryJson"
  ) | Set-Content -Path $summaryMd -Encoding UTF8

  Write-Host "TINYSPAN_PS_DDR_X4_SMOKE_SUMMARY_JSON=$summaryJson"
  Write-Host "TINYSPAN_PS_DDR_X4_SMOKE_SUMMARY_MD=$summaryMd"
  Write-Host "TINYSPAN_PS_DDR_X4_SMOKE_BOARD_PNG=$boardPng"
  Write-Host "TINYSPAN_PS_DDR_X4_SMOKE_FPS=$fps"
  Write-Host "PASS run_ps_tinyspan_ddr_x4_smoke"
} finally {
  Pop-Location
}
