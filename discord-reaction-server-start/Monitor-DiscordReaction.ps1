$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$managerDir = Split-Path $PSScriptRoot -Parent

function Resolve-ManagerPath {
  param([string]$PathText)
  if (-not $PathText) { return "" }
  return $PathText.Replace("{Manager}", $managerDir)
}

function Assert-ConfigValue {
  param([string]$Name, [string]$Value)
  if (-not $Value -or $Value -like "PUT_*") {
    throw "$Name is not configured in config.json."
  }
}

Assert-ConfigValue "BotToken" $config.BotToken
Assert-ConfigValue "ChannelId" $config.ChannelId
Assert-ConfigValue "WebhookUrl" $config.WebhookUrl

if (-not $config.EmojiName -and -not $config.EmojiId) {
  throw "EmojiName or EmojiId must be configured."
}

$threshold = [int]$config.Threshold
if ($threshold -lt 1) {
  throw "Threshold must be 1 or higher."
}

$pollSeconds = [int]$config.PollSeconds
if ($pollSeconds -lt 5) {
  $pollSeconds = 5
}

$startScript = Resolve-ManagerPath $config.StartScript
if (-not (Test-Path $startScript)) {
  throw "StartScript not found: $startScript"
}

$stateFile = $config.StateFile
if (-not [System.IO.Path]::IsPathRooted($stateFile)) {
  $stateFile = Join-Path $PSScriptRoot $stateFile
}

$voteStateFile = $config.VoteStateFile
if (-not $voteStateFile) {
  $voteStateFile = "reaction-vote-message.json"
}
if (-not [System.IO.Path]::IsPathRooted($voteStateFile)) {
  $voteStateFile = Join-Path $PSScriptRoot $voteStateFile
}

Add-Type -AssemblyName System.Net.Http

$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bot", [string]$config.BotToken)
$httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("AutomationManager/1.0")

function Invoke-DiscordGetJson {
  param([Parameter(Mandatory = $true)][string]$Uri)

  $response = $httpClient.GetAsync($Uri).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result
  if ([int]$response.StatusCode -eq 404) {
    throw "Discord API GET failed: 404 Not Found $responseBody"
  }
  if (-not $response.IsSuccessStatusCode) {
    throw "Discord API GET failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
  }

  if ($responseBody) {
    return $responseBody | ConvertFrom-Json
  }

  return $null
}

function Invoke-DiscordDelete {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [switch]$IgnoreMissing
  )

  $response = $httpClient.DeleteAsync($Uri).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result
  if ($IgnoreMissing -and [int]$response.StatusCode -eq 404) {
    return
  }
  if (-not $response.IsSuccessStatusCode) {
    throw "Discord API DELETE failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
  }
}

function Invoke-WebhookPost {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$JsonBody
  )

  $content = [System.Net.Http.StringContent]::new($JsonBody, [System.Text.Encoding]::UTF8, "application/json")
  $response = $httpClient.PostAsync($Uri, $content).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result
  if (-not $response.IsSuccessStatusCode) {
    throw "Webhook POST failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
  }
}

function Get-ActiveMessageId {
  if ($config.MessageId) {
    return [string]$config.MessageId
  }

  if (-not (Test-Path $voteStateFile)) {
    throw "No active vote message exists. Run Post-VoteMessage.ps1 first."
  }

  $voteState = Get-Content $voteStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if (-not $voteState.MessageId) {
    throw "Vote state file has no MessageId: $voteStateFile"
  }

  return [string]$voteState.MessageId
}

function Get-ActiveVoteState {
  if (-not (Test-Path $voteStateFile)) {
    return $null
  }

  try {
    return Get-Content $voteStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
  }
  catch {
    return $null
  }
}

