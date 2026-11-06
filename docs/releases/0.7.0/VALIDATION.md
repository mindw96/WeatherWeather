# 쌓임쌓임 0.7.0 검증 상태

버전 0.7.0, 빌드 11. 연결된 모니터별로 날씨 효과를 켜고 끄는 기능을 추가합니다. 로컬 기능 검증, 앱·DMG 서명·공증, GitHub 공개 배포, 공개 다운로드와 Sparkle 버전 판별, 현재 Mac 설치·실행을 완료했습니다.

## 완료한 기능 검증

Apple Silicon Mac, macOS 27.2, 연결된 화면 3개 환경에서 확인했습니다. [결과 요약](local-validation.json)은 이번 버전에서 실행한 검사만 집계합니다.

| 검사 | 결과 | 근거 |
| --- | --- | --- |
| WeatherCore | 76개 통과 | [테스트 로그](core-tests.txt) |
| 업데이트 구성 | 6개 통과 | [구성 검사 로그](update-config-tests.txt) |
| 모서리·겹친 창 | 96개 통과 | [결과](corner-validation.json) |
| 포커스 창 | 62개 통과 | [검증 자료](focused-window/) |
| 눈사람 | 26개 통과 | [검증 자료](snowman/) |
| 실제 AppKit 창·모니터 선택 | 69개 통과, 이 중 모니터 선택 관련 신규 22개 | [결과와 진단](smoke.json) |

모니터 검사는 기본 전체 ON, 각 화면만 선택, 끈 화면의 패널·눈사람 숨김과 입자·누적 초기화, 끈 화면의 시뮬레이션 정지, 나머지 화면의 갱신 유지, 모든 화면 OFF와 재개, 설정 재로딩 후 선택 복원, 분리된 화면 ID 유지, 새 화면 기본 ON, 화면 재구성 후 선택 유지, 기존 날씨·눈사람 설정 보존을 확인했습니다. 화면 연결 변경 알림에서 사용하는 재구성 함수를 직접 호출한 검사이며, 실제 물리 케이블을 분리·재연결한 검사는 아닙니다.

로컬 `settings-preview.png`를 직접 확인했습니다. 이 이미지는 설정 UI 검증 자료이며 실제 데스크톱 전체의 효과 합성이나 물리 마우스 입력을 검증한 자료는 아닙니다. AppKit 검사의 클릭 통과 항목 역시 패널 설정 검사입니다.

## 완료한 패키지 검증

- Apple Silicon·Intel 통합 Release 앱을 빌드하고 Developer ID로 서명했습니다.
- 앱 ZIP 공증: `Accepted`, 제출 ID `01aae2bd-9aef-4bc3-a384-58e90c75540e`. [Apple 응답](notarization.json)
- DMG 공증: `Accepted`, 제출 ID `5921bd0a-ca6c-44c2-90fe-2281a313904d`. [Apple 응답](dmg-notarization.json)
- 앱·DMG 공증 티켓, 코드 서명, Gatekeeper 승인과 ZIP 무결성을 검증했습니다. Sparkle appcast의 버전 0.7.0·빌드 11과 업데이트 ZIP의 EdDSA 서명도 확인했습니다. [앱·ZIP 검증](artifact-verification.txt)
- DMG 안의 앱 서명·공증 티켓·실행 파일 일치·통합 아키텍처·Applications 링크를 확인했습니다. [DMG 검증](dmg-artifact-verification.txt)

## 공개 배포와 설치

[GitHub 0.7.0 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.7.0)에 다섯 파일을 공개했습니다. 비로그인 다운로드 HTTP 200과 로컬 SHA-256 일치, latest 피드의 바이트 일치를 확인했습니다. [게시 기록](github-release.json)과 [공개 다운로드 결과](public-download-verification.json)에 근거를 보관합니다. 게시 직후 latest URL은 0.6.3을 반환했으며 [초기 결과](public-download-initial.json)를 보존했습니다. 같은 URL의 재조회에서 0.7.0으로 갱신된 것을 확인했고 제품 캐시·설정은 변경하지 않았습니다.

실제 Sparkle 2.10.1 검증 호스트에서 빌드 10은 빌드 11·0.7.0과 정확한 업데이트 ZIP URL을 발견했고, 빌드 11은 `OnLatestVersion`으로 판별했습니다. 두 호스트의 자동 확인 ON→OFF 저장도 통과했습니다. [업데이트 발견](update-probe/available.json)과 [최신 버전 판별](update-probe/current.json)은 정보 조회 검사이며 설치 검사는 아닙니다.

현재 Mac의 `~/Applications/WindowWeather.app`을 공증된 0.7.0·빌드 11로 교체했습니다. 교체 전후 서명·공증 티켓·Gatekeeper와 실행 파일 일치를 검증하고 정확한 설치 경로의 실행 프로세스를 확인했습니다. 기존 0.6.3은 `/private/tmp/window-weather-pre-070-backup.1483za_r/WindowWeather.app`에 보관했습니다. [설치 기록](runtime-check.json)을 제공합니다.

소스 커밋 `d409dba05a2b737f2368a10aaf6e871d40657eec`의 main CI는 앱 빌드·업데이트 구성·핵심 테스트를 통과했습니다. 동일 소스의 v0.7.0 태그 CI는 기록 시점에 실행 대기 중입니다. [CI 기록](ci.json)에 각 실행의 상태를 구분합니다.

최종 DMG SHA-256: `b20d428b286b83185434a3378ba746069552377f805aaedb06bcf3bac97a92e7`.
공유·업데이트 ZIP SHA-256: `b5003a4d555ed40007e9d4d6bae943ffe17da8b2cf56f66ed023be045d808be8`.

Sparkle를 통한 실제 업데이트 설치·재실행은 버전 판별 검사와 별개이며 아직 수행하지 않았습니다. CPU 사용량 실측, 물리 케이블 재연결, Intel Mac·macOS 14 실기기, 모든 허브·미러링·배율·잠자기 조합도 별도 검증이 필요합니다.

## 화면 식별과 범위

화면 이름이나 현재 배열 순서 대신 macOS의 디스플레이 UUID로 선택을 저장합니다. UUID를 얻지 못하면 현재 세션의 화면 ID로 대체하므로 이 경우 재연결·재부팅 뒤에는 선택을 다시 확인해야 합니다. 미러링은 macOS가 제공하는 논리 화면 단위이며 물리 모니터마다 다른 내용을 표시하는 기능은 아닙니다. 자세한 동작은 [모니터 선택 안내](../../DISPLAY_SELECTION.md)에 있습니다.
