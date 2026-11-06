# Sparkle 0.6.3 공개 피드 조회 검증 준비

2026-11-06. 현재는 임시 호스트 빌드·서명 준비를 마쳤으며 공개 피드는 아직 조회하지 않았습니다. 0.6.3 게시 완료 후 실행합니다.

0.6.2의 검증 소스를 재사용해 기대 빌드 10·표시 버전 0.6.3·정확한 업데이트 ZIP URL을 검사하도록 변경했습니다. 공식 Sparkle 2.10.1 프레임워크와 `swiftc -swift-version 5 -O -target arm64-apple-macos14.0 -framework AppKit -framework Sparkle`로 컴파일하고 `@executable_path/../Frameworks` RPATH를 지정했습니다.

임시 호스트는 `/private/tmp/window-weather-063-sparkle-probe.p2yglwyz/Build9.app`(0.6.2), `/private/tmp/window-weather-063-sparkle-probe.p2yglwyz/Build10.app`(0.6.3)입니다. 앱과 내장 Sparkle 도구를 ad-hoc 서명한 뒤 `codesign --verify --deep --strict`를 통과했습니다.

호스트마다 고유 번들 ID와 독립된 설정을 사용합니다. 자동 확인은 시작 시 끄고 ON→OFF 저장을 검사하며, 자동 다운로드·자동 설치·시스템 프로파일 전송은 비활성화합니다. `SPUUpdater.checkForUpdateInformation()`으로 피드만 확인하고, 종료 전에 자신의 테스트 설정 도메인을 제거합니다.

게시 후 `open -n -W <Build9.app> --args <available.json> available`과 `open -n -W <Build10.app> --args <current.json> current`로 각각 실행합니다. 기대 결과는 빌드 9의 0.6.3 업데이트 발견과 빌드 10의 최신 버전 판별입니다.

아직 실행 결과 JSON은 생성하지 않았습니다. 실제 업데이트 안내창·ZIP 다운로드·설치·재실행은 이 검증의 범위 밖이며 제품 앱·사용자 설정은 변경하지 않습니다.
