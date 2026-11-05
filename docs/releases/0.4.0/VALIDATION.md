# Window Weather 0.4.0 검증

2026-11-05, Apple Silicon Mac, 화면 2개.

## 동작

- 눈 모드의 `눈사람 표시` 기본 ON. 각 화면 오른쪽 아래에 원본 벡터 눈사람을 표시합니다.
- 모자·몸통·팔의 보이는 부분을 끌어 같은 화면 안에서 이동합니다. 화면별 이동 가능 범위의 상대 좌표를 마우스를 놓을 때 저장합니다.
- 일반 날씨 패널은 계속 클릭을 통과시키고, 별도의 작은 비활성 패널만 눈사람 드래그를 처리합니다. 키보드 포커스를 가져가지 않도록 설정했습니다.
- 투명 모서리와 포커스 설정으로 가려진 부분은 드래그 영역에서 제외합니다. 새 패널은 기존 창 충돌 목록에서도 제외합니다.
- OFF·다른 날씨·일시정지는 눈사람을 숨깁니다. 누적 ON/OFF·누적 지우기는 눈사람과 저장 위치를 지우지 않습니다.

## 검증 결과

| 검사 | 결과 | 확인 범위 |
| --- | --- | --- |
| XCTest | 59개 통과 | 기존 52개 + 상대 위치·화면 경계·크기 변경·저장 형식 7개. 잘못된 경계 보완 후 관련 7개 재실행 통과 |
| 포커스 렌더링·설정 | 42개 통과 | 기존 기능 회귀 검사. `docs/validation/focused-window/focus-validation.json` |
| 눈사람 검사 | 26개 통과 | 실제 WeatherView/SnowmanView 렌더링, 표시·숨김, 마스크, 설정·위치 저장, 직접 전달한 네이티브 뷰 드래그 이벤트. `docs/validation/snowman/snowman-validation.json` |
| 실제 창·컨트롤러 통합 | 40개 통과 | 화면 잠금 해제 후 기존 창 동작 30개와 Dock 정책·설정 메뉴·닫기/최소화 복원 10개. `docs/validation/smoke.json` |
| 설정 UI | 확인 | 자체 뷰 이미지에서 눈사람 스위치, 모드별 비활성화 연결, 미리보기 및 하단 버튼 배치 |

눈사람 검사에서는 보이지 않는 실제 NSPanel의 NSView에 생성한 `NSEvent`를 직접 전달해 mouseDown → mouseDragged → mouseUp 연결, 좌표 이동, 드래그 종료와 위치 복원을 확인했습니다. 실제 Window Server가 물리 마우스 이벤트를 전달하는 경로를 자동 주입한 검사는 아닙니다. 다른 앱의 키보드 포커스 유지와 투명 모서리의 빠른 클릭, 화면 연결 변경은 수동 확인 범위입니다.

작은 눈사람 패널의 입력 통과 여부는 기존 일반 30Hz·저전력 20Hz 루프에서 현재 포인터 위치로 판단합니다. 경계 진입 직후 최대 약 33–50ms의 갱신 지연이 있을 수 있습니다. 마우스를 놓을 때는 즉시 다시 판단합니다. 위치는 화면 식별자별로 저장하며 식별자가 달라진 새 화면은 기본 위치로 시작합니다. 다른 모니터로 옮기는 드래그는 현재 지원하지 않고 각 눈사람이 원래 화면 안에서 이동합니다.

## 컨트롤러 접근 보완

Dock에서 보이지 않았던 원인은 `.accessory` 활성화 정책과 `LSUIElement=true`였습니다. 일반 실행은 `.regular`, 두 번들 스크립트는 `LSUIElement=false`로 변경했습니다. 메뉴 막대 아이콘도 유지합니다. 설정창은 Dock 재열기, Dock의 ‘설정 열기…’, 앱 메뉴의 ‘설정…’(⌘,), 메뉴 막대 날씨 메뉴로 열며 최소화 상태를 복원하고 현재 Space로 이동합니다. 창을 닫아도 앱과 오버레이는 유지합니다.

