import Foundation
import WeatherCore

/// This protocol belongs only to the validation session; no live request is made.
private final class WeatherValidationURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    private static var requestCount = 0
    private static var returnsFailure = false
    static let timestamp: Double = 1_800_000_000

    static var requests: Int {
        lock.lock(); defer { lock.unlock() }
        return requestCount
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        requestCount = 0; returnsFailure = false
    }

    static func failRequests() {
        lock.lock(); defer { lock.unlock() }
        returnsFailure = true
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requestCount += 1
        let failure = Self.returnsFailure
        Self.lock.unlock()
        guard let url = request.url,
              let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        func value(_ name: String) -> String { query.first { $0.name == name }?.value ?? "" }
        let data: Data
        if url.host == "geocoding-api.open-meteo.com" {
            data = Data("""
            {"results":[{"id":1,"name":"서울","country":"대한민국","latitude":37.5,"longitude":127}]}
            """.utf8)
        } else {
            let latitude = value("latitude"), longitude = value("longitude")
            let code = latitude == "38.0" ? 73 : 61
            data = Data("""
            {"latitude":\(latitude),"longitude":\(longitude),"current":{"time":\(Self.timestamp),
            "weather_code":\(code),"rain":0,"showers":0,"snowfall":0}}
            """.utf8)
        }
        let response = HTTPURLResponse(url: url, statusCode: failure ? 503 : 200, httpVersion: nil, headerFields: nil)!
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.04) { [self] in
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    // Deliberately deliver late replies to exercise cancellation and generation checks.
    override func stopLoading() {}
}

enum LiveWeatherValidation {
    @MainActor
    static func run(to path: String) async {
        WeatherValidationURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WeatherValidationURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        var time = Date(timeIntervalSince1970: WeatherValidationURLProtocol.timestamp)
        var modes: [WeatherMode] = []
        let service = LiveWeatherService(session: session, now: { time }, automaticallyPolls: false) { modes.append($0) }
        let city = WeatherCity(id: 1, name: "서울", latitude: 37.5, longitude: 127)
        let nextCity = WeatherCity(id: 2, name: "도시 B", latitude: 38, longitude: 127)
        var checks: [String: Bool] = [:]
        func waitForReply() async { try? await Task.sleep(nanoseconds: 150_000_000) }
        func finishRequest() async {
            for _ in 0..<100 {
                if !service.isFetching && !service.isSearching { return }
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        func requestStarted(after count: Int) async -> Bool {
            for _ in 0..<100 {
                if WeatherValidationURLProtocol.requests > count { return true }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
            return false
        }

        service.configure(enabled: false, city: city, fallback: .autumn)
        service.refresh(force: true); service.search("서울")
        await waitForReply()
        checks["disabledMakesNoRequests"] = WeatherValidationURLProtocol.requests == 0 && modes.isEmpty

        service.configure(enabled: true, city: city, fallback: .autumn)
        await finishRequest()
        checks["validRainApplied"] = modes.last == .rain && service.lastUpdated == time && !service.isFetching
        let count = WeatherValidationURLProtocol.requests
        service.refresh()
        await waitForReply()
        checks["automaticRefreshIsThrottled"] = WeatherValidationURLProtocol.requests == count

        service.manuallySelected(.bubbles)
        let modeCount = modes.count
        service.refresh(force: true)
        await finishRequest()
        checks["networkResponsePreservesManualChoice"] = modes.count == modeCount && service.manualUntil != nil
        time = time.addingTimeInterval(1_800)
        service.configure(enabled: true, city: city, fallback: .autumn)
        checks["manualChoiceExpires"] = modes.last == .rain && service.manualUntil == nil

        time = time.addingTimeInterval(1_801)
        service.configure(enabled: true, city: city, fallback: .autumn)
        checks["oldObservationFallsBack"] = modes.last == .autumn && service.status.contains("1시간")

        let beforeDisable = WeatherValidationURLProtocol.requests
        service.configure(enabled: true, city: nextCity, fallback: .confetti)
        let pendingWeatherStarted = await requestStarted(after: beforeDisable)
        service.configure(enabled: false, city: nextCity, fallback: .confetti)
        let disabledCount = modes.count
        await waitForReply()
        checks["disableCancelsPendingWeather"] = pendingWeatherStarted && modes.count == disabledCount && service.lastUpdated == nil && !service.isFetching

        time = Date(timeIntervalSince1970: WeatherValidationURLProtocol.timestamp)
        let beforeCityChange = WeatherValidationURLProtocol.requests
        service.configure(enabled: true, city: city, fallback: .autumn)
        let oldCityStarted = await requestStarted(after: beforeCityChange)
        service.configure(enabled: true, city: nextCity, fallback: .autumn)
        await finishRequest()
        checks["oldCityResponseCannotOverrideNewCity"] = oldCityStarted && modes.last == .snow && service.lastUpdated == time

        service.search("서울")
        await finishRequest()
        checks["geocodingReturnsValidatedCity"] = service.searchResults.count == 1 && service.searchResults[0].isValid
        let beforeSearchDisable = WeatherValidationURLProtocol.requests
        service.search("서울")
        let pendingSearchStarted = await requestStarted(after: beforeSearchDisable)
        service.configure(enabled: false, city: nextCity, fallback: .autumn)
        await waitForReply()
        checks["disableCancelsSearch"] = pendingSearchStarted && service.searchResults.isEmpty && !service.isSearching

        WeatherValidationURLProtocol.failRequests()
        service.configure(enabled: true, city: city, fallback: .confetti)
        await finishRequest()
        checks["HTTPFailureUsesFallbackAndExplains"] = modes.last == .confetti && service.status.contains("기본 효과") && !service.isFetching

        let before = WeatherValidationURLProtocol.requests
        var appliedInValidation = false
        let offline = LiveWeatherService(networkEnabled: false, session: session, automaticallyPolls: false) { _ in appliedInValidation = true }
        offline.configure(enabled: true, city: city, fallback: .snow)
        offline.search("서울"); offline.refresh(force: true)
        await waitForReply()
        checks["validationMakesNoRequests"] = before == WeatherValidationURLProtocol.requests && !appliedInValidation
        service.configure(enabled: false, city: nil, fallback: .snow)

        let report: [String: Any] = ["checks": checks, "passed": checks.values.allSatisfy { $0 },
                                   "network": "Session-scoped URLProtocol fixtures only; no live API requests."]
        do {
            let destination = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: destination)
        } catch {
            fputs("Weather service validation report failed: \(error)\n", stderr)
        }
    }
}
