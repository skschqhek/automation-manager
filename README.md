# 자동화 관리

Windows PowerShell automation manager for Minecraft server, Discord notices, wake schedule, and reaction votes.

`automation-manager` 폴더 안에 들어 있는 자동화 폴더를 한 화면에서 관리하는 Windows용 PowerShell UI입니다.

관리 대상:

- `curseforge-server-automation`
- `13 50 login`
- `discord scheduled message`
- `discord-reaction-server-start`

## 실행

`AutomationManager.bat`를 더블클릭합니다.

## 제작 기록

기능 구조, 제작 과정, 시행착오는 [AUTOMATION_HISTORY.md](AUTOMATION_HISTORY.md)에 정리했습니다.

## 버튼

- `즉시 실행`: 마인크래프트 서버 즉시 실행
- `즉시 투표 올리기`: 디스코드에 감시용 투표 메시지 즉시 게시
- `예약 등록`: 해당 자동화의 예약 작업 등록
- `예약 해제`: 서버 시작/종료 예약 작업 제거
- `설정 열기`: 설정 파일 열기
- `폴더 열기`: 자동화 폴더 열기
- `서버 폴더`: 실제 마인크래프트 서버 폴더 열기
- `로그 열기`: 서버 자동화 로그 열기
- `설정 등록`: 13:50 절전 해제 설정 등록
- `설정 제거`: 13:50 절전 해제 설정 제거
- `테스트 전송`: 디스코드 메시지 테스트 전송
- `예약 제거`: 디스코드 예약 제거
- `메시지 올리기`: 디스코드 이모지 투표 메시지 게시 후 감시 자동 시작
- `메시지 예약`: 디스코드 이모지 투표 메시지 예약, 게시 시 감시 자동 시작
- `상태 초기화`: 반응 감지 실행 상태 초기화
- `원버튼 예약+절전`: 가까운 13:50 절전 해제, 13:55 디스코드 발송, 14:00 서버 실행을 예약한 뒤 절전 모드로 전환

13:50 절전 해제 설정 등록/제거는 관리자 권한 승인을 요구할 수 있습니다.
원버튼 기능도 전원 설정과 절전 전환을 수행하므로 관리자 권한 승인을 요구할 수 있습니다.

## GitHub 게시 주의

실제 `config.json` 파일은 봇 토큰, 웹후크 URL, RCON 비밀번호 같은 개인 설정을 포함할 수 있으므로 저장소에 올리지 않습니다.
공개 저장소에는 `config.example.json`만 포함합니다.
