function Get-AutomationConfig {
  $configPath = Join-Path $PSScriptRoot "config.json"
  if (-not (Test-Path $configPath)) {
    throw "config.json not found. Copy config.example.json to config.json, then edit it."
  }

  $config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $desktopPath = [Environment]::GetFolderPath("Desktop")

  if ($config.ServerDir) {
    $config.ServerDir = $config.ServerDir.Replace("{Desktop}", $desktopPath)
  }

  return $config
}

function Get-ConfigPath {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  Join-Path $Config.ServerDir $Path
}

function Write-AutomationLog {
  param(
    [Parameter(Mandatory = $true)]$Config,
    [Parameter(Mandatory = $true)][string]$Message
  )

  $logPath = Get-ConfigPath -Config $Config -Path $Config.LogFile
  $logDir = Split-Path $logPath -Parent
  if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  }

  $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
  Add-Content -Path $logPath -Value $line -Encoding UTF8
}

function Get-NextDateTime {
  param([Parameter(Mandatory = $true)][string]$TimeText)

  $parts = $TimeText.Split(":")
  if ($parts.Count -ne 2) {
    throw "Time format must be HH:mm: $TimeText"
  }

  $target = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
  if ($target -lt (Get-Date)) {
    $target = $target.AddDays(1)
  }

  return $target
}

function Stop-ProcessTree {
  param([Parameter(Mandatory = $true)][int]$ProcessId)

  $children = Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue
  foreach ($child in $children) {
    Stop-ProcessTree -ProcessId $child.ProcessId
  }

  $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($process) {
    Stop-Process -Id $ProcessId -Force
  }
}

Export-ModuleMember -Function Get-AutomationConfig, Get-ConfigPath, Write-AutomationLog, Get-NextDateTime, Stop-ProcessTree
