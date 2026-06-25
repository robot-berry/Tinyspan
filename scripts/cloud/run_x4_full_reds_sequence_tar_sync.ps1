param(
    [string]$HostName = "connect.westc.seetacloud.com",
    [int]$Port = 48335,
    [string]$User = "root",
    [string]$PasswordEnv = "SEETA_PASS",
    [string]$LocalRedsRoot = "G:/REDS",
    [string]$RemoteRepo = "/root/autodl-tmp/Tinyspan",
    [string]$RemoteData = "/root/autodl-tmp/data/REDS",
    [int]$Attempts = 20,
    [int]$RetrySeconds = 60,
    [string]$Python = "python"
)

$ErrorActionPreference = "Continue"
$repoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")
$syncScript = Join-Path $PSScriptRoot "sync_reds_and_start_x4_quality_training.py"

Set-Location $repoRoot

for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    Write-Output ("SYNC_ATTEMPT={0} START={1}" -f $attempt, (Get-Date -Format o))
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

    $code = $LASTEXITCODE
    Write-Output ("SYNC_ATTEMPT={0} EXIT={1} END={2}" -f $attempt, $code, (Get-Date -Format o))
    if ($code -eq 0) {
        exit 0
    }
    Start-Sleep -Seconds $RetrySeconds
}

exit 1
