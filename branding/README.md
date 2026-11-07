# 쌓임쌓임 앱 아이콘

현재 앱 아이콘은 `window-weather-logo-v2.png`를 사용합니다. 0.7.1에서 보이던 바깥 흰 여백을 제거하고 파랑·청록 배경을 캔버스 가장자리까지 이어 붙인 1,254 × 1,254 불투명 PNG입니다. 창·눈·눈 세 점의 디자인을 유지했습니다. 표시 외곽은 macOS의 아이콘 처리에 따르며, 확인한 시스템 이미지는 [0.7.2 검증 기록](../docs/releases/0.7.2/VALIDATION.md)에 구분해 기록합니다.

흰 배경의 이전 원본 `window-weather-logo-v1.png`도 보존합니다. 생성·편집 프롬프트는 각 버전의 `.prompt.md`에 있습니다.

앱에는 현재 원본을 크기만 바꿔 포장한 `Resources/AppIcon.icns`를 사용합니다. 다음 명령은 macOS 기본 `sips`와 `iconutil`로 16–1,024px의 1x·2x 표현을 만들고, 역변환하여 10개 표현을 확인한 뒤 리소스를 갱신합니다.

```sh
./script/generate_app_icon.sh
```

개발·배포 스크립트의 `CFBundleIconFile`이 이 리소스를 가리킵니다. 두 번들 모두 서명 전에 Resources를 복사하며, 아이콘 파일이 없으면 빌드를 중단합니다. `.icns`는 저장소에 포함하므로 일반 앱 빌드 때마다 다시 생성할 필요는 없습니다.

[Apple의 CFBundleIconFile 문서](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile)와 [고해상도 아이콘 포장 안내](https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html)를 따릅니다.
