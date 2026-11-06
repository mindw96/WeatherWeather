# Sparkle 0.6.2 공개 피드 조회 검증

2026-11-06, Sparkle 2.10.1 공식 프레임워크, Apple Silicon Mac.

v0.6.2 GitHub Release를 공개한 뒤 제품 앱과 별개의 임시 앱 두 개에서 `SPUUpdater.checkForUpdateInformation()`으로 실제 공개 피드를 조회했습니다. 각 앱은 고유 번들 ID와 독립된 설정을 사용하며 종료 전에 자신의 테스트 설정 도메인만 제거합니다.

| 임시 앱 | 기대 동작 | 실제 결과 | 시간 |
| --- | --- | --- | --- |
| 빌드 8, 표시 버전 0.6.1 | 빌드 9 업데이트 발견 | 빌드 9 / 버전 0.6.2, 정확한 공개 업데이트 ZIP URL 확인 | 1.46초 |
| 빌드 9, 표시 버전 0.6.2 | 최신 버전 | `OnLatestVersion`, 최신 항목 9 | 0.76초 |

두 경우 모두 `passed: true`이며 자동 확인 설정 ON → OFF 저장도 통과했습니다. 자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화했으며 조회 제한 시간은 30초입니다.

- [공개 피드](https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml)
- [발견한 업데이트](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.2/WindowWeather-0.6.2-update.zip)
- 원본 결과: `available.json`, `current.json`

`main.swift`는 0.6.1 검증 소스의 기대 빌드를 9로 바꾸고 업데이트 발견 시 표시 버전과 ZIP URL까지 일치하는지 검사합니다. 공식 Sparkle 2.10.1 프레임워크와 `swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -framework AppKit -framework Sparkle`로 빌드하고 `@executable_path/../Frameworks` RPATH를 지정했습니다. Info.plist에는 공개 피드·공개 키, 테스트별 버전과 고유 번들 ID를 설정했습니다. 임시 앱은 ad-hoc 서명 후 `codesign --verify --deep --strict`를 통과했습니다.

임시 호스트는 `/private/tmp/window-weather-062-sparkle-probe.q8b_thyv/Build8.app`, `Build9.app`입니다. `open -n -W <임시 앱> --args <결과.json> available` 또는 `current`로 실행했고 두 프로세스가 정상 종료했습니다. 제품 소스, 설치된 제품 앱, 배포 파일은 변경하지 않았습니다.

이 검사는 실제 Sparkle의 공개 피드 다운로드·파싱·버전 선택·완료 콜백을 확인합니다. 업데이트 안내창, 업데이트 ZIP 다운로드, 설치·재실행은 수행하지 않았습니다. 배포 파일의 서명·공증·EdDSA 및 공개 다운로드 무결성은 상위 릴리스 검증 기록에서 별도로 다룹니다.
