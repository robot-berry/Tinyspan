param(
    [string]$HostName = "connect.westc.seetacloud.com",
    [int]$Port = 48335,
    [string]$User = "root",
    [string]$PasswordEnv = "SEETA_PASS",
    [string]$LocalRedsRoot = "G:/REDS",
    [string]$RemoteRepo = "/root/autodl-tmp/Tinyspan",
    [string]$RemoteData = "/root/autodl-tmp/data/REDS",
    [int]$ValSequences = 30,
    [int]$Workers = 4,
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
if ($Workers -lt 1) {
    throw "Workers must be >= 1"
}

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$syncScript = Join-Path $PSScriptRoot "sync_reds_and_start_x4_quality_training.py"
$logDir = Join-Path $repoRoot "logs\cloud"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Set-Location $repoRoot

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$chunk = [Math]::Ceiling($ValSequences / [double]$Workers)
$procs = @()

for ($worker = 0; $worker -lt $Workers; $worker++) {
    $start = [int]($worker * $chunk + 1)
    $end = [int]([Math]::Min(($worker + 1) * $chunk, $ValSequences))
    if ($start -gt $ValSequences) {
        continue
    }

    $outLog = Join-Path $logDir ("x4_val_parallel_{0}_worker{1}_{2:D3}_{3:D3}.out.log" -f $stamp, ($worker + 1), $start, $end)
    $errLog = Join-Path $logDir ("x4_val_parallel_{0}_worker{1}_{2:D3}_{3:D3}.err.log" -f $stamp, ($worker + 1), $start, $end)
    $args = @(
        $syncScript,
        "--host", $HostName,
        "--port", "$Port",
        "--user", $User,
        "--password-env", $PasswordEnv,
        "--local-reds-root", $LocalRedsRoot,
        "--remote-repo", $RemoteRepo,
        "--remote-data", $RemoteData,
        "--sync-mode", "sequence-tar",
        "--skip-train",
        "--include-val",
        "--sequence-start", "$start",
        "--sequence-end", "$end",
        "--progress-every", "1"
    )
    $proc = Start-Process -FilePath $Python -ArgumentList $args -RedirectStandardOutput $outLog -RedirectStandardError $errLog -WindowStyle Hidden -PassThru
    $procs += [PSCustomObject]@{ Process = $proc; Worker = ($worker + 1); Start = $start; End = $end; OutLog = $outLog; ErrLog = $errLog }
    Write-Output ("STARTED val_worker={0} pid={1} range={2}-{3} out={4}" -f ($worker + 1), $proc.Id, $start, $end, $outLog)
}

$failed = $false
foreach ($item in $procs) {
    Wait-Process -Id $item.Process.Id
    $proc = $item.Process
    $proc.Refresh()
    Write-Output ("FINISHED val_worker={0} pid={1} range={2}-{3} exit={4}" -f $item.Worker, $proc.Id, $item.Start, $item.End, $proc.ExitCode)
    if ($proc.ExitCode -ne 0) {
        $failed = $true
    }
}

if ($failed) {
    Write-Error "At least one val_sharp upload worker failed. Rerun this wrapper; completed sequences will be skipped."
    exit 1
}

Write-Output ("VAL_SPLITS_DONE={0}" -f (Get-Date -Format o))
exit 0
