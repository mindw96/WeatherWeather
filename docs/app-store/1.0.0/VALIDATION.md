# 쌓임쌓임 1.0.0 App Store 제출 검증

버전 **1.0.0**, 빌드 **15**, macOS 14 이상, Apple Silicon·Intel 통합. App Store Connect 앱 ID **6833310691**, 번들 ID `org.windowweather.app`.

현재 상태: **1.0.0·빌드 15의 App Store 심사 제출을 완료했고, 2026-11-11 14:12:45 KST에 ‘심사 대기 중’(`WAITING_FOR_REVIEW`)을 독립적으로 재확인했습니다.** Apple 업로드는 13:52:23 KST에 완료했으며 처리 완료·빌드 연결·최종 접수를 순서대로 확인했습니다. 업로드한 Archive의 앱으로 최종 Sandbox GUI 검사 74개도 통과했습니다. 심사 승인이나 공개 출시가 완료된 상태는 아닙니다. 승인 후 수동 출시로 설정했고 GitHub의 공개 최신 버전은 0.8.0으로 유지합니다. [최종 심사 상태 재확인](submission-readback.json)

## 기능과 배포 구성

- 바람 방향: 왼쪽 / 가운데(없음) / 오른쪽. 가운데는 유효 바람을 0으로 만들고 별도 세기를 보존합니다. 방향·세기 저장 및 기존 설정 이전을 검사했습니다.
- App Store 빌드: `project.yml`에서 같은 소스를 빌드하고 `APP_STORE` 조건을 사용합니다. Sparkle 링크·파일·업데이트 메뉴·피드 설정은 없습니다. GitHub 직접 배포의 기존 Sparkle 구성은 유지합니다.
- 권한: App Sandbox, 외부 HTTPS 요청, 사용자가 직접 선택한 파일 읽기. 화면 기록·위치·접근성 권한이나 임시 예외는 추가하지 않았습니다.
- 개인정보: 선택 기능인 날씨 조회의 검색 기록·기타 데이터, 앱 기능 목적·신원 비연결·추적 없음. 앱 내 개인정보·지원 링크와 번들 PrivacyInfo.xcprivacy를 포함했습니다.

## 확인된 결과

