$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $config.SendTime) {
  throw "SendTime is empty in config.json."
}

$taskName = $config.TaskName
if (-not $taskName) {
  $taskName = "Discord Scheduled Message"
}

$parts = $config.SendTime.Split(":")
if ($parts.Count -ne 2) {
  throw "SendTime must be HH:mm, for example 13:50."
}

$at = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$sendScript = Join-Path $PSScriptRoot "Send-DiscordMessage.ps1"

$action = New-ScheduledTaskAction `
  -Execute $powershell `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$sendScript`""

$trigger = New-ScheduledTaskTrigger -Daily -At $at

$settings = New-ScheduledTaskSettingsSet `
  -StartWhenAvailable `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Description "Check daily at the configured time, and send only when the Minecraft server is scheduled to start today." `
  -Force | Out-Null

Write-Host "Schedule installed." -ForegroundColor Green
Write-Host "Task name: $taskName"
Write-Host "Send time: $($config.SendTime)"

