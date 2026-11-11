# Sparkle 1.0.0 공개 피드 조회 검증

2026-11-11, Sparkle 2.10.1, Apple Silicon Mac.

두 프로브의 컴파일·ad-hoc 서명·`codesign --verify --deep --strict` 검증을 완료했습니다. 아직 피드는 조회하지 않았으며, v1.0.0 공개와 latest 피드 일치가 확인된 뒤 실행합니다.

| 임시 앱 | 호스트 버전 / 빌드 | 기대 결과 |
| --- | --- | --- |
| `Build14.app` | 0.8.0 / 14 | 1.0.0 / 15와 정확한 업데이트 ZIP URL 발견 |
| `Build15.app` | 1.0.0 / 15 | `OnLatestVersion`, 최신 빌드 15 |

## 준비

```sh
python3 docs/releases/1.0.0/update-probe/prepare.py
```

0.8.0 검증의 구조를 그대로 사용합니다. `prepare.py`는 설치된 제품의 Sparkle 2.10.1 프레임워크를 임시 디렉터리에 복사하며 새 의존성을 받지 않습니다. 제품과 동일한 피드 URL과 `Config/Updates.plist`의 공개 키를 사용합니다. Swift 5 모드, `arm64-apple-macos14.0` 대상으로 컴파일한 뒤 XPC·보조 실행 파일·프레임워크·앱 순서로 ad-hoc 서명합니다. Downloader에는 `--preserve-metadata=entitlements`를 적용하고 두 호스트를 `codesign --verify --deep --strict`로 검사합니다.

각 실행에 고유 bundle ID(`org.windowweather.sparkle-probe.v100.*`)와 임시 경로를 사용합니다. 컴파일 명령, 실행 명령, 소스 SHA-256과 서명 검증 결과는 `prepared-hosts.json`에 기록합니다. `main.swift`는 이 프로브 도메인 밖에서 실행하지 못하도록 확인합니다. 제품 설정·키·캐시는 변경하지 않습니다.

## 공개 후 실행

v1.0.0 공개 및 latest 피드가 1.0.0을 가리키는 것이 확인된 뒤 `prepared-hosts.json`에 기록된 각 호스트의 `runCommand`를 순서대로 실행합니다. 기대하는 업데이트 ZIP은 `https://github.com/mindw96/WeatherWeather/releases/download/v1.0.0/WindowWeather-1.0.0-update.zip`입니다.

두 결과 JSON의 `passed`가 모두 `true`이고 최신 빌드가 `15`인지 확인합니다. 구버전 호스트는 표시 버전과 ZIP URL까지 일치해야 하며, 최신 호스트는 `SPUNoUpdateFoundReason.onLatestVersion`이어야 합니다. `open`의 종료 코드만으로 성공을 판정하지 않습니다.

자동 확인·자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화 상태로 시작합니다. 실제 조회 시 자동 확인 ON → OFF 저장을 검사하고 종료 시 테스트 앱 자신의 설정 도메인만 정리합니다.

## 검증 범위

`SPUUpdater.checkForUpdateInformation()`의 실제 피드 다운로드·파싱·버전 선택·완료 콜백과 자동 확인 설정 저장을 검사합니다. 제한 시간은 30초입니다. 업데이트 안내창·ZIP 다운로드·설치·재실행·Intel 실행은 이 프로브의 검증 범위에 포함되지 않습니다.
