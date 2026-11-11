# Sparkle 0.8.0 공개 피드 조회 검증

2026-11-11, Sparkle 2.10.1, Apple Silicon Mac.

v0.8.0 공개와 latest 피드 일치를 확인한 뒤 제품과 별개의 임시 호스트 두 개에서 실제 공개 피드를 조회했습니다. 두 호스트 모두 첫 실행 결과 `passed: true`이며 자동 확인 ON → OFF 저장도 통과했습니다. 제품 키·캐시·설정은 변경하지 않았습니다.

| 임시 앱 | 호스트 버전 / 빌드 | 실제 결과 | 시간 |
| --- | --- | --- | --- |
| `Build13.app` | 0.7.2 / 13 | 0.8.0 / 14와 정확한 업데이트 ZIP URL 발견 | 0.98초 |
| `Build14.app` | 0.8.0 / 14 | `OnLatestVersion`, 최신 빌드 14 | 0.42초 |

원본 결과는 [available.json](available.json), [current.json](current.json)이며 첫 실행 기록은 [available-launch.txt](available-launch.txt), [current-launch.txt](current-launch.txt)에 있습니다. 업데이트 URL은 `https://github.com/mindw96/WeatherWeather/releases/download/v0.8.0/WindowWeather-0.8.0-update.zip`입니다.

## 재현

```sh
python3 docs/releases/0.8.0/update-probe/prepare.py
```

`prepare.py`는 현재 설치된 제품의 Sparkle 2.10.1 프레임워크를 임시 디렉터리에 복사합니다. 새 의존성을 받지 않으며, 제품 키·설정·캐시는 변경하지 않습니다. Swift 5 모드, `arm64-apple-macos14.0` 대상으로 컴파일하고 XPC·보조 실행 파일·프레임워크·앱 순서로 서명합니다. Downloader 서명에는 기존 패키징 스크립트와 같은 `--preserve-metadata=entitlements` 옵션을 적용하며 두 호스트에 `codesign --verify --deep --strict` 검사를 실행합니다. 실행할 때마다 고유 bundle ID와 임시 경로를 사용하며 정확한 명령과 소스 SHA-256을 `prepared-hosts.json`에 기록합니다.

초기 sandbox 내부의 Downloader entitlement XML 조회에서 경고가 있었으나, sandbox 밖에서 원본·이전 staging·설치본·현재 staging의 arm64/x86_64 8개 조합을 조회하고 strict 서명을 검증했을 때 모두 경고 없이 통과했습니다. 빈 entitlement dictionary도 정상 파싱했습니다. [별도 확인 기록](../sparkle-entitlements-check.json)은 관측된 실행 환경 차이를 기록하며 OS 내부 원인을 확정하지 않습니다.

`main.swift`는 0.7.2 프로브의 기대 버전·빌드·ZIP URL을 갱신하고 테스트 설정 도메인 밖에서 실행하지 못하도록 확인을 추가했습니다. 최신 버전 판정은 Sparkle의 `SPUNoUpdateFoundReason.onLatestVersion.rawValue`를 사용합니다.

제품과 동일한 공개 피드 URL과 `Config/Updates.plist`의 공개 키를 사용합니다. 자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작합니다. 실제 조회 실행 시 자동 확인 ON → OFF 저장을 검사하고 테스트 앱 자신의 설정 도메인만 정리합니다.

## 실제 실행

v0.8.0 [공개 다운로드 및 latest 피드 확인](../public-download-verification.json) 후 GUI·네트워크 실행 권한이 있는 환경에서 아래 명령을 순서대로 실행했습니다. 두 호스트의 첫 결과를 보존했으며 피드 URL 변경, 재조회 또는 제품 캐시 변경은 하지 않았습니다. 다시 준비한다면 경로가 바뀌므로 `prepared-hosts.json`의 `runCommand`를 사용합니다.

```sh
/usr/bin/open -n -W /private/tmp/window-weather-080-sparkle-probe.4_g6b1vm/Build13.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.8.0/update-probe/available.json available
/usr/bin/open -n -W /private/tmp/window-weather-080-sparkle-probe.4_g6b1vm/Build14.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.8.0/update-probe/current.json current
```

두 결과 JSON의 `passed`가 모두 `true`이며 최신 빌드 `14`와 자동 확인 설정 저장도 확인했습니다. `open`의 종료 코드만으로 성공을 판정하지 않았습니다.

## 검증 범위

`SPUUpdater.checkForUpdateInformation()`으로 실제 피드 다운로드·파싱·버전 선택·완료 콜백과 자동 확인 설정 저장을 검사했습니다. 제한 시간은 30초입니다. 업데이트 안내창·ZIP 다운로드·설치·재실행·Intel 실행은 검사하지 않았습니다.
