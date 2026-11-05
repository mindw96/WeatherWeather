# Sparkle 0.5.1 공개 피드 조회 검증

2026-11-05, Sparkle 2.10.1 공식 프레임워크, Apple Silicon Mac.

GitHub Releases의 v0.5.1을 공개한 뒤 제품 앱과 별개의 임시 앱 두 개에서 `SPUUpdater.checkForUpdateInformation()`으로 실제 공개 피드를 조회했습니다. 두 앱은 서로 다른 고유 번들 ID와 독립된 설정을 사용하며, 검사가 끝나면 각 테스트 설정 도메인만 제거합니다.

| 임시 앱 | 기대 동작 | 실제 결과 | 시간 |
| --- | --- | --- | --- |
| 빌드 5, 표시 버전 0.5.0 | 빌드 6 업데이트 발견 | 빌드 6 / 버전 0.5.1, 공개 업데이트 ZIP URL 확인 | 1.45초 |
| 빌드 6, 표시 버전 0.5.1 | 최신 버전 | `OnLatestVersion`, 최신 항목 6 | 1.08초 |

두 경우 모두 `passed: true`이며, 자동 확인 설정을 ON → OFF로 바꾸면 해당 값이 테스트 앱의 UserDefaults에 저장되는 것도 확인했습니다. 자동 다운로드·자동 설치·시스템 프로파일 전송은 꺼져 있습니다. 조회 제한 시간은 30초입니다.

- 피드: <https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml>
- 발견한 업데이트: <https://github.com/mindw96/WeatherWeather/releases/download/v0.5.1/WindowWeather-0.5.1-update.zip>
- 원본 결과: `available.json`, `current.json`

`main.swift`가 실제 검증 소스입니다. 0.5.0 검증 소스에서 기대하는 최신 빌드만 6으로 바꿨습니다. 공식 Sparkle 2.10.1 프레임워크를 `Contents/Frameworks`에 복사하고, `swiftc -swift-version 5 -O -framework AppKit -framework Sparkle`로 빌드하면서 `@executable_path/../Frameworks` RPATH를 지정했습니다. Info.plist에는 `Config/Updates.plist`의 피드·공개 키와 테스트별 빌드 번호·표시 버전·고유 번들 ID를 넣고 자동 확인 기본값은 OFF로 설정했습니다. 임시 앱은 ad-hoc 서명 후 `codesign --verify --deep --strict`를 통과했습니다.

임시 호스트는 `/private/tmp/window-weather-051-sparkle-probe.cjd_hfea/Build5.app`, `Build6.app`입니다. 실행은 `open -n -W <임시 앱> --args <결과.json> available` 또는 `current`로 수행했습니다. 제품 소스나 설치된 제품 앱은 수정하지 않았습니다.

이 검사는 실제 Sparkle의 공개 피드 다운로드·파싱·버전 선택·완료 콜백을 확인합니다. 업데이트 안내창, 업데이트 ZIP 다운로드, 서명 검증 후 설치·재실행은 수행하지 않았습니다. 앱 배포 파일의 서명·공증·EdDSA 검증과 공개 다운로드 해시 확인은 상위 릴리스 검증 기록에서 별도로 다룹니다.
