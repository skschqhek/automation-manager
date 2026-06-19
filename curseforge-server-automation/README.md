# CurseForge Minecraft Server Auto Scheduler

이 패키지는 CurseForge 마인크래프트 모드 서버를 매일 정해진 시간에 켜고, 종료 전에 접속자에게 채팅 공지를 보낸 뒤 안전하게 끄는 Windows용 자동화 스크립트입니다.

## 1. 파일 배치

이 폴더 전체를 서버 폴더 안이나 원하는 관리 폴더에 둡니다.

예:

```text
D:\Minecraft\server-automation
```

## 2. 설정 파일 만들기

`config.example.json`을 복사해서 `config.json`으로 이름을 바꾼 뒤 값을 수정합니다.

중요 설정:

- `ServerDir`: CurseForge 서버 폴더
- `StartCommand`: 서버를 켤 때 실행할 파일, 보통 `.\\run.bat` 또는 `.\\start.bat`
- `StartTime`: 매일 서버를 켤 시간
- `StopTime`: 매일 서버를 끌 시간
- `WarningMinutes`: 종료 몇 분 전에 공지할지
- `RconPassword`: `server.properties`의 `rcon.password`와 같은 값

## 3. RCON 켜기

서버 폴더의 `server.properties`에 아래 항목을 설정합니다.

```properties
enable-rcon=true
rcon.port=25575
rcon.password=CHANGE_ME
```

`CHANGE_ME`는 반드시 본인만 아는 긴 비밀번호로 바꾸세요. `config.json`의 `RconPassword`도 같은 값이어야 합니다.

## 4. 예약 작업 등록

PowerShell을 열고 이 폴더로 이동한 뒤 실행합니다.

```powershell
.\Install-Schedule.ps1
```

등록되는 작업:

- `CurseForge Server Start`: `StartTime`에 서버 시작
- `CurseForge Server Stop With Notice`: 가장 이른 종료 공지 시간에 시작해서 공지 후 종료

## 5. 수동 실행

서버 켜기:

```powershell
.\Start-CurseForgeServer.ps1
```

종료 전 공지 후 끄기:

```powershell
.\Stop-CurseForgeServer.ps1
```

바로 채팅 명령 보내기:

```powershell
.\Send-RconCommand.ps1 "list"
```

## 6. 동작 방식

종료 스크립트는 `WarningMinutes`에 적힌 시간에 맞춰 서버 채팅에 공지합니다.

예를 들어 `StopTime`이 `02:00`, `WarningMinutes`가 `[30, 10, 5, 1]`이면 다음처럼 공지합니다.

- 01:30: 30분 후 서버가 종료됩니다.
- 01:50: 10분 후 서버가 종료됩니다.
- 01:55: 5분 후 서버가 종료됩니다.
- 01:59: 1분 후 서버가 종료됩니다.
- 02:00: `save-all` 후 `stop`

서버가 정상 종료되지 않으면 `ForceKillAfterSeconds` 이후 마지막 수단으로 서버 프로세스를 종료합니다.

