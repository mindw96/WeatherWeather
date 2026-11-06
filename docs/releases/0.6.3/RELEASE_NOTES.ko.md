# 쌓임쌓임 0.6.3

창이 겹칠 때 뒤쪽 창에 쌓인 눈·물막과 개별 효과가 앞쪽 창의 둥근 모서리를 따라 가려지도록 개선했습니다. macOS 14 이상용 Apple Silicon·Intel 통합 앱입니다.

배포 상태: 앱과 DMG의 Developer ID 서명·Apple 공증 및 설치 파일 검증을 완료했습니다.

## 이번 변경

- **겹친 창의 가림 개선:** 뒤쪽 누적을 수직으로 잘라 표시하던 방식을 바꿔, 앞 창의 둥근 외곽 안에 들어간 부분만 가립니다. 모서리 틈과 앞 창 위로 솟은 눈이 보이는 부분을 유지합니다.
- **앞뒤 표시 순서:** 뒤쪽 창의 효과부터 그려, 겹치는 누적 효과도 창의 앞뒤 순서를 따릅니다.
- **전체 화면 경계 유지:** 전체 화면으로 판정된 창은 사각형 외곽으로 뒤쪽 효과를 가립니다.

창 모서리는 기존 16pt·10pt 추정값을 사용합니다. 입자의 충돌 가능 구간과 작업 창 효과 숨김은 기존의 보수적인 사각형 경계를 유지합니다. 새 권한이나 설정은 추가하지 않습니다.

## 다운로드와 설치

**[DMG 다운로드 — 권장](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.3/WindowWeather-0.6.3-macOS-universal.dmg)** · [앱만 담은 ZIP](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.3/WindowWeather-0.6.3-macOS-universal.zip)

0.5.0 이상에서는 앱의 **업데이트 확인…**으로 배포된 새 버전을 확인하실 수 있습니다. 직접 설치하려면 기존 앱을 종료하고 DMG의 앱을 Applications로 옮겨 주세요. ZIP에는 앱 하나만 들어 있습니다.

설정창은 Dock 아이콘, 메뉴 막대의 **설정…**, **⌘,**로 열 수 있습니다. [사용 안내](https://github.com/mindw96/WeatherWeather/blob/main/docs/releases/0.6.3/START_HERE.ko.txt)를 제공합니다.

Intel Mac·macOS 14 실기기와 모든 Spaces·배율 조합은 별도 확인이 필요합니다. 다른 앱의 독자적인 창 모양에서는 곡률 차이가 남을 수 있습니다. Windows와 실제 날씨 자동 연동은 아직 제공하지 않습니다.
