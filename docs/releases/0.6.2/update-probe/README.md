# Sparkle 0.6.2 공개 피드 조회 검증

2026-11-06. 현재는 준비 완료이며 피드는 아직 조회하지 않았습니다. 0.6.2 게시 완료 후 실행합니다.

0.6.1의 검증 소스를 재사용해 기대 빌드9·표시 버전0.6.2·정확한 업데이트 ZIP URL을 검사하도록 변경했습니다. 임시 호스트는 `/private/tmp/window-weather-062-sparkle-probe.q8b_thyv/Build8.app`(0.6.1), `Build9.app`(0.6.2)입니다. 공식 Sparkle2.10.1 프레임워크와 Swift5 모드·arm64 macOS14 타깃으로 컴파일하고 ad-hoc 서명 및 strict deep 서명 검사를 통과했습니다.

호스트마다 고유 번들 ID와 독립된 설정을 사용합니다. 자동 다운로드·설치·시스템 프로파일 전송은 끄고 `SPUUpdater.checkForUpdateInformation()`으로만 확인하며, 종료 전 자신의 테스트 설정 도메인을 제거합니다. 실제 업데이트 설치·재실행은 수행하지 않습니다.
