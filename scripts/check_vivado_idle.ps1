param(
  [int]$WaitSeconds = 0,
  [int]$PollSeconds = 30,
  [int]$StableIdleSeconds = 0
)

$ErrorActionPreference = "Stop"

function Get-VivadoProcesses {
  $names = @(
    "vivado",
    "vivado_lab",
    "parallel_synth_helper",
    "rdi_xsdb",
    "hw_server",
    "cs_server",
    "xelab",
    "xsim",
    "xvlog",
    "xvhdl"
  )
  @(Get-Process -Name $names -ErrorAction SilentlyContinue | Sort-Object ProcessName, Id)
}

$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ($true) {
  $vivado = Get-VivadoProcesses
  if ($vivado.Count -eq 0) {
    if ($StableIdleSeconds -gt 0) {
      Write-Host "VIVADO_IDLE_CANDIDATE=1"
      Start-Sleep -Seconds $StableIdleSeconds
      $vivadoAfterStableWindow = Get-VivadoProcesses
      if ($vivadoAfterStableWindow.Count -ne 0) {
        Write-Host "VIVADO_IDLE_STABLE=0"
        $vivado = $vivadoAfterStableWindow
      } else {
        Write-Host "VIVADO_IDLE_STABLE=1"
        Write-Host "VIVADO_IDLE=1"
        return
      }
    } else {
      Write-Host "VIVADO_IDLE=1"
      return
    }
  }

  Write-Host "VIVADO_IDLE=0"
  foreach ($p in $vivado) {
    $workingSetMb = [math]::Round($p.WorkingSet64 / 1MB)
    $cpu = if ($null -eq $p.CPU) { "" } else { "{0:F3}" -f $p.CPU }
    Write-Host "VIVADO_PROCESS PID=$($p.Id) CPU=$cpu WORKING_SET_MB=$workingSetMb START=$($p.StartTime)"
  }

  if ($WaitSeconds -le 0 -or (Get-Date) -ge $deadline) {
    throw "Vivado is not idle; refusing to start another Vivado job"
  }
  Start-Sleep -Seconds $PollSeconds
}
