# Window Weather 배포

2026-11-05 사용자가 이 앱의 이후 업데이트에 대해 Developer ID 서명과 Apple 공증 업로드를 자동 진행하도록 승인했습니다. 아래 명령은 Window Weather의 실행 파일과 번들 정보가 포함된 ZIP을 Apple 공증 서비스에 제출합니다. 이후 사용자가 지정한 공개 저장소 `https://github.com/mindw96/WeatherWeather.git`를 origin으로 연결했습니다. 소스와 버전별 GitHub Releases를 같은 저장소에 게시합니다.

```sh
./script/release.sh
```

통합 Release 빌드 → Sparkle 프레임워크·내부 도구와 앱의 Developer ID 서명 → Apple 제출 → Accepted 확인 → 공증 티켓 첨부 → 공유 ZIP과 앱 전용 업데이트 ZIP 생성 → EdDSA 서명 appcast 생성 → 압축 해제본의 서명·티켓·Gatekeeper·아키텍처·업데이트 서명 검사 → SHA-256 생성을 순서대로 진행합니다. 각 공증 대기는 30초 단위이며, 기본 20분이 지나도 심사가 끝나지 않으면 상태를 보존하고 종료합니다.

이 Mac에서는 Developer ID Application 인증서 `Dongwook Min (4J7HGK26PF)`와 키체인 프로필 `DdayNotary`를 기본 사용합니다. 인증서의 개인 키와 공증 자격 증명은 키체인에 있으며 저장소에 포함하지 않습니다. 다른 개발 환경에서는 아래 환경 변수를 설정해 주세요.

```sh
WEATHER_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
WEATHER_NOTARY_PROFILE='YourNotaryProfile' \
./script/release.sh
```

중단·네트워크 오류·공증 지연 후에는 다음 명령으로 기존 제출 ID를 재사용합니다. 이미 완료된 ZIP은 해시를 확인하고 그대로 반환합니다.

```sh
./script/release.sh --resume
```

진행 정보는 `dist/releases/<version>/release-state.json`과 `notary-submission.json`, `notary-status.json`에 저장합니다. 업로드한 ZIP과 서명된 앱은 상태 파일에 기록된 `/private/tmp/window-weather-package.*` 폴더에 보존합니다. 완료 전 이 폴더를 삭제하거나 앱을 다시 서명하지 마세요. ZIP은 모든 검사가 통과한 뒤에만 최종 공유 경로에 놓입니다.

업로드 요청 직후 연결이 끊어져 제출 ID를 저장하지 못한 경우에는 중복 업로드를 방지하며 멈춥니다. `xcrun notarytool history --keychain-profile DdayNotary`에서 제출을 확인하고 해당 ID를 `release-state.json`의 `submission_id`에 복구한 뒤 재개해 주세요. 제출이 실제로 없음을 확인하기 전에는 `submission_attempted`를 초기화하지 마세요. 강제 종료로 `.release-lock` 폴더가 남은 경우에는 배포 프로세스가 더 이상 실행 중이지 않은지 확인한 후 해당 버전의 빈 잠금 폴더만 제거할 수 있습니다.

완료 결과는 `dist/releases/<version>/`의 `WindowWeather-<version>-macOS-universal.zip`(사용 안내 포함), `WindowWeather-<version>-update.zip`(앱만 포함), `appcast.xml`, `SHA256SUMS.txt`입니다. 완료 상태 재개는 세 배포 파일의 해시를 검증합니다. Apple의 응답과 압축 해제본 검증 기록은 `docs/releases/<version>/notarization.json`, `artifact-verification.txt`에 남깁니다. Gatekeeper 허용과 Intel 바이너리 포함 검사는 Intel Mac 실기기 동작 검증과 구분합니다.

새 버전 준비 시에는 `script/package_share.sh`와 `script/build_and_run.sh`의 버전·빌드 번호를 함께 변경하고 `docs/releases/<version>/START_HERE.ko.txt`, `RELEASE_NOTES.ko.md`를 준비해 주세요. 두 안내문에는 `배포 상태:`로 시작하는 줄을 정확히 하나씩 둡니다. 포장 단계에서는 공증 전으로, 최종 검증 후 ZIP 안에서는 공증 완료로 표시합니다. 소스 문서의 배포 상태는 검증 결과를 확인한 뒤 갱신합니다.

`script/package_share.sh`는 서명까지만 하는 하위 작업입니다. 일반 배포에는 `script/release.sh`를 사용합니다. 로컬 개발·테스트는 기존 `script/build_and_run.sh`를 사용하며 Apple 업로드가 필요하지 않습니다.

