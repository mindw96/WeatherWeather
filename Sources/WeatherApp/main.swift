import AppKit
import Combine
import SwiftUI
import WeatherCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences: Preferences
    var overlays: OverlayController?
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var subscriptions: Set<AnyCancellable> = []
    private let validationSuiteName: String?
    // Validation must not contact the update server or change the user's Sparkle preferences.
    lazy var updater = AppUpdater(enabled: validationSuiteName == nil)
    @MainActor lazy var weather = LiveWeatherService(networkEnabled: validationSuiteName == nil) { [weak self] mode in
        self?.preferences.mode = mode
    }
    lazy var login = LoginItemService(available: validationSuiteName == nil)
    let shortcuts = GlobalShortcutService()

    override init() {
        let validating = CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--render-previews")
            || CommandLine.arguments.contains("--validate-focus")
            || CommandLine.arguments.contains("--validate-snowman")
            || CommandLine.arguments.contains("--validate-features")
            || CommandLine.arguments.contains("--validate-weather-service")
        let suiteName = validating ? "org.windowweather.validation.\(UUID().uuidString)" : nil
        validationSuiteName = suiteName
        let defaults = suiteName.map { UserDefaults(suiteName: $0)! } ?? .standard
        preferences = Preferences(defaults: defaults)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if let index = CommandLine.arguments.firstIndex(of: "--validate-weather-service"), CommandLine.arguments.count > index + 1 {
            Task { @MainActor in
                await LiveWeatherValidation.run(to: CommandLine.arguments[index + 1])
                NSApp.terminate(nil)
            }
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--validate-features"), CommandLine.arguments.count > index + 1 {
            FeatureValidation.run(to: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--validate-snowman"), CommandLine.arguments.count > index + 1 {
            SnowmanValidation.run(to: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--validate-focus"), CommandLine.arguments.count > index + 1 {
            FocusedWindowValidation.run(to: CommandLine.arguments[index + 1])
            NSApp.terminate(nil)
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--smoke-test"), CommandLine.arguments.count > index + 1,
           Validation.blockGUIValidationIfNeeded(output: CommandLine.arguments[index + 1]) {
            NSApp.terminate(nil)
            return
        }
        if let index = CommandLine.arguments.firstIndex(of: "--render-previews"), CommandLine.arguments.count > index + 1 {
            Validation.renderPreviews(to: CommandLine.arguments[index + 1])
            preferences.detectedWindows = WindowTracker.windows().count
            showSettings()
            settingsWindow?.appearance = NSAppearance(named: .darkAqua)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                if let window = settingsWindow {
                    Validation.renderSettings(window: window, to: CommandLine.arguments[index + 1])
                }
                preferences.showEffectsOnFocusedWindow = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
                    if let window = settingsWindow {
                        Validation.renderSettings(window: window, to: CommandLine.arguments[index + 1],
                                                  filename: "settings-focus-hidden-preview.png")
                    }
                    NSApp.terminate(nil)
                }
            }
            return
        }
        // Keep a Dock entry so settings remain reachable when menu-bar space is limited.
        NSApp.setActivationPolicy(.regular)
        installApplicationMenu()
        overlays = OverlayController(preferences: preferences)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.isVisible = true
        Publishers.CombineLatest(preferences.$mode, preferences.$paused)
            .sink { [weak self] mode, paused in self?.refreshMenu(mode: mode, paused: paused) }
            .store(in: &subscriptions)
        if validationSuiteName == nil {
            shortcuts.onToggle = { [weak self] in self?.preferences.paused.toggle() }
            Publishers.CombineLatest(preferences.$globalShortcutEnabled, preferences.$globalShortcut)
                .sink { [weak self] enabled, shortcut in self?.shortcuts.configure(enabled: enabled, shortcut: shortcut) }
                .store(in: &subscriptions)
            Publishers.CombineLatest3(preferences.$liveWeatherEnabled, preferences.$weatherCity, preferences.$fairWeatherMode)
                .sink { [weak self] enabled, city, fallback in
                    self?.weather.configure(enabled: enabled, city: city, fallback: fallback)
                }.store(in: &subscriptions)
        }
        if let index = CommandLine.arguments.firstIndex(of: "--smoke-test"), CommandLine.arguments.count > index + 1 {
            Validation.smokeTest(delegate: self, output: CommandLine.arguments[index + 1])
        } else if preferences.showSettingsOnLaunch {
            showSettings()
        }
    }

    func refreshMenu(mode: WeatherMode, paused: Bool) {
        statusItem?.button?.image = NSImage(systemSymbolName: paused ? "pause.circle" : mode.symbol, accessibilityDescription: AppIdentity.displayName)
        statusItem?.button?.title = statusItem?.button?.image == nil ? String(AppIdentity.displayName.prefix(1)) : ""
        statusItem?.button?.toolTip = AppIdentity.displayName
        let menu = NSMenu()
        menu.addItem(withTitle: AppIdentity.displayName, action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        for (index, weather) in WeatherMode.allCases.enumerated() {
            let item = menu.addItem(withTitle: "\(weather.title) 표시", action: #selector(selectWeather(_:)), keyEquivalent: String(index + 1))
            item.representedObject = weather.rawValue
            item.state = mode == weather ? .on : .off
            item.image = NSImage(systemSymbolName: weather.symbol, accessibilityDescription: nil)
        }
        menu.addItem(withTitle: paused ? "다시 내리기" : "잠시 멈추기", action: #selector(togglePause), keyEquivalent: "p")
        menu.addItem(withTitle: "30분 동안 숨기기", action: #selector(pauseForThirtyMinutes), keyEquivalent: "")
        menu.addItem(withTitle: "쌓인 흔적 지우기", action: #selector(clear), keyEquivalent: "k")
        menu.addItem(.separator())
        menu.addItem(withTitle: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "종료", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items where item.action != nil { item.target = self }
        menu.insertItem(updater.menuItem(), at: menu.numberOfItems - 1)
        statusItem?.menu = menu
    }

    private func installApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = mainMenu.addItem(withTitle: AppIdentity.displayName, action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: AppIdentity.displayName)
        applicationItem.submenu = applicationMenu
        let settings = applicationMenu.addItem(withTitle: "설정…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        applicationMenu.addItem(updater.menuItem())
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "\(AppIdentity.displayName) 가리기", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = applicationMenu.addItem(withTitle: "다른 앱 가리기", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        applicationMenu.addItem(withTitle: "모두 보기", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "\(AppIdentity.displayName) 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let windowItem = mainMenu.addItem(withTitle: "윈도우", action: nil, keyEquivalent: "")
        let windowMenu = NSMenu(title: "윈도우")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "최소화", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "닫기", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "설정 열기…", action: #selector(showSettings), keyEquivalent: "")
        item.target = self
        return menu
    }

    @MainActor @objc func selectWeather(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String, let mode = WeatherMode(rawValue: rawValue) else { return }
        selectMode(mode)
    }
    @MainActor func selectMode(_ mode: WeatherMode) {
        preferences.mode = mode
        weather.manuallySelected(mode)
    }
    @objc func togglePause() { preferences.paused.toggle() }
    @objc func pauseForThirtyMinutes() { preferences.pause(for: 30 * 60) }
    @objc func clear() { overlays?.clear() }
    @objc func quit() { NSApp.terminate(nil) }

    @MainActor @objc func showSettings() {
        if settingsWindow == nil {
            let view = SettingsView(preferences: preferences, updater: updater, weather: weather, login: login,
                                    shortcuts: shortcuts, selectMode: { [weak self] in self?.selectMode($0) }) { [weak self] in self?.overlays?.clear() }
            let host = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: host)
            window.title = AppIdentity.displayName
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.collectionBehavior = [.moveToActiveSpace]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindow?.isMiniaturized == true { settingsWindow?.deminiaturize(nil) }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlays?.stop()
        if let validationSuiteName {
            UserDefaults(suiteName: validationSuiteName)?.removePersistentDomain(forName: validationSuiteName)
        }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
