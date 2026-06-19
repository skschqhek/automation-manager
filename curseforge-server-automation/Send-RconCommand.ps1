param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Command
)

$ErrorActionPreference = "Stop"

Import-Module (Join-Path $PSScriptRoot "AutomationCommon.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "MinecraftRcon.psm1") -Force

$config = Get-AutomationConfig
$response = Invoke-MinecraftRcon `
  -HostName $config.RconHost `
  -Port $config.RconPort `
  -Password $config.RconPassword `
  -Command $Command

if ($response) {
  Write-Output $response
}
