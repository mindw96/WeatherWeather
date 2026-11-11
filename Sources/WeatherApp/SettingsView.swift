import SwiftUI
import UniformTypeIdentifiers
import WeatherCore

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var updater: AppUpdater
    @ObservedObject var weather: LiveWeatherService
    @ObservedObject var login: LoginItemService
    @ObservedObject var shortcuts: GlobalShortcutService
    let selectMode: (WeatherMode) -> Void
    let clear: () -> Void
    @State private var screens = NSScreen.screens
    @State private var availableApps: [ApplicationChoice] = []

    private var hasSelectedDisplay: Bool {
        screens.contains { preferences.isDisplayEnabled(DisplayIdentity.key(for: $0)) }
    }

    var body: some View {
        ScrollView {
            content.padding(24)
        }
        .padding(.bottom, 24)
        .frame(width: 450, height: min(820, max(320, (screens.map { $0.visibleFrame.height }.min() ?? 900) - 100)))
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottomTrailing) {
            Text("버전 \(AppIdentity.version)")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.trailing, 24).padding(.bottom, 6)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = NSScreen.screens
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                Text(AppIdentity.displayName).font(.system(size: 26, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: preferences.mode.symbol)
                    .font(.system(size: 30)).symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(nsColor: preferences.mode.accent))
            }

            DemoView(mode: preferences.mode, intensity: preferences.intensity, wind: preferences.effectiveWind, accumulation: preferences.accumulation, showEffectsOnFocusedWindow: preferences.showEffectsOnFocusedWindow, showSnowman: preferences.showSnowman, snowmanAppearance: preferences.snowmanAppearance, movementReactionEnabled: preferences.movementReactionEnabled, paused: preferences.paused, clearVersion: preferences.clearVersion)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .topTrailing) {
                    Text("미리보기").font(.caption2).foregroundStyle(.white.opacity(0.5)).padding(10)
                }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 6) {
                ForEach(WeatherMode.allCases, id: \.self) { mode in
                    Toggle(isOn: Binding(
                        get: { preferences.mode == mode },
                        set: { if $0 { selectMode(mode) } }
                    )) {
                        Label(mode.title, systemImage: mode.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .toggleStyle(.button)
                    .tint(Color(nsColor: mode.accent))
                }
            }

            GroupBox("효과를 표시할 모니터") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(screens.enumerated()), id: \.element) { index, screen in
                        Toggle(isOn: Binding(
                            get: { preferences.isDisplayEnabled(DisplayIdentity.key(for: screen)) },
                            set: { preferences.setDisplayEnabled($0, for: DisplayIdentity.key(for: screen)) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(index + 1). \(screen.localizedName)")
                                    .lineLimit(1)
                                Text(displayDetails(screen, primary: index == 0))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .help(screen.localizedName)
                    }
                    Text(hasSelectedDisplay
                         ? "선택한 모니터에만 날씨 효과와 눈사람을 표시합니다."
                         : "선택한 모니터가 없어요. 표시할 모니터를 켜 주세요.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 15) {
                HStack {
                    Text("내리는 양").frame(width: 72, alignment: .leading)
                    Slider(value: $preferences.intensity, in: 0...1)
                    Text("\(Int(preferences.intensity * 100))%")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 38, alignment: .trailing)
                }
                HStack {
                    Text("바람 방향").frame(width: 72, alignment: .leading)
                    Picker("바람 방향", selection: $preferences.wind) {
                        Text("← 왼쪽").tag(-1.0)
                        Text("오른쪽 →").tag(1.0)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                HStack {
                    Text("바람 세기").frame(width: 72, alignment: .leading)
                    Slider(value: $preferences.windStrength, in: 0...1)
                    Text("\(Int(preferences.windStrength * 100))%")
                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 38, alignment: .trailing)
                }
                Toggle("창과 바람에 쌓인 효과가 반응", isOn: $preferences.movementReactionEnabled)
                    .toggleStyle(.switch)
                    .help("창을 움직이면 눈 조각이 떨어지고, 강한 바람에 쌓인 잎과 꽃잎이 다시 날립니다.")
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

            snowmanSettings
            excludedAppSettings
            desktopSettings
            LiveWeatherSettingsView(service: weather, enabled: $preferences.liveWeatherEnabled,
                                    city: $preferences.weatherCity, fallback: $preferences.fairWeatherMode)

            Divider()
            HStack {
                Circle().fill(preferences.paused || !hasSelectedDisplay ? .orange : .mint).frame(width: 7, height: 7)
                Text(!hasSelectedDisplay ? "선택한 모니터가 없어요" : preferences.paused ? "잠시 쉬는 중" : "\(preferences.detectedWindows)개 창을 따라 내리고 있어요")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("쌓인 흔적 지우기", action: clear).controlSize(.small)
            }
            HStack {
                Text("효과는 계정 없이 오프라인으로 작동합니다.\n날씨 연동·업데이트 확인에는 인터넷을 사용합니다.")
                    .font(.caption).foregroundStyle(.secondary).lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button {
                    preferences.paused.toggle()
                } label: {
                    Label(preferences.paused ? "다시 내리기" : "잠시 멈추기", systemImage: preferences.paused ? "play.fill" : "pause.fill")
                }.buttonStyle(.borderedProminent).tint(.teal)
            }
            if let until = preferences.pauseUntil {
                Text("\(until.formatted(date: .omitted, time: .shortened))에 자동으로 다시 내립니다.")
                    .font(.caption).foregroundStyle(.secondary)
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
    }

    private var snowmanSettings: some View {
        GroupBox("눈사람 꾸미기") {
            VStack(spacing: 10) {
                Picker("모자", selection: $preferences.snowmanAppearance.hat) {
                    ForEach(SnowmanColor.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Picker("목도리", selection: $preferences.snowmanAppearance.scarf) {
                    ForEach(SnowmanColor.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                HStack {
                    Text("크기")
                    Slider(value: $preferences.snowmanAppearance.scale, in: 0.6...1.5)
                    Text("\(Int(preferences.snowmanAppearance.scale * 100))%")
                        .monospacedDigit().frame(width: 42, alignment: .trailing)
                }
            }.padding(.vertical, 5)
        }.disabled(preferences.mode != .snow || !preferences.showSnowman)
    }

    private var excludedAppSettings: some View {
        GroupBox("효과를 숨길 앱") {
            VStack(alignment: .leading, spacing: 10) {
                Text("선택한 앱의 창 안과 창 위에 쌓인 효과를 숨깁니다.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(preferences.excludedApplications.keys.sorted(), id: \.self) { id in
                    HStack {
                        Text(preferences.excludedApplications[id] ?? id).lineLimit(1)
                        Spacer()
                        Button { preferences.excludedApplications.removeValue(forKey: id) } label: {
                            Image(systemName: "minus.circle")
                        }.buttonStyle(.borderless).accessibilityLabel("\(preferences.excludedApplications[id] ?? id) 제외 해제")
                    }
                }
                HStack {
                    Menu("실행 중인 앱 추가") {
                        ForEach(availableApps) { app in
                            Button(app.name) { preferences.excludedApplications[app.id] = app.name }
                                .disabled(preferences.excludedApplications[app.id] != nil)
                        }
                        Divider()
                        Button("목록 새로고침", action: refreshApps)
                    }
                    Button("앱 선택…", action: chooseApplication)
                }.controlSize(.small)
            }.padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: refreshApps)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in refreshApps() }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in refreshApps() }
    }

    private var desktopSettings: some View {
        GroupBox("빠른 제어와 시작") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("어디서나 단축키로 숨기기·복원", isOn: $preferences.globalShortcutEnabled)
                    .toggleStyle(.switch)
                Picker("단축키", selection: $preferences.globalShortcut) {
                    ForEach(GlobalShortcut.allCases, id: \.self) { Text($0.title).tag($0) }
                }.disabled(!preferences.globalShortcutEnabled)
                if let error = shortcuts.error { Text(error).font(.caption).foregroundStyle(.orange) }
                Button("30분 동안 숨기기") { preferences.pause(for: 30 * 60) }.controlSize(.small)
                Divider()
                Toggle("Mac 로그인 시 자동 실행", isOn: Binding(get: { login.enabled }, set: { enabled in
                    if login.setEnabled(enabled), enabled { preferences.showSettingsOnLaunch = false }
                })).toggleStyle(.switch)
                Toggle("시작할 때 설정창 열기", isOn: $preferences.showSettingsOnLaunch).toggleStyle(.switch)
                Text("자동 실행을 켜면 설정창 없이 시작합니다. Dock이나 메뉴 막대에서 다시 열 수 있어요.")
                    .font(.caption).foregroundStyle(.secondary)
                if login.needsApproval { Button("시스템 설정에서 자동 실행 허용", action: login.openSettings) }
                if let error = login.error { Text(error).font(.caption).foregroundStyle(.orange) }
            }.padding(.vertical, 5)
        }.onAppear { login.refresh() }
    }

    private func refreshApps() {
        var apps: [String: String] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { continue }
            apps[id] = app.localizedName ?? id
        }
        availableApps = apps.map { ApplicationChoice(id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "추가"
        panel.begin { response in
            guard response == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return }
            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.deletingPathExtension().lastPathComponent
            preferences.excludedApplications[id] = name
        }
    }

    private func displayDetails(_ screen: NSScreen, primary: Bool) -> String {
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let resolution = "\(CGDisplayPixelsWide(number)) × \(CGDisplayPixelsHigh(number))"
        return primary ? "\(resolution) · 주 디스플레이" : resolution
    }
}

private struct ApplicationChoice: Identifiable { let id: String; let name: String }

private struct DemoView: NSViewRepresentable {
    let mode: WeatherMode
    let intensity: Double
    let wind: Double
    let accumulation: Bool
    let showEffectsOnFocusedWindow: Bool
    let showSnowman: Bool
    let snowmanAppearance: SnowmanAppearance
    let movementReactionEnabled: Bool
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
        view.simulation.movementReactionEnabled = movementReactionEnabled
        view.snowmanAppearance = snowmanAppearance
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
