# Discord Reaction Server Start

봇이 지정한 채널에 매일 감시용 메시지를 올리고, 그 메시지에 특정 이모트 반응이 일정 수 이상 모이면 마인크래프트 서버를 켜고 Webhook으로 공지를 보내는 스크립트입니다.

## 중요

Webhook만으로는 반응 수를 읽을 수 없습니다. 반응 수 감지는 Discord Bot Token으로 하고, 공지는 Webhook으로 보냅니다.

봇에는 최소한 아래 권한이 필요합니다.

- 메시지를 볼 채널 접근 권한
- 메시지 기록 보기 권한
- 메시지 보내기 권한

## 설정

`config.example.json`을 복사해서 `config.json`으로 만듭니다.

```json
{
  "BotToken": "봇 토큰",
  "ChannelId": "채널 ID",
  "MessageId": "",
  "VoteMessage": "Sunlit Valley 서버를 열고 싶다면 아래 이모트로 반응해주세요.",
  "VotePostTime": "13:00",
  "VoteTaskName": "Discord Reaction Vote Message",
  "EmojiName": "✅",
  "EmojiId": "",
  "AddInitialReaction": true,
  "Threshold": 5,
  "PollSeconds": 30,
  "PostRetryCount": 5,
  "PostRetryDelaySeconds": 10,
  "WebhookUrl": "공지용 Webhook URL",
  "StartScript": "{Manager}\\curseforge-server-automation\\Start-CurseForgeServer.ps1",
  "AnnouncementMessage": "반응 수가 기준에 도달해 Sunlit Valley 서버를 시작합니다.",
  "StateFile": "reaction-server-start.state",
  "AllowRepeat": false
}
```

일반 유니코드 이모지는 `EmojiName`에 그대로 넣습니다.

커스텀 서버 이모지는 `EmojiId`를 넣는 쪽이 더 정확합니다.

## 매일 감시용 메시지 올리기

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-VoteMessageSchedule.ps1
```

즉시 한 번 올리려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\Post-VoteMessage.ps1
```

메시지를 올리면 `reaction-vote-message.json`에 그 메시지 ID가 저장됩니다.

`AddInitialReaction`이 `true`이면 봇이 감시용 메시지에 `EmojiName` 이모트를 반응으로 한 번 달아둡니다. 이 반응도 디스코드의 반응 개수에 포함됩니다.

투표 메시지 게시나 초기 반응 추가가 네트워크 문제로 실패하면 `PostRetryCount` 횟수만큼, `PostRetryDelaySeconds` 간격으로 재시도합니다.

새 감시용 메시지를 올릴 때 이전 감시용 메시지가 남아 있으면 먼저 삭제합니다.

## 감시 실행

```powershell
powershell -ExecutionPolicy Bypass -File .\Monitor-DiscordReaction.ps1
```

또는 `Start-Monitor.bat`를 더블클릭합니다.

## 중복 실행 방지

기준을 한 번 넘기면 `reaction-server-start.state` 파일이 생기고, `AllowRepeat`가 `false`인 동안 같은 날에는 다시 실행하지 않습니다.

다음 날 새 감시용 메시지가 올라가면 이전 실행 기록은 자동으로 지워집니다.

반응 수가 기준에 도달해 서버 시작 조건이 충족되면 감시하던 투표 메시지도 삭제됩니다.

다시 감지하게 하려면:

```powershell
powershell -ExecutionPolicy Bypass -File .\Reset-TriggeredState.ps1
```
