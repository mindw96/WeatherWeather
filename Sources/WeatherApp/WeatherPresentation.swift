import AppKit
import WeatherCore

extension WeatherMode {
    var title: String {
        switch self {
        case .snow: return "눈"
        case .rain: return "비"
        case .autumn: return "낙엽"
        case .cherryBlossom: return "벚꽃"
        case .bubbles: return "비눗방울"
        case .confetti: return "색종이"
        }
    }

    var symbol: String {
        switch self {
        case .snow: return "cloud.snow.fill"
        case .rain: return "cloud.rain.fill"
        case .autumn: return "leaf.fill"
        case .cherryBlossom: return "camera.macro"
        case .bubbles: return "bubbles.and.sparkles"
        case .confetti: return "party.popper.fill"
        }
    }

    var accent: NSColor {
        switch self {
        case .snow, .rain: return .systemCyan
        case .autumn: return .systemOrange
        case .cherryBlossom: return .systemPink
        case .bubbles: return .systemMint
        case .confetti: return .systemPurple
        }
    }

    var accumulationLabel: String {
        switch self {
        case .rain: return "창 위에 빗물 고이기"
        case .bubbles: return "창 위에 비눗방울 머무르기"
        default: return "창 위에 \(title) 쌓기"
        }
    }

}
