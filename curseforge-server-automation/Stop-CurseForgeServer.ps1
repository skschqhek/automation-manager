$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "AutomationCommon.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "MinecraftRcon.psm1") -Force

$config = Get-AutomationConfig
$stopAt = Get-NextDateTime -TimeText $config.StopTime
$warningMinutes = @($config.WarningMinutes | Sort-Object -Descending)

function Send-ServerCommand {
  param([Parameter(Mandatory = $true)][string]$Command)

  Invoke-MinecraftRcon `
    -HostName $config.RconHost `
    -Port $config.RconPort `
    -Password $config.RconPassword `
    -Command $Command | Out-Null
}

foreach ($minute in $warningMinutes) {
  $announceAt = $stopAt.AddMinutes(-[int]$minute)
  $seconds = [int]($announceAt - (Get-Date)).TotalSeconds
  if ($seconds -gt 0) {
    Start-Sleep -Seconds $seconds
  }

  if ((Get-Date) -lt $stopAt) {
    $message = $config.WarningMessageTemplate.Replace("{minutes}", [string]$minute)
    Send-ServerCommand -Command "say $message"
    Write-AutomationLog -Config $config -Message "Shutdown notice sent: $minute minutes before stop"
  }
}

$remainingSeconds = [int]($stopAt - (Get-Date)).TotalSeconds
if ($remainingSeconds -gt 0) {
  Start-Sleep -Seconds $remainingSeconds
}

Write-AutomationLog -Config $config -Message "Sending save and stop commands"
Send-ServerCommand -Command "say $($config.StopNowMessage)"
Send-ServerCommand -Command "save-all"
Start-Sleep -Seconds 5
Send-ServerCommand -Command $config.StopCommand

$pidPath = Get-ConfigPath -Config $config -Path $config.PidFile
if (Test-Path $pidPath) {
  $pidText = Get-Content $pidPath -Raw
  if ($pidText -match "^\d+$") {
    $deadline = (Get-Date).AddSeconds([int]$config.ForceKillAfterSeconds)
    while ((Get-Date) -lt $deadline) {
      if (-not (Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $pidPath -Force
        Write-AutomationLog -Config $config -Message "Server stopped normally"
        exit 0
      }
      Start-Sleep -Seconds 5
    }

    $process = Get-Process -Id ([int]$pidText) -ErrorAction SilentlyContinue
    if ($process) {
      Stop-ProcessTree -ProcessId ([int]$pidText)
      Write-AutomationLog -Config $config -Message "Forced process tree stop. PID=$pidText"
    }
  }

  Remove-Item -Path $pidPath -Force
}
