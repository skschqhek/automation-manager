$ErrorActionPreference = "Stop"

Write-Host "Sending test Discord message..." -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "Send-DiscordMessage.ps1") -Force
Write-Host "Test complete." -ForegroundColor Green
pause
