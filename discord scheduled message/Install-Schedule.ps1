$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$taskName = $config.TaskName
if (-not $taskName) {
  $taskName = "Discord Scheduled Message"
}

$noticeMinutesBeforeStart = 10
if ($config.NoticeMinutesBeforeStart) {
  $noticeMinutesBeforeStart = [int]$config.NoticeMinutesBeforeStart
}
if ($noticeMinutesBeforeStart -lt 1) {
  throw "NoticeMinutesBeforeStart must be 1 or higher."
}

$managerDir = Split-Path $PSScriptRoot -Parent
$minecraftConfigPath = Join-Path $managerDir "curseforge-server-automation\config.json"
if (-not (Test-Path $minecraftConfigPath)) {
  throw "Minecraft config.json not found: $minecraftConfigPath"
}

$minecraftConfig = Get-Content $minecraftConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $minecraftConfig.StartTime) {
  throw "StartTime is empty in Minecraft config.json."
}

$parts = ([string]$minecraftConfig.StartTime).Split(":")
if ($parts.Count -ne 2) {
  throw "Minecraft StartTime must be HH:mm, for example 14:00."
}

$serverStartAt = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
$at = $serverStartAt.AddMinutes(-1 * $noticeMinutesBeforeStart)
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
Write-Host "Minecraft start time: $($minecraftConfig.StartTime)"
Write-Host "Discord notice time: $($at.ToString('HH:mm')) ($noticeMinutesBeforeStart minutes before server start)"
