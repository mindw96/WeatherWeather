# 0.6.1 둥근 경계의 Core 비용 확인

2026-11-06, Apple Silicon에서 `swiftc -O`로 **현재의 동일한 Core 코드**에 반지름 0과 26을 전달하여 비교했습니다. 이전 배포 버전과의 비교가 아닙니다. 창마다 늘어난 높이 샘플과 곡면 충돌 계산이 뚜렷한 병목을 만드는지 확인하기 위한 제한된 합성 부하입니다.

3840×2160pt 화면, 너비 650pt인 창 10개, 여섯 효과, 강도 1, 바람 0.15, seed 17을 사용했습니다. 각 조건에서 30Hz 시뮬레이션 900프레임을 먼저 계산한 다음 3,000프레임을 측정했습니다. 같은 창 정보를 6프레임마다 전달했으며 평면/곡면 순서를 교대해 3회씩 측정했습니다. 총 높이 샘플은 평면 1,100개, 곡면 3,260개입니다. 곡면 변경에 따라 실제 입자의 충돌과 최종 상태는 달라집니다.

| 효과 | 반지름 0 | 반지름 26 | 추가 시간 |
| --- | ---: | ---: | ---: |
| 눈 | 0.0606ms | 0.0681ms | 0.0074ms |
| 비 | 0.0341ms | 0.0448ms | 0.0107ms |
| 낙엽 | 0.0660ms | 0.0725ms | 0.0065ms |
| 벚꽃 | 0.0952ms | 0.1025ms | 0.0073ms |
| 비눗방울 | 0.0551ms | 0.0614ms | 0.0063ms |
| 색종이 | 0.0990ms | 0.1071ms | 0.0082ms |

표는 **시뮬레이션 한 프레임당 시간의 3회 중간값**입니다. 이 부하에서는 곡면에 따른 추가 시간이 0.0063~0.0107ms였습니다. 전체 앱 CPU·배터리, AppKit/Core Graphics 렌더링, 창 추적, Window Server 합성 비용은 측정하지 않았습니다. 다른 빌드와 GUI 검증이 같은 Mac에서 진행 중이었으므로 작은 상대 차이를 일반적인 성능 보장으로 해석하지 않습니다.

[측정 소스](core-benchmark.swift)와 [36개 원시 표본·중간값·환경·소스 SHA-256](core-benchmark.json)을 보관했습니다. 각 실행은 입자 상한, 높이의 유효성, 같은 조건의 반복 실행에서 최종 개수의 일치를 검사합니다.

저장소 루트에서 재현할 수 있습니다. 별도 임시 디렉터리의 바이너리와 모듈 캐시를 사용합니다.

```sh
CURVES_PERF_DIR="$(mktemp -d /private/tmp/window-weather-curves-perf.XXXXXX)"
cp Sources/WeatherCore/WeatherSimulation.swift "$CURVES_PERF_DIR/WeatherSimulation.swift"
cp docs/releases/0.6.1/performance/core-benchmark.swift "$CURVES_PERF_DIR/benchmark.swift"
swiftc -O -module-cache-path "$CURVES_PERF_DIR/module-cache" \
  "$CURVES_PERF_DIR/WeatherSimulation.swift" "$CURVES_PERF_DIR/benchmark.swift" \
  -o "$CURVES_PERF_DIR/benchmark"
"$CURVES_PERF_DIR/benchmark" > "$CURVES_PERF_DIR/raw.json"
```
