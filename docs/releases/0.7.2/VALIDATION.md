# 쌓임쌓임 0.7.2 검증 상태

버전 0.7.2, 빌드 13. 앱 아이콘 바깥의 흰 테두리를 제거했습니다. 아이콘·번들 검사, 개발용 빌드, 앱·DMG 서명·공증, 현재 Mac 설치·실행과 OS 아이콘 확인을 완료했습니다. 공개 배포·Sparkle 버전 판별·main 및 버전 태그 CI 결과 확인도 완료했습니다.

## 아이콘 원본과 번들 검사

새 원본 `branding/window-weather-logo-v2.png`는 파랑·청록 배경으로 정사각 캔버스 끝까지 채웁니다. 기존 창·눈 구성을 유지하며 바깥 흰 여백을 제거한 형태입니다. v1 원본은 보존했습니다.

[외곽 표본 검사](border-validation.json)에서 v1은 외곽 2,512개 표본 모두 흰색이었고, v2는 같은 수의 표본 중 흰색이 0개였습니다. 내부 흰색 표본은 v1 733개·v2 759개로 남아 있습니다. 이 검사는 바깥 흰 여백 제거와 내부 흰색 유지의 표본 검사이며, 내부 그림이 픽셀 단위로 동일하다는 뜻은 아닙니다. 창·눈 구성은 별도로 시각 검토합니다.

[아이콘 검사](icon-validation.json)의 8개 항목이 통과했습니다.

- ICNS를 다시 읽어 16~1024px의 10개 이미지 표현과 각 크기를 확인했습니다.
- 개발용·배포용 번들의 `CFBundleIconFile`, 아이콘 리소스 해시, 버전 0.7.2·빌드 13이 일치합니다.
- v1 원본의 보존을 확인했습니다. v2 원본과 앱 아이콘의 SHA-256도 기록했습니다.

v2 원본 SHA-256: `0f59cff0fa679394eaf124fc76b741c497aaa7ec472d265c4dbf0220f4bb091b`.
앱 아이콘 SHA-256: `b369aad8ac74ac5259e2e3334a507e298d52560754e017ce909ca8cb781cc2ad`.

## 빌드와 패키지 검증

- 개발용 앱 빌드가 성공했습니다. [빌드 기록](build.txt)
- 업데이트 구성 검사 6개가 통과했습니다. [검사 기록](update-config-tests.txt)
- Apple Silicon·Intel 통합 Release 앱을 빌드하고 Developer ID로 서명했습니다.
- 앱 ZIP 공증: `Accepted`, 제출 ID `fde70b3d-6386-4937-90b5-b2c628fa8818`. [Apple 응답](notarization.json)
- DMG 공증: `Accepted`, 제출 ID `06176cc5-382a-4f92-9cd5-0f0ec2e0c17a`. [Apple 응답](dmg-notarization.json)
- 앱·DMG의 서명·공증 티켓·Gatekeeper 승인, ZIP 무결성·통합 아키텍처와 Sparkle appcast의 버전·빌드·업데이트 ZIP EdDSA 서명을 검증했습니다. [앱·ZIP 검증](artifact-verification.txt)
- DMG 안의 앱 서명·공증 티켓·실행 파일 일치·통합 아키텍처·Applications 링크를 확인했습니다. [DMG 검증](dmg-artifact-verification.txt)

이번 변경에서 `Sources/`와 `Tests/`는 수정하지 않았습니다. 날씨 시뮬레이션·창 동작의 전체 GUI 회귀 검사는 반복하지 않았으며, 이전 버전의 통과 결과를 0.7.2에서 새로 실행한 검사로 집계하지 않습니다.

## 설치본과 OS 아이콘 표시

현재 Mac의 `~/Applications/WindowWeather.app`을 공증된 0.7.2·빌드 13으로 교체했습니다. 후보와 설치본의 서명·공증 티켓·Gatekeeper를 각각 확인하고 정확한 설치 경로의 실행 프로세스를 확인했습니다. 이전 앱은 `/private/tmp/window-weather-pre-072-backup.vwdov0if/WindowWeather.app`에 보관했습니다. [설치 기록](runtime-check.json)

`NSWorkspace`의 파일 아이콘과 `NSRunningApplication`의 실행 앱 아이콘을 32px·128px PNG로 추출했습니다. [OS 조회 결과](system-icon-check.json)에 경로·실행 상태·이미지 목록을 기록했습니다. `finder-resolved-icon-128.png`와 `running-app-icon-128.png`를 직접 확인했으며, 두 이미지 모두 둥근 파란 외곽으로 표시되고 이전의 두꺼운 흰 테두리가 없습니다.

추가로 128px 실행 앱 아이콘에서 이전 흰 테두리 안쪽 132개 표본을 비교했습니다. 0.7.1은 132개가 흰색이고 0.7.2는 0개였으며, [시스템 테두리 검사](system-border-validation.json)를 통과했습니다. 이는 해당 Mac에서 추출한 두 아이콘의 비교이며 다른 OS의 표시를 보장하지 않습니다.

등록 전 개발용 번들의 `NSWorkspace` 조회에서 나온 정사각형 이미지는 최종 표시 판정에 사용하지 않았습니다. 최종 판정은 설치·실행한 앱에서 얻은 아이콘을 기준으로 합니다. 이 결과는 OS가 반환한 아이콘을 화면 밖에서 그린 이미지이며, 실제 데스크톱 화면 캡처와는 구분합니다.

## 공개 배포와 자동 업데이트

[GitHub 0.7.2 Release](https://github.com/mindw96/WeatherWeather/releases/tag/v0.7.2)에 DMG·공유 ZIP·업데이트 ZIP·appcast·체크섬 파일을 공개했습니다. 다섯 파일의 비로그인 다운로드 HTTP 200·로컬 SHA-256 일치와 latest appcast의 바이트 일치를 확인했습니다. [게시 기록](github-release.json)과 [다운로드 검증](public-download-verification.json)을 보관합니다.

실제 Sparkle 2.10.1 검증 호스트에서 빌드 12는 0.7.2·빌드 13과 정확한 업데이트 ZIP URL을 발견했고, 빌드 13은 `OnLatestVersion`으로 판별했습니다. 두 호스트의 자동 확인 ON→OFF 저장도 통과했습니다. [업데이트 발견](update-probe/available.json)과 [최신 판별](update-probe/current.json)은 독립된 테스트 호스트의 정보 조회 결과이며 실제 업데이트 설치 검사는 아닙니다.

소스 커밋 `8c20bca9742f2f2ceae70ea3940d747250c0b050`의 main·v0.7.2 태그 CI 모두 앱 빌드·업데이트 구성·핵심 테스트를 통과했습니다. [CI 기록](ci.json)을 제공합니다.

최종 DMG SHA-256: `7509a3dbfa0463b2b2478852051bca60f771c4728392cedfedd795ea08845dd7`.
공유·업데이트 ZIP SHA-256: `a48f5a2d34584f75742914297583ad8e56360cfeddc7aef9d2b8b130f9f2f0bc`.

## 확인하지 않은 범위

다른 macOS 버전·Intel Mac·모든 화면 배율의 실제 표시, 날씨 전체 GUI 회귀, 실제 Finder·Dock 화면 캡처, Sparkle를 통한 업데이트 설치·재실행은 아직 수행하지 않았습니다. 공개 피드의 버전 판별은 실제 업데이트 설치 검사를 대신하지 않습니다.
