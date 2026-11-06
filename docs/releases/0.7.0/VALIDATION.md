# 쌓임쌓임 0.7.0 검증 상태

버전 0.7.0, 빌드 11. 연결된 모니터별로 날씨 효과를 켜고 끄는 기능을 추가합니다. 현재 로컬 검증과 앱·DMG 서명·공증을 완료했으며, GitHub 공개 배포와 공개 피드·설치본 확인은 다음 단계입니다.

## 완료한 기능 검증

Apple Silicon Mac, macOS 27.2, 연결된 화면 3개 환경에서 확인했습니다. [결과 요약](local-validation.json)은 이번 버전에서 실행한 검사만 집계합니다.

| 검사 | 결과 | 근거 |
| --- | --- | --- |
| WeatherCore | 76개 통과 | [테스트 로그](core-tests.txt) |
| 업데이트 구성 | 6개 통과 | [구성 검사 로그](update-config-tests.txt) |
| 모서리·겹친 창 | 96개 통과 | [결과](corner-validation.json) |
| 포커스 창 | 62개 통과 | [검증 자료](focused-window/) |
| 눈사람 | 26개 통과 | [검증 자료](snowman/) |
| 실제 AppKit 창·모니터 선택 | 69개 통과, 이 중 모니터 선택 관련 신규 22개 | [결과와 진단](smoke.json) |

모니터 검사는 기본 전체 ON, 각 화면만 선택, 끈 화면의 패널·눈사람 숨김과 입자·누적 초기화, 끈 화면의 시뮬레이션 정지, 나머지 화면의 갱신 유지, 모든 화면 OFF와 재개, 설정 재로딩 후 선택 복원, 분리된 화면 ID 유지, 새 화면 기본 ON, 화면 재구성 후 선택 유지, 기존 날씨·눈사람 설정 보존을 확인했습니다. 화면 연결 변경 알림을 통한 재구성과 실제 물리 케이블 분리·재연결은 구분합니다.

[설정창 미리보기](settings-preview.png)를 직접 확인했습니다. 이 이미지는 설정 UI 검증 자료이며 실제 데스크톱 전체의 효과 합성이나 물리 마우스 입력을 검증한 자료는 아닙니다. AppKit 검사의 클릭 통과 항목 역시 패널 설정 검사입니다.

## 완료한 패키지 검증

- Apple Silicon·Intel 통합 Release 앱을 빌드하고 Developer ID로 서명했습니다.
- 앱 ZIP 공증: `Accepted`, 제출 ID `01aae2bd-9aef-4bc3-a384-58e90c75540e`. [Apple 응답](notarization.json)
- DMG 공증: `Accepted`, 제출 ID `5921bd0a-ca6c-44c2-90fe-2281a313904d`. [Apple 응답](dmg-notarization.json)
- 앱·DMG 공증 티켓, 코드 서명, Gatekeeper 승인과 ZIP 무결성을 검증했습니다. Sparkle appcast의 버전 0.7.0·빌드 11과 업데이트 ZIP의 EdDSA 서명도 확인했습니다. [앱·ZIP 검증](artifact-verification.txt)
- DMG 안의 앱 서명·공증 티켓·실행 파일 일치·통합 아키텍처·Applications 링크를 확인했습니다. [DMG 검증](dmg-artifact-verification.txt)

## 남은 배포 확인

- GitHub 0.7.0 공개 게시, 공개 다운로드 해시와 latest appcast 확인.
- 공개 피드에 대한 실제 Sparkle의 구버전→0.7.0 및 최신 버전 판별.
- 현재 Mac의 설치본 교체 후 실행·버전 확인과 main·태그 CI 확인.

Sparkle를 통한 실제 업데이트 설치·재실행은 버전 판별 검사와 별개이며 아직 수행하지 않았습니다. CPU 사용량 실측, 물리 케이블 재연결, Intel Mac·macOS 14 실기기, 모든 허브·미러링·배율·잠자기 조합도 별도 검증이 필요합니다.

## 화면 식별과 범위

화면 이름이나 현재 배열 순서 대신 macOS의 디스플레이 UUID로 선택을 저장합니다. UUID를 얻지 못하면 현재 세션의 화면 ID로 대체하므로 이 경우 재연결·재부팅 뒤에는 선택을 다시 확인해야 합니다. 미러링은 macOS가 제공하는 논리 화면 단위이며 물리 모니터마다 다른 내용을 표시하는 기능은 아닙니다. 자세한 동작은 [모니터 선택 안내](../../DISPLAY_SELECTION.md)에 있습니다.
