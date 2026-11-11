# 쌓임쌓임 1.0.0 — GitHub 직접 배포

바람 방향에 **가운데(없음)**를 추가했습니다. 바람 세기를 바꾸지 않고 바람만 잠시 멈췄다가, 왼쪽이나 오른쪽을 선택해 이전 세기로 돌아갈 수 있습니다.

**1.0.0 · 빌드 15를 공개했습니다.** Apple Silicon·Intel 통합 앱과 DMG 모두 Developer ID 서명·Apple 공증을 마쳤습니다. 공개 다운로드·Sparkle 버전 판별과 현재 Mac 설치·실행을 확인했습니다. [DMG 다운로드](https://github.com/mindw96/WeatherWeather/releases/download/v1.0.0/WindowWeather-1.0.0-macOS-universal.dmg) · [앱만 담은 ZIP](https://github.com/mindw96/WeatherWeather/releases/download/v1.0.0/WindowWeather-1.0.0-macOS-universal.zip)

## 달라진 점

- 바람 방향을 **왼쪽 / 가운데(없음) / 오른쪽**으로 고릅니다.
- 가운데에서는 바람 세기 설정을 보존한 채 실제 바람을 0으로 만듭니다. 앱을 다시 실행해도 선택을 기억합니다.
- 기존 여덟 효과, 창과 바람의 반응, 모니터·앱별 표시 옵션, 눈사람 꾸미기와 실제 날씨 연동을 유지합니다.

## 설치와 업데이트

macOS 14 이상용 Apple Silicon·Intel 통합 DMG와 앱만 담은 ZIP을 제공합니다. DMG에서는 앱을 Applications로 끌어 옮기고, ZIP은 압축을 풀어 나온 `WindowWeather.app`을 응용 프로그램 폴더로 옮겨 실행합니다.

이 GitHub 직접 배포판에는 **Sparkle 업데이트 확인**을 포함합니다. 0.5.0 이상 직접 배포판은 앱의 **업데이트 확인…**으로 새 버전을 확인할 수 있습니다. 자동 확인은 설정에서 끌 수 있고 다운로드·설치는 사용자가 선택합니다. 기존 앱 설정과 화면별 눈사람 위치는 유지합니다.

## App Store 제출과 구분

같은 1.0.0·빌드 15의 App Store 전용 앱은 Sandbox를 사용하고 Sparkle를 제외하며, 업데이트를 App Store에서 관리합니다. 2026-11-11 제출 기록은 **심사 대기 중**으로, 이번 GitHub 직접 배포는 App Store의 심사 승인이나 공개 출시를 의미하지 않습니다. [스토어 제출 기록](../../app-store/1.0.0/VALIDATION.md)

[사용 안내](START_HERE.ko.txt) · [직접 배포 검증 상태](VALIDATION.md) · [개인정보 처리방침](../../PRIVACY.md) · [지원](../../SUPPORT.md)
