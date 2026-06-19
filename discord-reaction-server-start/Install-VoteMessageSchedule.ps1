$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$votePostTime = $config.VotePostTime
if (-not $votePostTime) {
  $votePostTime = "13:00"
}

$taskName = $config.VoteTaskName
if (-not $taskName) {
  $taskName = "Discord Reaction Vote Message"
}

$parts = $votePostTime.Split(":")
if ($parts.Count -ne 2) {
  throw "VotePostTime must be HH:mm, for example 13:00."
}

$at = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$postScript = Join-Path $PSScriptRoot "Post-VoteMessage.ps1"

$action = New-ScheduledTaskAction `
  -Execute $powershell `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$postScript`""

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
  -Description "Post the daily Discord reaction vote message." `
  -Force | Out-Null

Write-Host "Vote message schedule installed." -ForegroundColor Green
Write-Host "Task name: $taskName"
Write-Host "Post time: $votePostTime"
