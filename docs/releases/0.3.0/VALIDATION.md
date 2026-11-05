# Window Weather 0.3.0 검증

2026-11-05, Apple Silicon macOS 호스트, 연결된 화면 2개.

## 이번 변경

`사용 중인 창에도 효과 표시`를 추가했습니다. 기본 ON이며 OFF에서는 활성 앱의 맨 앞 일반 창 안의 낙하 효과와 해당 창의 전체 누적을 숨깁니다. 표시만 바꾸므로 기존 누적과 시뮬레이션은 유지합니다. 전체 화면 누적 옵션과 독립적이고, OFF인 포커스 창에는 누적을 켜도 표시하지 않습니다.

일반 창 선택에는 `NSWorkspace.frontmostApplication`과 `kCGWindowOwnerPID`, CG 창의 앞뒤 순서를 사용합니다. 별도 권한 요청이나 창 제목·내용 수집은 추가하지 않았습니다. 프로세스 ID는 메모리에서만 사용합니다. 작은 팝업·별도 레이어 도구 패널은 정확한 키 창 상태와 다를 수 있습니다.

## 결과

| 검사 | 결과 | 범위 |
| --- | --- | --- |
| SwiftPM XCTest | 52개 통과 | 기존 42개 및 포커스 선택·표시 정책 10개 |
| 포커스 렌더링·설정 저장 | 42개 통과 | `docs/validation/focused-window/focus-validation.json` |
| 공유 ZIP의 Release 렌더링 | 42개 통과 | `focused-window/focus-validation.json`; ZIP 재추출 후 실행 |
| 실제 창 통합 점검 | 보류 | 화면 잠금 감지로 `status=blocked`; 실제 포커스 전환 성공으로 간주하지 않음 |

설정 UI의 ON/OFF 상태도 앱 자체 비트맵으로 확인했습니다. OFF 미리보기에서 오른쪽 가상 작업 창의 적설과 창 안 낙하가 사라지고 왼쪽 창은 유지됩니다. 스위치와 설명, 하단 조작 버튼은 잘리지 않습니다.

렌더링 검사는 실제 `WeatherView.draw`를 자체 생성 비트맵에 그려 눈·비·낙엽·벚꽃의 숨김/표시 결과를 픽셀 단위로 비교합니다. 창 내부의 투명도, 다른 영역의 동일성, 윗변 위 누적의 숨김, 다른 창 누적의 유지, 재표시 시 동일 프레임 복원, 시뮬레이션 상태 보존, 빗방울 튐까지 확인했습니다. 사용자의 데스크톱을 촬영한 결과가 아닙니다.

실제 창 점검에는 두 창을 번갈아 활성화하여 숨김 대상 이동·옵션 ON 복원을 확인하는 항목을 추가했습니다. 현재 Mac 세션이 잠겨 있어 실행되지 않았으며, 잠금 해제 후 `./script/build_and_run.sh --smoke`로 확인해야 합니다. Intel Mac, macOS 14 실기기, 모든 앱의 특수 창·Spaces 조합은 검증하지 않았습니다.

## 재현

```sh
swift test --disable-sandbox --cache-path /private/tmp/window-weather-swiftpm-cache --scratch-path /private/tmp/window-weather-core-build
WEATHER_BUILD_DIR=/private/tmp/window-weather-focus-build ./script/build_and_run.sh --validate-focus
WEATHER_BUILD_DIR=/private/tmp/window-weather-focus-build ./script/build_and_run.sh --smoke
WEATHER_BUILD_DIR=/private/tmp/window-weather-focus-build ./script/build_and_run.sh --previews
```

`--disable-sandbox`는 도구 환경의 SwiftPM 중첩 sandbox 제약을 피하기 위한 테스트 옵션이며, 앱의 보안 설정 변경 절차가 아닙니다.

## 패키지와 현재 실행 상태

`script/build_and_run.sh --verify`에서 0.3.0 앱의 프로세스가 유지되는 것을 확인했고, 프로젝트의 `dist/WindowWeather.app`을 실행 상태로 남겼습니다. 화면 잠금 중이므로 이것을 실제 창 포커스 전환 검증으로 보지는 않습니다.

`dist/releases/0.3.0/WindowWeather-0.3.0-macOS-universal.zip`에 arm64·x86_64 Release 앱과 한국어 안내, 변경 내역, MIT 라이선스를 담았습니다. Developer ID Application 서명, Hardened Runtime, timestamp를 적용하고 재추출한 앱의 엄격한 서명 검사를 통과했습니다. 같은 폴더의 `SHA256SUMS.txt`가 최종 ZIP 해시입니다.

Apple 업로드는 처음 자동 승인 검토에서 거절됐습니다. 0.2.0 ZIP의 이전 승인은 이 0.3.0 ZIP 전송에 적용되지 않는다는 이유였으며, 이후 사용자에게 **“0.3.0도 Apple에 업로드하여 공증”**이라는 명시적 승인을 받아 제출했습니다.

Apple 공증 결과는 **Accepted**, 제출 ID는 `7950086f-4673-4f4f-8486-428acce10bc9`입니다. 원본 서비스 응답은 `notarization.json`에 보관합니다. 제출한 ZIP의 SHA-256은 `f58caf997aacf85ff4b7137831ac60f85306925243295e468f0c1d3930016a6b`이며, 공증 정보 첨부와 안내 문서 갱신 후 최종 배포 ZIP의 해시는 `SHA256SUMS.txt`에서 확인합니다. 이 공증 승인은 위의 GUI·Intel 실기기 검증 보류를 해소한 것으로 간주하지 않습니다.

공증 티켓을 앱에 첨부한 뒤 안내 문서를 갱신하고 ZIP을 다시 만들었습니다. 최종 ZIP을 새 임시 폴더에 재추출하여 엄격한 코드 서명 검사, Info.plist 검사, arm64·x86_64 아키텍처 확인, `stapler validate`를 통과했습니다. Gatekeeper 결과는 **accepted / source=Notarized Developer ID**, 서명 정보는 **Notarization Ticket=stapled**입니다. 상세 출력은 `artifact-verification.txt`에 보관합니다. ZIP 압축 무결성 검사도 통과했으며 최종 크기는 **425,935바이트**입니다.
