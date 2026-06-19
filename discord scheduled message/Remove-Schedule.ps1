$ErrorActionPreference = "Continue"

$configPath = Join-Path $PSScriptRoot "config.json"
$taskName = "Discord Scheduled Message"

if (Test-Path $configPath) {
  $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($config.TaskName) {
    $taskName = $config.TaskName
  }
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "Schedule removed if it existed." -ForegroundColor Green
pause
