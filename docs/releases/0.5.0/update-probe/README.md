# Sparkle 공개 피드 조회 검증

2026-11-05, Sparkle 2.10.1 공식 프레임워크, Apple Silicon Mac.

제품 앱과 별개의 임시 `.app` 두 개를 빌드하고 `SPUUpdater.checkForUpdateInformation()`으로 공개 GitHub Releases 피드를 조회했습니다. 두 앱은 서로 다른 고유 번들 ID와 독립된 설정을 사용합니다. 검사가 끝나면 각 테스트 설정 도메인만 제거합니다.

| 임시 앱 | 기대 동작 | 실제 결과 |
| --- | --- | --- |
| 빌드 5, 표시 버전 0.5.0 | 최신 버전 | `OnLatestVersion`, 최신 항목 5, 1.21초 |
| 빌드 4, 표시 버전 0.4.0 | 새 업데이트 발견 | 빌드 5 / 버전 0.5.0, 공개 업데이트 ZIP URL 확인 |

두 경우 모두 Sparkle 자동 확인 설정을 ON → OFF로 바꿀 때 해당 값이 테스트 앱의 UserDefaults에 저장되는 것도 확인했습니다. 자동 다운로드·자동 설치·시스템 프로파일 전송은 꺼져 있습니다. 조회 제한 시간은 30초입니다.

`main.swift`가 실제 검증 소스입니다. 공식 `Sparkle.framework`를 `Contents/Frameworks`에 복사하고, `swiftc -swift-version 5 -O -framework AppKit -framework Sparkle`로 빌드하면서 `@executable_path/../Frameworks` RPATH를 지정했습니다. 앱의 Info.plist에는 `config/Updates.plist`의 피드·공개 키와 테스트별 빌드 번호, 고유 번들 ID를 넣고 자동 확인은 OFF로 설정했습니다. 임시 앱은 ad-hoc 서명한 뒤 `codesign --verify --deep --strict`를 통과했습니다.

실행은 `open -n -W <임시 앱> --args <결과.json> current` 또는 `available`로 수행했습니다. 이 저장소의 제품 코드에는 검증 전용 실행 경로를 추가하지 않았습니다.

이 검사는 실제 Sparkle의 공개 피드 다운로드·파싱·버전 선택·완료 콜백을 확인합니다. 업데이트 안내창, 업데이트 ZIP 다운로드, 서명 검증 후 설치·재실행은 수행하지 않습니다. 빌드 4 앱은 Sparkle를 포함한 테스트 호스트이며, Sparkle가 없었던 기존 0.4.0 배포 앱이 자동으로 0.5.0을 받을 수 있다는 의미는 아닙니다.
