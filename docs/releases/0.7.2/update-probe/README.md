# Sparkle 0.7.2 공개 피드 조회 검증

2026-11-07, Sparkle 2.10.1, Apple Silicon Mac.

v0.7.2 공개와 latest 피드 일치 확인 후 제품과 별개의 임시 호스트 두 개에서 실제 공개 피드를 조회했습니다. 두 호스트 모두 첫 실행 결과 `passed: true`이며 자동 확인 ON → OFF 저장도 통과했습니다. 제품 키·캐시·설정은 변경하지 않았습니다.

| 임시 앱 | 호스트 버전 / 빌드 | 실제 결과 | 시간 |
| --- | --- | --- | --- |
| `Build12.app` | 0.7.1 / 12 | 0.7.2 / 13과 정확한 업데이트 ZIP URL 발견 | 1.15초 |
| `Build13.app` | 0.7.2 / 13 | `OnLatestVersion`, 최신 빌드 13 | 0.23초 |

원본 결과는 `available.json`, `current.json`이며 실행 기록은 `available-launch.txt`, `current-launch.txt`에 있습니다. 업데이트 URL은 `https://github.com/mindw96/WeatherWeather/releases/download/v0.7.2/WindowWeather-0.7.2-update.zip`입니다.

## 구성과 실행

`main.swift`는 0.7.1 프로브에서 기대 버전·빌드·업데이트 ZIP URL만 바꿨습니다. 최신 버전 판정은 Sparkle의 `SPUNoUpdateFoundReason.onLatestVersion.rawValue`를 사용하며 별도 숫자를 가정하지 않습니다.

설치된 제품의 Sparkle 2.10.1 프레임워크를 임시 디렉터리로 복사해 Swift 5 모드, `arm64-apple-macos14.0` 대상으로 컴파일했습니다. 제품과 다른 고유 번들 ID를 사용하고 XPC·보조 실행 파일·프레임워크·앱 순서로 기존 entitlement를 보존해 ad-hoc 서명했습니다. 두 호스트의 `codesign --verify --deep --strict` 검사도 통과했습니다. 경로·번들 ID·컴파일 명령은 `prepared-hosts.json`에 있습니다.

제품과 동일한 공개 피드 URL과 `Config/Updates.plist`의 공개 키를 사용했습니다. 자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작하며, 실행 중 자동 확인 ON → OFF 저장을 검사하고 자신의 테스트 설정 도메인만 정리합니다.

다음 명령을 GUI 실행 권한이 있는 환경에서 순서대로 실행했습니다. 첫 결과를 보존했고 앱 재실행이나 피드 URL·캐시 변경은 하지 않았습니다.

```sh
/usr/bin/open -n -W /private/tmp/window-weather-072-sparkle-probe.kbyte_9g/Build12.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.2/update-probe/available.json available
/usr/bin/open -n -W /private/tmp/window-weather-072-sparkle-probe.kbyte_9g/Build13.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.7.2/update-probe/current.json current
```

## 검증 범위

`SPUUpdater.checkForUpdateInformation()`으로 실제 피드 다운로드·파싱·버전 선택·완료 콜백과 자동 확인 설정 저장을 검사했습니다. 제한 시간은 30초입니다. 업데이트 안내창·ZIP 다운로드·설치·재실행·Intel 실행은 검사하지 않았습니다.
