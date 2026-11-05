# Koi 눈·비 효과 벤치마킹 분석

분석일: 2026-11-05 (Asia/Seoul)

대상: 사용자가 지정한 `/Applications/Koi.app` 및 첨부 이미지 2장
목적: 창 위로 눈·비가 내리고 창 경계와 상호작용하는 기능을 독립 구현할 때 필요한 구조와 요구사항 파악

## 결론

설치된 Koi는 Swift/AppKit 기반 macOS 네이티브 앱입니다. 날씨 관련 클래스는 **제어기 → 화면별 창/프레임 루프 → 시뮬레이션 → 렌더러**로 나뉘어 있습니다. 눈에는 적설 높이·가림·흘러내림을 나타내는 메타데이터가 있고, 비에는 낙하 입자·물방울·파문·번개를 나타내는 메타데이터가 있습니다. Metal 관련 import와 렌더러 상태가 있어 GPU 렌더링을 사용하는 구조로 강하게 추정됩니다.

이 결과는 배포된 앱의 **정적 메타데이터 관찰**입니다. Koi를 실행하거나 함수 호출을 추적하지 않았으므로 실제 실행 순서, 프레임률, 충돌 공식, 권한 요구 시점까지 확인한 것은 아닙니다. 독립 앱은 아래의 동작 요구사항을 구현하며, Koi의 코드·셰이더·아이콘·배경 이미지·음원은 가져오지 않습니다.

## 대상 식별

| 항목 | 관찰 결과 | 근거 |
| --- | --- | --- |
| 앱 이름 | Koi | E1 |
| Bundle ID | `com.koiscribe.koi` | E1 |
| 버전 / 빌드 | `4.3.0` / `55` | E1 |
| 최소 macOS | `14.0` 선언 | E1 |
| 실행 형태 | `LSUIElement = true` 선언 | E1 |
| 실행 파일 | `Contents/MacOS/Koi` | E1, L1 |
| 아키텍처 | Mach-O Universal, arm64 + x86_64 | L1 |
| 실행 파일 SHA-256 | `8f66a563bb75c25220e3862888e8156adf71b8fc68788f2e5a4cf47c078999cb` | L1 |
| Info.plist SHA-256 | `560ef643df50897c5badff29efb70fb9b490c9c40b2f538bb7e357c6058296d3` | L1 |

해시는 분석 당시 파일에 대한 값입니다. 앱 업데이트 이후에는 같은 버전명이라도 해시를 다시 비교해야 합니다. REA 리소스 세션 자체는 실행 파일 해시를 바인딩하지 않으며, 위 실행 파일 해시는 별도의 로컬 관찰입니다.

## 근거 목록과 재현 범위

| ID | 수단 / 파일 | 범위와 한계 |
| --- | --- | --- |
| E1 | REA `open_bundle_resources` → `inspect_plist`; Evidence ID `ev_679bd367b4468e98d6f7ad3eade35c4542e3bfb8f47bc52a375253d5b103d99a` | 번들의 plist 선언 관찰. 실행 동작이나 바이너리 분석 결과가 아님 |
| L1 | `docs/evidence/koi-local-metadata.json`; 관찰 ID `LOCAL-KOI-METADATA-2026-11-05` | 로컬 `file`, `otool`, `nm`, `strings`, SHA-256 및 plist 파서. REA Evidence ID로 간주하지 않음 |
| V1 | 사용자가 제공한 눈 스크린샷 | 여러 창의 윗변에 흰 적설층이 보임. 시계열·창 이동 동작은 확인 불가 |
| V2 | 사용자가 제공한 비 스크린샷 | 화면 위에 세로 빗줄기가 보임. 한 장만으로 물웅덩이·파문·충돌을 입증할 수 없음 |

E1 원본은 [REA 리소스 Evidence](docs/evidence/koi-rea-resource-evidence.json)에 저장했습니다. L1은 [로컬 메타데이터 수집기](docs/evidence/collect-koi-metadata.py)로 재현할 수 있습니다. 수집기는 Koi를 실행하지 않으며, 관련 클래스의 필드 선언·import·기능 문구만 저장합니다. 코드 본문이나 그래픽 리소스를 복사하지 않습니다.

초기 `open_binary` 호출은 자동 승인 검토에서 분석 제공자의 외부 전송 가능성이 불명확하다는 이유로 거절되었습니다. 설정을 읽어 REA가 로컬 Node stdio 프로세스임을 확인했지만, 거절된 심층 분석 호출을 반복하거나 우회하지 않았습니다. 대신 승인된 리소스 전용 REA 세션과 macOS 로컬 정적 도구를 사용했습니다. 이 분석에서는 디컴파일을 수행하지 않았습니다. 리소스 Evidence를 내보낸 뒤 REA 세션을 종료했습니다.

## 관찰된 기능과 구조

### 사용자에게 보이는 동작

