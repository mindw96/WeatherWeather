import SwiftUI
import WeatherCore

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var updater: AppUpdater
    let clear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text(AppIdentity.displayName).font(.system(size: 26, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: preferences.mode.symbol)
                    .font(.system(size: 30)).symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(nsColor: preferences.mode.accent))
            }

            DemoView(mode: preferences.mode, intensity: preferences.intensity, wind: preferences.wind, accumulation: preferences.accumulation, showEffectsOnFocusedWindow: preferences.showEffectsOnFocusedWindow, showSnowman: preferences.showSnowman, paused: preferences.paused, clearVersion: preferences.clearVersion)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    Text("미리보기").font(.caption2).foregroundStyle(.white.opacity(0.5)).padding(10)
                }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(WeatherMode.allCases, id: \.self) { mode in
                    Toggle(isOn: Binding(
                        get: { preferences.mode == mode },
                        set: { if $0 { preferences.mode = mode } }
                    )) {
                        Label(mode.title, systemImage: mode.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .toggleStyle(.button)
                    .tint(Color(nsColor: mode.accent))
                }
            }

            VStack(spacing: 15) {
                HStack {
                    Text("내리는 양").frame(width: 72, alignment: .leading)
                    Slider(value: $preferences.intensity, in: 0...1)
                    Text("\(Int(preferences.intensity * 100))%")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Text("바람").frame(width: 72, alignment: .leading)
                    Image(systemName: "arrow.left").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $preferences.wind, in: -1...1)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                }
                Toggle(preferences.mode.accumulationLabel, isOn: $preferences.accumulation)
                    .toggleStyle(.switch)
                Toggle("눈사람 표시", isOn: $preferences.showSnowman)
                    .toggleStyle(.switch)
                    .disabled(preferences.mode != .snow)
                    .help("눈 모드에서 눈사람을 표시합니다. 마우스로 끌어 위치를 옮길 수 있습니다.")
                Toggle("전체 화면에서도 쌓기", isOn: $preferences.accumulateOnFullScreen)
                    .toggleStyle(.switch)
                    .disabled(!preferences.accumulation)
                    .help("화면을 가득 채운 창과 최대화한 창에도 효과가 쌓입니다.")
                VStack(alignment: .leading, spacing: 5) {
                    Toggle("사용 중인 창에도 효과 표시", isOn: $preferences.showEffectsOnFocusedWindow)
                        .toggleStyle(.switch)
                        .help("모든 효과에 적용됩니다. 쌓인 효과는 지우지 않고 잠시 숨깁니다.")
                    Text("끄면 작업 중인 창 안의 효과와 창 위에 쌓인 효과를 숨깁니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
            HStack {
                Circle().fill(preferences.paused ? .orange : .mint).frame(width: 7, height: 7)
                Text(preferences.paused ? "잠시 쉬는 중" : "\(preferences.detectedWindows)개 창을 따라 내리고 있어요")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("쌓인 흔적 지우기", action: clear).controlSize(.small)
            }
            HStack {
                Text("날씨 효과는 계정 없이, 인터넷 없이.\nDock과 메뉴 막대에서 바꿀 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    preferences.paused.toggle()
                } label: {
                    Label(preferences.paused ? "다시 내리기" : "잠시 멈추기", systemImage: preferences.paused ? "play.fill" : "pause.fill")
                }.buttonStyle(.borderedProminent).tint(.teal)
            }

            Divider()
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Toggle("자동 업데이트 확인", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: updater.setAutomaticallyChecksForUpdates
                    ))
                    .toggleStyle(.switch)
                    .disabled(!updater.isConfigured)
                    Spacer()
                    Button("업데이트 확인…", action: updater.checkForUpdates)
                        .controlSize(.small)
                        .disabled(!updater.canCheckForUpdates)
                }
                Text(updater.isConfigured
                     ? "새 버전을 하루에 한 번 확인합니다. 설치는 직접 선택해 주세요."
                     : "이 빌드에서는 업데이트 확인을 사용할 수 없습니다.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottomTrailing) {
            Text("버전 \(AppIdentity.version)")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.trailing, 24).padding(.bottom, 6)
        }
    }
}

private struct DemoView: NSViewRepresentable {
    let mode: WeatherMode
    let intensity: Double
    let wind: Double
    let accumulation: Bool
    let showEffectsOnFocusedWindow: Bool
    let showSnowman: Bool
    let paused: Bool
    let clearVersion: Int

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WeatherView {
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 402, height: 160))
        view.demoBackground = true
        view.simulation.setSurfaces([
            Surface(id: 1, x: 30, y: 105, width: 180, cornerRadius: WindowTracker.estimatedCornerRadius),
            Surface(id: 2, x: 233, y: 75, width: 145, cornerRadius: WindowTracker.estimatedCornerRadius),
            Surface(id: 0, x: 0, y: 159, width: 402)
        ])
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ view: WeatherView, context: Context) {
        view.simulation.mode = mode
        view.simulation.intensity = intensity
        view.simulation.wind = wind
        view.simulation.accumulationEnabled = accumulation
        if view.showSnowman != showSnowman {
            view.showSnowman = showSnowman
            view.needsDisplay = true
        }
        let hiddenWindow = showEffectsOnFocusedWindow ? nil : WindowGeometry(id: 2, x: 233, y: 75, width: 145, height: 85)
        if view.hiddenFocusedWindow != hiddenWindow {
            view.hiddenFocusedWindow = hiddenWindow
            view.needsDisplay = true
        }
        if context.coordinator.clearVersion != clearVersion {
            view.simulation.clearAccumulation()
            view.needsDisplay = true
            context.coordinator.clearVersion = clearVersion
        }
        if context.coordinator.lastMode != mode {
            for _ in 0..<240 { view.simulation.update(deltaTime: 0.1) }
            context.coordinator.lastMode = mode
            view.needsDisplay = true
        }
        context.coordinator.setPaused(paused)
    }

    static func dismantleNSView(_ view: WeatherView, coordinator: Coordinator) { coordinator.timer?.invalidate() }

    final class Coordinator {
        weak var view: WeatherView?
        var timer: Timer?
        var clearVersion = -1
        var lastMode: WeatherMode?
        func setPaused(_ paused: Bool) {
            if paused { timer?.invalidate(); timer = nil; return }
            guard timer == nil else { return }
            let timer = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
                guard let view = self?.view, view.window?.isVisible == true else { return }
                view.simulation.update(deltaTime: 1.0 / 24.0)
                view.needsDisplay = true
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        deinit { timer?.invalidate() }
    }
}