## Sparkle와 GitHub Releases

`Config/Updates.plist`에는 공개 피드 주소와 공개 Ed25519 키만 있습니다. 피드는 `https://github.com/mindw96/WeatherWeather/releases/latest/download/appcast.xml`이며, 각 항목의 앱 파일 주소는 `releases/download/v<version>/WindowWeather-<version>-update.zip`입니다. 공개 키에 대응하는 개인 키는 Mac 키체인 계정 `org.windowweather.app`에 저장되어 있습니다. 저장소·ZIP에는 포함하지 않습니다.

앱은 Sparkle 기본 주기인 하루에 한 번 새 버전을 확인합니다. `SUEnableAutomaticChecks=true`는 기본값이며 사용자가 설정에서 끈 값은 Sparkle가 저장합니다. 앱 시작 시 이를 강제로 다시 켜지 않습니다. 자동 다운로드·설치와 시스템 프로파일 전송은 비활성화했습니다. 수동 확인 메뉴의 활성 상태는 Sparkle의 `canCheckForUpdates`를 따릅니다. 테스트·미리보기 실행은 업데이트 컨트롤러를 시작하지 않습니다.

새 버전 배포 순서입니다. 0.5.0 예시이며 다음 버전에서는 태그·경로를 함께 변경합니다.

1. 코드 검사와 로컬 검증을 마치고 두 번들 스크립트의 버전·빌드 번호 및 릴리스 안내문을 갱신합니다.
2. `./script/release.sh`를 실행해 공증과 EdDSA 검증이 모두 통과한 결과를 만듭니다. 최종 ZIP을 수정하면 서명·크기·해시가 달라지므로 재압축하지 않습니다.
3. 검증한 소스를 커밋하고 origin에 push한 뒤 해당 커밋에 버전 태그를 붙입니다.
4. 다음처럼 파일 네 개를 **초안 Release**에 올리고 전부 올라온 뒤 게시합니다. appcast만 먼저 공개하면 아직 없는 ZIP을 안내할 수 있습니다.

```sh
git tag v0.5.0
git push origin main v0.5.0
gh release create v0.5.0 --repo mindw96/WeatherWeather --verify-tag --draft \
  --title 'Window Weather 0.5.0' \
  --notes-file docs/releases/0.5.0/RELEASE_NOTES.ko.md \
  dist/releases/0.5.0/WindowWeather-0.5.0-macOS-universal.zip \
  dist/releases/0.5.0/WindowWeather-0.5.0-update.zip \
  dist/releases/0.5.0/appcast.xml \
  dist/releases/0.5.0/SHA256SUMS.txt
gh release edit v0.5.0 --repo mindw96/WeatherWeather --draft=false --latest
```

5. 공개 피드와 ZIP을 다시 내려받아 해시를 확인하고 실제 Sparkle가 현재 버전/새 버전을 구분하는지 점검합니다. 0.4.0 이하 앱에는 업데이터가 없으므로 0.5.0을 처음 한 번 직접 설치해야 합니다.

Sparkle는 공식 2.10.1 SwiftPM 바이너리를 사용하며 `Package.resolved`를 커밋합니다. `script/embed_sparkle.py`가 프레임워크와 XPC/Updater/Autoupdate를 안쪽부터 서명하고 원본 라이선스를 앱 리소스에 포함합니다. GitHub Actions는 개발용 번들 빌드와 핵심 테스트·업데이트 설정 검사를 수행합니다. Developer ID와 EdDSA 개인 키는 CI에 복사하지 않고 현재 Mac의 키체인을 사용합니다.

## 로컬 폴더와 검증 산출물

공유 앱의 실행·업데이트는 `/Applications` 또는 `~/Applications`에서 확인합니다. 이 프로젝트의 Documents 폴더는 File Provider가 FinderInfo를 다시 붙여 서명 검사를 방해할 수 있습니다. 0.5.0의 실제 실행본은 `~/Applications/WindowWeather.app`에 설치했습니다. 배포용 ZIP은 계속 `/private/tmp`의 깨끗한 앱으로 만듭니다.

재생성 가능한 `docs/**/*.png` 미리보기는 로컬에 보관하고 Git에서는 제외합니다. `--previews`, `--validate-focus`, `--validate-snowman`으로 다시 만들 수 있습니다. 텍스트 검증 보고서·성능 원시 값·재현 코드는 저장소에 포함합니다. Git 객체가 iCloud의 dataless 상태라 읽기 대기가 생기면 해당 프로젝트 폴더의 다운로드를 완료하거나 로컬 체크아웃에서 작업합니다.
