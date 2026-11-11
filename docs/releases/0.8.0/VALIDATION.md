# 쌓임쌓임 0.8.0 검증 상태

버전 **0.8.0**, 빌드 **14**. 기준일 **2026-11-11 (Asia/Seoul)**.

**현재 상태: 0.8.0 구현·검증·공증·공개 배포·현재 Mac 설치 완료.** 핵심 테스트 98개와 아래 렌더링·설정·서비스 검사, 최종 서명 앱의 GUI 검사 76개를 통과했습니다. Apple Silicon·Intel 통합 앱과 DMG, 공개 다운로드, 실제 Sparkle 버전 판별, PR·main·버전 태그 CI도 확인했습니다. 이전 버전의 결과를 이번 실행으로 집계하지 않습니다.

검증한 소스·구성·리소스의 파일별 SHA-256은 [source-hashes.json](source-hashes.json)에 기록합니다. 공개 태그 `v0.8.0`의 추적되는 빌드 입력 50개와 최종 빌드 입력이 모두 일치했습니다. 두 `.DS_Store` 파일은 태그의 추적 대상이 아니며 별도로 표시합니다. [태그·소스 비교](tag-source-verification.json)

## 구현 범위

- 앱별 효과 숨김과 기존 포커스·모니터·전체 화면 정책의 조합
- 방향·세기가 분리된 바람 및 기존 값 마이그레이션
- 창 이동의 눈 흩어짐, 강풍의 낙엽·벚꽃 재비산, 빗물 파문·물방울 병합
- 반딧불·별가루로 확장한 여덟 효과
- 눈사람 모자·목도리 색과 크기, 드래그·클릭 영역·위치 저장
- 전역 단축키, 30분 숨기기, 로그인 자동 실행과 설정창 표시
- 도시 직접 선택 방식의 실제 날씨 연동, 수동 우선·만료·실패·취소 처리

프리셋·날씨 소리·모니터마다 다른 효과·Windows 구현은 이번 범위에 없습니다.

## 자동 검사와 실제 실행

| 검사 | 상태 | 근거와 경계 |
| --- | --- | --- |
| 전체 핵심 테스트 | **98개 통과** | 현재 저장소에서 실행한 [SwiftPM 결과](core-tests.txt). 시뮬레이션·곡면·가림·화면 간 전달·새 효과·날씨 정책을 포함합니다. |
| 포커스·앱별 숨김 렌더링 | **131개 통과** | [결과](focus-validation.json). 여덟 효과와 눈사람의 가림·복원이며 물리 입력 전달 검증은 아닙니다. |
| 눈사람 꾸미기·드래그 | **40개 통과** | [결과](snowman-validation.json). 색·크기·클릭 영역·직접 전달한 드래그 이벤트·상대 위치 보존입니다. |
| 곡면·겹침·새 렌더링 | **134개 통과** | [결과](corner-validation.json). 파문·물방울과 여덟 효과의 곡면·가림 처리를 포함합니다. |
| 새 설정·네이티브 제어 | **18개 통과** | [결과](features.json). 바람 마이그레이션·앱 제외 저장·타이머·네이티브 단축키 등록/충돌/해제와 앱 내부 이벤트 콜백입니다. |
| 개발 앱 빌드 | **성공** | [빌드 기록](build.txt). 배포용 통합 Release 빌드·서명과 구분합니다. |
| 여덟 효과 미리보기 | **생성·시각 확인 완료** | 생성된 눈·비·낙엽·벚꽃·비눗방울·색종이·반딧불·별가루를 확인했습니다. 실제 전체 데스크톱 화면 캡처는 아닙니다. |
| 실제 데스크톱 GUI smoke | **76개 통과** | [최종 서명 앱 결과](smoke-release.json). 실제 세 모니터에서 창 이동·크기 변경·모니터 간 누적 전달·포커스 전환·네이티브 전체 화면 진입/복귀·컨트롤러·모니터 선택을 확인했습니다. |
| 업데이트 구성 Python 검사 | **6개 통과** | [결과](update-config-tests.txt). 실제 Sparkle 업데이트 설치 검사는 아닙니다. |
| 실제 날씨 정책 단위 검사 | **6개 통과** | `LiveWeatherPolicyTests`가 전체 핵심 98개에 포함되므로 별도 합산하지 않습니다. |
| 날씨 서비스 모의 응답 검사 | **12개 통과** | [결과](weather-service.json). 세션 전용 URLProtocol만 사용하며 실제 네트워크는 호출하지 않습니다. |
| 공개 샘플 날씨 API | **통과** | [결과](weather-live.json). 서울 검색·현재 날씨 HTTP 200과 실제 Swift 디코딩·유효성 검사. 기기 위치 미사용. |

