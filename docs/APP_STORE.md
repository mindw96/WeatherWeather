# 1.0.0 Mac App Store 제출 구성과 확인 기준

확인일: 2026-11-11. 이 문서는 소스와 공식 문서를 바탕으로 한 제출 구성·판단 근거입니다. **1.0.0·빌드 15의 업로드·처리·빌드 연결·심사 제출을 완료했고, 14:12:45 KST에 ‘심사 대기 중’(`WAITING_FOR_REVIEW`)을 독립적으로 재확인했습니다.** 업로드 Archive 앱의 최종 Sandbox GUI 검사 74개와 로컬 PKG 내부 검사 13개도 통과했습니다. 승인·공개 출시는 아직 아니며 승인 후 수동 출시로 설정했습니다. GitHub 공개 최신 버전은 0.8.0입니다. [최종 상태 재확인](app-store/1.0.0/submission-readback.json), [제출 단계별 근거와 검증 한계](app-store/1.0.0/VALIDATION.md)

## 배포 구성

스토어용 빌드는 같은 WeatherCore와 AppKit 화면 구현을 사용하되 Sparkle 의존성·프레임워크·보조 실행 파일·업데이트 메뉴·자동 확인 설정을 제외합니다. Info.plist의 Sparkle 피드·공개 키도 포함하지 않습니다. 기존 GitHub 직접 배포판은 별도로 유지합니다.

Mac App Store에는 Sandbox 적용과 Apple 도구를 통한 단일 앱 패키징이 필요하고, 업데이트는 App Store를 사용해야 합니다. 로그인 자동 실행은 사용자의 선택으로만 켭니다. [Apple 심사 지침 2.4.5](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility)

제품 기능에 필요한 최소 Sandbox 권한은 다음과 같습니다.

| Entitlement | 사용 목적 |
| --- | --- |
| `com.apple.security.app-sandbox` | 앱 Sandbox |
| `com.apple.security.network.client` | 선택 기능인 Open-Meteo HTTPS 조회 |
| `com.apple.security.files.user-selected.read-only` | NSOpenPanel로 직접 선택한 앱 번들의 표시 이름·식별자 읽기 |

파일 선택은 이름·식별자를 읽은 뒤 그 값만 저장하므로 영구 파일 접근용 bookmark는 필요하지 않습니다. 화면 녹화·위치·마이크·카메라·일반 키 입력 감시 권한을 추가할 근거는 현재 제품 코드에 없습니다. [Sandbox 구성](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox), [사용자 선택 파일 접근](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)

