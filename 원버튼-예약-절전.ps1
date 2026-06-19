$ErrorActionPreference = "Stop"

$desktop = [Environment]::GetFolderPath("Desktop")
$minecraftDir = Join-Path $PSScriptRoot "curseforge-server-automation"
$discordDir = Join-Path $PSScriptRoot "discord scheduled message"

$minecraftStartScript = Join-Path $minecraftDir "Start-CurseForgeServer.ps1"
$discordSendScript = Join-Path $discordDir "Send-DiscordMessage.ps1"
$discordConfigPath = Join-Path $discordDir "config.json"
$discordExamplePath = Join-Path $discordDir "config.example.json"

$wakeTaskName = "OneButton Wake 13-50"
$discordTaskName = "OneButton Discord 13-55"
$serverTaskName = "OneButton Minecraft Server Start"

function Get-NextTimeTodayOrTomorrow {
  param([int]$Hour, [int]$Minute)

  $target = (Get-Date).Date.AddHours($Hour).AddMinutes($Minute)
  if ($target -le (Get-Date)) {
    $target = $target.AddDays(1)
  }
  return $target
}

function Assert-File {
  param([string]$Path, [string]$Name)
  if (-not (Test-Path $Path)) {
    throw "$Name 파일을 찾을 수 없습니다: $Path"
  }
}

function Register-OneTimeTask {
  param(
    [string]$TaskName,
    [datetime]$At,
    [string]$ScriptPath,
    [switch]$WakeToRun
  )

  $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
  $action = New-ScheduledTaskAction `
    -Execute $powershell `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

  $trigger = New-ScheduledTaskTrigger -Once -At $At

  if ($WakeToRun) {
    $settings = New-ScheduledTaskSettingsSet `
      -WakeToRun `
      -StartWhenAvailable `
      -AllowStartIfOnBatteries `
      -DontStopIfGoingOnBatteries
  }
  else {
    $settings = New-ScheduledTaskSettingsSet `
      -StartWhenAvailable `
      -AllowStartIfOnBatteries `
      -DontStopIfGoingOnBatteries
  }

  Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Created by Automation Manager one-button flow." `
    -Force | Out-Null
}

Write-Host "=== 원버튼 예약 + 절전 ===" -ForegroundColor Cyan

Assert-File $minecraftStartScript "마인크래프트 서버 시작"
Assert-File $discordSendScript "디스코드 발송"

if (-not (Test-Path $discordConfigPath)) {
  if (Test-Path $discordExamplePath) {
    Copy-Item $discordExamplePath $discordConfigPath
    Write-Host "디스코드 config.json을 예시 파일에서 생성했습니다. WebhookUrl을 설정한 뒤 다시 실행하세요." -ForegroundColor Yellow
    pause
    exit 1
  }
  throw "디스코드 config.json이 없습니다."
}

$discordConfig = Get-Content $discordConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $discordConfig.WebhookUrl -or $discordConfig.WebhookUrl -like "*WEBHOOK_ID*") {
  Write-Host "디스코드 WebhookUrl이 아직 설정되지 않았습니다." -ForegroundColor Yellow
  Write-Host "파일을 열어 WebhookUrl을 넣은 뒤 다시 실행하세요:"
  Write-Host $discordConfigPath
  pause
  exit 1
}

if ($discordConfig.PSObject.Properties.Name -contains "ServerStartTaskName") {
  $discordConfig.ServerStartTaskName = $serverTaskName
}
else {
  $discordConfig | Add-Member -NotePropertyName "ServerStartTaskName" -NotePropertyValue $serverTaskName
}
$discordConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $discordConfigPath -Encoding UTF8

$wakeAt = Get-NextTimeTodayOrTomorrow -Hour 13 -Minute 50
$discordAt = $wakeAt.Date.AddHours(13).AddMinutes(55)
$serverAt = $wakeAt.Date.AddHours(14)

Write-Host "절전 해제 예정: $wakeAt"
Write-Host "디스코드 발송 예정: $discordAt"
Write-Host "서버 실행 예정: $serverAt"

Write-Host "전원 설정을 적용합니다."
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
powercfg /S SCHEME_CURRENT | Out-Null

$wakeScript = Join-Path $env:TEMP "automation-manager-wake-marker.ps1"
Set-Content -Path $wakeScript -Encoding UTF8 -Value "Write-Output 'Wake marker task ran.'"

Register-OneTimeTask -TaskName $wakeTaskName -At $wakeAt -ScriptPath $wakeScript -WakeToRun
Register-OneTimeTask -TaskName $discordTaskName -At $discordAt -ScriptPath $discordSendScript
Register-OneTimeTask -TaskName $serverTaskName -At $serverAt -ScriptPath $minecraftStartScript

Write-Host ""
Write-Host "예약 등록 완료." -ForegroundColor Green
Write-Host "10초 후 컴퓨터를 절전 모드로 전환합니다."
Write-Host "취소하려면 지금 이 창을 닫으세요."
Start-Sleep -Seconds 10

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SleepControl {
  [DllImport("PowrProf.dll", SetLastError = true)]
  public static extern bool SetSuspendState(bool hibernate, bool forceCritical, bool disableWakeEvent);
}
"@

[SleepControl]::SetSuspendState($false, $false, $false) | Out-Null
