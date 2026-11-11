import AppKit
import Combine
import WeatherCore

@MainActor
final class LiveWeatherService: ObservableObject {
    @Published private(set) var status = "자동 날씨 연동이 꺼져 있어요."
    @Published private(set) var isFetching = false
    @Published private(set) var isSearching = false
    @Published private(set) var searchResults: [WeatherCity] = []
    @Published private(set) var searchError: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var manualUntil: Date?

    private let networkEnabled: Bool
    private let session: URLSession
    private let now: () -> Date
    private let automaticallyPolls: Bool
    private let onMode: (WeatherMode) -> Void
    private var enabled = false
    private var city: WeatherCity?
    private var fallback: WeatherMode = .snow
    private var snapshot: LiveWeatherSnapshot?
    private var lastError: String?
    private var lastAttempt: Date?
    private var lastAppliedMode: WeatherMode?
    private var generation = 0
    private var searchGeneration = 0
    private var weatherTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var timer: Timer?
    private var wakeObserver: AnyCancellable?

    init(networkEnabled: Bool = true, session: URLSession? = nil,
         now: @escaping () -> Date = Date.init, automaticallyPolls: Bool = true,
         onMode: @escaping (WeatherMode) -> Void) {
        self.networkEnabled = networkEnabled
        if let session { self.session = session }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 15
            configuration.timeoutIntervalForResource = 20
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            self.session = URLSession(configuration: configuration)
        }
        self.now = now
        self.automaticallyPolls = automaticallyPolls
        self.onMode = onMode
        wakeObserver = NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in Task { @MainActor in self?.tick() } }
    }

    func configure(enabled: Bool, city: WeatherCity?, fallback: WeatherMode) {
        let validCity = city.flatMap { $0.isValid ? $0 : nil }
        let changed = self.enabled != enabled || self.city != validCity
        self.fallback = fallback
        guard changed else { evaluate(); return }
        generation += 1
        searchGeneration += 1
        weatherTask?.cancel(); weatherTask = nil
        searchTask?.cancel(); searchTask = nil
        timer?.invalidate(); timer = nil
        self.enabled = enabled
        self.city = validCity
        snapshot = nil; lastUpdated = nil; lastAttempt = nil; lastError = nil
        searchResults = []; searchError = nil
        manualUntil = nil; lastAppliedMode = nil
        isFetching = false; isSearching = false
        evaluate()
        guard enabled, validCity != nil, networkEnabled else { return }
        if automaticallyPolls {
            let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            timer.tolerance = 5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        refresh()
    }

    /// Call after applying a choice from the weather buttons or menu.
    func manuallySelected(_ mode: WeatherMode) {
        guard enabled else { return }
        manualUntil = now().addingTimeInterval(LiveWeatherPolicy.manualOverrideDuration)
        lastAppliedMode = mode
        evaluate()
    }

    func resumeAutomatic() {
        manualUntil = nil
        evaluate()
        refresh(force: true)
    }

    func refresh(force: Bool = false) {
        guard enabled, networkEnabled, let city, city.isValid, weatherTask == nil else { return }
        let time = now()
        if !force, let lastAttempt, time.timeIntervalSince(lastAttempt) >= 0,
           time.timeIntervalSince(lastAttempt) < LiveWeatherPolicy.refreshInterval { return }
        lastAttempt = time
        isFetching = true
        let token = generation
        let url = Self.weatherURL(for: city)
        weatherTask = Task { [weak self, session] in
            do {
                let data = try await Self.fetch(url, session: session)
                try Task.checkCancellation()
                guard let self, self.generation == token, self.enabled, self.city == city else { return }
                let observation = try LiveWeatherSnapshot.decode(data, for: city, now: self.now())
                self.snapshot = observation
                self.lastUpdated = observation.observedAt
                self.lastError = nil
                self.isFetching = false
                self.weatherTask = nil
                self.evaluate()
            } catch {
                guard !Task.isCancelled, let self, self.generation == token, self.enabled else { return }
                self.lastError = (error as? LiveWeatherError)?.errorDescription ?? "날씨에 연결하지 못했어요."
                self.isFetching = false
                self.weatherTask = nil
                self.evaluate()
            }
        }
    }

    func search(_ query: String) {
        searchGeneration += 1
        searchTask?.cancel(); searchTask = nil
        isSearching = false; searchResults = []; searchError = nil
        guard enabled, networkEnabled else { return }
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...80).contains(query.count) else {
            searchError = "도시 이름을 2~80자로 입력해 주세요."
            return
        }
        let token = generation, searchToken = searchGeneration
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [URLQueryItem(name: "name", value: query),
                                 URLQueryItem(name: "count", value: "8"),
                                 URLQueryItem(name: "language", value: "ko"),
                                 URLQueryItem(name: "format", value: "json")]
        let url = components.url!
        isSearching = true
        searchTask = Task { [weak self, session] in
            do {
                let data = try await Self.fetch(url, session: session)
                try Task.checkCancellation()
                struct Response: Decodable { let results: [WeatherCity]? }
                let decoded = try JSONDecoder().decode(Response.self, from: data).results ?? []
                guard let self, self.enabled, self.generation == token, self.searchGeneration == searchToken else { return }
                var seen = Set<Int>()
                self.searchResults = Array(decoded.filter { $0.isValid && seen.insert($0.id).inserted }.prefix(8))
                self.searchError = self.searchResults.isEmpty ? "찾은 도시가 없어요. 영문 이름으로도 검색해 보세요." : nil
                self.isSearching = false
                self.searchTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.enabled,
                      self.generation == token, self.searchGeneration == searchToken else { return }
                self.searchError = "도시를 검색하지 못했어요. 잠시 후 다시 시도해 주세요."
                self.isSearching = false
                self.searchTask = nil
            }
        }
    }

    func cancelSearch() {
        searchGeneration += 1
        searchTask?.cancel(); searchTask = nil
        isSearching = false; searchResults = []; searchError = nil
    }

    private func tick() {
        evaluate()
        refresh()
    }

    private func evaluate() {
        guard enabled else { status = "자동 날씨 연동이 꺼져 있어요."; return }
        guard city != nil else { status = "연동할 도시를 선택해 주세요."; return }
        guard networkEnabled else { status = "검증 실행에서는 날씨에 연결하지 않습니다."; return }
        let time = now()
        if let until = manualUntil, until <= time { manualUntil = nil }
        if let mode = LiveWeatherPolicy.mode(snapshot: snapshot, fallback: fallback, now: time, manualUntil: manualUntil),
           mode != lastAppliedMode {
            lastAppliedMode = mode
            onMode(mode)
        }
        if manualUntil != nil {
            status = "직접 고른 효과를 30분 동안 유지합니다."
        } else if let snapshot, snapshot.isFresh(at: time) {
            status = lastError == nil ? "\(snapshot.conditionDescription) · 자동 반영 중"
                : "연결 지연 · 마지막 날씨를 잠시 유지합니다."
        } else if let lastError {
            status = "\(lastError) 기본 효과로 표시합니다."
        } else if snapshot != nil {
            status = "날씨 정보가 1시간 이상 지나 기본 효과로 표시합니다."
        } else {
            status = "날씨 확인 전까지 기본 효과로 표시합니다."
        }
    }

    private static func weatherURL(for city: WeatherCity) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [URLQueryItem(name: "latitude", value: String(city.latitude)),
                                 URLQueryItem(name: "longitude", value: String(city.longitude)),
                                 URLQueryItem(name: "current", value: "weather_code,rain,showers,snowfall"),
                                 URLQueryItem(name: "timeformat", value: "unixtime"),
                                 URLQueryItem(name: "timezone", value: "GMT"),
                                 URLQueryItem(name: "forecast_days", value: "1")]
        return components.url!
    }

    private static func fetch(_ url: URL, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url?.scheme == "https", http.url?.host == url.host,
              data.count <= 512_000 else { throw LiveWeatherError.invalidResponse }
        return data
    }

    deinit {
        timer?.invalidate()
        weatherTask?.cancel()
        searchTask?.cancel()
    }
}
