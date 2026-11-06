# 쌓임쌓임 0.6.2 검증

2026-11-06, Apple Silicon Mac. 앱 버전 0.6.2, 빌드 9. 기본 코너 반경 보정·설정창의 버전 표시·비 RGB 조정을 적용했습니다.

## 화면과 동작

- `settings-preview.png`에서 오른쪽 아래 `버전 0.6.2`와 기존 업데이트 설명이 겹치지 않는 것을 직접 확인했습니다. 버전은 Bundle에서 읽으며 기존 창 높이를 유지합니다. 검증 모드의 이미지는 업데이터가 비활성화된 상태입니다.
- `corner-before.png` / `corner-after.png`는 같은 16pt 가상 창 위에 26pt/16pt 곡선을 그린 비교입니다. 이전의 넓은 원호가 안쪽으로 들어가는 차이가 줄어드는 것을 확인했습니다. 제공된 화면의 픽셀 관측과 배율 추정은 `corner-calibration.md`에 기록했습니다. 다른 앱의 실제 곡률을 조회한 결과는 아닙니다.
- 기존 26pt 일반 곡선 fixture의 렌더링 검사 42개를 통과했습니다. `corner-validation.json`은 곡선 알고리즘·가림 회귀 검사이고 16pt 실창 정확도를 측정한 결과가 아닙니다.
- 실제 AppKit 테스트 창·컨트롤러 45개 검사를 통과했습니다. 새 16pt 반경 전달, 이동·크기 변경·전체 화면 옵션과 기존 컨트롤러 동작을 확인했습니다. `smoke.json`을 보관합니다.
- 업데이트 구성 검사 6개를 통과했습니다. 핵심 시뮬레이션 소스는 변경하지 않았으며 전체 XCTest는 GitHub CI에서 확인합니다.

프로젝트의 `script/build_and_run.sh --build-only`로 개발 번들을 만들고 ZIP을 `/private/tmp/window-weather-062-validation/WindowWeather.app`에 풀어 미리보기·통합 검증을 실행했습니다. 최초 개발 ZIP 출력은 iCloud 덮어쓰기 시간 초과가 발생했으나 재생성 후 통과했습니다. 기존 공유 릴리스·설치본은 이 재생성 과정에서 수정하지 않았습니다.

## 비 색상 비교

제품 변경은 `WeatherView.swift`의 빗줄기·물막·튀는 물방울 RGB 값 세 줄입니다. alpha·길이·두께·입자 운동은 그대로 유지했습니다. 독립 오프스크린 비교 21개 검사를 통과했고, 여섯 효과의 입자 상태와 alpha가 같으며 비 외 다섯 효과의 RGBA 바이트도 일치했습니다. 흰색·어두운 배경의 생성 이미지를 직접 확인했습니다.

흰색 배경의 같은 빗줄기 영역에서 RGB 차이 합이 4,295에서 7,251로 늘었고, 어두운 배경에서는 25,459에서 22,503으로 줄었습니다. 이는 합성 픽셀 값 비교이며 사람의 시인성·WCAG 명암비·모든 모니터에서의 가시성을 뜻하지 않습니다. `rain-visibility/`에 재현 소스·원시 결과·기준 patch와 해시를 보관합니다.

## 배포

통합 Release 앱 빌드와 중첩 Sparkle 코드 및 앱의 Developer ID 서명·엄격 코드 서명 검사를 통과했습니다. iCloud 읽기 지연을 피하려고 해시를 기록한 임시 소스 사본에서 같은 배포 스크립트를 사용했습니다. 제품·테스트·설정·패키지 파일이 원본 작업 폴더와 일치하는 것을 확인했으며 `release-source-snapshot.json`에 보관합니다.

