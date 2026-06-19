$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
if (-not (Test-Path $configPath)) {
  throw "config.json not found. Copy config.example.json to config.json, then edit it."
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Assert-ConfigValue {
  param([string]$Name, [string]$Value)
  if (-not $Value -or $Value -like "PUT_*") {
    throw "$Name is not configured in config.json."
  }
}

Assert-ConfigValue "BotToken" $config.BotToken
Assert-ConfigValue "ChannelId" $config.ChannelId

if (-not $config.VoteMessage) {
  throw "VoteMessage is empty in config.json."
}

$postRetryCount = [int]$config.PostRetryCount
if ($postRetryCount -lt 1) {
  $postRetryCount = 5
}

$postRetryDelaySeconds = [int]$config.PostRetryDelaySeconds
if ($postRetryDelaySeconds -lt 1) {
  $postRetryDelaySeconds = 10
}

function Invoke-WithRetry {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Operation,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $lastError = $null
  for ($attempt = 1; $attempt -le $postRetryCount; $attempt++) {
    try {
      Write-Host "$Name attempt $attempt/$postRetryCount"
      return & $Operation
    }
    catch {
      $lastError = $_
      Write-Host "$Name failed: $($_.Exception.Message)" -ForegroundColor Yellow
      if ($attempt -lt $postRetryCount) {
        Write-Host "Retrying in $postRetryDelaySeconds seconds..."
        Start-Sleep -Seconds $postRetryDelaySeconds
      }
    }
  }

  throw $lastError
}

$voteStateFile = $config.VoteStateFile
if (-not $voteStateFile) {
  $voteStateFile = "reaction-vote-message.json"
}
if (-not [System.IO.Path]::IsPathRooted($voteStateFile)) {
  $voteStateFile = Join-Path $PSScriptRoot $voteStateFile
}

$triggerStateFile = $config.StateFile
if (-not $triggerStateFile) {
  $triggerStateFile = "reaction-server-start.state"
}
if (-not [System.IO.Path]::IsPathRooted($triggerStateFile)) {
  $triggerStateFile = Join-Path $PSScriptRoot $triggerStateFile
}

Add-Type -AssemblyName System.Net.Http

$httpClient = [System.Net.Http.HttpClient]::new()
$httpClient.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("Bot", [string]$config.BotToken)
$httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("AutomationManager/1.0")

function New-JsonContent {
  param([string]$Json)
  return [System.Net.Http.StringContent]::new($Json, [System.Text.Encoding]::UTF8, "application/json")
}

function Invoke-DiscordPostJson {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$JsonBody
  )

  $content = New-JsonContent -Json $JsonBody
  $response = $httpClient.PostAsync($Uri, $content).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result
  if (-not $response.IsSuccessStatusCode) {
    throw "Discord API POST failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
  }

  if ($responseBody) {
    return $responseBody | ConvertFrom-Json
  }

  return $null
}

function Invoke-DiscordPut {
  param([Parameter(Mandatory = $true)][string]$Uri)

  $response = $httpClient.PutAsync($Uri, $null).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result
  if (-not $response.IsSuccessStatusCode) {
    throw "Discord API PUT failed: $([int]$response.StatusCode) $($response.ReasonPhrase) $responseBody"
  }
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

function Remove-PreviousVoteMessage {
  if (-not (Test-Path $voteStateFile)) {
    return
  }

  try {
    $oldState = Get-Content $voteStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $oldState.MessageId) {
      return
    }

    $oldChannelId = $oldState.ChannelId
    if (-not $oldChannelId) {
      $oldChannelId = $config.ChannelId
    }

    $deleteUri = "https://discord.com/api/v10/channels/$oldChannelId/messages/$($oldState.MessageId)"
    Invoke-WithRetry -Name "Delete previous vote message" -Operation {
      Invoke-DiscordDelete -Uri $deleteUri -IgnoreMissing
    } | Out-Null

    Remove-Item -Path $voteStateFile -Force -ErrorAction SilentlyContinue
    Write-Host "Previous vote message deleted before posting a new one." -ForegroundColor Green
  }
  catch {
    Write-Host "Previous vote message could not be deleted: $($_.Exception.Message)" -ForegroundColor Yellow
  }
}

Remove-PreviousVoteMessage

$body = @{
  content = $config.VoteMessage
} | ConvertTo-Json -Depth 5

$uri = "https://discord.com/api/v10/channels/$($config.ChannelId)/messages"
$message = Invoke-WithRetry -Name "Post vote message" -Operation {
  Invoke-DiscordPostJson -Uri $uri -JsonBody $body
}

if ($config.AddInitialReaction -ne $false) {
  if ($config.EmojiId) {
    $emojiRoute = [System.Uri]::EscapeDataString("$($config.EmojiName):$($config.EmojiId)")
  }
  else {
    $emojiRoute = [System.Uri]::EscapeDataString([string]$config.EmojiName)
  }

  $reactionUri = "https://discord.com/api/v10/channels/$($config.ChannelId)/messages/$($message.id)/reactions/$emojiRoute/@me"
  Invoke-WithRetry -Name "Add initial reaction" -Operation {
    Invoke-DiscordPut -Uri $reactionUri
  } | Out-Null
}

$state = [ordered]@{
  ChannelId = [string]$config.ChannelId
  MessageId = [string]$message.id
  PostedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Date = (Get-Date).ToString("yyyy-MM-dd")
}

$state | ConvertTo-Json -Depth 5 | Set-Content -Path $voteStateFile -Encoding UTF8

if (Test-Path $triggerStateFile) {
  Remove-Item -Path $triggerStateFile -Force
}

Write-Host "Vote message posted." -ForegroundColor Green
Write-Host "MessageId: $($message.id)"
if ($config.AddInitialReaction -ne $false) {
  Write-Host "Initial reaction added: $($config.EmojiName)" -ForegroundColor Green
}
Write-Host "State file: $voteStateFile"
Write-Host "Previous trigger state cleared for the new vote message."

$httpClient.Dispose()