스토어 서명·프로비저닝과 App Store Connect 앱 레코드 `6833310691`을 확인했습니다. 기존 Developer ID 공증 성공을 스토어 서명이나 심사 제출의 증거로 사용하지 않습니다. 업로드 성공과 처리 완료·심사 상태를 각각 확인합니다. 로컬 PKG는 업로드에 사용한 동일 Archive의 내보내기이며, 그 SHA-256을 Apple 전송 패키지의 해시로 주장하지 않습니다. [패키지 근거](app-store/1.0.0/package.json), [Apple 빌드 업로드 안내](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

## Sandbox에서 검증할 동작

현재 1개 실제 화면에서 다른 프로세스의 창 ID/PID·좌표·누적 표면을 포함한 최종 GUI 검사 74개를 통과했습니다. 반딧불 검사에서는 가려진 외부 테스트 창의 윗변을 도우미에서만 앞으로 유지해 400pt를 노출했고, 동일 업로드 Archive 앱으로 정착 최대 11개를 관측했습니다. 제품의 창 순서·시뮬레이션은 변경하지 않았습니다. 아래 표의 물리 입력·재로그인·기기 조합 검증까지 완료했다는 의미는 아닙니다. [최종 GUI 결과](app-store/1.0.0/sandbox-smoke-uploaded.json), [테스트 창 노출 근거](app-store/1.0.0/fixture-visibility.json)

| 기능 | 코드·문서에서 확인한 내용 | 실제 검증 기준 |
| --- | --- | --- |
| 다른 앱 창 추적 | CGWindowListCopyWindowInfo의 ID·bounds·소유 PID만 사용. 제목·픽셀·공유 상태는 사용하지 않음 | **다른 프로세스**가 만든 창의 ID·좌표가 스토어 앱에 보여야 함. 자기 앱의 테스트 창만으로 판정하지 않음 |
| 날씨·눈사람 오버레이 | 공개 NSPanel API, floating level, all-Spaces·fullScreenAuxiliary 설정 | 클릭 통과, 화면 선택, 전체 화면과 실제 눈사람 드래그 확인 |
| 포커스·앱 제외 | NSWorkspace 활성·실행 앱과 창 PID를 로컬에서 연결 | 다른 앱으로 포커스를 옮길 때 가림 대상 변경 확인 |
| 전역 단축키 | Carbon RegisterEventHotKey로 선택한 조합만 등록 | Sandbox 빌드에서 등록·충돌·해제와 실제 다른 앱 사용 중 입력 확인 |
| 로그인 자동 실행 | SMAppService.mainApp의 등록 상태·사용자 승인을 사용 | 등록/해제 후 상태 일치와 실제 재로그인 구분 |
| 네트워크 | 기본 OFF, 선택 도시의 HTTPS 요청 | OFF 무요청과 network.client 적용 빌드의 실제 응답 확인 |

Apple의 WWDC19 설명은 위치·크기·소유 PID 같은 창 메타데이터와 화면 내용·창 제목을 구분합니다. 이 설명은 현재 OS에서 Sandbox를 적용한 실제 교차 프로세스 검사를 대신하지 않습니다. [Advances in macOS Security](https://developer.apple.com/videos/play/wwdc2019/701/)

RegisterEventHotKey는 현재 설치된 SDK의 CarbonEvents.h에 deprecated 표시 없이 선언되어 있습니다. 사용 중인 Control+Option+Command 조합에는 Command와 Control이 포함됩니다. [Apple 엔지니어의 modifier 제한 설명](https://developer.apple.com/forums/thread/763878), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

Sandbox 도입 시 설정 저장 위치가 달라질 수 있으므로 기존 직접 배포판의 설정 복원도 실제 확인합니다. 자동 이전이 된다고 가정하거나 다른 앱의 설정 읽기 예외 권한을 추가하지 않습니다. [컨테이너 이전](https://developer.apple.com/documentation/security/migrating-your-app-s-files-to-its-app-sandbox-container)

현재 Mac에서는 첫 Sandbox 실행 뒤 기존 외부 설정 파일이 없고, 컨테이너 안에 바람·모니터·눈사람·도시 설정을 포함한 18개 키와 이전 Sparkle 키가 존재함을 읽기 전용으로 확인했습니다. 설정 파일의 생성·수정 시각은 컨테이너 생성보다 앞서므로 OS가 기존 설정을 옮긴 정황과 일치합니다. 설정값은 기록하지 않았으며, 이전 전후 값 비교나 모든 지원 OS의 자동 이전 보장으로 확대하지 않습니다. 이 관측만을 이유로 추가 이전 코드·임시 권한을 넣지 않았습니다. [경로·시각·키 이름과 검증 범위](app-store/1.0.0/preferences-migration.json)

## 개인정보 문서·선언

제출 메타데이터와 앱 안에 [개인정보 처리방침](PRIVACY.md)을 연결하고, [지원 페이지](SUPPORT.md)를 제공합니다. main 브랜치에 게시하고 HTTP 200을 확인한 URL은 다음과 같습니다.

- 개인정보: `https://github.com/mindw96/WeatherWeather/blob/main/docs/PRIVACY.md`
- 지원: `https://github.com/mindw96/WeatherWeather/blob/main/docs/SUPPORT.md`

Apple은 App Store Connect와 앱 내부 모두에 개인정보 링크를 요구합니다. [심사 지침 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy)

현재 코드의 UserDefaults는 자체 설정만 저장하고, systemUptime은 프레임 사이 경과 시간을 계산합니다. PrivacyInfo.xcprivacy를 포함한다면 각각 `CA92.1`, `35F9.1` 사유가 해당 코드 용도에 맞습니다. macOS 앱에서는 `Contents/Resources/`에 배치합니다. Apple의 required-reason 개요는 iOS·iPadOS·tvOS·visionOS·watchOS를 명시하므로, 선언 누락만으로 macOS 업로드가 반드시 차단된다고 단정하지 않습니다. [허용 사유](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype), [manifest 배치](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk), [적용 설명](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

### 실제 날씨와 App Privacy 답변 근거

앱이 자체 서버를 운영하지 않는다는 이유로 **수집 없음**을 선택하지 않습니다. Apple의 수집 정의는 실시간 요청 처리에 필요한 시간을 넘겨 제공자가 보관하는 데이터도 고려합니다. [Apple App Privacy 정의](https://developer.apple.com/app-store/app-privacy-details/)

| 정보 | 확인한 처리 | 답변 시 구분 |
| --- | --- | --- |
| 도시 검색어 | 코드가 geocoding-api.open-meteo.com의 GET `name`으로 전송. 로컬 디스크 검색 기록 없음 | 앱 내 검색 정보. 무료 API 정책은 검색어 자체의 보관을 따로 명시하지 않으므로 보관 사실을 단정하지 않음 |
| 선택 도시 좌표 | 코드가 api.open-meteo.com의 GET `latitude`/`longitude`로 전송. 제공자 로그에 좌표가 포함될 수 있음 | 사용자 선택 도시이며 기기의 현재 위치가 아님. 숫자의 소수점 자릿수만으로 기기의 정밀 위치를 수집한다고 표현하지 않음 |
| IP 주소·기술 요청 정보 | 제공자는 유지관리·오용 방지 목적으로 처리할 수 있다고 밝힘 | 기술 운영·보안 목적의 진단 정보. IP를 광고 식별자로 사용하지 않음 |
| 창·포커스·앱 제외·눈사람 정보 | 기기 내 처리. 날씨 요청에 포함하지 않음 | 전송하지 않는 로컬 기능 데이터 |

Open-Meteo는 무료 API의 문제 해결 로그를 90일 후 삭제하고 사용자 신원과 연결하거나 제3자에게 공유하지 않는다고 설명합니다. 유료 API의 URL·구독 연계 설명을 무료 API의 사실로 옮기지 않습니다. App Privacy 유형·목적·연결 여부의 최종 답변은 실제 송신 항목과 이 보관 정책을 함께 반영해야 하며, 정책 문구만으로 로그 내부의 세부 구조까지 검증한 것은 아닙니다. [무료 API 개인정보 정책](https://open-meteo.com/en/terms)

무료 API는 비상업 용도이며 광고·구독 없는 무료 앱 범위로 준비합니다. 유료 판매·광고·구독을 추가하면 공급자 이용 조건을 다시 검토합니다. [Open-Meteo 조건](https://open-meteo.com/en/terms)

1.0.0의 선언은 **검색 기록**과 **기타 데이터**를 앱 기능 목적으로 처리하고, 사용자 신원과 연결하거나 추적하지 않는 것으로 준비합니다. 기타 데이터에는 선택한 도시의 조회 좌표와 IP·기술 요청 정보가 포함됩니다. 선택 도시가 사용자·기기의 실제 위치라는 가정은 하지 않으므로 기기 위치 수집으로 표시하지 않습니다. 공급자의 검색어 보관 범위를 보증할 수 없어 검색 기록도 보수적으로 공시합니다. 번들의 PrivacyInfo.xcprivacy와 App Store Connect 답변을 일치시킵니다.

## 제출 자료

실제 동작을 보여 주는 Mac 스크린샷, 설명·키워드·지원/개인정보 URL, 연령 등급, 개인정보 답변, 암호화 답변과 심사 연락처를 준비합니다. 계정 로그인은 없으므로 데모 계정이 필요하지 않습니다. 심사 메모에는 Dock/메뉴 막대 설정 접근, 기본 OFF인 실제 날씨와 도시 선택, 일반 창 위 누적과 전체 화면 옵션을 설명합니다.

Mac 스크린샷의 허용 규격과 개수는 업로드 전 [Apple 스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)을 확인합니다. 테스트 화면을 생성했다는 사실을 실제 다른 앱의 창 추적·물리 입력 검증으로 집계하지 않습니다.
