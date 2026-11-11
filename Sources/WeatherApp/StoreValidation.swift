#if APP_STORE
import AppKit
import SwiftUI
import WeatherCore

@MainActor enum StoreValidation {
    static func liveWeather(to path: String) async {
        var applied: WeatherMode?
        let service = LiveWeatherService(automaticallyPolls: false) { applied = $0 }
        service.configure(enabled: true, city: nil, fallback: .snow)
        service.search("Seoul")
        let searchDeadline = Date().addingTimeInterval(25)
        while service.isSearching && Date() < searchDeadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let city = service.searchResults.first { $0.isValid }
        if let city {
            service.configure(enabled: true, city: city, fallback: .snow)
            let weatherDeadline = Date().addingTimeInterval(25)
            while service.isFetching && Date() < weatherDeadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        let checks = ["publicCitySearch": city != nil,
                      "currentWeatherDecoded": service.lastUpdated != nil,
                      "effectSelected": applied != nil]
        let report: [String: Any] = ["passed": checks.values.allSatisfy { $0 }, "checks": checks,
            "city": city?.name ?? "", "mode": applied?.rawValue ?? "", "status": service.status,
            "scope": "Sandbox product service; public Seoul sample, no device location or user preference changes."]
        service.configure(enabled: false, city: nil, fallback: .snow)
        write(report, to: path)
    }

    static func screenshots(to directory: String, delegate: AppDelegate) async {
        let frame = NSRect(x: 0, y: 0, width: 1280, height: 800)
        let canvas = StoreScreenshotCanvas(frame: frame)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = canvas
        window.appearance = NSAppearance(named: .darkAqua)
        let scene = WeatherView(frame: NSRect(x: 0, y: 0, width: 810, height: 800))
        scene.demoBackground = true
        scene.simulation.setSurfaces([
            Surface(id: 1, x: 60, y: 285, width: 360, cornerRadius: WindowTracker.estimatedCornerRadius),
            Surface(id: 2, x: 455, y: 410, width: 300, cornerRadius: WindowTracker.estimatedCornerRadius)
        ])
        scene.simulation.intensity = 0.65
        canvas.addSubview(scene)
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 34, weight: .semibold)
        title.textColor = .white
        title.frame = NSRect(x: 40, y: 716, width: 720, height: 48)
        canvas.addSubview(title)
        let caption = NSTextField(labelWithString: "쌓임쌓임 · 효과 미리보기")
        caption.textColor = .secondaryLabelColor
        caption.font = .systemFont(ofSize: 16)
        caption.frame = NSRect(x: 42, y: 680, width: 700, height: 28)
        canvas.addSubview(caption)
        let settings = SettingsView(preferences: delegate.preferences, updater: delegate.updater,
            weather: delegate.weather, login: delegate.login, shortcuts: delegate.shortcuts,
            selectMode: { delegate.preferences.mode = $0 }, clear: {})
        let host = NSHostingView(rootView: settings)
        host.frame = NSRect(x: 838, y: 24, width: 414, height: 752)
        host.setBoundsSize(NSSize(width: 450, height: 818))
        canvas.addSubview(host)
        window.orderFrontRegardless()
        var results: [[String: Any]] = []
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for mode in [WeatherMode.snow, .rain, .autumn, .fireflies, .stardust] {
                delegate.preferences.mode = mode
                delegate.preferences.wind = 0
                scene.simulation.mode = mode
                scene.simulation.reset()
                scene.simulation.wind = 0
                for _ in 0..<300 { scene.simulation.update(deltaTime: 0.1) }
                title.stringValue = mode.title
                try await Task.sleep(nanoseconds: 250_000_000)
                canvas.layoutSubtreeIfNeeded()
                scene.needsDisplay = true
                canvas.displayIfNeeded()
                guard let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) else { continue }
                canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
                guard let rendered = bitmap.cgImage,
                      let opaque = CGContext(data: nil, width: bitmap.pixelsWide, height: bitmap.pixelsHigh,
                          bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { continue }
                opaque.draw(rendered, in: CGRect(x: 0, y: 0, width: bitmap.pixelsWide, height: bitmap.pixelsHigh))
                guard let rgb = opaque.makeImage(),
                      let data = NSBitmapImageRep(cgImage: rgb).representation(using: .png, properties: [:]) else { continue }
                let name = "\(mode.rawValue)-app-store.png"
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name))
                let validSize = (bitmap.pixelsWide == 1280 && bitmap.pixelsHigh == 800)
                    || (bitmap.pixelsWide == 2560 && bitmap.pixelsHigh == 1600)
                results.append(["file": name, "width": bitmap.pixelsWide, "height": bitmap.pixelsHigh, "passed": validSize])
            }
        } catch { fputs("Store screenshots: \(error)\n", stderr) }
        window.close()
        write(["passed": results.count == 5 && results.allSatisfy { $0["passed"] as? Bool == true },
               "screenshots": results, "scope": "Product renderer preview and actual settings UI; no third-party window content captured."],
              to: URL(fileURLWithPath: directory).appendingPathComponent("screenshots.json").path)
    }

    private static func write(_ object: [String: Any], to path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        } catch { fputs("Store validation: \(error)\n", stderr) }
    }
}

private final class StoreScreenshotCanvas: NSView {
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        bounds.fill()
    }
}
#endif
