param(
    [string]$WorkerPids = "",
    [string]$HostName = "connect.westc.seetacloud.com",
    [int]$Port = 48335,
    [string]$User = "root",
    [string]$PasswordEnv = "SEETA_PASS",
    [string]$LocalRedsRoot = "G:/REDS",
    [string]$RemoteRepo = "/root/autodl-tmp/Tinyspan",
    [string]$RemoteData = "/root/autodl-tmp/data/REDS",
    [string]$Python = "python",
    [int]$PollSeconds = 120
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$syncScript = Join-Path $PSScriptRoot "sync_reds_and_start_x4_quality_training.py"
Set-Location $repoRoot

Write-Output ("WATCH_X4_FINAL_START={0}" -f (Get-Date -Format o))
$workerPidValues = @()
if (-not [string]::IsNullOrWhiteSpace($WorkerPids)) {
    $workerPidValues = @($WorkerPids -split "[,\s]+" | Where-Object { $_ } | ForEach-Object { [int]$_ })
}
Write-Output ("WORKER_PIDS={0}" -f ($workerPidValues -join ","))

while ($true) {
    $alive = @()
    foreach ($workerPid in $workerPidValues) {
        $proc = Get-Process -Id $workerPid -ErrorAction SilentlyContinue
        if ($proc) {
            $alive += $workerPid
        }
    }
    if ($alive.Count -eq 0) {
        break
    }
    Write-Output ("WATCH_X4_FINAL_WAIT alive={0} time={1}" -f ($alive -join ","), (Get-Date -Format o))
    Start-Sleep -Seconds $PollSeconds
}

Write-Output ("WATCH_X4_FINAL_RUN_SYNC={0}" -f (Get-Date -Format o))
& $Python $syncScript `
    --host $HostName `
    --port $Port `
    --user $User `
    --password-env $PasswordEnv `
    --local-reds-root $LocalRedsRoot `
    --remote-repo $RemoteRepo `
    --remote-data $RemoteData `
    --sync-mode sequence-tar `
    --include-val `
    --start-training `
    --progress-every 1

if ($LASTEXITCODE -ne 0) {
    throw "Final REDS verification/start-training sync failed with exit code $LASTEXITCODE"
}

Write-Output ("WATCH_X4_FINAL_DONE={0}" -f (Get-Date -Format o))
exit 0
