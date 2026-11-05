# 0.5.0 성능 변경과 측정

2026-11-05, Apple Silicon Mac에서 `swiftc -O`로 변경 전후를 비교했습니다. 결과는 **Core 시뮬레이션과 화면 밖 렌더링 각각의 합성 부하**에 대한 시간입니다. 앱 전체 CPU·배터리 사용량이나 Window Server 합성 비용은 측정하지 않았으며, 아래 두 감소율을 합산하지 않습니다.

Ponytail의 작은 변경 원칙에 따라 효과가 확인된 처리만 줄였습니다.

- 같은 창 경계의 반복 갱신에서 pile 배열 재구성을 생략합니다.
- 입자가 도달할 수 없는 창은 높이 보간을 시작하기 전에 제외합니다.
- 낙엽·꽃잎의 기본 도형과 색을 재사용합니다.

입자 배열을 단순히 제자리에서 압축하는 방법은 측정 시 느려져 제외했습니다. 입자의 순서, 충돌 결과, 그림의 모양·색·크기·회전·가림 정책을 바꾸는 최적화는 하지 않았습니다.

## Core 시뮬레이션

조건은 3840×2160 화면, 창 윗변 12개, 강도 1, 바람 0.15, 고정 seed 17입니다. 30Hz로 900프레임을 먼저 계산한 다음 9,000프레임을 측정하며, 창 경계는 6프레임마다 같은 값으로 갱신합니다. 변경 전후를 번갈아 5회 실행한 중간값입니다. 표의 시간은 9,000프레임 전체 계산 시간입니다.

| 모드 | 변경 전 | 변경 후 | 시간 감소 |
| --- | ---: | ---: | ---: |
| 눈 | 1.168초 | 0.581초 | 50.2% |
| 비 | 0.579초 | 0.316초 | 45.5% |
| 낙엽 | 0.882초 | 0.600초 | 32.0% |
| 벚꽃 | 1.361초 | 0.931초 | 31.6% |

별도의 창 경계 갱신 검사에서는 움직이지 않는 창 24개의 정보를 20,000회 전달했습니다. 중간값은 0.0891초에서 0.00111초로 줄었습니다(98.8%). 같은 정보로 반복 갱신하는 함수에만 해당하는 수치이며 전체 앱의 비용 절감율이 아닙니다.

모든 실행에서 입자·누적 높이·물튀김·정착 입자의 상태 fingerprint가 변경 전후 같았습니다. 최대 누적 높이 경계, 이동 경로의 양 끝이 창 밖에 있는 충돌, 동일 창 갱신 시 상태 보존을 포함한 Core XCTest 61개도 통과했습니다.

- [조건·중간값·상태 fingerprint](validation/performance/core-summary.json)
- [고정 입력 측정 코드](validation/performance/core-benchmark.swift)
- 원시 측정: `validation/performance/core-before-1.json`~`core-before-5.json`, `core-after-1.json`~`core-after-5.json`

## 화면 밖 렌더링

800×480 Core Graphics bitmap에 동일한 결정적 시뮬레이션 상태를 그렸습니다. 같은 크기·회전·불투명도 변환을 유지하며, 각 80프레임씩 7회 실행하고 전후 측정 순서를 교대했습니다. 시간은 프레임당 중간값입니다.

| 모드 | 내리는 입자 / 정착 입자 | 변경 전 | 변경 후 | 시간 감소 |
| --- | ---: | ---: | ---: | ---: |
| 낙엽 | 75 / 573 | 4.451ms | 3.816ms | 14.3% |
| 벚꽃 | 145 / 702 | 3.427ms | 2.706ms | 21.1% |

눈·비·낙엽·벚꽃 각각에서 포커스 창 가림 ON/OFF를 비교한 **8개 이미지의 RGBA 바이트가 모두 일치**했습니다. 실제 화면을 캡처한 검사가 아니며 눈사람은 이 렌더링 비교에서 꺼두었습니다. 눈사람 회귀는 별도 검사를 따릅니다.

- [원시 표본·픽셀 비교 결과](validation/performance/render-comparison.json)
- [렌더링 측정 코드](validation/performance/render-main.swift)

## 재현 방법

