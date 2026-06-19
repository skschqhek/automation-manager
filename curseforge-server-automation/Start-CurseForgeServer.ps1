$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "AutomationCommon.psm1") -Force

$config = Get-AutomationConfig
$pidPath = Get-ConfigPath -Config $config -Path $config.PidFile

function Test-ConfiguredValue {
  param([string]$Value)
  return ($Value -and $Value -notlike "CHANGE_ME" -and $Value -notlike "*WEBHOOK_ID*")
}

function Get-DiscordWebhookUrl {
  if (Test-ConfiguredValue $config.DiscordWebhookUrl) {
    return [string]$config.DiscordWebhookUrl
  }

  $managerDir = Split-Path $PSScriptRoot -Parent
  $discordConfigPath = Join-Path $managerDir "discord scheduled message\config.json"
  if (Test-Path $discordConfigPath) {
    $discordConfig = Get-Content $discordConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (Test-ConfiguredValue $discordConfig.WebhookUrl) {
      return [string]$discordConfig.WebhookUrl
    }
  }

  return ""
}

function Get-TimeText {
  param([string]$TimeText)

  $parts = $TimeText.Split(":")
  if ($parts.Count -ne 2) {
    return $TimeText
  }

  return ("{0:00}:{1:00}" -f [int]$parts[0], [int]$parts[1])
}

function Get-OperationWindowText {
  $startText = Get-TimeText $config.StartTime
  $stopText = Get-TimeText $config.StopTime

  $startParts = $startText.Split(":")
  $stopParts = $stopText.Split(":")
  if ($startParts.Count -eq 2 -and $stopParts.Count -eq 2) {
    $start = (Get-Date).Date.AddHours([int]$startParts[0]).AddMinutes([int]$startParts[1])
    $stop = (Get-Date).Date.AddHours([int]$stopParts[0]).AddMinutes([int]$stopParts[1])
    if ($stop -le $start) {
      return "$startText ~ 다음날 $stopText"
    }
  }

  return "$startText ~ $stopText"
}

function Send-StartupAnnouncement {
  if ($config.PSObject.Properties.Name -contains "StartupAnnouncementEnabled" -and $config.StartupAnnouncementEnabled -eq $false) {
    return
  }

  $webhookUrl = Get-DiscordWebhookUrl
  if (-not $webhookUrl) {
    Write-AutomationLog -Config $config -Message "서버 시작 디스코드 공지 생략: WebhookUrl 없음"
    return
  }

  $delaySeconds = 0
  if ($config.StartupAnnouncementDelaySeconds) {
    $delaySeconds = [int]$config.StartupAnnouncementDelaySeconds
  }
  if ($delaySeconds -gt 0) {
    Start-Sleep -Seconds $delaySeconds
  }

  $operationWindow = Get-OperationWindowText
  $startTimeText = Get-TimeText $config.StartTime
  $stopTimeText = Get-TimeText $config.StopTime
  $message = $config.StartupAnnouncementMessage
  if (-not $message) {
    $message = "서버가 켜졌습니다.`n운영 시간: {operationWindow}"
  }

  $message = ([string]$message).
    Replace("{startTime}", $startTimeText).
    Replace("{stopTime}", $stopTimeText).
    Replace("{operationWindow}", $operationWindow)

  Add-Type -AssemblyName System.Net.Http
  $httpClient = [System.Net.Http.HttpClient]::new()
  try {
    $httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("AutomationManager/1.0")
    $body = @{ content = $message } | ConvertTo-Json -Depth 5
    $content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
    $response = $httpClient.PostAsync($webhookUrl, $content).Result
    $responseBody = $response.Content.ReadAsStringAsync().Result
    if (-not $response.IsSuccessStatusCode) {
      throw "Discord webhook failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
    }
    Write-AutomationLog -Config $config -Message "서버 시작 디스코드 공지 전송 완료"
  }
  catch {
    Write-AutomationLog -Config $config -Message "서버 시작 디스코드 공지 실패: $($_.Exception.Message)"
  }
  finally {
    $httpClient.Dispose()
  }
}

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
Send-StartupAnnouncement
