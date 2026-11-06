# Sparkle 0.6.3 공개 피드 조회 검증

2026-11-06, Sparkle 2.10.1 공식 프레임워크, Apple Silicon Mac.

v0.6.3 GitHub Release를 공개한 뒤 제품 앱과 별개의 임시 앱 두 개에서 `SPUUpdater.checkForUpdateInformation()`으로 실제 공개 피드를 조회했습니다. 각 앱은 고유 번들 ID와 독립된 설정을 사용하며 종료 전에 자신의 테스트 설정 도메인만 제거합니다.

| 임시 앱 | 기대 동작 | 최종 결과 | 시간 |
| --- | --- | --- | --- |
| 빌드 9, 표시 버전 0.6.2 | 빌드 10 업데이트 발견 | 빌드 10 / 버전 0.6.3, 정확한 공개 업데이트 ZIP URL 확인 | 0.44초 |
| 빌드 10, 표시 버전 0.6.3 | 최신 버전 | `OnLatestVersion`, 최신 항목 10 | 0.45초 |

두 경우 모두 `passed: true`이며 자동 확인 설정 ON → OFF 저장도 통과했습니다. 자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화했으며 조회 제한 시간은 30초입니다. 이후 캐시를 추가로 건드리지 않고 같은 호스트에서 한 번씩 더 실행했으며 두 검사 모두 통과했습니다(`warm-available.json`, `warm-current.json`).

- [공개 피드](https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml)
- [발견한 업데이트](https://github.com/mindw96/WeatherWeather/releases/download/v0.6.3/WindowWeather-0.6.3-update.zip)
- 최종 원본 결과: `available.json`, `current.json`

## 게시 직후 이전 피드 응답

최초 실행에서는 두 호스트가 빌드 9의 이전 appcast를 받아 기대 검사에 실패했습니다. 이 결과는 `initial-available.json`, `initial-current.json`에 보존했습니다. 같은 호스트의 재조회에서도 이전 피드를 받았지만, 같은 latest URL의 curl 조회와 Sparkle 형식의 Accept/User-Agent를 사용한 curl 조회는 빌드 10을 반환했습니다. curl의 GitHub 리디렉션은 `/releases/download/v0.6.3/appcast.xml`, Cache-Control은 `no-cache`였습니다.

격리된 테스트 호스트의 URL 캐시에서 실제 0.6.2 appcast 본문을 확인했습니다. 호스트가 종료된 것을 확인한 뒤 해당 두 캐시 디렉터리만 `/private/tmp/window-weather-063-sparkle-probe.p2yglwyz/initial-cache-build9` 및 `initial-cache-build10`으로 백업 이동했습니다. 같은 앱과 정확히 같은 피드 URL로 재실행했을 때 기대 결과를 얻었고, 이어 캐시를 유지한 재실행도 통과했습니다. 쿼리 문자열·피드 주소·제품 앱·제품 캐시·사용자 설정은 변경하지 않았습니다.

이 관측만으로 게시 직후 배포 전파 지연과 URL 리디렉션/캐시 중 단독 원인을 확정하지 않습니다. Sparkle 2.10.1 원본 `SPUDownloadDriver.m`은 appcast 요청에 `NSURLRequestReloadIgnoringLocalCacheData`를 설정합니다. 모든 기존 설치의 캐시에서 즉시 새 버전을 찾는다는 검증은 아닙니다.

## 검증 구성과 범위

`main.swift`는 0.6.2 검증 소스의 기대 빌드를 10으로 바꾸고 업데이트 발견 시 표시 버전과 ZIP URL까지 일치하는지 검사합니다. 공식 Sparkle 2.10.1 프레임워크와 `swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -framework AppKit -framework Sparkle`로 빌드하고 `@executable_path/../Frameworks` RPATH를 지정했습니다. Info.plist에는 공개 피드·공개 키, 테스트별 버전과 고유 번들 ID를 설정했습니다. 임시 앱은 ad-hoc 서명 후 `codesign --verify --deep --strict`를 통과했습니다.

임시 호스트는 `/private/tmp/window-weather-063-sparkle-probe.p2yglwyz/Build9.app`, `Build10.app`입니다. `open -n -W <임시 앱> --args <결과.json> available` 또는 `current`로 실행했고 두 프로세스가 정상 종료했습니다. 제품 소스, 설치된 제품 앱, 배포 파일은 변경하지 않았습니다.

이 검사는 실제 Sparkle의 공개 피드 다운로드·파싱·버전 선택·완료 콜백을 확인합니다. 업데이트 안내창, 업데이트 ZIP 다운로드, 설치·재실행은 수행하지 않았습니다. 배포 파일의 서명·공증·EdDSA 및 공개 다운로드 무결성은 상위 릴리스 검증 기록에서 별도로 다룹니다.
