# 쌓임쌓임 0.6.1 검증

2026-11-06, Apple Silicon Mac. 앱 0.6.1, 빌드 8. 둥근 상단 표면과 여섯 효과의 충돌·착지·그림을 연결하고, 완전히 가려진 누적의 빈 클리핑 처리를 수정했습니다.

## 코드와 화면

| 검사 | 결과 | 범위 |
| --- | --- | --- |
| Core XCTest | 76개 통과 | 곡선·고속 대각선 충돌·이동/크기 변경·모니터 전달·반경 검증·평평한 전체 화면/바닥 신규 8개 포함 |
| 곡선 렌더링 | 42개 통과 | 여섯 효과의 양쪽 모서리, 허공의 수평 띠 없음, 곡선 밑면, 가림·포커스 숨김 |
| 포커스 옵션 | 62개 통과 | 여섯 효과의 숨김·복원과 설정 저장 |
| 눈사람 | 26개 통과 | 그림·숨김·직접 전달한 드래그 콜백·위치 저장 |
| 실제 테스트 창·컨트롤러 | 45개 통과 | 추적·이동·크기 변경·전체 화면 정책·곡선 전달·컨트롤러 |
| 업데이트 설정 | 6개 통과 | 공개 피드·키 구성과 개발 번들 현지화 |

Core 결과는 소스를 격리한 SwiftPM 패키지에서 수행했으며 원시 stdout을 `core-tests.txt`에 보관합니다. 나머지 결과는 `corner-validation.json`, `focused-window/focus-validation.json`, `snowman/snowman-validation.json`, `smoke.json`입니다. 프로젝트 실행 스크립트로 빌드한 앱 ZIP을 `/private/tmp/window-weather-061-validation/WindowWeather.app`에 풀어 실행했습니다.

`/private/tmp/window-weather-061-previews/corner-before.png`, `corner-after.png`, `snow-preview.png`를 직접 확인했습니다. 같은 26pt 둥근 창 모형에서 눈이 수평으로 떠 있는 상태와 곡선을 따르는 상태를 비교합니다. 실제 다른 앱의 화면 캡처나 실제 코너 측정이 아닙니다. AppKit 테스트 창 검증과 물리 마우스 조작은 구분합니다.

## Core 비용 측정

현재 같은 소스의 반경 0과 26을 비교했습니다. 3840×2160, 650pt 창 10개, 강도1, 고정 seed, 30Hz, 900프레임 워밍업·3,000프레임 측정을 순서 교대로 3회 수행했습니다. 곡선 사용 시 모드별 중간값은 0.0448~0.1071ms/시뮬레이션 프레임이며, 평평한 표면 대비 추가 비용은 0.0063~0.0107ms였습니다. 원시 값과 재현 소스는 `performance/`에 있습니다. 렌더링·Window Server·실앱 CPU·배터리 비용은 측정하지 않았습니다.

## 배포

앱과 DMG의 Developer ID 서명, Apple 공증 Accepted, 공증 티켓, Gatekeeper 허용을 확인했습니다. 앱 제출 ID는 `6128ee06-34bb-4f30-8d62-cbd7f060a4f4`, DMG 제출 ID는 `c6197e21-9183-46ab-b530-0f76a73eff8c`입니다.

공유 ZIP에는 앱 하나만 있으며 업데이트 ZIP과 바이트가 같습니다. Sparkle appcast의 빌드8·0.6.1·ZIP URL·크기 및 EdDSA 서명을 확인했습니다. DMG의 서명·티켓·마운트와 내부 앱·Applications 바로가기를 검증했습니다. `notarization.json`, `dmg-notarization.json`, `artifact-verification.txt`, `dmg-artifact-verification.txt`에 근거가 있습니다.

공개 게시·다운로드 검증은 진행 중입니다.

## 한계

다른 앱의 실제 곡률을 반환하는 공개 API가 없어 OS 스타일 추정값을 적용합니다. 독자적인 창 모양·사각 창에서는 차이가 남을 수 있으며 앞 창의 가림은 기존 사각형 경계로 보수적으로 처리합니다. [구현 범위와 공식 출처](../../CORNER_GEOMETRY.md)를 따릅니다.

Intel Mac·macOS 14 실기기, 모든 배율·Spaces·Mission Control·잠자기 조합, 물리적인 눈사람 드래그는 이번에 검증하지 않았습니다. 실제 날씨 연동은 계속 검토만 완료한 상태입니다.

배포 파일 SHA-256:

- `WindowWeather-0.6.1-macOS-universal.zip`: `1be729d106e28828d93dd54b3e467dba97056e49dcc6b71d104802fd5fb13f23`
- `WindowWeather-0.6.1-update.zip`: `1be729d106e28828d93dd54b3e467dba97056e49dcc6b71d104802fd5fb13f23`
- `appcast.xml`: `46b177c2ee01220fd84f55f2035548a0784044910f3fa0f4a73ace52fdcc06e4`
- `WindowWeather-0.6.1-macOS-universal.dmg`: `06975bf2301985185fbe91358402d7eb761897e2be62dbab7f871713c7acb19b`
