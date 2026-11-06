# 쌓임쌓임 0.6.2

창 모서리 곡선을 더 작게 맞추고, 밝은 화면에서 비를 보기 쉽게 개선했습니다. macOS 14 이상용 Apple Silicon·Intel 통합 앱입니다.

배포 상태: 앱과 DMG의 Developer ID 서명·Apple 공증, 공개 배포 파일 검증을 완료했습니다.

## 이번 변경

- **모서리 곡선 교정:** macOS 26 이상에서 기본 추정 반경을 26pt에서 16pt로 줄였습니다. 제공된 화면에서 물막이 실제 창보다 넓게 돌아 안쪽으로 들어가던 차이를 줄입니다. 설정창 미리보기에도 같은 반경을 사용합니다.
- **현재 버전 표시:** 설정창 오른쪽 아래에 현재 앱 버전을 표시합니다. 설치된 번들에서 읽으므로 이후 업데이트 시 자동으로 바뀝니다.
- **밝은 화면의 비:** 빗줄기·물막·튀는 물방울을 조금 더 선명한 파란색으로 조정했습니다. 비의 양·속도·길이·투명도는 유지합니다.

다른 앱의 실제 모서리 곡률은 공개 창 정보에서 제공하지 않아 추정값을 사용합니다. 독자적인 모양의 창에서는 차이가 남을 수 있습니다. 전체 화면·작업 창 표시 옵션, 눈사람과 기존 설정은 유지합니다.

## 다운로드와 설치

**[DMG 다운로드 — 권장](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.2/WindowWeather-0.6.2-macOS-universal.dmg)** · [앱만 담은 ZIP](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.2/WindowWeather-0.6.2-macOS-universal.zip)

0.5.0 이상에서는 앱의 **업데이트 확인…**으로 새 버전을 확인하실 수 있습니다. 직접 설치하려면 기존 앱을 종료하고 DMG의 앱을 Applications로 옮겨 주세요. ZIP에는 앱 하나만 들어 있습니다.

설정창은 Dock 아이콘, 메뉴 막대의 **설정…**, **⌘,**로 열 수 있습니다. [사용 안내](https://github.com/mindw96/WeatherWeather/blob/main/docs/releases/0.6.2/START_HERE.ko.txt)를 제공합니다.

Intel Mac·macOS 14 실기기와 모든 Spaces·배율 조합은 별도 확인이 필요합니다. Windows와 실제 날씨 자동 연동은 아직 제공하지 않습니다.