날씨 서비스 검사는 OFF/검증 실행 무요청, 15분 조회 제한, 30분 수동 선택 유지와 만료, 오래된 값의 기본 효과 복귀, 도시 변경·해제 뒤 진행 중 요청의 늦은 응답 차단, 검색·HTTP 오류를 포함합니다.

서명한 Release 앱에서도 [설정·단축키 18개](features-release.json)와 [날씨 서비스 12개](weather-service-release.json)를 통과했습니다. 최종 GUI 검사는 `/private/tmp/window-weather-package.LGvhIZ/WindowWeather-0.8.0-macOS/WindowWeather.app`의 실제 실행 결과입니다.

잠긴 세션에서 중단된 [최초 결과](smoke.json)와 잠금 해제 직후 포커스 전환 한 항목이 실패한 [76개 검사 결과](smoke-unlocked.json)는 보존했습니다. 첫 포커스 실패의 원인은 확정하지 않았습니다. 진단을 추가한 [재검사](smoke-focus-diagnostics.json)와 최종 서명 앱 검사는 모두 통과했고, 키 창·앞쪽 앱 PID·운영체제 창 순서·숨김 대상이 일치했습니다. 제품 포커스 정책이나 검사 대기 시간을 바꾸지는 않았습니다.

재현 명령:

```sh
swift test
./script/build_and_run.sh --previews
./script/build_and_run.sh --validate-focus
./script/build_and_run.sh --validate-snowman
./script/build_and_run.sh --validate-features
./script/build_and_run.sh --validate-weather-service
./script/build_and_run.sh --smoke
```

`--validate-weather-service`는 외부 서비스에 접속하지 않습니다. 실제 API 검사는 공개 샘플 서울에 대해 별도로 수행했으며 자동 반복하지 않습니다. 생성 미리보기는 실제 전체 데스크톱 캡처가 아닙니다.

## 패키지·서명·공증

`release.sh`로 Apple Silicon·Intel 통합 Release 앱을 만들고 Developer ID로 서명했습니다. 최종 소스 해시·번들·중첩 코드 서명·공증 티켓·Gatekeeper를 [확인](signed-build-verification.json)했습니다.

| 산출물 | 결과와 근거 |
| --- | --- |
| 앱 ZIP | Apple **Accepted**, 제출 `962bc7ad-9673-4d46-8395-f100876e8314`. [공증 결과](notarization.json), [앱·공유 ZIP·업데이트 ZIP 검사](artifact-verification.txt) |
| DMG | Apple **Accepted**, 제출 `114098df-e9f5-4693-8a41-4be943b1c1a8`. [공증 결과](dmg-notarization.json), [서명·티켓·Gatekeeper·마운트·Applications 링크 검사](dmg-artifact-verification.txt) |
| Sparkle 업데이트 | appcast의 버전 0.8.0·빌드 14·URL·파일 크기 일치, EdDSA 검증 통과. [결과](artifact-verification.txt) |
| 최종 파일 | `dist/releases/0.8.0/`에 DMG·공유 ZIP·업데이트 ZIP·appcast와 `SHA256SUMS.txt` 생성 완료 |

공유 ZIP에는 앱 하나만, DMG에는 앱과 Applications 바로가기를 넣었습니다. 통합 아키텍처는 `x86_64 arm64`이며 Intel 실기기 실행을 의미하지 않습니다.

잠금 해제 후 기존 `WindowWeatherNotary` 프로필이 정상 인증됐습니다. 인증된 Apple 제출 이력에 0.8.0 제출이 없는 것을 확인하고 이전 시도와 ZIP을 `dist/releases/0.8.0/pre-unlock/`에 보존한 뒤 진단 추가 소스로 다시 빌드했습니다. 새 자격 증명을 만들거나 변경하지 않았습니다. [이전 중단 기록](notarization-blocker.json), [복구 근거](notarization-recovery.json). 화면 잠금과 인증 오류의 인과관계는 확정하지 않았습니다.

