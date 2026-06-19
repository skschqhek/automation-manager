# Discord Scheduled Message

지정한 디스코드 채널에 정해진 시각마다 메시지를 보내는 PowerShell 스크립트입니다.

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
  "Message": "서버가 곧 열립니다.",
  "SendTime": "13:50",
  "TaskName": "Discord Scheduled Message"
}
```

## 3. 테스트 전송

```powershell
powershell -ExecutionPolicy Bypass -File .\Test-DiscordMessage.ps1
```

## 4. 예약 등록

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Schedule.ps1
```

이후 매일 `SendTime`에 메시지가 전송됩니다.

## 5. 예약 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-Schedule.ps1
```
