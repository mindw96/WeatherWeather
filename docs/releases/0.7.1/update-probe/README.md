# Sparkle 0.7.1 공개 피드 조회 검증

2026-11-07, Sparkle 2.10.1, Apple Silicon Mac.

v0.7.1 공개 및 latest 피드 바이트 일치 확인 후, 제품과 별개의 임시 호스트 두 개에서 실제 공개 피드를 조회했습니다. 두 호스트 모두 첫 실행 결과 `passed: true`이며 자동 확인 ON → OFF 저장도 통과했습니다. 제품 키·캐시·사용자 설정은 수정하지 않았습니다.

| 임시 앱 | 호스트 버전 / 빌드 | 실제 결과 | 시간 |
| --- | --- | --- | --- |
| `Build11.app` | 0.7.0 / 11 | 0.7.1 / 12 업데이트 및 정확한 ZIP URL 발견 | 0.74초 |
| `Build12.app` | 0.7.1 / 12 | `OnLatestVersion`, 최신 항목 12 | 0.22초 |

원본 결과는 `available.json`, `current.json`에 있습니다. 업데이트 URL은 `https://github.com/mindw96/WeatherWeather/releases/download/v0.7.1/WindowWeather-0.7.1-update.zip`입니다.

## 구성과 실행

`main.swift`는 0.7.0 검증 소스에서 기대 버전·빌드·ZIP URL만 변경했습니다. 설치된 제품의 Sparkle 2.10.1 프레임워크를 임시 디렉터리로 복사하고 Swift 5 모드·`arm64-apple-macos14.0` 대상·`@executable_path/../Frameworks` RPATH로 컴파일했습니다. 두 호스트의 고유 번들 ID는 제품과 다르며, 내부 XPC·보조 실행 파일·프레임워크·앱을 순서대로 ad-hoc 서명했습니다. `Downloader.xpc`의 기존 entitlement를 보존했고 두 앱 모두 `codesign --verify --deep --strict`를 통과했습니다. 빌드 명령·경로·결과는 `prepared-hosts.json`에 기록했습니다.

제품과 동일한 `https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml` 및 `Config/Updates.plist`의 공개 키를 사용했습니다. 자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작하며, 실행 중 자동 확인 ON → OFF 저장을 검사하고 종료 전에 자신의 테스트 설정 도메인만 정리합니다.

다음 두 명령을 GUI 실행 권한이 있는 환경에서 순서대로 실행했습니다. 앱을 다시 실행하거나 피드 URL·캐시를 변경하지 않고 첫 결과를 보존했습니다.

```sh
/usr/bin/open -n -W /private/tmp/window-weather-071-sparkle-probe.itmolhe6/Build11.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.1/update-probe/available.json available
/usr/bin/open -n -W /private/tmp/window-weather-071-sparkle-probe.itmolhe6/Build12.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.1/update-probe/current.json current
```

실행을 마친 뒤 Python 래퍼의 추가 확인이 `OnLatestVersion` 원시 값을 0으로 잘못 가정해 실패했습니다. Sparkle 2.10.1의 `Headers/SUErrors.h`에서 `Unknown=0`, `OnLatestVersion=1`을 확인했고 원본 JSON의 값 1을 재검증했습니다. Swift 프로브 자체는 enum의 실제 rawValue를 사용해 처음부터 `passed: true`를 기록했습니다. 이 사후 확인 오류와 정정은 `postflight-check.txt`에 기록했으며 원본 JSON은 변경하지 않았습니다.

## 검증 범위

`SPUUpdater.checkForUpdateInformation()`으로 실제 피드 다운로드·파싱·버전 선택·완료 콜백과 자동 확인 설정 저장을 검사했습니다. 제한 시간은 30초입니다. 업데이트 안내창·ZIP 다운로드·설치·재실행·Intel 실행은 검사하지 않았습니다.