컨트롤러 검사 10개는 실제 앱의 AppKit 메뉴 액션을 전달하고 닫기·최소화·재열기 콜백을 실행해 동일 설정창의 표시·키 윈도우·화면 내 위치와 날씨 유지 여부를 확인했습니다. 실제 Dock이나 메뉴 막대에 물리 마우스 클릭을 주입한 검사는 아닙니다. 메뉴 막대 버튼이 생성되고 콘텐츠와 표시 상태가 정상임은 확인했지만 사용자가 이전 아이콘을 못 보신 원인을 메뉴 막대 공간 부족으로 단정하지 않습니다.

## 실행과 배포

현재 실행 앱은 `dist/WindowWeather.app`, 개발용 압축 파일은 `dist/WindowWeather-macOS.zip`입니다. 동기화 폴더가 FinderInfo를 다시 붙여 서명을 방해한 문제가 있어, 빌드 스크립트를 임시 로컬 폴더 서명 → 메타데이터 없는 ZIP → 실행 앱 복사 순서로 보완했습니다.

최종 `--verify`에서 0.4.0 (4) 앱 프로세스가 정상 유지되는 것을 확인하고 실행 상태로 남겼습니다. 설정 화면의 `미리보기` 표시는 눈사람과 겹치지 않도록 위쪽으로 옮겼으며 최종 자체 렌더링 이미지에서 배치를 확인했습니다.

0.4.0 공유 앱은 `arm64 x86_64` 통합 Release 빌드이며 Developer ID 서명·Apple 공증을 완료했습니다. `script/release.sh`가 Accepted 확인 후 티켓 첨부와 ZIP 재압축을 진행했고, 최종 ZIP을 다시 풀어 `codesign --verify --deep --strict`, `stapler validate`, `spctl --assess`(accepted, Notarized Developer ID), plist·아키텍처·ZIP 무결성을 모두 확인했습니다. `--resume` 재실행도 완료 ZIP을 재업로드 없이 반환했습니다.

- 공증 ID: `077c3300-e5ba-40c9-a3c0-4499731c8e8f`
- ZIP: `dist/releases/0.4.0/WindowWeather-0.4.0-macOS-universal.zip`
- 크기: 515,190바이트
- SHA-256: `56b84687edbf25dbe9142ec2fd4fd8dcd8b14d13e0dd8477aae5055701600aca`
- 근거: `notarization.json`, `artifact-verification.txt`, `runtime-check.json`, 배포 폴더의 `SHA256SUMS.txt`.

프로젝트의 `dist/WindowWeather.app`도 공증된 Release 앱으로 교체하고 서명·티켓을 재검증한 뒤 실행했습니다. `dist/WindowWeather-macOS.zip`은 개발 스크립트의 로컬 개발용 ZIP이므로 공유에는 버전별 universal ZIP을 사용합니다. 기존 0.3.0 공유 파일은 유지했습니다. Intel Mac 및 macOS 14 실기기 동작은 확인하지 않았습니다.

```sh
swift test --disable-sandbox --cache-path /private/tmp/window-weather-swiftpm-cache --scratch-path /private/tmp/window-weather-core-build
WEATHER_BUILD_DIR=/private/tmp/window-weather-snowman-build ./script/build_and_run.sh --validate-snowman
WEATHER_BUILD_DIR=/private/tmp/window-weather-snowman-build ./script/build_and_run.sh --validate-focus
WEATHER_BUILD_DIR=/private/tmp/window-weather-snowman-build ./script/build_and_run.sh --smoke
WEATHER_BUILD_DIR=/private/tmp/window-weather-snowman-build ./script/build_and_run.sh --previews
WEATHER_BUILD_DIR=/private/tmp/window-weather-snowman-build ./script/build_and_run.sh --verify
```
