# 13:50 Wake From Sleep

이 스크립트는 Windows PC를 매일 13:50에 절전 모드에서 깨우도록 예약합니다.

## 사용 방법

PowerShell을 관리자 권한으로 열고 이 폴더에서 실행합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Wake1350.ps1
```

## 자동 로그인에 대한 의미

이 스크립트의 "자동 로그인"은 완전히 꺼진 PC에 비밀번호를 입력해 로그인하는 기능이 아닙니다.

대신 아래 조건에서 동작합니다.

- 사용자가 이미 로그인된 상태
- PC를 종료가 아니라 절전 모드로 둠
- 절전 해제 후 암호 요구가 꺼져 있음

이 조건이면 13:50에 PC가 깨어난 뒤 잠금 화면에서 암호 입력을 요구하지 않고 기존 세션으로 돌아갑니다.

## 주의

- 완전 종료 상태에서는 동작하지 않습니다.
- BIOS/UEFI가 절전 해제 타이머를 허용해야 합니다.
- 노트북은 배터리 절약 설정에 따라 동작이 제한될 수 있습니다.
- 암호 요구를 끄면 보안이 낮아집니다.

## 제거

```powershell
powershell -ExecutionPolicy Bypass -File .\Remove-Wake1350.ps1
```
