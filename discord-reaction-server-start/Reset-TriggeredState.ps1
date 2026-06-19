$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "config.json"
$stateFile = Join-Path $PSScriptRoot "reaction-server-start.state"
$voteStateFile = Join-Path $PSScriptRoot "reaction-vote-message.json"

if (Test-Path $configPath) {
  $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($config.StateFile) {
    $stateFile = $config.StateFile
    if (-not [System.IO.Path]::IsPathRooted($stateFile)) {
      $stateFile = Join-Path $PSScriptRoot $stateFile
    }
  }
  if ($config.VoteStateFile) {
    $voteStateFile = $config.VoteStateFile
    if (-not [System.IO.Path]::IsPathRooted($voteStateFile)) {
      $voteStateFile = Join-Path $PSScriptRoot $voteStateFile
    }
  }
}

if (Test-Path $stateFile) {
  Remove-Item -Path $stateFile -Force
  Write-Host "Triggered state reset." -ForegroundColor Green
}
else {
  Write-Host "No triggered state file exists." -ForegroundColor Yellow
}

if (Test-Path $voteStateFile) {
  Remove-Item -Path $voteStateFile -Force
  Write-Host "Vote message state reset." -ForegroundColor Green
}

pause
