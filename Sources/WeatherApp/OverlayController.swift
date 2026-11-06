import AppKit
import Combine
import WeatherCore

final class OverlayController {
    struct Display {
        let id: String
        let screen: NSScreen
        let panel: WeatherPanel
        let view: WeatherView
        let snowman: SnowmanOverlay
    }
    private(set) var displays: [Display] = []
    let preferences: Preferences
    private var animationTimer: Timer?
    private var geometryTimer: Timer?
    private var subscriptions: Set<AnyCancellable> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private var lastFrame = ProcessInfo.processInfo.systemUptime
    private var asleep = false

    init(preferences: Preferences) {
        self.preferences = preferences
        rebuildDisplays()
        Publishers.CombineLatest4(preferences.$mode, preferences.$intensity, preferences.$wind, preferences.$accumulation)
            .sink { [weak self] mode, intensity, wind, accumulation in
                self?.displays.forEach {
                    $0.view.simulation.mode = mode
                    $0.view.simulation.intensity = intensity
                    $0.view.simulation.wind = wind
                    $0.view.simulation.accumulationEnabled = accumulation
                    $0.view.needsDisplay = true
                }
            }.store(in: &subscriptions)
        preferences.$paused.sink { [weak self] paused in self?.setRunning(!paused) }.store(in: &subscriptions)
        preferences.$disabledDisplayIDs.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                for display in self.displays where !self.preferences.isDisplayEnabled(display.id) {
                    display.view.simulation.reset()
                    display.view.simulation.setSurfaces([])
                    display.view.windowGeometry = []
                    display.view.hiddenFocusedWindow = nil
                }
                self.refreshSurfaces()
                self.setRunning(!self.preferences.paused)
            }.store(in: &subscriptions)
        // @Published emits before storage changes; read the updated policy on
        // the next main-run-loop turn so disabling it clears existing piles.
        preferences.$accumulateOnFullScreen.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSurfaces() }.store(in: &subscriptions)
        preferences.$showEffectsOnFocusedWindow.dropFirst().receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSurfaces() }.store(in: &subscriptions)
        Publishers.CombineLatest(preferences.$mode, preferences.$showSnowman)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSnowmen() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.rebuildDisplays() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in self?.setRunning(!(self?.preferences.paused ?? true)) }.store(in: &subscriptions)
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                     object: nil, queue: .main) { [weak self] _ in
            self?.refreshSurfaces()
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.asleep = true
                self?.setRunning(false)
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.asleep = false
                self?.refreshSurfaces()
                self?.setRunning(!(self?.preferences.paused ?? true))
            })
        }
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.displays.forEach { $0.view.simulation.clearAccumulation() }
            self?.refreshSurfaces()
        })
    }

    func rebuildDisplays() {
        displays.forEach { $0.snowman.close(); $0.panel.close() }
        displays = NSScreen.screens.enumerated().map { index, screen in
            let panel = WeatherPanel(screen: screen)
            let view = WeatherView(frame: NSRect(origin: .zero, size: screen.frame.size), seed: UInt64(index + 2026))
            view.simulation.mode = preferences.mode
            view.simulation.intensity = preferences.intensity
            view.simulation.wind = preferences.wind
            view.simulation.accumulationEnabled = preferences.accumulation
            view.showSnowman = false // Dedicated panel handles desktop dragging.
            panel.contentView = view
            panel.setFrame(screen.frame, display: false)
            return Display(id: DisplayIdentity.key(for: screen), screen: screen, panel: panel, view: view,
                           snowman: SnowmanOverlay(screen: screen, preferences: preferences))
        }
        refreshSurfaces()
        setRunning(!preferences.paused)
    }

    func refreshSurfaces(running: Bool? = nil) {
        let active = displays.filter { preferences.isDisplayEnabled($0.id) }
        guard !active.isEmpty else {
            if preferences.detectedWindows != 0 { preferences.detectedWindows = 0 }
            refreshSnowmen(running: running)
            return
        }
        let excluded = Set(displays.flatMap { [UInt32($0.panel.windowNumber), UInt32($0.snowman.panel.windowNumber)] })
        let windows = WindowTracker.windows(excluding: excluded)
        let focusedID = preferences.showEffectsOnFocusedWindow ? nil : WindowTracker.focusedWindowID(in: windows)
        var detectedWindowIDs = Set<UInt32>()
        // Harvest before removing off-display windows so a drag to another monitor
        // carries its local accumulation across. Floor state remains per display.
        let accumulated = active.flatMap { $0.view.simulation.piles }.filter { $0.surfaceID != 0 }
        let settled = active.flatMap { $0.view.simulation.settledParticles }.filter { $0.surfaceID != 0 }
        for display in active {
            let policy = WindowTracker.fullScreenPolicy(screen: display.screen)
            let local = WindowTracker.localWindows(windows, screen: display.screen).map { window in
                var window = window
                if policy.isScreenFilling(window) { window.cornerRadius = 0 }
                return window
            }
            detectedWindowIDs.formUnion(local.map(\.id))
            display.view.windowGeometry = local
            // Visibility only: leave collisions and existing piles intact so a
            // focus switch or re-enabling the option restores the scene naturally.
            display.view.hiddenFocusedWindow = FocusedWindowPolicy.hiddenWindow(
                in: local, focusedWindowID: focusedID,
                showEffectsOnFocusedWindow: preferences.showEffectsOnFocusedWindow
            )
            let surfaces = policy.surfaces(for: local, accumulateOnFullScreen: preferences.accumulateOnFullScreen)
            display.view.simulation.setSurfaces(surfaces)
            display.view.simulation.inheritAccumulation(from: accumulated)
            display.view.simulation.inheritSettledParticles(from: settled)
            display.view.needsDisplay = true
        }
        if preferences.detectedWindows != detectedWindowIDs.count { preferences.detectedWindows = detectedWindowIDs.count }
        refreshSnowmen(running: running)
    }

    private func refreshSnowmen(running: Bool? = nil) {
        for display in displays {
            display.snowman.update(running: (running ?? (!preferences.paused && !asleep)) && preferences.isDisplayEnabled(display.id),
                                   mode: preferences.mode, enabled: preferences.showSnowman,
                                   hiddenWindow: display.view.hiddenFocusedWindow)
        }
    }

    private func setRunning(_ requested: Bool) {
        animationTimer?.invalidate()
        geometryTimer?.invalidate()
        animationTimer = nil
        geometryTimer = nil
        let running = requested && !asleep
        displays.forEach {
            running && preferences.isDisplayEnabled($0.id) ? $0.panel.orderFrontRegardless() : $0.panel.orderOut(nil)
        }
        refreshSnowmen(running: running)
        guard running, displays.contains(where: { preferences.isDisplayEnabled($0.id) }) else { return }
        lastFrame = ProcessInfo.processInfo.systemUptime
        let fps = ProcessInfo.processInfo.isLowPowerModeEnabled ? 20.0 : 30.0
        let animation = Timer(timeInterval: 1 / fps, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            let delta = min(0.1, max(0, now - self.lastFrame))
            self.lastFrame = now
            for display in self.displays where self.preferences.isDisplayEnabled(display.id) {
                display.view.simulation.update(deltaTime: delta)
                display.view.needsDisplay = true
                display.snowman.updateHitTesting()
            }
        }
        animation.tolerance = 0.003
        RunLoop.main.add(animation, forMode: .common)
        animationTimer = animation
        let geometry = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.refreshSurfaces() }
        geometry.tolerance = 0.03
        RunLoop.main.add(geometry, forMode: .common)
        geometryTimer = geometry
        refreshSurfaces(running: running)
    }

    func clear() {
        preferences.clearVersion += 1
        displays.forEach {
            $0.view.simulation.clearAccumulation()
            $0.view.needsDisplay = true
        }
    }

    func stop() {
        animationTimer?.invalidate()
        geometryTimer?.invalidate()
        displays.forEach { $0.snowman.close(); $0.panel.close() }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
    }
}