- **눈:** 첨부 이미지에서 창의 윗변에 눈이 쌓인 모습을 확인했습니다. 배포 바이너리의 기능 문구도 창과 Dock에 쌓이는 눈을 설명합니다. [V1, L1]
- **비:** 배포 바이너리의 기능 문구는 창 위에서 튀는 빗방울과 간헐적인 번개를 설명합니다. `RainField`의 `droplets`, `ripples`, `strikes` 필드도 이 설명과 일치합니다. [L1]
- **종료 진입점:** 배포 문구에는 노치의 눈송이 버튼으로 눈 효과를 멈춘다는 설명이 있습니다. 실제 버튼 동작은 실행 관찰하지 않았습니다. [L1]

사용자의 “쌓이는” 요구는 첫 구현에서 **눈은 적설층, 비는 얕은 물막·충돌 물방울·파문**으로 해석합니다. 비의 지속적인 물 높이 증가가 Koi의 기능이라는 근거는 확보하지 못했습니다. 물막의 누적·배수는 새 앱의 독립적인 제품 선택입니다.

### 정적 클래스 메타데이터

아래의 클래스 이름과 필드 이름은 arm64 슬라이스의 Objective-C/Swift 메타데이터에서 직접 관찰했습니다. 역할 설명은 이름과 관련 import를 종합한 **추론**입니다. 복구된 소스 코드나 완전한 타입 정보가 아닙니다. [L1]

| 관찰 클래스 | 관련 필드 예시 | 추론되는 역할 |
| --- | --- | --- |
| `SnowController` | `screens`, `observers`, `ticker`, `polledAt`, `movedAt`, `spaceChangedAt`, `dockShelf`, `lastFrames`, `asleep`, `saving`, `powerReadAt` | 화면별 효과 수명 관리, 창/Space 변경 반영, Dock 경계, 절전 상태 처리 |
| `SnowScreen` | `frame`, `window`, `loop`, `share`, `shown` | 화면별 오버레이 창과 실행 루프 |
| `SnowLoop` | `link`, `fall`, `screen`, `primaryTop`, `lock`, `lastFrame` | 디스플레이에 맞춘 업데이트 및 좌표 변환 |
| `Snowfall`, `Rainfall` | `field`, `renderer`, `frames` | 시뮬레이션 상태와 렌더링 상태 분리 |
| `SnowField` | `ground`, `ledges`, `ledgeList`, `flakes`, `settles`, `landings`, `grains`, `puffs`, `reduceMotion` | 눈 입자의 낙하·표면 충돌·정착·추가 입자 효과 |
| `SnowDrift` | `heights`, `bed`, `visible`, `occluders`, `spill`, `velocity`, `capacity`, `cornerRadius`, `depth`, `opensAtEnds` | 표면별 적설 높이와 가림, 끝부분 흘러내림, 이동 반응 |
| `SnowRenderer` | `device`, `queue`, `flakes`, `falling`, `drifts` | 낙하 입자와 적설층 렌더링 |
| `SnowRenderer.Frames` | `free`, `heights`, `sprites`, `flakes`, `next` | 여러 프레임의 GPU 입력 버퍼 관리 가능성 |
| `RainField` | `drops`, `droplets`, `ripples`, `ledges`, `reduceMotion`, `strikes`, `nextStrike` | 비 낙하, 충돌 물방울, 파문, 번개 타이밍 |
| `RainRenderer` | `device`, `queue`, `strokes`, `ripples`, `flash` | 빗줄기·파문·섬광 렌더링 |

특히 `SnowDrift.heights`는 표면을 가로 방향의 여러 높이로 표현하는 모델과 잘 맞습니다. 그러나 실제 자료형, 샘플 간격, 보간법과 눈의 질량 보존 방식은 확인되지 않았습니다. 따라서 새 앱의 높이 배열 방식은 이 구조를 참고한 독립 설계로 기록합니다.

### 창 감지 및 렌더링 API

다음 import를 관찰했습니다. **import 존재는 해당 기능에서의 실제 호출을 입증하지 않습니다.** Koi는 날씨 외에 여러 기능을 가진 앱이므로 호출 경로가 확인되지 않은 API를 날씨 전용으로 단정하지 않습니다. [L1]

| 관찰 항목 | 설명 가능한 기능 | 확인되지 않은 점 |
| --- | --- | --- |
| `CGWindowListCopyWindowInfo`, `kCGWindowBounds`, `kCGWindowNumber`, `kCGWindowLayer`, `kCGWindowAlpha`, `kCGWindowIsOnscreen` | 창 목록·위치·레이어·가시성 필터링 | 날씨 제어기에서 쓰는 조건과 주기 |
| `AXObserverCreate`, `AXObserverAddNotification`, `AXUIElementCopyAttributeValue` | 접근성 기반 창 변화 관찰 및 UI 정보 조회 | 날씨 기능의 접근성 권한 의존 여부 |
| `CGPreflightScreenCaptureAccess`, `CGRequestScreenCaptureAccess` | 화면 기록 권한 확인/요청 | 다른 화면·녹화 기능용일 수 있음. 날씨가 이 권한을 요구하는지는 미확인 |
| `MTLCreateSystemDefaultDevice`, `CAMetalLayer`, `CAMetalDisplayLink`, `MTLRenderPipelineDescriptor` | Metal 렌더링 및 프레임 동기화 | 실제 프레임률·장치 미지원 fallback |
| `AppKit`, `SwiftUI`, `CoreGraphics`, `QuartzCore`, `Metal` framework | 네이티브 UI/오버레이/렌더링 | 각 프레임워크의 날씨 기능 내 정확한 책임 |

