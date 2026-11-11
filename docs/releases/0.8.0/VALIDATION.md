# 쌓임쌓임 0.8.0 검증 상태

버전 **0.8.0**, 빌드 **14**. 기준일 **2026-11-11 (Asia/Seoul)**.

**현재 상태: 자동 검사·미리보기 확인 완료, 실제 데스크톱 통합 검사와 배포 준비 진행 중.** 현재 저장소에서 전체 SwiftPM 테스트 98개를 통과했고 아래 렌더링·설정·서비스 검사를 완료했습니다. GUI smoke는 Mac 잠금으로 중단되었으며 성공으로 집계하지 않습니다. 통합 Release 빌드·Developer ID 서명은 완료했으며 앱·DMG Apple 공증·Sparkle 업데이트 서명·공개 게시·설치본 교체는 아직 완료하지 않았습니다. 이전 버전의 결과를 이번 실행으로 집계하지 않습니다.

검증한 소스·구성·리소스의 파일별 SHA-256은 [source-hashes.json](source-hashes.json)에 기록합니다.

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
| 실제 데스크톱 GUI smoke | **잠금으로 차단됨** | [결과](smoke.json)의 `status=blocked`, `screenLocked=true`. 잠금 해제 후 실제 테스트 창·이동·화면 전환 검사가 필요합니다. |
| 업데이트 구성 Python 검사 | **6개 통과** | 실행 결과를 확인했습니다. 이 문서 갱신 시 별도 로그 파일은 아직 첨부되지 않았습니다. 실제 Sparkle 업데이트 설치 검사는 아닙니다. |
| 실제 날씨 정책 단위 검사 | **6개 통과** | `LiveWeatherPolicyTests`가 전체 핵심 98개에 포함되므로 별도 합산하지 않습니다. |
| 날씨 서비스 모의 응답 검사 | **12개 통과** | [결과](weather-service.json). 세션 전용 URLProtocol만 사용하며 실제 네트워크는 호출하지 않습니다. |
| 공개 샘플 날씨 API | **통과** | [결과](weather-live.json). 서울 검색·현재 날씨 HTTP 200과 실제 Swift 디코딩·유효성 검사. 기기 위치 미사용. |

날씨 서비스 검사는 OFF/검증 실행 무요청, 15분 조회 제한, 30분 수동 선택 유지와 만료, 오래된 값의 기본 효과 복귀, 도시 변경·해제 뒤 진행 중 요청의 늦은 응답 차단, 검색·HTTP 오류를 포함합니다.

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

Developer ID 서명 인증서의 유효성은 확인했습니다. `release.sh`의 Apple Silicon·Intel 통합 Release 빌드와 서명은 진행 중이며 최종 결과를 기다립니다. 앱과 DMG가 공증되었다고 판단할 근거는 아직 없습니다.

공증 사전 조회에서 `WindowWeatherNotary` 프로필을 찾지 못해 종료 코드 69가 한 차례 발생했습니다. 화면 잠금과의 관련성은 확정하지 않았으며 프로필이 없거나 자격 증명을 새로 만들어야 한다고 단정하지 않습니다. 잠금 해제 후 기존 프로필·제출 상태를 확인하고 진행해야 합니다.

- Apple Silicon·Intel 통합 Release 빌드: 완료 (`x86_64 arm64`)
- Developer ID 앱 서명과 중첩 Sparkle 구성 확인: 완료. [서명·구조·소스 일치 검사](signed-build-verification.json)
- 앱 ZIP 공증·티켓 첨부·Gatekeeper: 대기
- DMG 서명·공증·티켓·마운트·Applications 링크: 대기
- 공유 ZIP·업데이트 ZIP 무결성·EdDSA·appcast 버전·빌드 일치: 대기
- 최종 파일 SHA-256: 대기

공유 ZIP에는 앱 하나만 넣고, DMG에는 앱과 Applications 바로가기를 제공합니다. 예상 결과 경로는 `dist/releases/0.8.0/`입니다. 예상 경로가 있다는 이유로 파일이 생성되었거나 배포되었다고 판단하지 않습니다.

## 공개 배포와 설치본

- 소스 커밋·태그 및 CI 결과: 대기
- GitHub Release 게시: 대기
- 공개 다운로드·체크섬·latest appcast: 대기
- 실제 Sparkle의 이전/현재 빌드 판별: 대기
- 로컬 설치 앱 교체·실행·서명 재확인: 대기
- 실제 Sparkle 업데이트 설치·재실행: 미검증

## 별도 확인이 필요한 범위

현재 Mac의 화면 잠금 때문에 실제 창을 이동·크기 변경하고 여러 화면·Spaces·전체 화면으로 전환하는 GUI smoke를 완료하지 못했습니다. 잠금 해제를 요청했으며 이 문서 갱신 시 응답을 기다리고 있습니다. 물리 마우스 드래그·다른 앱 클릭 통과·다른 앱 사용 중 실제 단축키 입력은 미검증입니다.

네이티브 단축키의 등록·충돌·해제와 앱 내부 이벤트 콜백은 통과했지만 물리 키 입력 전달을 대신하지 않습니다. 이번 자동 검사에서는 로그인 항목을 변경하지 않았으며 실제 등록·해제와 로그아웃·로그인 주기의 자동 실행도 미검증입니다.

모든 macOS 버전·Intel 실기기·모니터 배율 조합, 장시간 CPU·전력 사용량, 전 세계 날씨 정확도와 서비스 장기 가용성 역시 별도 확인 대상입니다.

### 2026-11-11 패키징 후 확인

- [업데이트 구성 검사](update-config-tests.txt): Python 6개 통과.
- 서명한 Release 앱에서도 [설정·단축키 18개](features-release.json)와 [날씨 서비스 12개](weather-service-release.json) 통과.
- `WindowWeatherNotary`를 기본 키체인 환경에서 재조회했고 기존 `DdayNotary`도 확인했으나 모두 exit 69(프로필 없음)였습니다. 잠금과의 인과관계는 확인하지 않았으며 자격 증명을 생성·변경하지 않았습니다. [중단 근거](notarization-blocker.json)
- Apple 제출 ID를 받지 못했습니다. 서명된 앱과 원본 제출 ZIP은 `/private/tmp/window-weather-package.oIkJcA/`에, 재개 상태는 `dist/releases/0.8.0/release-state.json`에 보존합니다.
- 재개할 때 먼저 프로필 인증과 Apple 제출 이력을 확인합니다. 제출이 없다면 인증 단계에서 실패한 시도의 `submission_attempted` 상태를 근거와 함께 복구한 뒤 `script/release.sh --resume`을 실행합니다. 제출 ID가 확인되면 해당 ID를 복원하여 중복 제출을 피합니다.
