$ErrorActionPreference = "Continue"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$desktop = [Environment]::GetFolderPath("Desktop")
$paths = [ordered]@{
  Minecraft = Join-Path $PSScriptRoot "curseforge-server-automation"
  Wake = Join-Path $PSScriptRoot "13 50 login"
  Discord = Join-Path $PSScriptRoot "discord scheduled message"
  Reaction = Join-Path $PSScriptRoot "discord-reaction-server-start"
}

function Resolve-TemplatePath {
  param([string]$PathText)
  if (-not $PathText) { return "" }
  return $PathText.Replace("{Desktop}", $desktop)
}

function Read-JsonFile {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return $null }
  try { return Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
  catch { return $null }
}

function Start-PowerShellFile {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [switch]$Admin
  )

  if (-not (Test-Path $FilePath)) {
    [System.Windows.Forms.MessageBox]::Show("파일을 찾을 수 없습니다:`r`n$FilePath", "파일 없음", "OK", "Error") | Out-Null
    return
  }

  $args = "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$FilePath`""
  if ($Admin) { Start-Process powershell.exe -ArgumentList $args -Verb RunAs }
  else { Start-Process powershell.exe -ArgumentList $args }
}

function Open-Path {
  param([string]$Path)
  if (Test-Path $Path) { Start-Process explorer.exe -ArgumentList "`"$Path`"" }
  else { [System.Windows.Forms.MessageBox]::Show("경로를 찾을 수 없습니다:`r`n$Path", "경로 없음", "OK", "Warning") | Out-Null }
}

function Open-File {
  param([string]$Path)
  if (Test-Path $Path) { Start-Process notepad.exe -ArgumentList "`"$Path`"" }
  else { [System.Windows.Forms.MessageBox]::Show("파일을 찾을 수 없습니다:`r`n$Path", "파일 없음", "OK", "Warning") | Out-Null }
}

function Convert-TaskState {
  param($State)
  switch ([string]$State) {
    "Ready" { return "대기 중" }
    "Running" { return "실행 중" }
    "Disabled" { return "비활성화" }
    "Queued" { return "대기열" }
    default { return [string]$State }
  }
}

function Get-TaskSummary {
  param([string]$TaskName)
  $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  if (-not $task) { return "등록 안 됨" }

  $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
  if ($info -and $info.NextRunTime) {
    return "$(Convert-TaskState $task.State), 다음 실행: $($info.NextRunTime)"
  }
  return "$(Convert-TaskState $task.State)"
}

function Get-ConsoleLockSummary {
  $output = powercfg /QH SCHEME_CURRENT SUB_NONE CONSOLELOCK 2>$null
  $ac = ($output | Select-String "AC").Line
  $dc = ($output | Select-String "DC").Line
  if ($ac -match "0x00000000" -and $dc -match "0x00000000") { return "절전 해제 후 암호 요구: 꺼짐" }
  if ($ac -match "0x00000001" -or $dc -match "0x00000001") { return "절전 해제 후 암호 요구: 켜짐" }
  return "절전 해제 후 암호 요구: 확인 불가"
}

function Get-DiscordNoticeSummary {
  param($DiscordConfig, $MinecraftConfig)

  $minutes = 10
  if ($DiscordConfig -and $DiscordConfig.NoticeMinutesBeforeStart) {
    $minutes = [int]$DiscordConfig.NoticeMinutesBeforeStart
  }

  if ($MinecraftConfig -and $MinecraftConfig.StartTime) {
    try {
      $parts = ([string]$MinecraftConfig.StartTime).Split(":")
      if ($parts.Count -eq 2) {
        $serverStart = (Get-Date).Date.AddHours([int]$parts[0]).AddMinutes([int]$parts[1])
        $noticeAt = $serverStart.AddMinutes(-1 * $minutes)
        return "서버 시작 $($MinecraftConfig.StartTime) 기준 $minutes분 전 ($($noticeAt.ToString('HH:mm')))"
      }
    }
    catch {}
  }

  return "서버 시작 기준 $minutes분 전"
}

function New-Button {
  param([string]$Text, [int]$X, [int]$Y, [int]$W, [scriptblock]$OnClick)
  $button = New-Object System.Windows.Forms.Button
  $button.Text = $Text
  $button.Location = New-Object System.Drawing.Point($X, $Y)
  $button.Size = New-Object System.Drawing.Size($W, 34)
  $button.FlatStyle = "System"
  $button.Add_Click($OnClick)
  return $button
}

function New-Label {
  param([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H = 24, [switch]$Bold)
  $label = New-Object System.Windows.Forms.Label
  $label.Text = $Text
  $label.Location = New-Object System.Drawing.Point($X, $Y)
  $label.Size = New-Object System.Drawing.Size($W, $H)
  $label.AutoEllipsis = $true
  if ($Bold) { $label.Font = New-Object System.Drawing.Font("Malgun Gothic", 10, [System.Drawing.FontStyle]::Bold) }
  else { $label.Font = New-Object System.Drawing.Font("Malgun Gothic", 9) }
  return $label
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "자동화 관리"
$form.Size = New-Object System.Drawing.Size(920, 790)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(860, 740)
$form.Font = New-Object System.Drawing.Font("Malgun Gothic", 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 247, 249)

$title = New-Label "자동화 관리" 20 16 400 34 -Bold
$title.Font = New-Object System.Drawing.Font("Malgun Gothic", 16, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)
$form.Controls.Add((New-Button "즉시 투표 올리기" 430 18 140 { Start-PowerShellFile (Join-Path $paths.Reaction "Post-VoteMessage.ps1") }))
$form.Controls.Add((New-Button "원버튼 예약+절전" 585 18 175 { Start-PowerShellFile (Join-Path $PSScriptRoot "OneButton-Schedule-Sleep.ps1") -Admin }))
$form.Controls.Add((New-Button "새로고침" 775 18 105 { Refresh-Status }))

$statusBox = New-Object System.Windows.Forms.TextBox
$statusBox.Location = New-Object System.Drawing.Point(20, 635)
$statusBox.Size = New-Object System.Drawing.Size(860, 95)
$statusBox.Multiline = $true
$statusBox.ReadOnly = $true
$statusBox.ScrollBars = "Vertical"
$statusBox.BackColor = [System.Drawing.Color]::White
$statusBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($statusBox)

$minecraftGroup = New-Object System.Windows.Forms.GroupBox
$minecraftGroup.Text = "마인크래프트 서버"
$minecraftGroup.Location = New-Object System.Drawing.Point(20, 65)
$minecraftGroup.Size = New-Object System.Drawing.Size(860, 135)
$form.Controls.Add($minecraftGroup)
$mcStatus = New-Label "" 15 26 820 24
$mcDetail = New-Label "" 15 52 820 24
$minecraftGroup.Controls.Add($mcStatus)
$minecraftGroup.Controls.Add($mcDetail)
$minecraftGroup.Controls.Add((New-Button "즉시 실행" 15 85 105 { Start-PowerShellFile (Join-Path $paths.Minecraft "Start-CurseForgeServer.ps1") }))
$minecraftGroup.Controls.Add((New-Button "예약 등록" 130 85 125 { Start-PowerShellFile (Join-Path $paths.Minecraft "Install-Schedule.ps1") }))
$minecraftGroup.Controls.Add((New-Button "예약 해제" 265 85 105 { Start-PowerShellFile (Join-Path $paths.Minecraft "Remove-Schedule.ps1") }))
$minecraftGroup.Controls.Add((New-Button "설정 열기" 380 85 105 { Open-File (Join-Path $paths.Minecraft "config.json") }))
$minecraftGroup.Controls.Add((New-Button "폴더 열기" 495 85 105 { Open-Path $paths.Minecraft }))
$minecraftGroup.Controls.Add((New-Button "서버 폴더" 610 85 105 { $config = Read-JsonFile (Join-Path $paths.Minecraft "config.json"); if ($config) { Open-Path (Resolve-TemplatePath $config.ServerDir) } }))
$minecraftGroup.Controls.Add((New-Button "로그 열기" 725 85 90 { $config = Read-JsonFile (Join-Path $paths.Minecraft "config.json"); if ($config) { $serverDir = Resolve-TemplatePath $config.ServerDir; $logPath = if ([System.IO.Path]::IsPathRooted($config.LogFile)) { $config.LogFile } else { Join-Path $serverDir $config.LogFile }; Open-File $logPath } }))

$wakeGroup = New-Object System.Windows.Forms.GroupBox
$wakeGroup.Text = "13:50 절전 해제"
$wakeGroup.Location = New-Object System.Drawing.Point(20, 215)
$wakeGroup.Size = New-Object System.Drawing.Size(860, 120)
$form.Controls.Add($wakeGroup)
$wakeStatus = New-Label "" 15 28 820 24
$wakeDetail = New-Label "" 15 54 820 24
$wakeGroup.Controls.Add($wakeStatus)
$wakeGroup.Controls.Add($wakeDetail)
$wakeGroup.Controls.Add((New-Button "설정 등록" 15 82 110 { Start-PowerShellFile (Join-Path $paths.Wake "Install-Wake1350.ps1") -Admin }))
$wakeGroup.Controls.Add((New-Button "설정 제거" 135 82 110 { Start-PowerShellFile (Join-Path $paths.Wake "Remove-Wake1350.ps1") -Admin }))
$wakeGroup.Controls.Add((New-Button "폴더 열기" 255 82 105 { Open-Path $paths.Wake }))

$discordGroup = New-Object System.Windows.Forms.GroupBox
$discordGroup.Text = "디스코드 예약 메시지"
$discordGroup.Location = New-Object System.Drawing.Point(20, 350)
$discordGroup.Size = New-Object System.Drawing.Size(860, 135)
$form.Controls.Add($discordGroup)
$discordStatus = New-Label "" 15 28 820 24
$discordDetail = New-Label "" 15 54 820 24
$discordGroup.Controls.Add($discordStatus)
$discordGroup.Controls.Add($discordDetail)
$discordGroup.Controls.Add((New-Button "테스트 전송" 15 85 105 { Start-PowerShellFile (Join-Path $paths.Discord "Test-DiscordMessage.ps1") }))
$discordGroup.Controls.Add((New-Button "예약 등록" 130 85 125 { Start-PowerShellFile (Join-Path $paths.Discord "Install-Schedule.ps1") }))
$discordGroup.Controls.Add((New-Button "예약 제거" 265 85 130 { Start-PowerShellFile (Join-Path $paths.Discord "Remove-Schedule.ps1") }))
$discordGroup.Controls.Add((New-Button "설정 열기" 405 85 105 { $configPath = Join-Path $paths.Discord "config.json"; if (-not (Test-Path $configPath)) { $example = Join-Path $paths.Discord "config.example.json"; if (Test-Path $example) { Copy-Item $example $configPath } }; Open-File $configPath }))
$discordGroup.Controls.Add((New-Button "폴더 열기" 520 85 105 { Open-Path $paths.Discord }))

$reactionGroup = New-Object System.Windows.Forms.GroupBox
$reactionGroup.Text = "디스코드 반응 감지 서버 실행"
$reactionGroup.Location = New-Object System.Drawing.Point(20, 500)
$reactionGroup.Size = New-Object System.Drawing.Size(860, 120)
$form.Controls.Add($reactionGroup)
$reactionStatus = New-Label "" 15 28 820 24
$reactionDetail = New-Label "" 15 54 820 24
$reactionGroup.Controls.Add($reactionStatus)
$reactionGroup.Controls.Add($reactionDetail)
$reactionGroup.Controls.Add((New-Button "메시지 올리기" 15 82 105 { Start-PowerShellFile (Join-Path $paths.Reaction "Post-VoteMessage.ps1") }))
$reactionGroup.Controls.Add((New-Button "메시지 예약" 130 82 105 { Start-PowerShellFile (Join-Path $paths.Reaction "Install-VoteMessageSchedule.ps1") }))
$reactionGroup.Controls.Add((New-Button "설정 검사" 245 82 105 { Start-PowerShellFile (Join-Path $paths.Reaction "Check-Config.ps1") }))
$reactionGroup.Controls.Add((New-Button "설정 열기" 360 82 105 {
  $configPath = Join-Path $paths.Reaction "config.json"
  if (-not (Test-Path $configPath)) {
    $example = Join-Path $paths.Reaction "config.example.json"
    if (Test-Path $example) { Copy-Item $example $configPath }
  }
  Open-File $configPath
}))
$reactionGroup.Controls.Add((New-Button "상태 초기화" 475 82 115 { Start-PowerShellFile (Join-Path $paths.Reaction "Reset-TriggeredState.ps1") }))
$reactionGroup.Controls.Add((New-Button "폴더 열기" 600 82 105 { Open-Path $paths.Reaction }))

function Refresh-Status {
  $lines = New-Object System.Collections.Generic.List[string]
  $mcConfigPath = Join-Path $paths.Minecraft "config.json"
  $mcConfig = Read-JsonFile $mcConfigPath
  if ($mcConfig) {
    $serverDir = Resolve-TemplatePath $mcConfig.ServerDir
    $startPath = Join-Path $serverDir $mcConfig.StartCommand
    $mcStatus.Text = "서버 폴더: " + $(if (Test-Path $serverDir) { "정상" } else { "없음" }) + "    실행 파일: " + $(if (Test-Path $startPath) { "정상" } else { "없음" })
    $mcDetail.Text = "시작 $($mcConfig.StartTime), 종료 $($mcConfig.StopTime), 예약: $(Get-TaskSummary 'CurseForge Server Start')"
    $lines.Add("마인크래프트 서버 폴더: $serverDir")
    $lines.Add("마인크래프트 실행 파일: $startPath")
  }
  else {
    $mcStatus.Text = "config.json을 읽을 수 없습니다."
    $mcDetail.Text = $mcConfigPath
  }

  $wakeStatus.Text = Get-TaskSummary "Wake PC At 13-50"
  $wakeDetail.Text = Get-ConsoleLockSummary

  $discordConfigPath = Join-Path $paths.Discord "config.json"
  $discordConfig = Read-JsonFile $discordConfigPath
  if ($discordConfig) {
    $hasWebhook = $discordConfig.WebhookUrl -and $discordConfig.WebhookUrl -notlike "*WEBHOOK_ID*"
    $discordStatus.Text = "설정: 정상    Webhook: " + $(if ($hasWebhook) { "설정됨" } else { "미설정" })
    $discordDetail.Text = "$(Get-DiscordNoticeSummary $discordConfig $mcConfig), 예약: $(Get-TaskSummary $discordConfig.TaskName)"
  }
  else {
    $discordStatus.Text = "config.json이 없습니다. 설정 열기를 누르면 예시 파일로 생성합니다."
    $discordDetail.Text = "예약: $(Get-TaskSummary 'Discord Scheduled Message')"
  }

  $lines.Add("절전 해제 예약: $(Get-TaskSummary 'Wake PC At 13-50')")
  $lines.Add("원버튼 절전 해제: $(Get-TaskSummary 'OneButton Wake 13-50')")
  $lines.Add("원버튼 디스코드: $(Get-TaskSummary 'OneButton Discord Notice')")
  $lines.Add("원버튼 서버 실행: $(Get-TaskSummary 'OneButton Minecraft Server Start')")
  $lines.Add("절전 해제 후 암호 설정: $(Get-ConsoleLockSummary)")
  if ($discordConfig) { $lines.Add("디스코드 공지 시간: $(Get-DiscordNoticeSummary $discordConfig $mcConfig)") }
  else { $lines.Add("디스코드 설정: 없음") }

  $reactionConfigPath = Join-Path $paths.Reaction "config.json"
  $reactionConfig = Read-JsonFile $reactionConfigPath
  if ($reactionConfig) {
    $hasBot = $reactionConfig.BotToken -and $reactionConfig.BotToken -notlike "PUT_*"
    $hasChannel = $reactionConfig.ChannelId -and $reactionConfig.ChannelId -notlike "PUT_*"
    $hasWebhook = $reactionConfig.WebhookUrl -and $reactionConfig.WebhookUrl -notlike "PUT_*"
    $reactionStatus.Text = "설정: " + $(if ($hasBot -and $hasChannel -and $hasWebhook) { "준비됨" } else { "입력 필요" })
    $reactionDetail.Text = "메시지 게시 $($reactionConfig.VotePostTime), 기준 반응 수 $($reactionConfig.Threshold), 이모트 $($reactionConfig.EmojiName)"
    $lines.Add("디스코드 반응 감지: " + $reactionStatus.Text)
  }
  else {
    $reactionStatus.Text = "config.json이 없습니다. 설정 열기를 누르면 생성합니다."
    $reactionDetail.Text = "봇 토큰, 채널 ID, 메시지 ID, 웹후크 URL이 필요합니다."
    $lines.Add("디스코드 반응 감지: 설정 없음")
  }
  $statusBox.Text = ($lines -join [Environment]::NewLine)
}

$form.Add_Shown({ Refresh-Status })
[void]$form.ShowDialog()
