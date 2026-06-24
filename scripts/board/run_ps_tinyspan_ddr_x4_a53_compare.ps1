param(
  [string]$VivadoBat = "D:\software\2025.2\Vivado\bin\vivado.bat",
  [string]$XsctBat = "D:\software\2025.2\Vitis\bin\xsct.bat",
  [string]$Gcc = "D:\software\2025.2\gnu\aarch64\nt\aarch64-none\bin\aarch64-none-elf-gcc.exe",
  [string]$Bitstream = "",
  [string]$PsuInitTcl = "",
  [string]$InputPng = "",
  [string]$FixedReferencePng = "",
  [int]$ImgW = 320,
  [int]$ImgH = 180,
  [int]$Scale = 4,
  [int]$PlFreqMhz = 155,
  [string]$CtrlBase = "0xA0000000",
  [string]$InputBase = "0x10000000",
  [string]$OutputBase = "0x11000000",
  [string]$ReferenceBase = "0x14000000",
  [int]$WaitMs = 1000,
  [int]$CompareTimeoutMs = 30000,
  [int]$XsctWallTimeoutSeconds = 600,
  [string]$OutputDir = "",
  [string]$PythonExe = "D:\software\anaconda\python.exe",
  [switch]$NoProgram
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$srcDir = Join-Path $root "software\ps_a53_frame_compare"

function Resolve-WorkflowPath {
  param([string]$PathValue)
  if ([string]::IsNullOrWhiteSpace($PathValue)) { return "" }
  if ([System.IO.Path]::IsPathRooted($PathValue)) {
    return [System.IO.Path]::GetFullPath($PathValue)
  }
  $underTinyspan = [System.IO.Path]::GetFullPath((Join-Path $root $PathValue))
  if (Test-Path $underTinyspan) { return $underTinyspan }
  return [System.IO.Path]::GetFullPath((Join-Path (Split-Path $root -Parent) $PathValue))
}

function Get-LatestPsuInitTcl {
  $candidate = Get-ChildItem -Path (Join-Path $root "vivado") -Recurse -Filter "psu_init.tcl" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match "\\pstinyspanx4ddr_ps_0\\psu_init\.tcl$" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($null -eq $candidate) {
    throw "Could not find TinySPAN PS DDR psu_init.tcl."
  }
  return $candidate.FullName
}

function Convert-HexStringToUInt32 {
  param([string]$Value)
  $text = $Value.Trim()
  if ($text.StartsWith("0x", [StringComparison]::OrdinalIgnoreCase)) {
    return [Convert]::ToUInt32($text.Substring(2), 16)
  }
  return [Convert]::ToUInt32($text, 10)
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

function New-PoisonWordsBin {
  param([string]$OutPath, [int]$Pixels)
  $words = New-Object byte[] ($Pixels * 4)
  for ($i = 0; $i -lt $Pixels; $i++) {
    $words[$i * 4 + 0] = 0x5a
    $words[$i * 4 + 1] = 0x5a
    $words[$i * 4 + 2] = 0x5a
    $words[$i * 4 + 3] = 0
  }
  [System.IO.File]::WriteAllBytes($OutPath, $words)
}

function Get-LogValue {
  param([string]$Text, [string]$Name)
  $m = [regex]::Match($Text, "TINYSPAN_A53_COMPARE_$Name=([0-9]+)")
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

function Get-LogHexValue {
  param([string]$Text, [string]$Name)
  $m = [regex]::Match($Text, "TINYSPAN_A53_COMPARE_$Name=(0x[0-9A-Fa-f]+)")
  if ($m.Success) { return $m.Groups[1].Value }
  return ""
}

Push-Location $root
try {
  if (-not (Test-Path $XsctBat)) { throw "XSCT executable not found: $XsctBat" }
  if (-not (Test-Path $Gcc)) { throw "AArch64 GCC not found: $Gcc" }
  if (-not (Test-Path $PythonExe)) { throw "Python executable not found: $PythonExe" }
  if (-not $NoProgram -and -not (Test-Path $VivadoBat)) { throw "Vivado batch executable not found: $VivadoBat" }

  if ([string]::IsNullOrWhiteSpace($Bitstream)) {
    $Bitstream = Join-Path $root "vivado\ps_tinyspan_ddr_x4_tile64_fifo_f155\ps_tinyspan_ddr_x4.runs\impl_1\pstinyspanx4ddr_wrapper.bit"
  } else {
    $Bitstream = Resolve-WorkflowPath $Bitstream
  }
  if ([string]::IsNullOrWhiteSpace($PsuInitTcl)) {
    $PsuInitTcl = Get-LatestPsuInitTcl
  } else {
    $PsuInitTcl = Resolve-WorkflowPath $PsuInitTcl
  }
  if ([string]::IsNullOrWhiteSpace($InputPng)) {
    $InputPng = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile32_20260624\lr_input_resized.png"
  }
  if ([string]::IsNullOrWhiteSpace($FixedReferencePng)) {
    $FixedReferencePng = "artifacts\20260618_x4_tinyspan_c32b4_baseline_30fps_safe\full_frame_tiled_reference_x4_320x180_tile64_fifo_f155_20260625\software_tiled_fixed_point_sr.png"
  }
  $InputPng = Resolve-WorkflowPath $InputPng
  $FixedReferencePng = Resolve-WorkflowPath $FixedReferencePng

  foreach ($path in @($Bitstream, $PsuInitTcl, $InputPng, $FixedReferencePng)) {
    if (-not (Test-Path $path)) { throw "Required path not found: $path" }
  }

  if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputDir = "board_runs\tinyspan_ps_ddr_x4_a53_compare\x4_${ImgW}x${ImgH}_tile64_fifo_f155_$stamp"
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
  $inPixels = $ImgW * $ImgH
  $outPixels = $outW * $outH
  $inputRaw = Join-Path $outDirAbs "input_rgb888_${ImgW}x${ImgH}.rgb"
  $inputWords = Join-Path $outDirAbs "input_words_${ImgW}x${ImgH}.bin"
  $referenceRaw = Join-Path $outDirAbs "reference_rgb888_${outW}x${outH}.rgb"
  $poisonWords = Join-Path $outDirAbs "output_poison_words_${outW}x${outH}.bin"
  $elf = Join-Path $outDirAbs "ps_a53_frame_compare.elf"
  $xsctLog = Join-Path $outDirAbs "tinyspan_a53_compare.log"
  $stdout = [System.IO.Path]::ChangeExtension($xsctLog, ".stdout.log")
  $stderr = [System.IO.Path]::ChangeExtension($xsctLog, ".stderr.log")
  $programLog = Join-Path $outDirAbs "program\program_tinyspan_ps_ddr_bitstream.log"
  $programJournal = Join-Path $outDirAbs "program\program_tinyspan_ps_ddr_bitstream.jou"
  $summaryJson = Join-Path $outDirAbs "tinyspan_a53_compare_summary.json"
  $summaryMd = Join-Path $outDirAbs "tinyspan_a53_compare_summary.md"

  & $PythonExe tools\convert_rgb_raw.py to-raw $InputPng $inputRaw --width $ImgW --height $ImgH
  if ($LASTEXITCODE -ne 0) { throw "input PNG to raw conversion failed" }
  & $PythonExe tools\convert_rgb_raw.py to-raw $FixedReferencePng $referenceRaw --width $outW --height $outH
  if ($LASTEXITCODE -ne 0) { throw "fixed reference PNG to raw conversion failed" }
  Convert-Rgb888RawToWordsBin -RawPath $inputRaw -OutPath $inputWords -Pixels $inPixels
  New-PoisonWordsBin -OutPath $poisonWords -Pixels $outPixels

  $outputBaseU32 = Convert-HexStringToUInt32 $OutputBase
  $referenceBaseU32 = Convert-HexStringToUInt32 $ReferenceBase
  & $Gcc -mcpu=cortex-a53 -ffreestanding -fno-builtin -nostdlib "-Wl,-T,$(Join-Path $srcDir "linker.ld")" `
    "-DOUTPUT_BASE=0x$($outputBaseU32.ToString('X8'))UL" `
    "-DREFERENCE_BASE=0x$($referenceBaseU32.ToString('X8'))UL" `
    "-DPIXEL_COUNT=$($outPixels)UL" `
    (Join-Path $srcDir "startup.S") (Join-Path $srcDir "main.c") -o $elf
  if ($LASTEXITCODE -ne 0) { throw "A53 frame compare ELF build failed" }

  if (-not $NoProgram) {
    Write-Host "TINYSPAN_A53_COMPARE_PROGRAM_LOG=$programLog"
    & $VivadoBat -mode batch -log $programLog -journal $programJournal -source scripts\board\program_tinyspan_ps_ddr_bitstream.tcl -tclargs $Bitstream
    if ($LASTEXITCODE -ne 0) { throw "TinySPAN PS DDR bitstream programming failed with exit code $LASTEXITCODE" }
  }

  Remove-Item -Path $xsctLog,$stdout,$stderr -Force -ErrorAction SilentlyContinue
  $xsctArgs = @(
    "scripts\board\run_xsct_ps_tinyspan_ddr_x4_a53_compare.tcl",
    $PsuInitTcl,
    $elf,
    $inputWords,
    $referenceRaw,
    $poisonWords,
    $CtrlBase,
    [string]$ImgW,
    [string]$ImgH,
    [string]$Scale,
    $InputBase,
    $OutputBase,
    $ReferenceBase,
    [string]$WaitMs,
    [string]$CompareTimeoutMs
  )
  $proc = Start-Process -FilePath $XsctBat `
    -ArgumentList $xsctArgs `
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
    throw "TinySPAN A53 compare XSCT timed out after $XsctWallTimeoutSeconds seconds"
  }
  if (Test-Path $stdout) { Get-Content -Path $stdout | Set-Content -Path $xsctLog -Encoding UTF8 }
  if (Test-Path $stderr) {
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_A53_COMPARE_STDERR_BEGIN"
    Get-Content -Path $stderr | Add-Content -Path $xsctLog -Encoding UTF8
    Add-Content -Path $xsctLog -Encoding UTF8 -Value "TINYSPAN_A53_COMPARE_STDERR_END"
  }
  $text = Get-Content -Path $xsctLog -Raw
  $exitCode = $proc.ExitCode
  if ($null -eq $exitCode) {
    $exitCode = if ($text -match "TINYSPAN_A53_COMPARE_PASS=1") { 0 } else { -1 }
  }
  if ($exitCode -ne 0 -or $text -notmatch "TINYSPAN_A53_COMPARE_PASS=1") {
    throw "TinySPAN A53 frame compare failed with exit code $exitCode. See $xsctLog"
  }

  $frameCycles = 5097068
  $fps = ($PlFreqMhz * 1000000.0) / [double]$frameCycles
  $summary = [ordered]@{
    status = "PASS"
    route = "TinySPAN PS DDR X4 via zynq_ultra_ps_e PS DDR controller IP; A53 in-DDR compare"
    no_custom_ddr_controller_or_phy = $true
    bitstream = $Bitstream
    psu_init_tcl = $PsuInitTcl
    input_png = $InputPng
    fixed_reference_png = $FixedReferencePng
    img_w = $ImgW
    img_h = $ImgH
    out_w = $outW
    out_h = $outH
    scale = $Scale
    pl_freq_mhz = $PlFreqMhz
    wait_ms = $WaitMs
    compare_timeout_ms = $CompareTimeoutMs
    ctrl_base = $CtrlBase
    input_base = $InputBase
    output_base = $OutputBase
    reference_base = $ReferenceBase
    mismatch_bytes = Get-LogValue $text "MISMATCH_BYTES"
    total_bytes = Get-LogValue $text "TOTAL_BYTES"
    max_diff = Get-LogValue $text "MAX_DIFF"
    first_mismatch_pixel = Get-LogValue $text "FIRST_MISMATCH_PIXEL"
    first_expected = Get-LogHexValue $text "FIRST_EXPECTED"
    first_actual = Get-LogHexValue $text "FIRST_ACTUAL"
    compare_pass = $true
    throughput_evidence = [ordered]@{
      source = "x4_320x180_tile64_fifo_f155_skipread_20260625_0412"
      frame_cycles = $frameCycles
      fps_from_frame_cycles = $fps
    }
    xsct_log = $xsctLog
    elf = $elf
  }
  $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryJson -Encoding UTF8
  @(
    "# TinySPAN PS/DDR X4 A53 frame compare summary",
    "",
    "- Status: PASS",
    "- Route: board PS DDR controller IP + A53 in-DDR compare",
    "- Custom DDR controller/PHY: no",
    "- Image: ${ImgW}x${ImgH} -> ${outW}x${outH}",
    "- Fixed wait: ${WaitMs} ms",
    "- Mismatch bytes: $($summary.mismatch_bytes) / $($summary.total_bytes)",
    "- Max diff: $($summary.max_diff)",
    "- Throughput evidence: $($fps) fps from prior SKIP-read frame_cycles=$frameCycles @ ${PlFreqMhz}MHz",
    "- XSCT log: $xsctLog",
    "- Summary JSON: $summaryJson"
  ) | Set-Content -Path $summaryMd -Encoding UTF8

  Write-Host "TINYSPAN_A53_COMPARE_SUMMARY_JSON=$summaryJson"
  Write-Host "TINYSPAN_A53_COMPARE_SUMMARY_MD=$summaryMd"
  Write-Host "TINYSPAN_A53_COMPARE_MISMATCH_BYTES=$($summary.mismatch_bytes)"
  Write-Host "TINYSPAN_A53_COMPARE_MAX_DIFF=$($summary.max_diff)"
  Write-Host "PASS run_ps_tinyspan_ddr_x4_a53_compare"
} finally {
  Pop-Location
}
