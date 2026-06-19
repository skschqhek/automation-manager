$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "AutomationCommon.psm1") -Force

$config = Get-AutomationConfig
$pidPath = Get-ConfigPath -Config $config -Path $config.PidFile

if (Test-Path $pidPath) {
  $existingPid = Get-Content $pidPath -Raw
  if ($existingPid -match "^\d+$") {
    $existingProcess = Get-Process -Id ([int]$existingPid) -ErrorAction SilentlyContinue
    if ($existingProcess) {
      Write-AutomationLog -Config $config -Message "서버가 이미 실행 중입니다. PID=$existingPid"
      exit 0
    }
  }
}

if (-not (Test-Path $config.ServerDir)) {
  throw "서버 폴더를 찾을 수 없습니다: $($config.ServerDir)"
}

$process = Start-Process -FilePath "cmd.exe" `
  -ArgumentList "/c $($config.StartCommand)" `
  -WorkingDirectory $config.ServerDir `
  -PassThru `
  -WindowStyle Hidden

Set-Content -Path $pidPath -Value $process.Id
Write-AutomationLog -Config $config -Message "서버 시작 요청 완료. PID=$($process.Id)"