| 검사 | 결과 | 근거와 범위 |
| --- | --- | --- |
| 핵심 테스트 | 98개 통과 | [SwiftPM 기록](core-tests.txt) |
| 무풍·설정·단축키 | 24개 통과 | [서명 Archive 검사](features.json). 가운데 재실행 복원·세기 보존·오래된 값 이전·비정상 값 복구 포함 |
| 최종 Sandbox GUI | 74개 통과 | [업로드 Archive 실행 결과](sandbox-smoke-uploaded.json). 현재 연결된 1개 실제 화면에서 창·전체 화면·포커스·표시 옵션 검사. 별도 프로세스 창의 ID/PID·좌표와 누적 표면, 반딧불 정착 최대 11개를 확인 |
| 실제 날씨 서비스 | 3개 통과 | [결과](weather-live.json). Sandbox 앱이 공개 샘플 서울 검색·현재 날씨 수신·효과 선택. 기기 위치와 사용자 설정 미사용 |
| PKG 내부 검증 | 13개 통과 | [결과](bundle-verification.json). 업로드에 사용한 동일 Archive를 로컬로 다시 내보낸 패키지의 스토어 서명, Sandbox, debug 권한 제거, 통합 아키텍처, Sparkle 파일·설정·링크 없음, 개인정보 선언 |
| 배포 패키지 | 생성·Installer 서명 확인 | [PKG 정보](package.json). `dist/app-store/1.0.0/WindowWeather.pkg`. 로컬 내보내기의 SHA-256이며 Apple 전송 패키지와 동일 바이트라는 증거로 사용하지 않음 |
| 스크린샷 | 5개, 2560×1600 RGB | [규격 검사](screenshots.json). 실제 제품 렌더러의 명시된 미리보기와 설정 UI를 사용. 제3자 앱 내용을 촬영하지 않음 |
| 기존 설정 | OS 이전 정황 확인 | [경로·시각·키 검사](preferences-migration.json). 이전 전후 값 동등성과 모든 macOS의 자동 이전을 보장하지 않음 |
| Apple 업로드 | 1.0.0·빌드 15 성공 | [업로드 기록](upload-status.json). 13:52:23 KST 완료 |
| App Store Connect | **심사 대기 중** | 처리된 빌드 ID `6aca5b90-12ef-4da1-9e7a-eefe18bae8c0`를 1.0.0에 연결해 제출했습니다. [최종 브라우저 상태](browser-state.json), [독립 재확인](submission-readback.json). 제출 ID `19e0df13-b028-4a3f-ae56-441d42b277e7`, 화면에서 `macOS 앱 1.0.0`·`1.0.0 (15)`·`심사 대기 중` 확인 |
| 스토어 메타데이터 | 저장·재조회 확인 | [최종 기록](browser-state.json). 무료, 175개 지역, 엔터테인먼트, 4+, 수동 출시, 스크린샷 5개, 개인정보 선언 게시, 한국어 설명·영어 심사 메모와 연락처 필드 존재 확인. 연락처 값은 기록하지 않음 |
| GitHub CI | 최종 진단 소스 통과 | [CI 결과](ci.json), [실행 42962970839](https://github.com/mindw96/WeatherWeather/actions/runs/42962970839). 소스 `eafd1ba`의 직접 배포·Sandbox 앱 빌드, 업데이트 구성, Core 98개와 모의 날씨 검사. 앞선 PR #2의 성공 및 main 병합 `9b28afc` 기록도 보존 |

최종 소스의 파일별 해시는 [source-hashes.json](source-hashes.json)에 기록합니다. 이번 재검증에서 제품 빌드 입력 변경은 `Validation.swift`의 관측·진단 보정이며, 별도 프로세스의 `ExternalWindowFixture.swift`는 제품 빌드 입력이 아닙니다.

## GUI 검사 보정과 이전 결과

이전의 [통과 결과](sandbox-smoke.json), 잠긴 세션에서의 [차단 결과](sandbox-smoke-final.json), 잠금 해제 후 반딧불 정착을 관측하지 못한 [첫 결과](sandbox-smoke-unlocked-final.json)와 [진단 추가 결과](sandbox-smoke-release.json), [윗변이 가려진 결과](sandbox-smoke-upper-occluded.json)를 보존합니다. 실패·차단 기록을 최종 성공으로 바꾸지 않았습니다.

반딧불은 창 위에 잠시 머문 뒤 떠나므로 낙하·정착 검사는 마지막 표본 하나만 보지 않고 모의 30초 동안 두 상태를 함께 관측했는지와 정착 수의 최댓값을 기록하도록 보정했습니다. 이 보정 뒤에도 정착 수가 0이었던 검사에서는 외부 테스트 창의 윗변 `y=67`이 앞쪽 최대화 창 `[0, 39, 1800, 1130]`에 완전히 가려져 있었습니다. 윗변이 노출되지 않은 상태로 정착을 기대한 테스트 배치가 최종 실패의 원인이었습니다.

외부 테스트 도우미에만 `orderFrontRegardless()`를 적용해 윗변 400pt가 노출된 상태를 유지했고, **동일한 업로드 Archive 앱**으로 74개를 모두 통과했습니다. 반딧불 정착 최대·마지막 개수는 각각 11개였습니다. [윗변 노출 근거](fixture-visibility.json), [최종 실행 결과](sandbox-smoke-uploaded.json). 제품 창의 순서나 시뮬레이션 동작을 바꾼 것은 아닙니다.

최초 업로드 인증 실패 뒤 사용자가 Xcode에서 기존 Apple 계정으로 로그인한 후 업로드에 성공했습니다. 에이전트가 새 자격 증명을 만들거나 변경하지 않았습니다. 로컬 PKG는 성공한 업로드와 같은 Archive에서 내보냈고 `x86_64`·`arm64` Mach-O UUID도 각각 일치합니다. 재포장·서명 때문에 Apple 전송 PKG와 해시가 같다고 주장하지 않습니다. [Archive·내보내기 연결 근거](package.json)

## 재현

```sh
xcodegen generate
xcodebuild -project WindowWeather.xcodeproj -scheme WindowWeather \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath /private/tmp/WindowWeather.xcarchive -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath /private/tmp/WindowWeather.xcarchive \
  -exportOptionsPlist Config/AppStore-ExportOptions.plist \
  -exportPath /private/tmp/WindowWeather-store -allowProvisioningUpdates
```

스토어 앱의 `--validate-features`, `--validate-weather-service`, `--smoke-test`는 테스트 전용 설정 도메인을 사용합니다. Sandbox 안에서 보고서를 쓰려면 해당 앱 컨테이너의 `Data/tmp/` 경로를 사용합니다. `--validate-store-weather`만 명시적으로 공개 샘플 API에 접속합니다. `--store-screenshots`는 미리보기와 설정 화면을 생성합니다.

외부 창 검사는 [ExternalWindowFixture.swift](ExternalWindowFixture.swift)를 별도 프로세스로 실행하고 반환된 창 ID·PID를 `--smoke-test PATH --expect-external-window ID PID`에 전달합니다. 자기 앱 창만 추적하는 검사와 구분합니다.

## 남은 확인

Apple 심사 결과와 승인 후 수동 출시는 남아 있습니다. 물리 키·마우스 입력, 실제 로그아웃/로그인, Intel 실기기, 모든 모니터 조합, App Store 설치·업데이트 전체 과정은 별도 확인 대상입니다. 심사 접수 자체가 승인이나 공개 출시를 의미하지 않습니다.
