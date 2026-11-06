# Sparkle 0.7.0 공개 피드 조회 준비

2026-11-07, Sparkle 2.10.1, Apple Silicon Mac.

**준비 완료, 아직 실행하지 않았습니다.** `main.swift`는 0.6.3 검증 소스를 재사용하고 기대 버전·빌드·업데이트 ZIP URL만 0.7.0 / 11로 변경했습니다. 제품 소스와 기존 Sparkle 키·캐시·사용자 설정은 변경하지 않았습니다.

| 임시 앱 | 호스트 버전 / 빌드 | 공개 이후 기대 결과 |
| --- | --- | --- |
| `Build10.app` | 0.6.3 / 10 | 0.7.0 / 11 업데이트 및 정확한 ZIP URL 발견 |
| `Build11.app` | 0.7.0 / 11 | `OnLatestVersion`, 최신 항목 11 |

설치된 제품 앱에 포함된 Sparkle 2.10.1 프레임워크를 임시 디렉터리로 복사했습니다. Swift 5 모드, `arm64-apple-macos14.0` 대상, `@executable_path/../Frameworks` RPATH로 컴파일했습니다. 두 호스트에 서로 다른 고유 번들 ID를 부여하고 Sparkle의 XPC 서비스·보조 실행 파일·프레임워크와 앱을 순서대로 ad-hoc 서명했습니다. `Downloader.xpc`의 entitlement를 보존했으며 두 앱 모두 `codesign --verify --deep --strict`를 통과했습니다. 빌드 명령·경로·번들 ID는 `prepared-hosts.json`에 기록했습니다.

피드 주소는 제품과 동일한 `https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml`입니다. 공개 키도 `Config/Updates.plist`의 값을 사용했습니다. 자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작합니다. 실행 시 자동 확인 설정 ON → OFF 저장을 검사하고, 종료 전에 자신의 테스트 설정 도메인만 제거합니다.

## v0.7.0 공개 이후 실행

아래 두 명령은 아직 실행하지 않았습니다.

```sh
open -n -W /private/tmp/window-weather-070-sparkle-probe.ga_71g9z/Build10.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.0/update-probe/available.json available
open -n -W /private/tmp/window-weather-070-sparkle-probe.ga_71g9z/Build11.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.0/update-probe/current.json current
```

`SPUUpdater.checkForUpdateInformation()`으로 실제 공개 피드를 조회하고 결과 JSON의 `passed`를 확인해야 합니다. 제한 시간은 30초입니다. 이 검사는 피드 다운로드·파싱·버전 선택·완료 콜백을 대상으로 합니다. 업데이트 안내창, 업데이트 ZIP 다운로드, 설치·재실행은 검사하지 않습니다. 임시 호스트가 arm64이므로 Intel 실행 검증도 포함하지 않습니다.

0.6.3 검증에서 게시 직후 이전 appcast 응답이 관측된 기록이 있으므로 실제 조회 결과를 확인하기 전에는 업데이트 발견 성공으로 보고하지 않습니다. 이번 준비 과정에서 피드를 미리 조회하거나 캐시를 변경하지 않았습니다.
