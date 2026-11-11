# Sparkle 0.8.0 공개 피드 조회 검증 준비

2026-11-11, Sparkle 2.10.1, Apple Silicon Mac.

제품과 별개의 임시 호스트 두 개를 컴파일하고 ad-hoc 서명 검증까지 완료했습니다. **아직 공개 피드를 조회하지 않았습니다.** v0.8.0 공개와 latest 피드 일치 확인 후 아래 명령으로 실제 조회해야 합니다.

| 임시 앱 | 호스트 버전 / 빌드 | 기대 결과 | 준비 상태 |
| --- | --- | --- | --- |
| `Build13.app` | 0.7.2 / 13 | 0.8.0 / 14와 정확한 업데이트 ZIP URL 발견 | 컴파일·서명 검증 통과 |
| `Build14.app` | 0.8.0 / 14 | `OnLatestVersion`, 최신 빌드 14 | 컴파일·서명 검증 통과 |

기대 업데이트 URL은 `https://github.com/mindw96/WeatherWeather/releases/download/v0.8.0/WindowWeather-0.8.0-update.zip`입니다.

## 재현

```sh
python3 docs/releases/0.8.0/update-probe/prepare.py
```

`prepare.py`는 현재 설치된 제품의 Sparkle 2.10.1 프레임워크를 임시 디렉터리에 복사합니다. 새 의존성을 받지 않으며, 제품 키·설정·캐시는 변경하지 않습니다. Swift 5 모드, `arm64-apple-macos14.0` 대상으로 컴파일하고 XPC·보조 실행 파일·프레임워크·앱 순서로 서명합니다. Downloader 서명에는 기존 패키징 스크립트와 같은 `--preserve-metadata=entitlements` 옵션을 적용하며 두 호스트에 `codesign --verify --deep --strict` 검사를 실행합니다. 실행할 때마다 고유 bundle ID와 임시 경로를 사용하며 정확한 명령과 소스 SHA-256을 `prepared-hosts.json`에 기록합니다.

설치된 원본 Downloader의 entitlement 표시 결과는 빈 `[Dict]`였으며 `--xml` 조회 시 invalid entitlements blob 경고가 있었습니다. 복사본의 표시 결과도 원본과 같았고 strict 서명 검사는 통과했습니다. 이 프로브는 업데이트 파일 다운로드·설치를 검증하지 않으므로 그 동작에 관한 근거로 사용하지 않습니다.

`main.swift`는 0.7.2 프로브의 기대 버전·빌드·ZIP URL을 갱신하고 테스트 설정 도메인 밖에서 실행하지 못하도록 확인을 추가했습니다. 최신 버전 판정은 Sparkle의 `SPUNoUpdateFoundReason.onLatestVersion.rawValue`를 사용합니다.

제품과 동일한 공개 피드 URL과 `Config/Updates.plist`의 공개 키를 사용합니다. 자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작합니다. 실제 조회 실행 시 자동 확인 ON → OFF 저장을 검사하고 테스트 앱 자신의 설정 도메인만 정리합니다.

## 공개 후 실행

v0.8.0 공개 완료 후 GUI 실행 권한이 있는 환경에서 순서대로 실행합니다. 다시 준비했다면 경로가 바뀌므로 `prepared-hosts.json`의 `runCommand`를 사용합니다.

```sh
/usr/bin/open -n -W /private/tmp/window-weather-080-sparkle-probe.4_g6b1vm/Build13.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.8.0/update-probe/available.json available
/usr/bin/open -n -W /private/tmp/window-weather-080-sparkle-probe.4_g6b1vm/Build14.app --args /Users/mindw/Documents/Projects/Weather/docs/releases/0.8.0/update-probe/current.json current
```

두 결과 JSON의 `passed`가 모두 `true`인지 확인해야 합니다. `open`의 종료 코드만으로 성공을 판정하지 않습니다. 실패 시 첫 결과를 보존한 다음 원인을 확인합니다.

## 검증 범위

준비 단계는 컴파일과 서명 검증만 완료했습니다. 실제 조회는 `SPUUpdater.checkForUpdateInformation()`으로 피드 다운로드·파싱·버전 선택·완료 콜백과 자동 확인 설정 저장을 검사하며 제한 시간은 30초입니다. 업데이트 안내창·ZIP 다운로드·설치·재실행·Intel 실행은 검사하지 않습니다.
