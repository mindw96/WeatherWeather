# 쌓임쌓임 0.5.1 검증

2026-11-05, Apple Silicon Mac. 앱 버전은 0.5.1, 빌드 번호는 6입니다. 한국어 앱 표시 이름과 설치 파일 구성을 변경했으며 기존 날씨 기능과 앱 식별자는 유지했습니다.

## 표시 이름과 앱 동작

| 검사 | 결과 | 확인 범위 |
| --- | --- | --- |
| 한국어 번들 이름 | 통과 | `preferredLocalizations = [ko]`에서 `CFBundleName`과 표시 이름 모두 `쌓임쌓임` |
| 영어 번들 이름 | 통과 | `preferredLocalizations = [en]`에서 두 이름 모두 `Window Weather` |
| 한국어 설정창 | 확인 | 렌더링한 설정창에서 `쌓임쌓임` 제목을 직접 확인 |
| 창·컨트롤러 통합 | 40개 통과 | 실제 테스트 창 감지·이동·크기 변경, 전체 화면 진입·복귀, 포커스·누적 정책, 설정창 재열기 경로 |

근거는 `name-ko.json`, `name-en.json`, `smoke.json`입니다. 두 언어의 Finder 이름 조회 결과는 모두 `WindowWeather.app`이므로 Finder 파일명이 한글로 바뀌었다고 판단하지 않습니다. 앱 표시 이름과 파일 이름을 구분합니다. 통합 검사는 AppKit 메뉴 액션과 재열기 콜백을 사용하며 물리적인 Dock 클릭이나 마우스 전달을 대신하지 않습니다.

## 서명·공증과 설치 파일

앱과 DMG 모두 Developer ID 서명과 Apple 공증 `Accepted`를 확인했습니다.

- 앱 제출 ID: `4b3244a0-01ee-484a-87c5-8fba0f3a8d89`
- DMG 제출 ID: `0af668f8-20b5-4f7f-b4cb-15db090c65b4`

앱에 공증 티켓을 첨부한 뒤 공유 ZIP과 업데이트 ZIP을 해제하여 엄격 코드 서명·티켓·Gatekeeper·arm64/x86_64를 확인했습니다. 두 ZIP은 앱 하나만 포함하며 SHA-256과 바이트 크기 모두 동일합니다. 프로젝트 MIT 라이선스는 서명 전에 `Contents/Resources/LICENSE.txt`에 넣었고, Sparkle 라이선스는 `THIRD_PARTY_NOTICES.txt`에 포함했습니다.

DMG에는 앱과 `/Applications` 바로가기가 있습니다. DMG 자체의 티켓·코드 서명·Gatekeeper·이미지 무결성을 확인하고 읽기 전용으로 마운트했습니다. 내부 앱의 서명·티켓·아키텍처·실행 파일 해시와 Applications 링크를 검증한 뒤 마운트를 해제했습니다. Apple DMG 공증 로그의 `issues`는 `null`입니다.

Sparkle appcast의 빌드 6, 버전 0.5.1, 업데이트 ZIP URL·길이를 확인하고 공식 도구로 EdDSA 서명을 검증했습니다. 근거는 `notarization.json`, `artifact-verification.txt`, `dmg-notarization.json`, `dmg-notarization-log.json`, `dmg-artifact-verification.txt`입니다.

| 로컬 배포 파일 | SHA-256 |
| --- | --- |
| `WindowWeather-0.5.1-macOS-universal.zip` | `f5392051d897fc51fd928d44276d143ee815c0daddd681bad239e749efec934b` |
| `WindowWeather-0.5.1-update.zip` | `f5392051d897fc51fd928d44276d143ee815c0daddd681bad239e749efec934b` |
| `appcast.xml` | `f3676b01e5adc5fbdc48039654b289eeed3b6a55d7e87d6f35d6e1aee607298b` |
| `WindowWeather-0.5.1-macOS-universal.dmg` | `07912cec61080e97ceaf2f904e19aeab82c8dedd231476b9532262f973dab8ed` |

## 게시와 남은 검증

[v0.5.1 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.5.1)를 게시했습니다. 공개 DMG·공유 ZIP·업데이트 ZIP·appcast·체크섬 다섯 파일을 인증 없이 다시 내려받아 모두 HTTP 200과 로컬 SHA-256 일치를 확인했습니다. latest 피드가 0.5.1 appcast와 동일한 것도 확인했습니다. 근거는 `github-release.json`, `public-download-verification.json`입니다.

공식 Sparkle 2.10.1의 실제 피드 조회 결과, 격리된 빌드 5/0.5.0 테스트 호스트는 업데이트 빌드 6/0.5.1과 정확한 ZIP 주소를 받았고 빌드 6/0.5.1 호스트는 `OnLatestVersion`으로 완료했습니다. 자동 확인 ON/OFF 설정 저장도 두 호스트에서 통과했습니다. 소스와 결과는 `update-probe/`에 있습니다. 실제 Sparkle의 앱 교체·설치·재실행은 수행하지 않았습니다.

제품 소스 커밋 `d59c89474361a9aad308a8ac0b8a343ebfa81fd8`의 [main CI](https://github.com/mindw96/WeatherWeather/actions/runs/42035630811)와 [v0.5.1 태그 CI](https://github.com/mindw96/WeatherWeather/actions/runs/42035631429)는 macOS 앱 빌드·업데이트 구성 검사·시뮬레이션 테스트를 모두 통과했습니다.

현재 Mac의 `/Users/mindw/Applications/WindowWeather.app`도 동일한 공증 앱으로 교체했습니다. 이전 설치본을 임시 폴더에 백업하고 새 설치본의 코드 서명·티켓·Gatekeeper를 확인한 뒤 실행했습니다. `NSRunningApplication.localizedName`은 **쌓임쌓임**, 활성화 정책은 일반 Dock 앱입니다. 근거는 `runtime-check.json`입니다.

Intel Mac과 macOS 14 실기기, 모든 모니터 배율·Spaces·Mission Control·잠자기 복귀 조합, 물리 마우스 이벤트 전달은 별도 확인이 필요합니다. 0.5.0의 단위·렌더링·성능 검증은 [이전 기록](../0.5.0/VALIDATION.md)에 보존하며 이번 버전에서 전부 재실행한 것으로 해석하지 않습니다.
