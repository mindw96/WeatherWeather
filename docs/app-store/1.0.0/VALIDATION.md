# 쌓임쌓임 1.0.0 App Store 제출 검증

버전 **1.0.0**, 빌드 **15**, macOS 14 이상, Apple Silicon·Intel 통합. App Store Connect 앱 ID **6833310691**, 번들 ID `org.windowweather.app`.

현재 상태: 스토어 전용 빌드·서명·PKG 내보내기·앱 등록을 완료했습니다. **Apple 업로드·처리 완료·심사 제출은 아직 완료하지 않았습니다.** 잠금이 다시 설정된 Mac에서 Xcode 업로드의 계정 인증이 실패했으며, 기존 계정이 없다고 단정하거나 새 자격 증명을 만들지 않았습니다.

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
| Sandbox GUI | 74개 통과 | [결과](sandbox-smoke.json). 현재 연결된 1개 화면에서 실제 창·전체 화면·포커스·표시 옵션 검사. 별도 프로세스 창의 ID/PID·좌표와 해당 누적 표면을 확인 |
| 실제 날씨 서비스 | 3개 통과 | [결과](weather-live.json). Sandbox 앱이 공개 샘플 서울 검색·현재 날씨 수신·효과 선택. 기기 위치와 사용자 설정 미사용 |
| PKG 내부 검증 | 13개 통과 | [결과](bundle-verification.json). 스토어 서명, Sandbox, debug 권한 제거, 통합 아키텍처, Sparkle 파일·설정·링크 없음, 개인정보 선언 |
| 배포 패키지 | 생성·Installer 서명 확인 | [PKG 정보](package.json). `dist/app-store/1.0.0/WindowWeather.pkg` |
| 스크린샷 | 5개, 2560×1600 RGB | [규격 검사](screenshots.json). 실제 제품 렌더러의 명시된 미리보기와 설정 UI를 사용. 제3자 앱 내용을 촬영하지 않음 |
| 기존 설정 | OS 이전 정황 확인 | [경로·시각·키 검사](preferences-migration.json). 이전 전후 값 동등성과 모든 macOS의 자동 이전을 보장하지 않음 |
| App Store Connect | macOS 앱·1.0.0 등록 완료 | [브라우저 상태](browser-state.json). 업로드와 심사 제출 완료를 뜻하지 않음 |

최종 소스의 파일별 해시는 [source-hashes.json](source-hashes.json)에 기록합니다. 최종 Archive GUI 재검사는 Mac 잠금으로 중단됐으며 [차단 결과](sandbox-smoke-final.json)를 성공으로 집계하지 않습니다.

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

잠금 해제 후 기존 Xcode 계정 인증·최종 GUI 검사·업로드를 재확인하고, Apple의 처리 완료·빌드 선택·심사 접수 상태를 확인해야 합니다. 물리 키·마우스 입력, 실제 로그아웃/로그인, Intel 실기기, 모든 모니터 조합, App Store 설치·업데이트 전체 과정은 별도 확인 대상입니다. 승인 후 수동 출시로 준비하므로 심사 접수 자체가 공개 출시를 의미하지 않습니다.
