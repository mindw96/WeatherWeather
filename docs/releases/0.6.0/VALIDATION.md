# 쌓임쌓임 0.6.0 검증

2026-11-05, Apple Silicon Mac. 앱 버전은 0.6.0, 빌드 번호는 7입니다. 비눗방울·색종이와 여섯 효과 선택 UI를 추가하고 설정창 부제를 제거했습니다. 기존 날씨 기능·앱 식별자·설정 저장 경로는 유지했습니다.

## 코드와 화면 검증

| 검사 | 결과 | 확인 범위 |
| --- | --- | --- |
| WeatherCore XCTest | 68개 통과 | 새 두 효과의 생성·이동·정착·수명·해제·모드 전환·다른 화면으로의 누적 전달 등 신규 7개와 기존 핵심 규칙 |
| 포커스 렌더링·설정 | 62개 통과 | 여섯 효과의 작업 창 숨김·복원, 누적 상태 보존, 화면 경계 가림과 설정 저장 |
| 눈사람 | 26개 통과 | 눈 모드 표시·가림·그림과 직접 전달한 드래그 콜백·위치 저장 |
| 창·컨트롤러 통합 | 44개 통과 | 실제 테스트 창 추적·이동·크기 변경·전체 화면 정책, 설정창 재열기와 새 효과의 낙하·정착·지우기 |
| 설정창·새 효과 미리보기 | 직접 확인 | 여섯 효과 선택, 부제 제거, 비눗방울과 색종이의 렌더링 |

근거는 `core-tests.json`, `focused-window/focus-validation.json`, `snowman/snowman-validation.json`, `smoke.json`입니다. Core 결과는 WeatherCore와 테스트를 복사한 별도 Core 전용 Swift 패키지에서 실행한 68개 테스트이며 WeatherApp·Sparkle 빌드 검증과 구분합니다. 테스트의 전체 stdout 로그는 보관하지 않았습니다.

`/private/tmp/window-weather-060-previews/`의 `settings-preview.png`, `bubbles-preview.png`, `confetti-preview.png`를 직접 확인했습니다. 이 이미지는 앱의 미리보기 렌더러로 생성했으며 실제 다른 앱 위의 전체 화면 합성 캡처는 아닙니다. 통합 검사는 AppKit 메뉴 액션과 재열기 콜백, 눈사람 검사는 직접 전달한 이벤트를 사용하므로 실제 물리적인 마우스 입력 검증과 구분합니다.

## 앱·DMG 서명과 공증

앱과 DMG의 Developer ID 서명과 Apple 공증 `Accepted`를 확인했습니다.

- 앱 제출 ID: `85177464-3bd4-46ed-a35b-ac90afe7b109`
- DMG 제출 ID: `77261a6a-4bc9-4cf2-adaa-0d2ddb0b6293`

앱 공증 티켓을 첨부한 후 공유 ZIP과 업데이트 ZIP을 해제해 엄격 코드 서명·공증 티켓·Gatekeeper·arm64/x86_64를 검증했습니다. 두 ZIP은 최상위에 앱 하나만 포함하고 1,591,530바이트 및 SHA-256이 동일합니다. 프로젝트 MIT 고지와 Sparkle 라이선스는 앱 리소스에 포함됩니다.

DMG 자체의 서명·공증 티켓·Gatekeeper·디스크 이미지 무결성 검사가 통과했습니다. 읽기 전용으로 마운트해 내부 앱의 서명·티켓·아키텍처·실행 파일 해시, `/Applications` 바로가기를 확인한 뒤 마운트를 해제했습니다. Apple DMG 공증 로그의 `issues`는 `null`입니다.

Sparkle appcast의 빌드 7·버전 0.6.0·업데이트 ZIP 주소·크기를 확인하고 공식 도구로 EdDSA 서명을 검증했습니다. `release-state.json`은 최종 `complete` 상태입니다. 근거는 `notarization.json`, `artifact-verification.txt`, `dmg-notarization.json`, `dmg-notarization-log.json`, `dmg-artifact-verification.txt`입니다.

| 로컬 배포 파일 | SHA-256 |
| --- | --- |
| `WindowWeather-0.6.0-macOS-universal.zip` | `d979aca06dad6890132e86de02ae5ce3d1586f708bebe3b025a31a5e3c208db9` |
| `WindowWeather-0.6.0-update.zip` | `d979aca06dad6890132e86de02ae5ce3d1586f708bebe3b025a31a5e3c208db9` |
| `appcast.xml` | `32278a5ef38fde7ecf3440db042987e6fd1d6b5d0e517aa3d9310a5ca91c5c4b` |
| `WindowWeather-0.6.0-macOS-universal.dmg` | `943b4a9d9eb73e263a0ec4e0c4bf621d0264a033e7cdbe17b0d53cda001511c4` |

## 실제 날씨 연동 검토

[날씨 연동 검토](../../WEATHER_INTEGRATION.md)는 공급자·배포 자격·위치 선택·호출 한도·비용과 오프라인 처리를 조사한 문서입니다. 이번 버전에는 날씨 조회 코드, 위치 권한 요청, 날씨에 따른 자동 효과 선택을 추가하지 않았습니다. 실제 공급자 연결이나 위치 권한 동작을 실측한 것으로 보지 않습니다.

## 게시와 남은 검증

GitHub 게시·공개 다운로드 해시·latest 피드와 이전 버전의 업데이트 탐지는 아직 완료로 기록하지 않았습니다. 게시 후 공개 파일과 실제 Sparkle 조회 결과를 추가합니다. 실제 Sparkle의 앱 교체·설치·재실행도 이번 로컬 검증에 포함되지 않습니다.

Intel Mac과 macOS 14 실기기, 실제 물리 마우스의 눈사람 드래그·클릭 전달, 모든 모니터 배율·Spaces·Mission Control·잠자기 복귀 조합은 별도 확인이 필요합니다. 기존 [0.5.0 성능 측정](../../PERFORMANCE.md)을 새 두 효과나 앱 전체 CPU·배터리 성능의 근거로 확대하지 않습니다.
