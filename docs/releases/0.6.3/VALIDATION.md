# 쌓임쌓임 0.6.3 검증

2026-11-06. 버전 0.6.3, 빌드 10. 창이 겹칠 때 누적 효과의 가림과 앞뒤 표시 순서를 수정했습니다.

## 구현과 전후 비교

기준선에서 계산한 노출 구간을 수직으로 확대해 누적 전체에 적용하던 렌더링을 제거했습니다. 이제 누적 전체 영역에서 앞 창의 둥근 외곽을 순차적으로 제외하며, 뒤 창부터 그립니다. 여러 앞 창이 겹쳐도 교집합이 다시 노출되지 않고, 완전히 빈 클립은 경로 생성 전에 건너뜁니다. 전체 화면으로 판정한 창의 외곽은 사각형입니다.

동일한 신규 fixture를 v0.6.2의 WeatherView·OverlayController로 실행했을 때 여섯 효과 각각의 둥근 틈·같은 높이의 잘림·가려진 기준선 위로 솟은 누적 등 18개 검사가 실패했습니다. 수정 렌더러는 기존 42개와 새 54개를 합한 96개를 통과했습니다. `overlap-comparison.json`과 `corner-validation.json`을 보관합니다. `overlap-before.png` / `overlap-after.png`는 이 두 렌더러로 만든 같은 합성 장면이며 직접 확인했습니다. 다른 앱을 캡처한 이미지는 아닙니다.

겹치지 않은 여섯 효과의 결정적 미리보기 PNG가 이전 렌더러와 바이트 단위로 같았습니다. `non-overlap-comparison.json`에 해시를 기록했습니다. 작업 창 숨김·복원·설정 보존 렌더링 검사 62개도 통과했습니다.

## 빌드와 창 동작

- 수정 전 핵심 XCTest 76개 통과. 이번 변경에서 WeatherCore와 핵심 테스트 파일은 변경하지 않았습니다.
- 업데이트 구성 검사 6개 통과. 앱은 기존 SwiftPM과 `script/build_and_run.sh --build-only`로 빌드했습니다.
- 실제 AppKit 창·컨트롤러 검사는 초기 수정본에서 47개를 통과했습니다. 빈 클립 생략을 추가한 뒤에는 46개가 통과했으나 `controllerIsKeyAfterReopen`이 실패했습니다. 사용자 인증 입력과 동시 실행되어 창 포커스 간섭 가능성이 있으며, 이 재실행의 실패 기록은 `smoke-focus-interrupted.json`에 보관합니다. 인증 입력을 마친 뒤 최종 제품 소스로 다시 실행하여 47개 모두 통과했습니다. `smoke.json`이 최종 결과입니다.

## 서명과 공증

새 MacBook에서 기존 Developer ID Application 인증서와 Sparkle 공개 키 일치를 확인했습니다. 새 인증서나 Sparkle 키를 만들지 않았습니다. 통합 arm64/x86_64 Release 앱 빌드와 Developer ID 서명을 수행했습니다.

기존 `DdayNotary` 조회·제출은 exit69로 실패했고 제출 ID는 없었습니다. 사용자가 새 MacBook임을 확인하고 새 등록을 요청하여 `WindowWeatherNotary`를 기본 프로필로 변경했습니다. 사용자가 로컬 Terminal의 보안 입력으로 등록을 마쳤고 인증된 공증 이력 조회를 통과했습니다. 암호를 채팅·저장소·로그 파일에 저장하지 않았으며 기존 Developer ID·Sparkle 키와 GitHub 인증은 재사용합니다.

- 앱 공증 **Accepted**: `7f5875ef-1264-4330-bf1b-2fb1ca37974f`.
- DMG 공증 **Accepted**: `29a4cb07-655c-4990-a1ee-a9099e8ad626`.
- 앱·DMG 티켓, 엄격 서명·Gatekeeper 검사, DMG 마운트 및 앱 실행 파일·통합 아키텍처·Applications 링크를 검증했습니다.
- 빌드 10 Sparkle EdDSA 서명을 검증했습니다. 공유 ZIP에는 앱 하나만 들어 있고 업데이트 ZIP과 바이트가 같습니다. `artifact-verification.txt`와 `dmg-artifact-verification.txt`에 기록했습니다.
- 현재 Mac에 공증된 0.6.3을 설치하고 실행 프로세스를 확인했습니다. 기존 0.6.2 백업 경로와 검증 명령은 `runtime-check.json`에 기록했습니다.
- 소스 `bee77b4620130451352d364386c38dc24acc3dc4`의 main·v0.6.3 태그 CI 모두 앱 빌드·업데이트 구성·핵심 테스트를 통과했습니다. `ci.json`에 기록했습니다.

최종 DMG SHA-256: `f7c562fbfd52ba6057032e2e062f137fd318e1af357c2924718490c8b9c7324a`.
공유·업데이트 ZIP SHA-256: `0c6ebfc1f2113bad130bf96100f17f037c4c6711b179ec8bcaa01f885dcd2d7d`.

[GitHub 0.6.3 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.6.3)에 다섯 파일을 공개했습니다. 비로그인 다운로드 HTTP 200과 로컬 SHA-256 일치, latest 피드의 바이트 일치를 확인했습니다. `github-release.json`과 `public-download-verification.json`에 결과를 보관합니다.

실제 Sparkle 2.10.1 검증 호스트에서 빌드 9는 빌드 10·0.6.3과 정확한 업데이트 ZIP URL을 발견했고, 빌드 10은 `OnLatestVersion`으로 판별했습니다. 두 호스트의 자동 확인 ON→OFF 저장도 통과했습니다. 게시 직후에는 테스트 호스트 캐시에 0.6.2 피드가 남아 실패하여, 종료된 테스트 호스트 두 개의 캐시만 백업 이동한 뒤 동일 URL로 재검사했습니다. 초기 실패와 최종 결과는 `update-probe/`에 보관합니다. 제품 앱의 캐시·설정은 변경하지 않았으며 실제 업데이트 설치 검사는 아닙니다.

## 구현 한계

창 모서리는 기존 추정 반경을 사용합니다. 충돌 가능 구간과 작업 창 효과 숨김은 기존 보수적인 사각형 정책을 유지합니다. 이번 수정은 누적을 표시하는 가림 범위와 그리기 순서입니다. CPU·배터리 성능 수치를 측정하지 않았습니다.

Intel Mac·macOS 14 실기기, 모든 모니터 배율·Spaces·잠자기 조합, Sparkle를 통한 실제 설치·재실행은 별도 검증이 필요합니다.