function Remove-ActiveVoteMessage {
  $voteState = Get-ActiveVoteState
  if (-not $voteState -or -not $voteState.MessageId) {
    return
  }

  $channelId = $voteState.ChannelId
  if (-not $channelId) {
    $channelId = $config.ChannelId
  }

  $deleteUri = "https://discord.com/api/v10/channels/$channelId/messages/$($voteState.MessageId)"
  try {
    Invoke-DiscordDelete -Uri $deleteUri -IgnoreMissing
    Remove-Item -Path $voteStateFile -Force -ErrorAction SilentlyContinue
    Write-Host "Vote message deleted after threshold was reached." -ForegroundColor Green
  }
  catch {
    Write-Host "Vote message could not be deleted: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

function Get-DiscordReactionCount {
  $messageId = Get-ActiveMessageId
  $uri = "https://discord.com/api/v10/channels/$($config.ChannelId)/messages/$messageId"
  try {
    $message = Invoke-DiscordGetJson -Uri $uri
  }
  catch {
    if ($_.Exception.Message -like "*404 Not Found*") {
      Remove-Item -Path $voteStateFile -Force -ErrorAction SilentlyContinue
      throw "Active vote message no longer exists. Post a new vote message before monitoring."
    }
    throw
  }

  if (-not $message.reactions) {
    return 0
  }

  foreach ($reaction in $message.reactions) {
    if ($config.EmojiId) {
      if ([string]$reaction.emoji.id -eq [string]$config.EmojiId) {
        return [int]$reaction.count
      }
    }
    elseif ([string]$reaction.emoji.name -eq [string]$config.EmojiName) {
      return [int]$reaction.count
    }
  }

  return 0
}

function Send-WebhookAnnouncement {
  $body = @{
    content = $config.AnnouncementMessage
  } | ConvertTo-Json -Depth 5

  Invoke-WebhookPost -Uri $config.WebhookUrl -JsonBody $body
}

function Start-MinecraftServer {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript
}

Write-Host "Discord reaction monitor started." -ForegroundColor Cyan
Write-Host "ChannelId: $($config.ChannelId)"
Write-Host "MessageId: $(Get-ActiveMessageId)"
Write-Host "Emoji: $($config.EmojiName) $($config.EmojiId)"
Write-Host "Threshold: $threshold"
Write-Host "Poll seconds: $pollSeconds"
Write-Host ""

while ($true) {
  if ((-not $config.AllowRepeat) -and (Test-Path $stateFile)) {
    $triggeredToday = $false
    try {
      $state = Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
      $triggeredToday = ([string]$state.Date -eq (Get-Date).ToString("yyyy-MM-dd"))
    }
    catch {
      $triggeredToday = ((Get-Item $stateFile).LastWriteTime.Date -eq (Get-Date).Date)
    }

    if ($triggeredToday) {
      Write-Host "Already triggered today. Delete this file to allow another trigger:" -ForegroundColor Yellow
      Write-Host $stateFile
      exit 0
    }

    Remove-Item -Path $stateFile -Force
  }

  try {
    $count = Get-DiscordReactionCount
    Write-Host ("{0} reaction count: {1}/{2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $count, $threshold)

    if ($count -ge $threshold) {
      Write-Host "Threshold reached. Starting Minecraft server..." -ForegroundColor Green
      Remove-ActiveVoteMessage
      Start-MinecraftServer
      Send-WebhookAnnouncement
      $state = [ordered]@{
        Date = (Get-Date).ToString("yyyy-MM-dd")
        TriggeredAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Count = $count
        MessageId = Get-ActiveMessageId
      }
      $state | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8

      if (-not $config.AllowRepeat) {
        Write-Host "Done. Monitor will now exit because AllowRepeat is false." -ForegroundColor Green
        exit 0
      }
    }
  }
  catch {
    Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
    if ($_.Exception.Message -like "*Post a new vote message*" -or $_.Exception.Message -like "*No active vote message*") {
      Write-Host "Monitor stopped. Post a new vote message first, then start monitoring again." -ForegroundColor Yellow
      exit 1
    }
  }

  Start-Sleep -Seconds $pollSeconds
}
