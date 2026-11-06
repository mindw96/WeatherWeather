# 쌓임쌓임 0.6.1

창 모서리 위에서 눈이 일직선으로 떠 보이던 부분을 개선했습니다. macOS 14 이상용 Apple Silicon·Intel 통합 앱입니다.

배포 상태: Developer ID 서명·Apple 공증과 공개 배포 파일 검증을 완료했습니다.

## 이번 변경

- 눈과 얕은 물막이 창 상단의 둥근 곡선을 따라 이어집니다. 양 끝의 눈 두께는 자연스럽게 줄어듭니다.
- 비의 충돌·물방울과 낙엽·벚꽃·비눗방울·색종이의 착지도 같은 곡선을 따릅니다.
- 창 이동·크기 변경 시 곡선을 갱신하며, 화면 바닥과 전체 화면으로 판정한 창은 평평하게 유지합니다.
- 다른 창에 완전히 가려진 누적이 그려질 수 있던 빈 클리핑 처리도 수정했습니다.
- 기존 누적·전체 화면·작업 창 표시 옵션, 눈사람 위치와 저장된 설정을 유지합니다.

다른 앱의 실제 모서리 곡률은 macOS 공개 창 정보에서 제공하지 않아 OS 스타일에 맞춘 추정 곡선을 사용합니다. 모든 앱의 외곽과 정확히 일치한다고 보장하지 않으며, 별도의 화면 기록·접근성 권한은 요청하지 않습니다. 실제 날씨 연동은 이전과 같이 검토만 완료된 상태입니다.

## 다운로드와 설치

**[DMG 다운로드 — 권장](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.1/WindowWeather-0.6.1-macOS-universal.dmg)** · [앱만 담은 ZIP](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.1/WindowWeather-0.6.1-macOS-universal.zip)

기존 앱을 종료하고 DMG의 앱을 Applications로 옮겨 주세요. ZIP에는 앱 하나만 들어 있습니다. **0.5.0 이상에서는 앱의 ‘업데이트 확인…’으로 설치하실 수 있습니다.** 다운로드·설치는 사용자가 선택합니다.

설정창은 Dock 아이콘, 메뉴 막대의 **설정…**, **⌘,**로 열 수 있습니다. [사용 안내](https://github.com/mindw96/WeatherWeather/blob/main/docs/releases/0.6.1/START_HERE.ko.txt)를 제공합니다.

Intel Mac·macOS 14 실기기 및 모든 Spaces·배율 조합은 별도 확인이 필요합니다. Windows 앱은 아직 제공하지 않습니다.
