$ErrorActionPreference = "Stop"

$target = Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter "*.ps1" |
  Where-Object { $_.Name -ne "AutomationManager.ps1" -and $_.Name -ne "OneButton-Schedule-Sleep.ps1" -and $_.Name -like "*예약*절전*.ps1" } |
  Select-Object -First 1

if (-not $target) {
  throw "One-button schedule script was not found."
}

& $target.FullName
