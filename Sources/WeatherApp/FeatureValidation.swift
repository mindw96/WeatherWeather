import AppKit
import Carbon
import WeatherCore

enum FeatureValidation {
    @MainActor static func run(to path: String) {
        let name = "org.windowweather.features.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        var checks: [String: Bool] = [:]
        defaults.set(0.0, forKey: "wind")
        let calm = Preferences(defaults: defaults)
        checks["legacyCalmWindSelectsCenter"] = calm.wind == 0 && calm.effectiveWind == 0
        defaults.set(-0.38, forKey: "wind")
        let settings = Preferences(defaults: defaults)
        checks["legacyWindPreservesDirectionAndMagnitude"] = settings.wind == -1 && abs(settings.effectiveWind + 0.38) < 0.000001
        checks["newNetworkAndHotkeyFeaturesAreOptIn"] = !settings.liveWeatherEnabled && !settings.globalShortcutEnabled
        settings.windStrength = 0.8
        settings.wind = 1
        let reloaded = Preferences(defaults: defaults)
        checks["independentWindSettingsSurviveReload"] = reloaded.wind == 1 && reloaded.windStrength == 0.8
        checks["legacyAppReadsEffectiveWind"] = defaults.double(forKey: "wind") == 0.8
        settings.wind = 0
        checks["centerStopsWindWithoutDiscardingStrength"] = settings.effectiveWind == 0
            && settings.windStrength == 0.8 && defaults.double(forKey: "wind") == 0
        let centered = Preferences(defaults: defaults)
        checks["centerSelectionSurvivesReload"] = centered.wind == 0
            && centered.windStrength == 0.8 && centered.effectiveWind == 0
        settings.wind = -1
        checks["directionRestoresSavedStrength"] = settings.effectiveWind == -0.8
        settings.excludedApplications = ["org.example.editor": "Editor", "org.example.video": "Video"]
        checks["excludedAppsPersistByBundleID"] = Preferences(defaults: defaults).excludedApplications == settings.excludedApplications
        settings.excludedApplications.removeValue(forKey: "org.example.editor")
        checks["removingOneExclusionPreservesOthers"] = Preferences(defaults: defaults).excludedApplications == ["org.example.video": "Video"]
        settings.movementReactionEnabled = false
        settings.showSettingsOnLaunch = false
        settings.globalShortcut = .space
        checks["desktopOptionsSurviveReload"] = !Preferences(defaults: defaults).movementReactionEnabled
            && !Preferences(defaults: defaults).showSettingsOnLaunch && Preferences(defaults: defaults).globalShortcut == .space
        let city = WeatherCity(id: 1835848, name: "Seoul", latitude: 37.5665, longitude: 126.978)
        settings.weatherCity = city
        settings.fairWeatherMode = .stardust
        checks["cityAndFallbackPersist"] = Preferences(defaults: defaults).weatherCity == city
            && Preferences(defaults: defaults).fairWeatherMode == .stardust
        settings.weatherCity = nil
        checks["cityCanBeRemoved"] = Preferences(defaults: defaults).weatherCity == nil
        settings.pause(for: 0.03)
        checks["timedPauseHidesEffects"] = settings.paused && settings.pauseUntil != nil
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        checks["timedPauseResumes"] = !settings.paused && settings.pauseUntil == nil
        settings.pause(for: 30)
        settings.paused = false
        checks["manualResumeCancelsTimer"] = settings.pauseUntil == nil
        defaults.set(Double.nan, forKey: "windStrength")
        checks["invalidSavedWindIsFinite"] = Preferences(defaults: defaults).effectiveWind.isFinite
        defaults.set(Double.nan, forKey: "windDirection")
        checks["invalidSavedDirectionFallsBackToLegacyWind"] = Preferences(defaults: defaults).wind == -1
        defaults.set(8.0, forKey: "windDirection")
        defaults.set(2.0, forKey: "windStrength")
        let clamped = Preferences(defaults: defaults)
        checks["savedWindDirectionAndStrengthAreBounded"] = clamped.wind == 1 && clamped.windStrength == 1
        let service = LiveWeatherService(networkEnabled: false) { _ in }
        service.configure(enabled: true, city: city, fallback: .snow)
        service.search("Seoul")
        service.refresh(force: true)
        checks["validationCannotStartWeatherNetwork"] = !service.isFetching && !service.isSearching && service.lastUpdated == nil
        let hotkey = GlobalShortcutService()
        var received = false
        hotkey.onToggle = { received = true }
        hotkey.configure(enabled: true, shortcut: .s)
        checks["nativeHotkeyRegistered"] = hotkey.registered
        let collision = GlobalShortcutService()
        collision.configure(enabled: true, shortcut: .s)
        checks["nativeHotkeyConflictReported"] = !collision.registered && collision.error != nil
        var event: EventRef?
        if CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), GetCurrentEventTime(), 0, &event) == noErr,
           let event {
            var identifier = EventHotKeyID(signature: 0x57575448, id: 1)
            SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              MemoryLayout<EventHotKeyID>.size, &identifier)
            SendEventToEventTarget(event, GetApplicationEventTarget())
            ReleaseEvent(event)
        }
        checks["nativeHotkeyCallbackDelivered"] = received
        hotkey.configure(enabled: false, shortcut: .s)
        collision.configure(enabled: true, shortcut: .s)
        checks["nativeHotkeyReleasedForReuse"] = collision.registered
        collision.configure(enabled: false, shortcut: .s)
        let report: [String: Any] = ["passed": checks.values.allSatisfy { $0 }, "checks": checks,
                                    "note": "Isolated preferences, timers, temporary native hotkey registration and app-local event delivery. Does not change login items or send physical keyboard input; no live weather requests."]
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        } catch { fputs("Feature validation failed: \(error)\n", stderr) }
    }
}
