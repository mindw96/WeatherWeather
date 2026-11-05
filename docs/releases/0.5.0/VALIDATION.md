# Window Weather 0.5.0 검증

2026-11-05, Apple Silicon Mac, 화면 2개. 0.5.0은 계산·렌더링 최적화와 Sparkle 2.10.1 업데이트 확인을 포함합니다.

## 자동 검사

| 검사 | 결과 | 확인 범위 |
| --- | --- | --- |
| WeatherCore XCTest | 61개 통과 | 기존 59개와 최대 누적 경계·빠른 횡단 충돌, 동일 창 갱신 시 상태 유지 2개 |
| 실제 창·컨트롤러 통합 | 40개 통과 | Sparkle framework가 포함된 앱의 실제 창 이동·크기 변경·닫기, 포커스·전체 화면 전환·누적 정책, Dock 및 메뉴 설정창 경로 |
| 포커스 렌더링·설정 | 42개 통과 | Sparkle 포함 빌드에서 네 효과의 포커스 창 가림·복원과 설정 저장 회귀 검사 |
| 눈사람 | 26개 통과 | Sparkle 포함 빌드에서 표시·가림·그림·직접 전달한 NSView 드래그 이벤트·위치 저장 회귀 검사 |
| Core 성능 비교 | 상태 동일 | 5회 전후 비교의 모든 상태 fingerprint 동일. 합성 부하의 Core 실행 시간 감소 |
| 렌더링 비교 | RGBA 8개 동일 | 네 효과 × 포커스 가림 ON/OFF에서 변경 전후 RGBA 바이트 일치. 낙엽·벚꽃 렌더 시간 감소 |

실행 보고서는 `docs/validation/smoke.json`, `docs/validation/focused-window/focus-validation.json`, `docs/validation/snowman/snowman-validation.json`에 있습니다. 성능 측정 조건과 원시 자료는 [PERFORMANCE.md](../../PERFORMANCE.md)와 `docs/validation/performance/`에 보관합니다.

## 변경 내용과 범위

`WeatherSimulation.setSurfaces`는 이미 정규화된 기존 창 경계와 입력이 같으면 배열을 재구성하지 않습니다. 새로운 입력의 검증은 유지합니다. 충돌 검사는 입자의 전체 이동 구간과 누적 최대 높이를 기준으로 불가능한 창을 먼저 제외하며, 기존 높이 보간과 가장 먼저 닿는 창 선택을 유지합니다.

렌더러는 계절 효과의 기본 색과 도형 경로를 재사용하도록 바꾸었습니다. 기존 크기·회전·불투명도·포커스 가림 계산은 유지합니다. Core 측정과 화면 밖 렌더링 측정은 서로 분리했으며, 수치를 더하거나 앱 전체 CPU·배터리 감소율로 해석하지 않습니다.

Sparkle이 자동 확인 주기와 저장된 선택을 관리합니다. 정상 배포 빌드의 자동 확인은 기본 ON이고 사용자가 끌 수 있으며, 설정창·앱 메뉴·날씨 메뉴에서 수동 확인을 시작합니다. 자동 설치는 사용하지 않습니다. 검증 전용 실행 모드는 업데이트 서버에 연결하거나 사용자 Sparkle 설정을 바꾸지 않도록 updater를 비활성화합니다.

## 배포와 업데이트 검증

0.5.0 Developer ID 서명과 Apple 공증이 완료되었습니다. 제출 ID는 `dc19790b-5d03-438f-9f28-cd165bbff88e`이며 응답은 `Accepted`입니다. 공증 티켓을 첨부한 뒤 공유 ZIP과 앱 전용 업데이트 ZIP을 각각 다시 풀어 엄격 코드 서명, 티켓, Gatekeeper `accepted / Notarized Developer ID`, 두 CPU 아키텍처를 확인했습니다.

공식 Sparkle `generate_appcast`로 빌드 5의 피드를 만들고 키체인 공개 키·앱 공개 키·설정 공개 키를 대조했습니다. 피드의 버전·ZIP URL·길이를 검증하고 공식 `sign_update --verify`로 업데이트 ZIP의 EdDSA 서명을 검증했습니다. 세 파일의 SHA-256은 배포 폴더 `SHA256SUMS.txt`에 보관합니다. 근거는 `notarization.json`과 `artifact-verification.txt`입니다.

[v0.5.0 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.5.0)를 공개했습니다. GitHub에 올라간 파일 네 개의 digest를 로컬과 대조했고, 공개 URL에서 피드·공유 ZIP·업데이트 ZIP을 인증 없이 다시 내려받아 HTTP 200과 SHA-256 일치를 확인했습니다. 결과는 `github-release.json`, `public-download-verification.json`에 있습니다.

공식 Sparkle `checkForUpdateInformation()`으로 공개 피드를 조회한 결과 두 테스트 호스트 모두 통과했습니다. 빌드 5는 `OnLatestVersion`과 최신 항목 5, 빌드 4는 업데이트 빌드 5/0.5.0과 올바른 ZIP URL을 받았습니다. 두 호스트에서 자동 확인 선택의 ON/OFF 저장도 통과했습니다. 소스와 결과는 `update-probe/`에 있습니다. 이는 조회·파싱·버전 선택 검사이며, 업데이트 설치·재실행 검사는 아닙니다. 빌드 4는 Sparkle가 포함된 테스트 호스트로 실제 배포한 0.4.0과 구분합니다.

최초 제품 소스 커밋 `5cc29910e4063c5691d390b34fedc4f5bb52cc7b`와 v0.5.0 태그의 GitHub Actions macOS 빌드·업데이트 설정 검사·XCTest가 모두 성공했습니다: [main 실행](https://github.com/mindw96/WeatherWeather/actions/runs/42029808736), [태그 실행](https://github.com/mindw96/WeatherWeather/actions/runs/42029808796).

동기화된 Documents 실행본에 FinderInfo가 다시 붙는 문제가 재현되어, 최종 실행 앱은 `/Users/mindw/Applications/WindowWeather.app`에 설치했습니다. 해당 설치본의 엄격 코드 서명·공증 티켓·Gatekeeper 허용을 확인하고 실행했습니다. 실제 프로세스·일반 Dock 앱 정책·화면 내 설정창은 `runtime-check.json`으로 확인합니다. 동기화 폴더의 개발용 `dist` 앱과 공증된 사용자 Applications 설치본을 구분합니다.

0.4.0에는 Sparkle이 없어 0.4.0 → 0.5.0 설치는 수동 교체입니다. 향후 업데이트는 공증된 앱 하나를 담은 업데이트 ZIP과 EdDSA 서명된 appcast를 사용합니다. 공유 안내·라이선스가 함께 담긴 universal ZIP과 업데이트 전용 ZIP은 별도 산출물입니다.

## 남은 실제 사용 검증

Intel Mac과 macOS 14 실기기, 실제 물리 마우스 이벤트의 눈사람 전달 경로, 모든 화면 배율·Spaces·Mission Control·잠자기 복귀 조합은 별도입니다. AppKit 메뉴 액션·재열기 콜백 검사와 직접 전달한 NSView 이벤트를 실제 Dock 클릭·물리 드래그 검사로 해석하지 않습니다. 성능 측정에는 Window Server 합성·여러 모니터의 전체 앱 실행·에너지 사용량이 포함되지 않습니다.
