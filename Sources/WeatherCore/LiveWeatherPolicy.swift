import Foundation

public struct WeatherCity: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public let country: String?
    public let admin1: String?
    public let latitude: Double
    public let longitude: Double

    public init(id: Int, name: String, country: String? = nil, admin1: String? = nil,
                latitude: Double, longitude: Double) {
        self.id = id; self.name = name; self.country = country; self.admin1 = admin1
        self.latitude = latitude; self.longitude = longitude
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200
            && latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }

    public var displayName: String {
        [name, admin1, country].compactMap { $0 }.reduce(into: [String]()) {
            if !$1.isEmpty && !$0.contains($1) { $0.append($1) }
        }.joined(separator: ", ")
    }
}

public enum LiveWeatherError: Error, LocalizedError {
    case invalidResponse
    case staleResponse

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "날씨 응답을 확인할 수 없어요."
        case .staleResponse: return "최신 날씨 정보를 받지 못했어요."
        }
    }
}

public struct LiveWeatherSnapshot: Equatable, Sendable {
    public let observedAt: Date
    public let weatherCode: Int
    public let rain: Double
    public let showers: Double
    public let snowfall: Double

    public init(observedAt: Date, weatherCode: Int, rain: Double, showers: Double, snowfall: Double) {
        self.observedAt = observedAt; self.weatherCode = weatherCode
        self.rain = rain; self.showers = showers; self.snowfall = snowfall
    }

    public var isValid: Bool {
        Self.supportedCodes.contains(weatherCode)
            && [rain, showers, snowfall].allSatisfy { $0.isFinite && (0...1_000).contains($0) }
            && observedAt.timeIntervalSince1970.isFinite
    }

    public func isFresh(at now: Date) -> Bool {
        let age = now.timeIntervalSince(observedAt)
        return isValid && age >= -900 && age <= LiveWeatherPolicy.maximumAge
    }

    public var precipitationMode: WeatherMode? {
        guard isValid else { return nil }
        if snowfall > 0 || [71, 73, 75, 77, 85, 86].contains(weatherCode) { return .snow }
        if rain + showers > 0 || [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82].contains(weatherCode) {
            return .rain
        }
        return nil
    }

    public var conditionDescription: String {
        if let mode = precipitationMode { return mode == .snow ? "눈" : "비" }
        switch weatherCode {
        case 0, 1: return "맑음"
        case 2, 3: return "구름"
        case 45, 48: return "안개"
        case 95, 96, 97, 99: return "뇌우 · 강수 없음"
        default: return "기본 효과"
        }
    }

    public static func decode(_ data: Data, for city: WeatherCity, now: Date) throws -> Self {
        struct Response: Decodable {
            struct Current: Decodable {
                let time: Double
                let weather_code: Int
                let rain: Double
                let showers: Double
                let snowfall: Double
            }
            let latitude: Double
            let longitude: Double
            let current: Current
        }
        guard city.isValid, data.count <= 512_000 else { throw LiveWeatherError.invalidResponse }
        let response = try JSONDecoder().decode(Response.self, from: data)
        let longitudeDelta = abs(response.longitude - city.longitude)
        guard response.latitude.isFinite, response.longitude.isFinite,
              (-90...90).contains(response.latitude), (-180...180).contains(response.longitude),
              abs(response.latitude - city.latitude) <= 2,
              min(longitudeDelta, 360 - longitudeDelta) <= 2 else { throw LiveWeatherError.invalidResponse }
        let current = response.current
        let result = Self(observedAt: Date(timeIntervalSince1970: current.time), weatherCode: current.weather_code,
                          rain: current.rain, showers: current.showers, snowfall: current.snowfall)
        guard result.isValid else { throw LiveWeatherError.invalidResponse }
        guard result.isFresh(at: now) else { throw LiveWeatherError.staleResponse }
        return result
    }

    private static let supportedCodes: Set<Int> = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57,
                                                  61, 63, 65, 66, 67, 71, 73, 75, 77,
                                                  80, 81, 82, 85, 86, 95, 96, 97, 99]
}

public enum LiveWeatherPolicy {
    public static let refreshInterval: TimeInterval = 15 * 60
    public static let maximumAge: TimeInterval = 60 * 60
    public static let manualOverrideDuration: TimeInterval = 30 * 60

    /// nil keeps the user's manual choice while its temporary override is active.
    public static func mode(snapshot: LiveWeatherSnapshot?, fallback: WeatherMode,
                            now: Date, manualUntil: Date?) -> WeatherMode? {
        if let manualUntil, manualUntil > now { return nil }
        guard let snapshot, snapshot.isFresh(at: now) else { return fallback }
        return snapshot.precipitationMode ?? fallback
    }
}
