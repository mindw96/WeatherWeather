# 쌓임쌓임 1.0.0 직접 배포 검증

버전 **1.0.0**, 빌드 **15**. 기준일 **2026-11-11 (Asia/Seoul)**. macOS 14 이상용 Apple Silicon·Intel 통합 앱을 GitHub Releases로 배포합니다.

**현재 상태: 서명·공증·최종 앱 검사 완료, 공개 준비 중.** 통합 앱과 DMG의 Developer ID 서명·Apple 공증, ZIP·Sparkle 서명과 패키지 검증을 완료했습니다. 현재 3개 모니터의 GUI 검사 78개·설정 검사 24개·날씨 서비스 검사 12개도 통과했습니다. 공개 다운로드, 실제 Sparkle 조회와 현재 Mac 설치는 진행 중입니다. 기존 0.8.0 배포나 같은 버전의 App Store 검사 결과를 이번 직접 배포 실행의 성공으로 집계하지 않습니다.

## 변경 범위와 배포 구분

- 바람 방향에 가운데(없음)를 추가했습니다. 방향은 `-1/0/1`이며 가운데에서는 세기를 보존하고 실제 바람만 0으로 만듭니다.
- 직접 배포는 SwiftPM 앱에 Sparkle를 포함하고 Developer ID 서명·Apple 공증을 거칩니다. 기존 업데이트 피드와 공개 키를 유지합니다.
- App Store의 같은 1.0.0·빌드 15는 별도 Sandbox·스토어 서명 구성으로 Sparkle를 제외합니다. [스토어 심사 제출 기록](../../app-store/1.0.0/VALIDATION.md)은 이 문서와 별도로 보존합니다.

## 검증 진행

| 항목 | 현재 상태 | 완료 기준 |
| --- | --- | --- |
| 직접 배포 앱·무풍 설정 | **24개 통과** | [최종 앱 검사](features-release.json). 가운데 저장·세기 보존과 설정·제어 검사 |
| 실제 데스크톱 GUI | **78개 통과** | [최종 앱 결과](smoke-release.json). 현재 연결된 3개 모니터에서 창·포커스·전체 화면·표시 옵션 등 검사 |
| 날씨 서비스 모의 응답 | **12개 통과** | [최종 앱 결과](weather-service-release.json). 실제 외부 API 호출과 구분 |
| 앱 서명·공증 | **완료** | [Apple Accepted](notarization.json), [검증 기록](artifact-verification.txt). Developer ID, `arm64`·`x86_64`, 티켓·Gatekeeper |
| 공유 ZIP·업데이트 ZIP | **완료** | [검증 기록](artifact-verification.txt). 앱만 포함, 압축 무결성, 서명·티켓 유지, EdDSA·appcast 버전 일치 |
| DMG | **완료** | [Apple Accepted](dmg-notarization.json), [서명·티켓·마운트·Applications 링크 검사](dmg-artifact-verification.txt) |
| 정확한 빌드 소스 CI | **통과** | 소스 `3754c25`의 [CI 42964504687](https://github.com/mindw96/WeatherWeather/actions/runs/42964504687), [기록](source-ci.json). 직접 배포·스토어 빌드와 핵심 테스트·모의 날씨 서비스 |
| GitHub 공개·소스 | 대기 | 실제 릴리스·태그·CI·빌드 입력 일치 |
| 공개 다운로드 | 대기 | 비로그인 다운로드·로컬 SHA-256 일치·latest appcast 일치 |
| 실제 Sparkle 버전 판별 | 대기 | 이전 빌드는 1.0.0·빌드 15 발견, 현재 빌드는 최신 판별 |
| 현재 Mac 설치·실행 | 대기 | 기존 앱 백업, 최종 앱 설치, 서명·티켓·Gatekeeper·실행 경로 확인 |

최종 소스 스냅샷은 Git 커밋 `2dbb677`의 추적 입력 **57개**만 사용하며 파일별 SHA-256이 일치합니다. 이 57개 입력은 CI를 통과한 `3754c25`의 입력과도 모두 일치합니다. [스냅샷·파일별 해시](release-source-snapshot.json), [CI 입력 비교](source-ci.json). 이 일치는 공개 태그나 업로드 성공을 대신하지 않습니다.

최종 앱 공증 제출은 `f9333b02-8b0f-4afc-ad50-82eeb2332b3b`, DMG는 `7273edcc-eca7-4427-9af9-8454e2178b08`이며 모두 **Accepted**입니다. `dist/releases/1.0.0/`에 DMG·공유 ZIP·업데이트 ZIP·appcast·체크섬 다섯 파일을 생성했습니다. 재현은 기존 [배포 절차](../../RELEASING.md)를 따릅니다.

공개 전 입력 비교에서 첫 패키지에 추적되지 않는 `.DS_Store`가 포함된 것을 발견해, Git 추적 파일만으로 재포장·재공증했습니다. 제품 코드 변경은 없으며 위 표의 78·24·12개 검사는 새 최종 패키지로 다시 실행한 결과입니다. 이전 패키지는 태그·릴리스로 공개하지 않았고 [대체된 검사·공증 기록](superseded-package/README.md)에 따로 보존합니다.

## 검증 경계

공개 피드의 Sparkle 버전 판별은 업데이트 다운로드·설치·재실행 전체 과정의 검증을 대신하지 않습니다. 통합 아키텍처 빌드는 Intel 실기기 실행의 근거가 아닙니다. 물리 키·마우스 입력, 실제 재로그인, 모든 모니터·Spaces 조합과 장시간 성능은 별도 확인 대상입니다.

GitHub 직접 배포가 완료돼도 App Store 심사 승인·공개 출시가 완료된 것으로 표현하지 않습니다.
