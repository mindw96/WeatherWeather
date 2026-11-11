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
        case .fireflies: return "반딧불"
        case .stardust: return "별가루"
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
        case .fireflies: return "lightbulb.fill"
        case .stardust: return "sparkles"
        }
    }

    var accent: NSColor {
        switch self {
        case .snow, .rain: return .systemCyan
        case .autumn: return .systemOrange
        case .cherryBlossom: return .systemPink
        case .bubbles: return .systemMint
        case .confetti: return .systemPurple
        case .fireflies: return .systemYellow
        case .stardust: return .systemOrange
        }
    }

    var accumulationLabel: String {
        switch self {
        case .rain: return "창 위에 빗물 고이기"
        case .bubbles: return "창 위에 비눗방울 머무르기"
        case .fireflies: return "창 위에 반딧불 머무르기"
        case .stardust: return "창 위에 별가루 반짝이기"
        default: return "창 위에 \(title) 쌓기"
        }
    }

}
