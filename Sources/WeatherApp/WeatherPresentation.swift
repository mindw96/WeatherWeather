import AppKit
import WeatherCore

extension WeatherMode {
    var title: String {
        switch self {
        case .snow: return "눈"
        case .rain: return "비"
        case .autumn: return "낙엽"
        case .cherryBlossom: return "벚꽃"
        }
    }

    var symbol: String {
        switch self {
        case .snow: return "cloud.snow.fill"
        case .rain: return "cloud.rain.fill"
        case .autumn: return "leaf.fill"
        case .cherryBlossom: return "camera.macro"
        }
    }

    var accent: NSColor {
        switch self {
        case .snow, .rain: return .systemCyan
        case .autumn: return .systemOrange
        case .cherryBlossom: return .systemPink
        }
    }

    var accumulationLabel: String {
        self == .rain ? "창 위에 빗물 고이기" : "창 위에 \(title) 쌓기"
    }

}
