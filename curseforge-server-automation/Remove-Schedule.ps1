$ErrorActionPreference = "Continue"

$taskNames = @(
  "CurseForge Server Start",
  "CurseForge Server Stop With Notice",
  "OneButton Minecraft Server Start"
)

Write-Host "=== 서버 예약 해제 ===" -ForegroundColor Cyan

foreach ($taskName in $taskNames) {
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($task) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "삭제됨: $taskName" -ForegroundColor Green
  }
  else {
    Write-Host "없음: $taskName" -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "서버 시작/종료 예약 해제가 완료되었습니다."
pause
