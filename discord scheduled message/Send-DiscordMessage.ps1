param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $config.WebhookUrl -or $config.WebhookUrl -like "*WEBHOOK_ID*") {
  throw "WebhookUrl is not configured in config.json."
}

if (-not $config.Message) {
  throw "Message is empty in config.json."
}

$today = (Get-Date).Date
$serverStartTaskNames = New-Object System.Collections.Generic.List[string]
if ($config.ServerStartTaskNames) {
  foreach ($name in $config.ServerStartTaskNames) {
    if ($name -and -not $serverStartTaskNames.Contains([string]$name)) {
      $serverStartTaskNames.Add([string]$name)
    }
  }
}
if ($config.ServerStartTaskName -and -not $serverStartTaskNames.Contains([string]$config.ServerStartTaskName)) {
  $serverStartTaskNames.Add([string]$config.ServerStartTaskName)
}
foreach ($name in @("OneButton Minecraft Server Start", "CurseForge Server Start")) {
  if (-not $serverStartTaskNames.Contains($name)) {
    $serverStartTaskNames.Add($name)
  }
}

$matchedTaskInfo = $null
$matchedTaskName = $null
foreach ($taskName in $serverStartTaskNames) {
  $serverTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if (-not $serverTask) {
    continue
  }

  $serverTaskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
  if ($serverTaskInfo -and $serverTaskInfo.NextRunTime -and $serverTaskInfo.NextRunTime.Date -eq $today) {
    $matchedTaskInfo = $serverTaskInfo
    $matchedTaskName = $taskName
    break
  }
}

if (-not $matchedTaskInfo -and -not $Force) {
  Write-Host "Minecraft server is not scheduled to start today. Discord message skipped." -ForegroundColor Yellow
  exit 0
}

$body = @{
  content = $config.Message
} | ConvertTo-Json -Depth 5

Add-Type -AssemblyName System.Net.Http
$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("AutomationManager/1.0")
$content = [System.Net.Http.StringContent]::new($body, [System.Text.Encoding]::UTF8, "application/json")
$response = $httpClient.PostAsync([string]$config.WebhookUrl, $content).Result
$responseBody = $response.Content.ReadAsStringAsync().Result
if (-not $response.IsSuccessStatusCode) {
  throw "Discord webhook failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
}
$httpClient.Dispose()

if ($Force) {
  Write-Host "Discord test message sent." -ForegroundColor Green
}
else {
  Write-Host "Discord message sent because the Minecraft server is scheduled to start today: $matchedTaskName at $($matchedTaskInfo.NextRunTime)" -ForegroundColor Green
}


