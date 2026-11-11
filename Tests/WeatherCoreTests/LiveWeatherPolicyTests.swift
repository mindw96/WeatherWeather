import XCTest
@testable import WeatherCore

final class LiveWeatherPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let city = WeatherCity(id: 1, name: "서울", country: "대한민국", latitude: 37.5665, longitude: 126.978)

    private func snapshot(code: Int, rain: Double = 0, showers: Double = 0, snowfall: Double = 0,
                          age: TimeInterval = 0) -> LiveWeatherSnapshot {
        LiveWeatherSnapshot(observedAt: now.addingTimeInterval(-age), weatherCode: code,
                            rain: rain, showers: showers, snowfall: snowfall)
    }

    func testSnowAndFreezingRainUseWeatherCodesWithoutTemperatureGuessing() {
        for code in [71, 73, 75, 77, 85, 86] { XCTAssertEqual(snapshot(code: code).precipitationMode, .snow) }
        for code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82] {
            XCTAssertEqual(snapshot(code: code).precipitationMode, .rain)
        }
        XCTAssertEqual(snapshot(code: 61, rain: 1, snowfall: 0.1).precipitationMode, .snow)
    }

    func testDryThunderstormAndFairWeatherUseChosenFallback() {
        for code in [0, 1, 2, 3, 45, 48, 95, 96, 97, 99] {
            XCTAssertEqual(LiveWeatherPolicy.mode(snapshot: snapshot(code: code), fallback: .cherryBlossom,
                                                  now: now, manualUntil: nil), .cherryBlossom)
        }
        XCTAssertEqual(snapshot(code: 95, showers: 0.1).precipitationMode, .rain)
    }

    func testManualChoiceExpiresAtThirtyMinutesAndStaleDataFallsBack() {
        let snow = snapshot(code: 73)
        let expiry = now.addingTimeInterval(LiveWeatherPolicy.manualOverrideDuration)
        XCTAssertNil(LiveWeatherPolicy.mode(snapshot: snow, fallback: .autumn, now: now, manualUntil: expiry))
        XCTAssertEqual(LiveWeatherPolicy.mode(snapshot: snow, fallback: .autumn, now: expiry, manualUntil: expiry), .snow)
        XCTAssertEqual(LiveWeatherPolicy.mode(snapshot: snapshot(code: 73, age: 3_601), fallback: .bubbles,
                                              now: now, manualUntil: nil), .bubbles)
        XCTAssertEqual(LiveWeatherPolicy.mode(snapshot: nil, fallback: .confetti, now: now, manualUntil: nil), .confetti)
    }

    func testInvalidAndFutureDataCannotDriveEffects() {
        XCTAssertFalse(snapshot(code: 123).isValid)
        XCTAssertFalse(snapshot(code: 0, rain: -.infinity).isValid)
        XCTAssertFalse(snapshot(code: 0, rain: -0.1).isValid)
        XCTAssertFalse(snapshot(code: 0, snowfall: .nan).isValid)
        XCTAssertFalse(snapshot(code: 0, age: -901).isFresh(at: now))
        XCTAssertTrue(snapshot(code: 0, age: 3_600).isFresh(at: now))
    }

    func testResponseDecodingChecksCoordinatesTimeAndNullValues() throws {
        func payload(latitude: Double = 37.57, time: Double = 1_800_000_000, rain: String = "0") -> Data {
            Data("""
            {"latitude":\(latitude),"longitude":126.98,"current":{
            "time":\(time),"weather_code":61,"rain":\(rain),"showers":0,"snowfall":0}}
            """.utf8)
        }
        XCTAssertEqual(try LiveWeatherSnapshot.decode(payload(), for: city, now: now).precipitationMode, .rain)
        XCTAssertThrowsError(try LiveWeatherSnapshot.decode(payload(latitude: 0), for: city, now: now))
        XCTAssertThrowsError(try LiveWeatherSnapshot.decode(payload(time: 1_799_996_399), for: city, now: now))
        XCTAssertThrowsError(try LiveWeatherSnapshot.decode(payload(rain: "null"), for: city, now: now))
    }

    func testCityPersistenceAndValidation() throws {
        XCTAssertEqual(try JSONDecoder().decode(WeatherCity.self, from: JSONEncoder().encode(city)), city)
        XCTAssertTrue(city.isValid)
        XCTAssertFalse(WeatherCity(id: 1, name: " ", latitude: 37, longitude: 127).isValid)
        XCTAssertFalse(WeatherCity(id: 1, name: "서울", latitude: 91, longitude: 127).isValid)
        XCTAssertFalse(WeatherCity(id: 1, name: "서울", latitude: 37, longitude: .nan).isValid)
        XCTAssertEqual(WeatherCity(id: 1, name: "서울", country: "대한민국", admin1: "서울",
                                  latitude: 37, longitude: 127).displayName, "서울, 대한민국")
    }
}
