# 비 색상 비교 — 0.6.2

2026-11-06, Apple Silicon, Core Graphics 오프스크린 800×480. 제품에서는 WeatherView의 세 RGB 색상만 바꿨습니다.

| 요소 | 이전 RGB | 새 RGB | alpha |
| --- | --- | --- | --- |
| 빗줄기 | 0.68 / 0.85 / 1 | 0.48 / 0.75 / 1 | 기존 입자 opacity × 0.72 유지 |
| 물막 | 0.48 / 0.77 / 1 | 0.34 / 0.68 / 0.98 | 0.46 유지 |
| 튀는 물방울 | 0.72 / 0.88 / 1 | 0.52 / 0.78 / 1 | 기존 min(0.8, life × 1.8) 유지 |

움직임·발생량·선 두께·길이·불투명도는 변경하지 않았습니다. 강도0.85·바람0.2·seed2026·30Hz 1,800프레임 뒤의 같은 상태를 사용했습니다. 모서리 보정과 색상 변경을 분리해 비교하기 위해 양쪽 모두 같은 반경16pt 가상 창을 사용했습니다.

21개 검사 모두 통과했습니다. 여섯 효과 모두 입자·누적·물튀김·정착 상태와 렌더링 alpha 바이트가 일치했고, 비를 제외한 다섯 효과는 모든 RGBA 바이트가 같았습니다. 원시 결과는 `rain-color-comparison.json`입니다.

창 위의 빈 배경 영역에서 빗줄기 픽셀과 배경 RGB의 거리 합은 흰색 배경에서 4,295→7,251(1.69배), 어두운 배경에서 25,459→22,503(0.884배)이었습니다. 같은 이미지의 색상 차이를 비교하는 보조 지표이며 WCAG 명암비·사람의 시인성 평가·성능 수치가 아닙니다.

`rain-light-before.png`, `rain-light-after.png`, `rain-dark-after.png`를 직접 확인했습니다. 흰 화면에서 푸른 줄기와 물튀김이 더 드러나면서 기존의 옅은 비 표현을 유지합니다. PNG는 자체 생성한 장면이며 사용자 화면을 캡처하거나 수정하지 않았습니다. 재생성 가능한 PNG는 Git에서 제외됩니다.

## 재현

`main.swift`를 기존 `docs/validation/performance/render-main.swift`와 같은 방식으로 독립 컴파일합니다. WeatherCore 소스를 별도 Swift 모듈로 만들고 현재 WeatherView·SnowmanRenderer를 복사합니다. 현재 WeatherView 복사본에 `baseline.patch`를 적용한 다음 `WeatherView`와 `WeatherPanel` 클래스 선언을 각각 `WeatherViewBefore`, `WeatherPanelBefore`로 바꾸면 비교본이 됩니다. 두 렌더러와 `main.swift`를 `swiftc -O`로 링크해 출력 디렉터리 하나를 인자로 실행합니다. 비교한 소스의 해시는 `source-hashes.json`에 있습니다.

이번 실행 위치는 `/private/tmp/window-weather-rain-062.9339x3oh/compare`이며 출력 인자는 같은 폴더의 `output`입니다. 시스템 화면 캡처·실제 앱 합성·사용자 모니터별 시인성은 검증하지 않았습니다.
