$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "AutomationCommon.psm1") -Force

$config = Get-AutomationConfig
$scriptRoot = $PSScriptRoot
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

function New-DailyTriggerFromText {
  param([Parameter(Mandatory = $true)][string]$TimeText)

  $parts = $TimeText.Split(":")
  if ($parts.Count -ne 2) {
    throw "시간 형식은 HH:mm 이어야 합니다: $TimeText"
  }

  $at = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
  New-ScheduledTaskTrigger -Daily -At $at
}

$maxWarning = (@($config.WarningMinutes) | Measure-Object -Maximum).Maximum
$stopNoticeAt = (Get-NextDateTime -TimeText $config.StopTime).AddMinutes(-[int]$maxWarning)
$stopNoticeText = $stopNoticeAt.ToString("HH:mm")

$startAction = New-ScheduledTaskAction `
  -Execute $powershell `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptRoot\Start-CurseForgeServer.ps1`""

$stopAction = New-ScheduledTaskAction `
  -Execute $powershell `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptRoot\Stop-CurseForgeServer.ps1`""

$startTrigger = New-DailyTriggerFromText -TimeText $config.StartTime
$stopTrigger = New-DailyTriggerFromText -TimeText $stopNoticeText

Register-ScheduledTask `
  -TaskName "CurseForge Server Start" `
  -Action $startAction `
  -Trigger $startTrigger `
  -Description "CurseForge Minecraft server auto start" `
  -Force | Out-Null

Register-ScheduledTask `
  -TaskName "CurseForge Server Stop With Notice" `
  -Action $stopAction `
  -Trigger $stopTrigger `
  -Description "CurseForge Minecraft server shutdown notices and stop" `
  -Force | Out-Null

Write-Output "예약 작업 등록 완료"
Write-Output "서버 시작: 매일 $($config.StartTime)"
Write-Output "종료 공지 시작: 매일 $stopNoticeText"
Write-Output "서버 종료: 매일 $($config.StopTime)"
