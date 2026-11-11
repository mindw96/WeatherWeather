import AppKit
import Combine
import WeatherCore

final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    private var snowmanPositions: [String: SnowmanPosition]
    @Published var mode: WeatherMode { didSet { defaults.set(mode.rawValue, forKey: "mode") } }
    @Published var intensity: Double { didSet { defaults.set(intensity, forKey: "intensity") } }
    @Published var wind: Double { didSet { saveWind() } }
    @Published var windStrength: Double { didSet { saveWind() } }
    var effectiveWind: Double { wind * windStrength }
    @Published var movementReactionEnabled: Bool { didSet { defaults.set(movementReactionEnabled, forKey: "movementReactionEnabled") } }
    @Published var excludedApplications: [String: String] { didSet { defaults.set(excludedApplications, forKey: "excludedApplications") } }
    @Published var snowmanAppearance: SnowmanAppearance {
        didSet { if let data = try? JSONEncoder().encode(snowmanAppearance) { defaults.set(data, forKey: "snowmanAppearance") } }
    }
    @Published var globalShortcutEnabled: Bool { didSet { defaults.set(globalShortcutEnabled, forKey: "globalShortcutEnabled") } }
    @Published var globalShortcut: GlobalShortcut { didSet { defaults.set(globalShortcut.rawValue, forKey: "globalShortcut") } }
    @Published var showSettingsOnLaunch: Bool { didSet { defaults.set(showSettingsOnLaunch, forKey: "showSettingsOnLaunch") } }
    @Published var liveWeatherEnabled: Bool { didSet { defaults.set(liveWeatherEnabled, forKey: "liveWeatherEnabled") } }
    @Published var weatherCity: WeatherCity? {
        didSet {
            if let weatherCity, let data = try? JSONEncoder().encode(weatherCity) { defaults.set(data, forKey: "weatherCity") }
            else { defaults.removeObject(forKey: "weatherCity") }
        }
    }
    @Published var fairWeatherMode: WeatherMode { didSet { defaults.set(fairWeatherMode.rawValue, forKey: "fairWeatherMode") } }
    @Published var accumulation: Bool { didSet { defaults.set(accumulation, forKey: "accumulation") } }
    @Published var accumulateOnFullScreen: Bool { didSet { defaults.set(accumulateOnFullScreen, forKey: "accumulateOnFullScreen") } }
    @Published var showEffectsOnFocusedWindow: Bool { didSet { defaults.set(showEffectsOnFocusedWindow, forKey: "showEffectsOnFocusedWindow") } }
    @Published var showSnowman: Bool { didSet { defaults.set(showSnowman, forKey: "showSnowman") } }
    @Published var disabledDisplayIDs: Set<String> {
        didSet { defaults.set(disabledDisplayIDs.sorted(), forKey: "disabledDisplayIDs") }
    }
    @Published var paused = false {
        didSet { if !paused { pauseTimer?.invalidate(); pauseTimer = nil; pauseUntil = nil } }
    }
    @Published private(set) var pauseUntil: Date?
    private var pauseTimer: Timer?
    @Published var detectedWindows = 0
    @Published var clearVersion = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snowmanPositions = defaults.data(forKey: "snowmanPositions")
            .flatMap { try? JSONDecoder().decode([String: SnowmanPosition].self, from: $0) } ?? [:]
        mode = WeatherMode(rawValue: defaults.string(forKey: "mode") ?? "snow") ?? .snow
        intensity = defaults.object(forKey: "intensity") == nil ? 0.55 : min(1, max(0, defaults.double(forKey: "intensity")))
        let oldWind = Self.finite(defaults.object(forKey: "wind") as? Double ?? 0.12, range: -1...1, fallback: 0.12)
        let direction = Self.finite(defaults.object(forKey: "windDirection") as? Double ?? oldWind,
                                    range: -1...1, fallback: oldWind)
        wind = direction == 0 ? 0 : (direction < 0 ? -1 : 1)
        windStrength = Self.finite(defaults.object(forKey: "windStrength") as? Double ?? abs(oldWind), range: 0...1, fallback: 0.12)
        movementReactionEnabled = defaults.object(forKey: "movementReactionEnabled") as? Bool ?? true
        excludedApplications = defaults.dictionary(forKey: "excludedApplications") as? [String: String] ?? [:]
        snowmanAppearance = defaults.data(forKey: "snowmanAppearance").flatMap { try? JSONDecoder().decode(SnowmanAppearance.self, from: $0) } ?? .init()
        globalShortcutEnabled = defaults.bool(forKey: "globalShortcutEnabled")
        globalShortcut = GlobalShortcut(rawValue: defaults.string(forKey: "globalShortcut") ?? "") ?? .p
        showSettingsOnLaunch = defaults.object(forKey: "showSettingsOnLaunch") as? Bool ?? true
        liveWeatherEnabled = defaults.bool(forKey: "liveWeatherEnabled")
        weatherCity = defaults.data(forKey: "weatherCity").flatMap { try? JSONDecoder().decode(WeatherCity.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil }
        fairWeatherMode = WeatherMode(rawValue: defaults.string(forKey: "fairWeatherMode") ?? "") ?? .snow
        accumulation = defaults.object(forKey: "accumulation") == nil ? true : defaults.bool(forKey: "accumulation")
        accumulateOnFullScreen = defaults.bool(forKey: "accumulateOnFullScreen")
        showEffectsOnFocusedWindow = defaults.object(forKey: "showEffectsOnFocusedWindow") == nil ? true : defaults.bool(forKey: "showEffectsOnFocusedWindow")
        showSnowman = defaults.object(forKey: "showSnowman") == nil ? true : defaults.bool(forKey: "showSnowman")
        disabledDisplayIDs = Set(defaults.stringArray(forKey: "disabledDisplayIDs") ?? [])
    }

    private static func finite(_ value: Double, range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }

    private func saveWind() {
        defaults.set(wind, forKey: "windDirection")
        defaults.set(windStrength, forKey: "windStrength")
        defaults.set(effectiveWind, forKey: "wind") // Preserve the effective setting if an older app is reopened.
    }

    func pause(for seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        pauseTimer?.invalidate()
        paused = true
        pauseUntil = Date().addingTimeInterval(seconds)
        let timer = Timer(timeInterval: seconds, repeats: false) { [weak self] _ in self?.paused = false }
        RunLoop.main.add(timer, forMode: .common)
        pauseTimer = timer
    }

    deinit { pauseTimer?.invalidate() }

    func isDisplayEnabled(_ id: String) -> Bool { !disabledDisplayIDs.contains(id) }

    func setDisplayEnabled(_ enabled: Bool, for id: String) {
        guard !id.isEmpty else { return }
        if enabled { disabledDisplayIDs.remove(id) }
        else { disabledDisplayIDs.insert(id) }
    }

    func snowmanPosition(for displayID: String) -> SnowmanPosition? {
        snowmanPositions[displayID].map { SnowmanPosition(x: $0.x, y: $0.y) }
    }

    func setSnowmanPosition(_ position: SnowmanPosition, for displayID: String) {
        guard !displayID.isEmpty else { return }
        snowmanPositions[displayID] = SnowmanPosition(x: position.x, y: position.y)
        if let data = try? JSONEncoder().encode(snowmanPositions) {
            defaults.set(data, forKey: "snowmanPositions")
        }
    }
}