처음에는 기존 키체인 프로필 `DdayNotary` 조회가 exit69로 실패했지만, 기본 키체인의 공증 이력을 다시 조회하여 기존 인증 정보가 유효한 것을 확인했습니다. 새 프로필·암호·키를 생성하거나 변경하지 않았습니다. 인증된 이력에 해당 버전 제출이 없음을 확인한 뒤 보존된 서명 ZIP으로 재개했습니다. DMG 제출에서도 같은 조회 실패가 있었으나 기존 프로필로 재시도해 완료했습니다. 일시적인 조회 실패의 근본 원인은 확정하지 않았습니다. `notarization-blocker.json`은 당시 오류와 해결 상태를, `notarization-recovery.json`은 복구 근거를 보관합니다.

- 앱 공증 **Accepted**: `7c682aeb-3de7-46d8-a5a4-9d0b16bddeb7`.
- DMG 공증 **Accepted**: `c25d6fe6-b904-4728-b5ff-f747f1216748`.
- 앱·DMG 티켓 첨부·엄격 서명·Gatekeeper 검사를 통과했습니다. DMG를 마운트하여 앱의 실행 파일 일치, arm64/x86_64 아키텍처와 Applications 링크를 확인했습니다.
- 공유 ZIP에는 앱 하나만 들어 있으며 업데이트 ZIP과 바이트가 같습니다. 빌드 9·버전 0.6.2의 Sparkle EdDSA 서명을 검증했습니다. `artifact-verification.txt`와 `dmg-artifact-verification.txt`에 결과를 보관합니다.
- 현재 Mac의 `/Users/mindw/Applications/WindowWeather.app`을 0.6.2(빌드 9)로 교체한 뒤 공증 티켓·Gatekeeper·실행 프로세스를 확인했습니다. 이전 설치본은 임시 폴더에 백업했으며 경로는 `runtime-check.json`에 기록했습니다.

소스 커밋 `7a05e02357e51323e544ef0ac6b2d22719afa407`과 v0.6.2 태그를 push했습니다. [main CI](https://github.com/mindw96/WeatherWeather/actions/runs/42155508580)와 [태그 CI](https://github.com/mindw96/WeatherWeather/actions/runs/42155508728)는 앱 빌드·업데이트 구성·전체 XCTest를 모두 통과했습니다. `ci.json`에 결과를 기록했습니다.

최종 DMG SHA-256: `307607b9c1a06cc33c003e6f103b089823e83c5785b3b8289551e6dfbddb191f`.
공유·업데이트 ZIP SHA-256: `924f2f0a563e8e815d57145ac52cc9d9ebcc2f4092f166e575fc9975f1a16fcd`.

[GitHub 0.6.2 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.6.2)에 다섯 파일을 공개했습니다. 비로그인 다운로드의 HTTP 200과 로컬 SHA-256 일치, latest 피드의 바이트 일치를 모두 확인했습니다. `github-release.json`과 `public-download-verification.json`에 근거를 보관합니다.

실제 Sparkle 2.10.1을 사용하는 임시 빌드 8 호스트는 빌드 9·0.6.2와 정확한 업데이트 ZIP URL을 발견했고, 빌드 9 호스트는 `OnLatestVersion`으로 판별했습니다. 두 호스트의 자동 확인 ON→OFF 저장도 통과했습니다. 별도 번들 ID·설정을 사용한 피드 조회이며 실제 업데이트 안내창·다운로드·설치·재실행을 실행한 검사는 아닙니다. `update-probe/`에 소스와 원시 결과를 보관합니다.

## 남은 범위

곡률은 첨부 창을 기준으로 조정한 추정값입니다. 다른 스타일·각진 창에서는 차이가 남을 수 있습니다. 원호 알고리즘이나 화면 기록·접근성 권한을 추가하지 않았습니다.

Intel Mac·macOS 14 실기기, 모든 모니터 배율·Spaces·잠자기 조합, Sparkle를 통한 실제 설치·재실행은 이번 검증 범위 밖입니다. 기존 Core 성능 측정을 이번 UI 색상 변경의 실앱 CPU·배터리 결과로 확대하지 않습니다.
