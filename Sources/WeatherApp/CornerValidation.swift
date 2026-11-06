import AppKit
import WeatherCore

/// Synthetic offscreen checks; no pixels from other apps are captured.
enum CornerValidation {
    static func run(to directory: String) {
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        var checks: [String: Bool] = [:]
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for mode in WeatherMode.allCases {
                let view = fixture(mode: mode, radius: 26)
                let raster = try render(view)
                let prefix = mode.rawValue
                let pile = view.simulation.piles[0]
                checks["\(prefix)NoFloatingStripAtLeftCorner"] = alphaSum(raster, in: CGRect(x: 31, y: 43, width: 5, height: 9)) == 0
                checks["\(prefix)NoFloatingStripAtRightCorner"] = alphaSum(raster, in: CGRect(x: 204, y: 43, width: 5, height: 9)) == 0
                for localX in [4.0, 176.0] {
                    let base = pile.baselineY(at: localX)
                    checks["\(prefix)FollowsCornerAt\(Int(localX))"] = alphaSum(raster, in: CGRect(x: pile.x + localX - 2, y: base - 8, width: 4, height: 9)) > 0
                }
                if !mode.hasSettledParticles {
                    checks["\(prefix)NoFlatUndersideBridge"] = alphaSum(raster, in: CGRect(x: 31, y: 50, width: 4, height: 5)) == 0
                    checks["\(prefix)NoFillBelowCurve"] = alphaSum(raster, in: CGRect(x: 33, y: 75, width: 4, height: 5)) == 0
                    let square = try render(fixture(mode: mode, radius: 0))
                    checks["\(prefix)SquareEdgeRemainsFlat"] = alphaSum(square, in: CGRect(x: 31, y: 48, width: 5, height: 2)) > 0
                }
                var covered = view.simulation.surfaces[0]
                covered.segments = []
                view.simulation.setSurfaces([covered])
                checks["\(prefix)CoveredEdgeHidden"] = alphaSum(try render(view), in: view.bounds) == 0
                view.simulation.setSurfaces([Surface(id: 7, x: 30, y: 50, width: 180, cornerRadius: 26)])
                view.hiddenFocusedWindow = WindowGeometry(id: 7, x: 30, y: 50, width: 180, height: 80)
                checks["\(prefix)FocusedPileHidden"] = alphaSum(try render(view), in: view.bounds) == 0
            }
            for (label, radius) in [("before", 26.0), ("after", WindowTracker.estimatedCornerRadius)] {
                let bitmap = try render(fixture(mode: .snow, radius: radius), scale: 3, background: true)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "CornerValidation", code: 2)
                }
                try png.write(to: output.appendingPathComponent("corner-\(label).png"))
            }
            try writeReport(checks, to: output)
        } catch {
            try? writeReport(checks, to: output, error: error.localizedDescription)
            fputs("Corner validation failed: \(error)\n", stderr)
        }
    }

    private static func fixture(mode: WeatherMode, radius: Double) -> WeatherView {
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        view.showSnowman = false
        view.simulation.mode = mode
        view.simulation.setSurfaces([Surface(id: 7, x: 30, y: 50, width: 180, cornerRadius: radius)])
        if mode.hasSettledParticles {
            let size = mode == .confetti ? 8.0 : 10.0
            view.simulation.inheritSettledParticles(from: [4.0, 176.0].enumerated().map { index, x in
                SettledParticle(id: UInt64(index + 1), mode: mode, surfaceID: 7, position: x / 180,
                                offsetY: 3, size: size, rotation: 0, variant: index, life: 5)
            })
        } else {
            var pile = view.simulation.piles[0]
            pile.heights = Array(repeating: mode == .snow ? 4 : 2, count: pile.heights.count)
            view.simulation.inheritAccumulation(from: [pile])
        }
        return view
    }

    private static func render(_ view: WeatherView, scale: Int = 1, background: Bool = false) throws -> NSBitmapImageRep {
        let width = Int(view.bounds.width) * scale, height = Int(view.bounds.height) * scale
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bytesPerRow: width * 4, bitsPerPixel: 32),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap), let bytes = bitmap.bitmapData else {
            throw NSError(domain: "CornerValidation", code: 1)
        }
        bytes.initialize(repeating: 0, count: bitmap.bytesPerRow * height)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = graphics
        let context = graphics.cgContext
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        view.draw(view.bounds)
        if background {
            for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                context.setFillColor(color.cgColor)
                context.fillEllipse(in: CGRect(x: 48 + Double(index) * 17, y: 65, width: 11, height: 11))
            }
            context.setBlendMode(.destinationOver)
            context.setFillColor(NSColor(calibratedWhite: 0.28, alpha: 1).cgColor)
            context.addPath(CGPath(roundedRect: CGRect(x: 30, y: 50, width: 180, height: 120),
                                  cornerWidth: WindowTracker.estimatedCornerRadius,
                                  cornerHeight: WindowTracker.estimatedCornerRadius, transform: nil))
            context.fillPath()
            context.setFillColor(NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.17, alpha: 1).cgColor)
            context.fill(view.bounds)
        }
        return bitmap
    }

    private static func alphaSum(_ bitmap: NSBitmapImageRep, in rect: CGRect) -> Int {
        guard let bytes = bitmap.bitmapData else { return 0 }
        let alpha = bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : 3
        var sum = 0
        for y in max(0, Int(rect.minY))..<min(bitmap.pixelsHigh, Int(rect.maxY)) {
            for x in max(0, Int(rect.minX))..<min(bitmap.pixelsWide, Int(rect.maxX)) {
                sum += Int(bytes[y * bitmap.bytesPerRow + x * 4 + alpha])
            }
        }
        return sum
    }

    private static func writeReport(_ checks: [String: Bool], to output: URL, error: String? = nil) throws {
        var report: [String: Any] = [
            "passed": error == nil && !checks.isEmpty && checks.values.allSatisfy { $0 },
            "checks": checks,
            "note": "Synthetic circular 26-point corners only. Does not measure another app's true corner shape."
        ]
        if let error { report["error"] = error }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("corner-validation.json"))
    }
}
