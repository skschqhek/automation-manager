$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  Write-Host "config.json이 없습니다." -ForegroundColor Red
  pause
  exit 1
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$managerDir = Split-Path $PSScriptRoot -Parent
$startScript = $config.StartScript.Replace("{Manager}", $managerDir)

Write-Host "=== 디스코드 반응 감지 설정 확인 ===" -ForegroundColor Cyan

function Show-Check {
  param([string]$Name, [bool]$Ok, [string]$Detail)
  if ($Ok) {
    Write-Host "정상: $Name - $Detail" -ForegroundColor Green
  }
  else {
    Write-Host "필요: $Name - $Detail" -ForegroundColor Yellow
  }
}

Show-Check "BotToken" ($config.BotToken -and $config.BotToken -notlike "PUT_*") "디스코드 봇 토큰"
Show-Check "ChannelId" ($config.ChannelId -and $config.ChannelId -notlike "PUT_*") "감시할 채널 ID"
Show-Check "VoteMessage" ([bool]$config.VoteMessage) "봇이 매일 올릴 감시 대상 메시지"
Show-Check "WebhookUrl" ($config.WebhookUrl -and $config.WebhookUrl -notlike "PUT_*" -and $config.WebhookUrl -like "https://discord.com/api/webhooks/*") "공지용 웹후크 URL"
Show-Check "StartScript" (Test-Path $startScript) $startScript

Write-Host ""
Write-Host "EmojiName: $($config.EmojiName)"
Write-Host "EmojiId: $($config.EmojiId)"
Write-Host "AddInitialReaction: $($config.AddInitialReaction)"
Write-Host "Threshold: $($config.Threshold)"
Write-Host "PollSeconds: $($config.PollSeconds)"
Write-Host "PostRetryCount: $($config.PostRetryCount)"
Write-Host "PostRetryDelaySeconds: $($config.PostRetryDelaySeconds)"
Write-Host "VotePostTime: $($config.VotePostTime)"
Write-Host ""
pause