## 새 앱에 적용할 설계

여기는 Koi의 확인된 구현이 아니라 **독립 구현안**입니다. 상세 진행 상태는 [PLAN.md](PLAN.md)를 따릅니다.

1. 메뉴 막대 앱에서 눈/비, 강도, 바람, 시작/중지와 누적 초기화를 제공합니다. 계정·로그인·원격 서버 없이 로컬에서 실행합니다.
2. 모니터마다 투명 오버레이 창을 만들고 마우스 입력을 통과시킵니다. 다른 앱의 창 선택과 텍스트 입력을 방해하지 않아야 합니다.
3. 창의 사각형과 Z 순서를 읽어 윗변의 **실제로 노출된 구간**을 계산합니다. 가려진 창 위에 적설선이 비치지 않도록 앞쪽 창의 사각형을 제외합니다.
4. 눈 입자의 이전 위치와 다음 위치 사이에서 표면을 가로지르는지 계산합니다. 충돌한 눈은 해당 창의 국소 좌표에 적설 높이를 더합니다. 높이에는 상한을 두고 인접 구간으로 완만하게 퍼뜨립니다.
5. 비가 표면에 닿으면 짧은 수명의 물방울과 파문을 만듭니다. 물막을 제공할 경우 상한과 배수·증발을 두어 화면을 덮지 않게 합니다.
6. 창 이동·크기 변경·닫기·최소화와 화면/Space 변경을 반영합니다. 창 ID와 로컬 표면 좌표를 보존해 누적 상태를 추적합니다.
7. 시뮬레이션은 OS API와 분리합니다. macOS의 창 수집기와 렌더러를 Windows 구현으로 교체할 수 있게 좌표·표면·입자 상태의 계약을 명확히 둡니다.
8. 눈·비 상태 변화, 겹치는 창의 표면 계산, 큰 시간 간격, 창 제거, 누적 상한을 자동 검증합니다. 클릭 통과와 실제 Space/Dock/다중 모니터 동작은 별도 수동 검증 대상으로 둡니다.

Windows는 macOS API를 그대로 가져갈 수 없습니다. 플랫폼별 창 열거·투명 오버레이·DPI·Z 순서 어댑터를 별도로 만들어야 합니다. Swift 핵심 모델을 즉시 공통 바이너리로 재사용할지, 이후 휴대성이 높은 언어로 옮길지는 첫 macOS 버전의 품질과 성능 검증 후 결정합니다. 현재 분석만으로 Windows 지원이 완성되었다고 보지 않습니다.

## 질문별 완료 상태

| 조사 질문 | 상태 | 답 / 남은 범위 |
| --- | --- | --- |
| 대상 앱의 버전과 기술 기반은 무엇인가? | 확인 | plist, Mach-O 및 Swift/AppKit/Metal 선언 확인 |
| 눈·비 기능이 각각 분리되어 있는가? | 확인 | 별도 Field/Renderer와 공통 controller/loop 관련 클래스 확인 |
| 창 위에 어떻게 쌓이는가? | 부분 확인 | 적설, 표면, 높이, 가림 관련 구조 확인. 충돌·누적 공식은 미확인 |
| 비가 창과 상호작용하는가? | 부분 확인 | 기능 문구와 droplets/ripples/ledges 메타데이터 확인. 실제 동작은 미관찰 |
| 창 이동·화면 변경·절전 처리가 있는가? | 부분 확인 | 대응 필드 이름 확인. 동작 정확도와 전환 조건은 미확인 |
| 로그인·네트워크 없이 같은 핵심 기능을 만들 수 있는가? | 독립 설계상 가능 | 화면 geometry와 로컬 입자 렌더링으로 구성 가능. Koi 로그인 정책을 변경하거나 우회할 필요 없음 |
| 성능과 권한 조건은 무엇인가? | 미확인 | Koi 런타임 미실행. 새 앱에서 권한 미부여·CPU/GPU 비용·배터리 영향을 별도로 확인해야 함 |

분석은 첫 기능의 독립 구현을 위한 범위까지 마쳤습니다. Koi 전체 앱, 인증/결제 구조, 네트워크, 사용자 저장 데이터, 정확한 원본 알고리즘은 조사하지 않았습니다.