아래 명령은 저장소 루트에서 실행합니다. 비교 기준은 최적화 직전에 보관한 로컬 0.4.0 소스이며 Git 커밋을 기준으로 삼지 않았습니다. 측정한 0.5.0 소스에서 기준 소스를 복원하는 작은 reverse patch와 [소스 해시](validation/performance/source-hashes.json)를 함께 보관했습니다. 이후 구현이 달라지면 patch나 해시가 맞지 않을 수 있으므로 같은 버전의 소스로 비교해야 합니다.

동기화 폴더에서 파일이 빌드 중 바뀌는 영향을 피하려고 필요한 소스를 `/private/tmp`에 복사합니다. 바이너리·Swift 모듈 캐시는 저장소에 넣지 않습니다.

Core 비교:

```sh
PERF_DIR="$(mktemp -d /private/tmp/window-weather-core-perf.XXXXXX)"
cp Sources/WeatherCore/WeatherSimulation.swift "$PERF_DIR/after.swift"
cp "$PERF_DIR/after.swift" "$PERF_DIR/before.swift"
patch "$PERF_DIR/before.swift" < docs/validation/performance/core-baseline.patch
cp docs/validation/performance/core-benchmark.swift "$PERF_DIR/benchmark.swift"
swiftc -O -module-cache-path "$PERF_DIR/module-cache" "$PERF_DIR/before.swift" "$PERF_DIR/benchmark.swift" -o "$PERF_DIR/before"
swiftc -O -module-cache-path "$PERF_DIR/module-cache" "$PERF_DIR/after.swift" "$PERF_DIR/benchmark.swift" -o "$PERF_DIR/after"
for trial in 1 2 3 4 5; do
  "$PERF_DIR/before" > "$PERF_DIR/before-$trial.json"
  "$PERF_DIR/after" > "$PERF_DIR/after-$trial.json"
done
```

각 JSON의 `seconds`를 같은 `case`끼리 모아 중간값을 비교하고, 모든 `fingerprint`가 같은지도 확인합니다. 측정 중 다른 빌드·앱 부하에 따라 시간은 달라질 수 있습니다.

렌더링 비교:

```sh
RENDER_DIR="$(mktemp -d /private/tmp/window-weather-render-perf.XXXXXX)"
mkdir "$RENDER_DIR/Core"
cp Sources/WeatherCore/*.swift "$RENDER_DIR/Core/"
cp Sources/WeatherApp/WeatherView.swift "$RENDER_DIR/WeatherView.swift"
cp Sources/WeatherApp/SnowmanRenderer.swift "$RENDER_DIR/SnowmanRenderer.swift"
cp "$RENDER_DIR/WeatherView.swift" "$RENDER_DIR/WeatherView.before.swift"
patch "$RENDER_DIR/WeatherView.before.swift" < docs/validation/performance/render-baseline.patch
sed -e 's/class WeatherView:/class WeatherViewBefore:/' \
    -e 's/class WeatherPanel:/class WeatherPanelBefore:/' \
    "$RENDER_DIR/WeatherView.before.swift" > "$RENDER_DIR/WeatherViewBefore.swift"
cp docs/validation/performance/render-main.swift "$RENDER_DIR/main.swift"
swiftc -O -module-cache-path "$RENDER_DIR/module-cache" -emit-module -emit-library \
    -module-name WeatherCore "$RENDER_DIR"/Core/*.swift -o "$RENDER_DIR/libWeatherCore.dylib"
swiftc -O -module-cache-path "$RENDER_DIR/module-cache" -I "$RENDER_DIR" -L "$RENDER_DIR" \
    -lWeatherCore -Xlinker -rpath -Xlinker "$RENDER_DIR" \
    "$RENDER_DIR/WeatherViewBefore.swift" "$RENDER_DIR/WeatherView.swift" \
    "$RENDER_DIR/SnowmanRenderer.swift" "$RENDER_DIR/main.swift" -o "$RENDER_DIR/render-compare"
"$RENDER_DIR/render-compare" "$RENDER_DIR"
```

이 실행은 픽셀이 달라지면 실패하며, 결과를 출력 폴더의 `render-comparison.json`에 기록합니다. 창 시스템의 실제 합성·포커스·입력과 업데이트 기능은 이 성능 비교의 검증 대상이 아닙니다.
