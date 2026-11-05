# 쌓임쌓임 0.5.1

macOS 14 이상용 Apple Silicon(arm64)·Intel(x86_64) 통합 앱입니다. 회원가입이나 로그인 없이 사용할 수 있으며 날씨 효과는 오프라인에서도 동작합니다.

배포 상태: Developer ID 서명과 Apple 공증을 완료했습니다.

## 이번 변경

- 한국어 환경의 앱 표시 이름을 **쌓임쌓임**으로 맞췄습니다. 설정창과 앱 메뉴에도 같은 이름을 사용하며, 영문 이름은 **Window Weather**입니다.
- **DMG**를 기본 설치 파일로 제공합니다. 앱을 옆의 Applications 폴더로 끌어 옮겨 설치하실 수 있습니다.
- **ZIP**은 압축을 풀면 앱 하나만 나오도록 정리했습니다. 사용 안내와 변경 내역은 GitHub에서 제공합니다.

눈·비·낙엽·벚꽃, 전체 화면 누적 옵션, 작업 창 효과 표시 옵션, 드래그 가능한 눈사람과 설정 저장 기능을 계속 제공합니다. 저장된 날씨 설정과 눈사람 위치도 유지합니다.

## 다운로드와 설치

**[DMG 다운로드 — 권장](https://github.com/mindw96/WeatherWeather/releases/download/v0.5.1/WindowWeather-0.5.1-macOS-universal.dmg)** · [앱만 담은 ZIP](https://github.com/mindw96/WeatherWeather/releases/download/v0.5.1/WindowWeather-0.5.1-macOS-universal.zip)

기존 앱을 종료한 뒤 DMG를 열고 앱을 `Applications` 폴더로 끌어 옮겨 주세요. 응용 프로그램 폴더에서 실행하고, 설치 후에는 Finder에서 DMG를 꺼내셔도 됩니다. ZIP으로 받으셨다면 압축을 풀어 나온 앱을 응용 프로그램 폴더에 옮깁니다. 앱 파일 이름은 `WindowWeather.app`입니다.

**0.5.0 사용자는 앱의 ‘업데이트 확인…’에서 새 버전을 확인하고 설치하실 수 있습니다.** 0.4.0 이하에는 업데이트 기능이 없으므로 DMG 또는 ZIP으로 직접 설치해 주세요. 자동 업데이트 확인은 설정에서 끌 수 있으며 다운로드와 설치는 사용자가 선택합니다.

설정창은 Dock 아이콘 클릭, Dock 오른쪽 클릭 → **설정 열기…**, 메뉴 막대의 **설정…**, 앱이 활성 상태일 때 **⌘,**로 다시 열 수 있습니다. [자세한 사용 안내](https://github.com/mindw96/WeatherWeather/blob/main/docs/releases/0.5.1/START_HERE.ko.txt)를 함께 제공합니다.

## 현재 범위

Windows 앱은 아직 제공하지 않습니다. Intel Mac·macOS 14 실기기와 모든 모니터 배율·Spaces 조합은 추가 확인이 필요합니다. 앱 소스는 MIT 라이선스이며, Sparkle 라이선스 고지도 앱에 포함합니다.
