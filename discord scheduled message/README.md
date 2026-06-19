# Discord Scheduled Message

마인크래프트 서버 시작 예약 시간 10분 전에 디스코드 메시지를 보내는 PowerShell 스크립트입니다.

## 1. 디스코드 Webhook 만들기

디스코드에서 메시지를 보낼 채널을 선택합니다.

1. 채널 오른쪽의 설정 아이콘
2. 연동 또는 Integrations
3. Webhooks
4. 새 Webhook 만들기
5. Webhook URL 복사

복사한 URL은 다른 사람에게 공유하지 마세요. 이 URL을 아는 사람은 해당 채널에 메시지를 보낼 수 있습니다.

## 2. 설정

`config.example.json`을 복사해서 `config.json`으로 만듭니다.

```json
{
  "WebhookUrl": "복사한 Webhook URL",
  "Message": "서버가 {serverStartTime}에 열릴 예정입니다. {noticeMinutes}분 전에 미리 안내드립니다.",
  "NoticeMinutesBeforeStart": 10,
  "TaskName": "Discord Scheduled Message",
  "ServerStartTaskNames": [
    "OneButton Minecraft Server Start",
    "CurseForge Server Start"
  ]
}
```

전송 시각은 이 파일의 `SendTime`이 아니라 `curseforge-server-automation/config.json`의 `StartTime`을 기준으로 계산됩니다.

예: 마인크래프트 `StartTime`이 `14:00`이고 `NoticeMinutesBeforeStart`가 `10`이면 디스코드 예약 메시지는 `13:50`에 등록됩니다.

메시지 안에서는 아래 치환값을 사용할 수 있습니다.

- `{serverStartTime}`: 실제 예약된 서버 시작 시각
- `{noticeMinutes}`: 서버 시작 몇 분 전에 보내는 공지인지

## 3. 테스트 전송

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-DiscordMessage.ps1
```

## 4. 예약 등록

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1
```

이후 매일 마인크래프트 서버 시작 시간 10분 전에 메시지 발송 여부를 확인합니다.

실제 메시지는 서버 시작 예약 작업이 가까운 시간에 존재할 때만 전송됩니다.

## 5. 예약 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-Schedule.ps1
```
