# Window Weather 0.2.0 공유 패키지 검증

2026-11-05, macOS Apple Silicon 호스트에서 작성했습니다.

공유 파일: `dist/releases/0.2.0/WindowWeather-0.2.0-macOS-universal.zip`.
압축에는 `WindowWeather.app`, `START_HERE.ko.txt`, `RELEASE_NOTES.ko.md`, `LICENSE`만 넣습니다.

## 빌드와 서명

- SwiftPM Release, `--arch arm64 --arch x86_64` 통합 빌드.
- 최소 지원 선언 macOS 14.0, 버전 0.2.0 (2).
- Developer ID Application: Dongwook Min (4J7HGK26PF), Hardened Runtime 및 서명 timestamp 적용.
- 임시 로컬 폴더에서 서명하고 ZIP에 Finder 확장 속성을 넣지 않습니다.
- 최종 ZIP을 다시 풀어 `codesign --verify --deep --strict`, `lipo -archs`, `plutil -lint`로 확인합니다. 결과는 `artifact-verification.txt`에 저장합니다.
- ZIP 파일 해시는 같은 배포 폴더의 `SHA256SUMS.txt`를 따릅니다.

## 기능 검증과 한계

핵심 시뮬레이션·전체 화면 정책·창 가림 XCTest **42개 통과, 실패 0**입니다.

공유 빌드의 검사 중 창 geometry가 달라지고 전체 화면 OFF 검사가 실패했습니다. 별도 시험 창도 활성화되지 않았고, `CGSessionCopyCurrentDictionary`에서 `CGSSessionScreenIsLocked = 1`, `pmset`에서 `UserIsActive = 0`을 확인했습니다. 잠금 세션에서 얻은 결과로 제품의 경계 허용치를 늘리지는 않았습니다. 전체 화면 정책은 기존 네 변 2pt 허용치를 유지합니다.

검증 도구는 잠금 세션을 `blocked`로 기록하고 GUI 검사를 중단하도록 보완했습니다. 전체 화면은 styleMask 변경이 아닌 `didEnterFullScreenNotification` / `didExitFullScreenNotification` 완료 알림을 기다립니다. 이전 개발 빌드의 26개 assertion 통과는 최종 공유 빌드의 GUI 검증 완료를 의미하지 않습니다. 최종 상태는 `release-smoke.json`에 기록하며 **잠금 해제 후 GUI 재검증이 필요합니다**.

Intel 코드는 포함하고 빌드·아키텍처를 확인했지만 Intel Mac 실행, macOS 14 실기기 실행, 모든 외부 앱의 Spaces 조합, 물리 마우스 통과, 배터리 사용량은 확인하지 않았습니다.

## Apple 공증

현재 **Developer ID 서명 및 Apple 공증 완료** 상태입니다. 처음 자동 승인 검토가 업로드를 거절했으며, 사용자에게 앱 실행 파일과 번들 정보를 Apple에 전송하는 범위를 설명한 뒤 **“Apple에 업로드하여 공증 진행”** 승인을 받았습니다. 이후 해당 ZIP을 제출해 `Accepted` 결과를 받았습니다. 공개 게시나 지인에게 직접 전송은 하지 않았습니다.

제출 ID: `7d4c0819-1fef-4b62-9487-005e5370592b`. 서비스 결과는 `notarization.json`에 보관합니다. Accepted 확인 → staged app에 staple → 안내 문서 상태 갱신 → ZIP 재생성 → 재추출 후 서명·staple·Gatekeeper 검사 → SHA-256 갱신을 완료했습니다. 최종 ZIP은 384,807바이트이며 압축 무결성 검사도 통과했습니다. 재추출한 앱은 `Notarization Ticket=stapled`, Gatekeeper `accepted`, `source=Notarized Developer ID`로 확인됐습니다. 인증 정보는 배포물에 넣지 않습니다.
