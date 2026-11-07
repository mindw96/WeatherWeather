# 쌓임쌓임 0.7.1 검증 상태

버전 0.7.1, 빌드 12. 승인된 창·눈 로고를 Finder·Dock의 앱 아이콘에 연결했습니다. 아이콘·번들 검사, 개발용 빌드, 앱·DMG 서명·공증과 현재 Mac 설치·실행을 완료했습니다. OS에서 읽은 아이콘 이미지도 직접 확인했습니다. 공개 다운로드·Sparkle 버전 판별과 main·버전 태그 CI 검증도 완료했습니다.

## 완료한 아이콘·번들 검사

[아이콘 검사 결과](icon-validation.json)의 8개 항목이 통과했습니다.

- ICNS를 다시 읽어 16~1024px의 10개 이미지 표현과 각 크기를 확인했습니다.
- 개발용·배포용 앱의 `CFBundleIconFile` 설정과 `Contents/Resources/AppIcon.icns`를 확인했습니다. 두 번들 아이콘의 해시가 소스 리소스와 같고 버전 0.7.1·빌드 12도 일치합니다.
- 승인된 `branding/window-weather-logo-v1.png`의 원본 해시를 보존했습니다. 원본은 변경하지 않고 macOS의 기본 도구로 앱 아이콘 리소스를 만들었습니다.
- 32px·128px PNG 미리보기를 직접 확인했습니다. 이 검사는 아이콘 리소스의 작은 크기 표현이며 실제 Dock 화면을 캡처한 검사는 아닙니다.

앱 아이콘 SHA-256: `297dfcd0681d263f1e46112bfaf59c36f67f74033c144ec1fff637e9cc075367`.

## 완료한 빌드와 패키지 검증

- 개발용 앱 빌드가 성공했습니다. [빌드 기록](build.txt)
- 업데이트 구성 검사 6개가 통과했습니다. [검사 기록](update-config-tests.txt)
- Apple Silicon·Intel 통합 Release 앱을 빌드하고 Developer ID로 서명했습니다.
- 앱 ZIP 공증: `Accepted`, 제출 ID `3455a8d9-5688-4ded-9702-3bac3ed73f38`. [Apple 응답](notarization.json)
- DMG 공증: `Accepted`, 제출 ID `8e9acc2a-46fe-4e80-b756-b21b5dc3f81d`. [Apple 응답](dmg-notarization.json)
- 앱·DMG의 서명·공증 티켓·Gatekeeper 승인, ZIP 무결성과 통합 아키텍처를 확인했습니다. Sparkle appcast의 0.7.1·빌드 12와 업데이트 ZIP의 EdDSA 서명도 검증했습니다. [앱·ZIP 검증](artifact-verification.txt)
- DMG를 마운트해 앱 서명·공증 티켓·실행 파일 일치·통합 아키텍처·Applications 링크를 확인했습니다. [DMG 검증](dmg-artifact-verification.txt)

이번 변경에서 `Sources/`와 `Tests/`는 수정하지 않았습니다. 날씨 시뮬레이션·창 동작의 전체 GUI 회귀 검사는 반복하지 않았으며, 이전 버전의 통과 결과를 0.7.1에서 새로 실행한 검사로 집계하지 않습니다.

## 설치본과 OS 아이콘 조회

현재 Mac의 `~/Applications/WindowWeather.app`을 공증된 0.7.1·빌드 12로 교체했습니다. 후보와 설치본의 서명·공증 티켓·Gatekeeper를 각각 확인하고 해당 설치 경로의 앱 실행을 확인했습니다. 이전 앱은 `/private/tmp/window-weather-pre-071-backup.lf35pkb6/WindowWeather.app`에 보관했습니다. [설치 기록](runtime-check.json)

`NSWorkspace`의 파일 아이콘과 `NSRunningApplication`의 실행 앱 아이콘을 각각 32px·128px PNG로 추출했습니다. [OS 조회 결과](system-icon-check.json)와 [재현 코드](system-icon-probe.swift)를 보관합니다. 이 기록은 OS가 반환한 아이콘을 화면 밖에서 그린 결과이며 데스크톱 화면 캡처가 아닙니다. `finder-resolved-icon-128.png`와 `running-app-icon-128.png`를 직접 확인했고 두 이미지 모두 새 창·눈 로고를 정상적으로 표시했습니다. 현재 macOS가 표시하는 바깥 테두리의 둥근 형태도 확인했습니다.

## 공개 배포와 자동 업데이트 확인

[GitHub 0.7.1 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.7.1)에 DMG·공유 ZIP·업데이트 ZIP·appcast·체크섬 파일을 공개했습니다. 다섯 파일의 비로그인 다운로드 HTTP 200과 로컬 SHA-256 일치, latest appcast의 바이트 일치를 확인했습니다. [공개 결과](github-release.json)와 [다운로드 검증](public-download-verification.json)을 보관합니다.

실제 Sparkle 2.10.1 검증 호스트에서 빌드 11은 0.7.1·빌드 12와 정확한 업데이트 ZIP URL을 발견했고, 빌드 12는 `OnLatestVersion`으로 판별했습니다. 두 호스트 모두 자동 확인 ON→OFF 저장 검사를 통과했습니다. [업데이트 발견](update-probe/available.json)과 [최신 판별](update-probe/current.json)은 독립된 테스트 호스트의 정보 조회 결과이며 실제 업데이트 설치 검사는 아닙니다.

소스 커밋 `0cba3a1febfe73f5d108a329ce8b046a411eede6`의 main·v0.7.1 태그 CI가 모두 앱 빌드·업데이트 구성·핵심 테스트를 통과했습니다. [CI 실행 기록](ci.json)을 제공합니다.

최종 DMG SHA-256: `621b8688b38e80a6ff1bfb8ef45b0be232e1a8a43223a9988d9306268053fb57`.
공유·업데이트 ZIP SHA-256: `c7bfcc28af094a7216e0b5cd7ea4729f500946a6a2a5d40ea4efe22357a98cd2`.

## 아직 확인하지 않은 범위

Intel Mac·macOS 14 실기기와 모든 화면 배율의 표시, 실제 Finder·Dock 화면 캡처, Sparkle를 통한 업데이트 설치·재실행은 아직 수행하지 않았습니다. 공개 피드의 버전 판별과 실제 설치·재실행은 별도 검사입니다.
