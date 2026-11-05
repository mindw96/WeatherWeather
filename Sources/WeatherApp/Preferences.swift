import AppKit
import Combine
import WeatherCore

final class Preferences: ObservableObject {
    private let defaults: UserDefaults
    private var snowmanPositions: [String: SnowmanPosition]
    @Published var mode: WeatherMode { didSet { defaults.set(mode.rawValue, forKey: "mode") } }
    @Published var intensity: Double { didSet { defaults.set(intensity, forKey: "intensity") } }
    @Published var wind: Double { didSet { defaults.set(wind, forKey: "wind") } }
    @Published var accumulation: Bool { didSet { defaults.set(accumulation, forKey: "accumulation") } }
    @Published var accumulateOnFullScreen: Bool { didSet { defaults.set(accumulateOnFullScreen, forKey: "accumulateOnFullScreen") } }
    @Published var showEffectsOnFocusedWindow: Bool { didSet { defaults.set(showEffectsOnFocusedWindow, forKey: "showEffectsOnFocusedWindow") } }
    @Published var showSnowman: Bool { didSet { defaults.set(showSnowman, forKey: "showSnowman") } }
    @Published var paused = false
    @Published var detectedWindows = 0
    @Published var clearVersion = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snowmanPositions = defaults.data(forKey: "snowmanPositions")
            .flatMap { try? JSONDecoder().decode([String: SnowmanPosition].self, from: $0) } ?? [:]
        mode = WeatherMode(rawValue: defaults.string(forKey: "mode") ?? "snow") ?? .snow
        intensity = defaults.object(forKey: "intensity") == nil ? 0.55 : min(1, max(0, defaults.double(forKey: "intensity")))
        wind = defaults.object(forKey: "wind") == nil ? 0.12 : min(1, max(-1, defaults.double(forKey: "wind")))
        accumulation = defaults.object(forKey: "accumulation") == nil ? true : defaults.bool(forKey: "accumulation")
        accumulateOnFullScreen = defaults.bool(forKey: "accumulateOnFullScreen")
        showEffectsOnFocusedWindow = defaults.object(forKey: "showEffectsOnFocusedWindow") == nil ? true : defaults.bool(forKey: "showEffectsOnFocusedWindow")
        showSnowman = defaults.object(forKey: "showSnowman") == nil ? true : defaults.bool(forKey: "showSnowman")
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
