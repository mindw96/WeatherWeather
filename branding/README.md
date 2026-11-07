# 쌓임쌓임 앱 아이콘

`window-weather-logo-v1.png`는 승인된 1,254 × 1,254 흰 배경 원본입니다. 생성 프롬프트는 `window-weather-logo-v1.prompt.md`에 보관합니다.

앱에는 이 원본을 크기만 바꿔 포장한 `Resources/AppIcon.icns`를 사용합니다. 색상·구성·흰 배경은 그대로 유지합니다. 다음 명령은 macOS 기본 `sips`와 `iconutil`로 16–1,024px의 1x·2x 표현을 만들고, 역변환하여 10개 표현을 확인한 뒤 리소스를 갱신합니다.

```sh
./script/generate_app_icon.sh
```

개발·배포 스크립트의 `CFBundleIconFile`이 이 리소스를 가리킵니다. 두 번들 모두 서명 전에 Resources를 복사하며, 아이콘 파일이 없으면 빌드를 중단합니다. `.icns`는 저장소에 포함하므로 일반 앱 빌드 때마다 다시 생성할 필요는 없습니다.

[Apple의 CFBundleIconFile 문서](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundleiconfile)와 [고해상도 아이콘 포장 안내](https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/Optimizing/Optimizing.html)를 따릅니다.