제한된 sandbox에서 표시된 Sparkle Downloader의 invalid-entitlements 경고는 보안 서비스에 접근할 수 있는 환경의 재검사에서 나타나지 않았습니다. 원본·이전 staged·설치본·최종 staged의 각 `arm64`/`x86_64`, 총 8개 조합에서 유효한 동일 entitlements와 strict 서명 검증을 확인했습니다. [실행 환경과 결과](sparkle-entitlements-check.json). 이 경고를 이유로 패키징 코드를 변경하지 않았습니다.

## 공개 배포와 설치본

- 최종 진단·공증 증거 커밋 `ddfbf21`의 [GitHub Actions](https://github.com/mindw96/WeatherWeather/actions/runs/42951445824)는 앱 빌드·업데이트 구성·Core 테스트·날씨 서비스 검사를 모두 통과했습니다. [PR #1](https://github.com/mindw96/WeatherWeather/pull/1)을 main에 병합했으며 공개 태그의 커밋은 `0a059798e7646367e6c70e1a3bb6a715e2c47bee`입니다. [PR CI 결과](ci.json), [main CI](https://github.com/mindw96/WeatherWeather/actions/runs/42951807204), [v0.8.0 태그 CI](https://github.com/mindw96/WeatherWeather/actions/runs/42951968606) 모두 성공했습니다. [릴리스 CI 기록](release-ci.json)
- GitHub Release 게시: **완료**. [v0.8.0](https://github.com/mindw96/WeatherWeather/releases/tag/v0.8.0)에 DMG·공유 ZIP·업데이트 ZIP·appcast·체크섬 다섯 파일을 공개했습니다. [게시 기록](github-release.json)
- 공개 다운로드·체크섬·latest appcast: **통과**. 다섯 파일 모두 비로그인 HTTP 200, 로컬 SHA-256과 일치했습니다. latest 피드는 로컬 appcast와 같은 바이트이며 0.8.0·빌드 14를 가리킵니다. [다운로드 검사](public-download-verification.json)
- 실제 Sparkle의 이전/현재 빌드 판별: **통과**. 격리된 실제 Sparkle 2.10.1 호스트에서 빌드 13은 0.8.0·빌드 14와 정확한 업데이트 ZIP URL을 발견했고, 빌드 14는 `OnLatestVersion`으로 판별했습니다. 두 호스트의 자동 확인 ON→OFF 저장도 통과했습니다. [업데이트 발견](update-probe/available.json), [최신 판별](update-probe/current.json). 정보 조회·버전 선택 검사이며 업데이트 설치 검사는 아닙니다.
- 로컬 설치 앱 교체·실행·서명 재확인: **완료**. `/Users/mindw/Applications/WindowWeather.app`은 0.8.0·빌드 14이며 실행 파일이 최종 Release와 일치합니다. strict 서명·공증 티켓·Gatekeeper와 해당 경로의 실행 프로세스를 확인했습니다. [실행 검사](runtime-check.json), [설치 기록](install-receipt.json). 이전 0.7.2는 `dist/backups/WindowWeather-0.7.2-before-0.8.0.app`에 보존했습니다.
- 실제 Sparkle 업데이트 설치·재실행: 미검증

## 별도 확인이 필요한 범위

GUI 검사는 AppKit으로 만든 실제 테스트 창과 공개 창 메타데이터를 사용합니다. 물리 마우스 드래그·다른 앱 클릭 통과·다른 앱 사용 중 실제 단축키 입력은 미검증입니다. 모든 앱의 겹침·Mission Control·Spaces 조합을 검사한 것은 아닙니다.

네이티브 단축키의 등록·충돌·해제와 앱 내부 이벤트 콜백은 통과했지만 물리 키 입력 전달을 대신하지 않습니다. 이번 자동 검사에서는 로그인 항목을 변경하지 않았으며 실제 등록·해제와 로그아웃·로그인 주기의 자동 실행도 미검증입니다.

모든 macOS 버전·Intel 실기기·모니터 배율 조합, 장시간 CPU·전력 사용량, 전 세계 날씨 정확도와 서비스 장기 가용성 역시 별도 확인 대상입니다.
