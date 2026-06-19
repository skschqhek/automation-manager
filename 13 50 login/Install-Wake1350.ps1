$ErrorActionPreference = "Stop"

$taskName = "Wake PC At 13-50"
$wakeTime = "13:50"
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

Write-Host "=== 13:50 절전 해제 설정 ===" -ForegroundColor Cyan

Write-Host ""
Write-Host "[1] 현재 전원 계획에서 절전 해제 타이머를 켭니다."
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_SLEEP RTCWAKE 1 | Out-Null

Write-Host "[2] 절전 해제 후 암호 요구를 끕니다."
powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0 | Out-Null
powercfg /S SCHEME_CURRENT | Out-Null

Write-Host "[3] 매일 13:50에 PC를 깨우는 예약 작업을 등록합니다."

$action = New-ScheduledTaskAction `
  -Execute $powershell `
  -Argument "-NoProfile -WindowStyle Hidden -Command `"Write-Output 'Wake task ran at 13:50'`""

$trigger = New-ScheduledTaskTrigger -Daily -At $wakeTime

$settings = New-ScheduledTaskSettingsSet `
  -WakeToRun `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Description "Wake this PC from sleep every day at 13:50." `
  -Force | Out-Null

Write-Host ""
Write-Host "완료되었습니다." -ForegroundColor Green
Write-Host "PC가 절전 상태이고 전원이 연결되어 있으면 매일 13:50에 깨어납니다."
Write-Host "이미 로그인된 상태에서 절전했다면, 암호 입력 없이 바탕화면으로 돌아가도록 설정했습니다."
Write-Host ""
Write-Host "확인 명령:"
Write-Host "Get-ScheduledTask -TaskName `"$taskName`""
Write-Host ""
pause
