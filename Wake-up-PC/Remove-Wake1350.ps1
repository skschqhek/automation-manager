$ErrorActionPreference = "Continue"

$taskName = "Wake PC At 13-50"

Write-Host "=== 13:50 절전 해제 설정 제거 ===" -ForegroundColor Cyan

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "예약 작업을 제거했습니다." -ForegroundColor Green
Write-Host "암호 요구 설정은 Windows 설정에서 직접 다시 켜는 것을 권장합니다."
Write-Host ""
pause
