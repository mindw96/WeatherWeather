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
                view.windowGeometry = [
                    WindowGeometry(id: 8, x: 0, y: 0, width: 240, height: 140),
                    WindowGeometry(id: 7, x: 30, y: 50, width: 180, height: 80, cornerRadius: 26)
                ]
                checks["\(prefix)CoveredEdgeHidden"] = alphaSum(try render(view), in: view.bounds) == 0
                view.simulation.setSurfaces([Surface(id: 7, x: 30, y: 50, width: 180, cornerRadius: 26)])
                view.windowGeometry = []
                view.hiddenFocusedWindow = WindowGeometry(id: 7, x: 30, y: 50, width: 180, height: 80)
                checks["\(prefix)FocusedPileHidden"] = alphaSum(try render(view), in: view.bounds) == 0
                try checkOverlap(mode: mode, checks: &checks)
            }
            for (label, radius) in [("before", 26.0), ("after", WindowTracker.estimatedCornerRadius)] {
                let bitmap = try render(fixture(mode: .snow, radius: radius), scale: 3, background: true)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "CornerValidation", code: 2)
                }
                try png.write(to: output.appendingPathComponent("corner-\(label).png"))
            }
            let overlap = overlapFixture(mode: .snow, windows: [
                WindowGeometry(id: 8, x: 100, y: 65, width: 130, height: 90, cornerRadius: 16),
                WindowGeometry(id: 7, x: 20, y: 65, width: 180, height: 100, cornerRadius: 16)
            ])
            var foreground = overlap.simulation.piles[0]
            foreground.heights = Array(repeating: 8, count: foreground.heights.count)
            overlap.simulation.inheritAccumulation(from: [foreground])
            let bitmap = try render(overlap, scale: 3, background: true)
            guard let png = bitmap.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "CornerValidation", code: 2)
            }
            try png.write(to: output.appendingPathComponent("overlap-after.png"))
            try writeReport(checks, to: output)
        } catch {
            try? writeReport(checks, to: output, error: error.localizedDescription)
            fputs("Corner validation failed: \(error)\n", stderr)
        }
    }

    private static func checkOverlap(mode: WeatherMode, checks: inout [String: Bool]) throws {
        let front = WindowGeometry(id: 8, x: 100, y: 80, width: 100, height: 90, cornerRadius: 16)
        let rear = WindowGeometry(id: 7, x: 20, y: 84, width: 200, height: 100)
        let view = overlapFixture(mode: mode, windows: [front, rear])
        let piles = view.simulation.piles, settled = view.simulation.settledParticles
        let raster = try render(view)
        let prefix = mode.rawValue
        checks["\(prefix)RearVisibleThroughRoundedCorner"] = alphaSum(raster, in: CGRect(x: 101, y: 80, width: 4, height: 4)) > 0
        checks["\(prefix)RearHiddenInsideForegroundBody"] = alphaSum(raster, in: CGRect(x: 124, y: 80, width: 8, height: 8)) == 0
        checks["\(prefix)OcclusionPreservesAccumulation"] = view.simulation.piles == piles && view.simulation.settledParticles == settled
        view.hiddenWindows = [front]
        let excludedFront = try render(view)
        checks["\(prefix)ExcludedForegroundStillOccludesRearAccumulation"] = alphaSum(excludedFront, in: CGRect(x: 124, y: 80, width: 8, height: 8)) == 0
        view.hiddenWindows = []

        var equalTop = rear
        equalTop.y = front.y
        let aligned = try render(overlapFixture(mode: mode, windows: [front, equalTop]))
        checks["\(prefix)EqualTopRidgeHasNoVerticalCut"] = alphaSum(aligned, in: CGRect(x: 102, y: 77, width: 4, height: 2)) > 0
        let reordered = try render(overlapFixture(mode: mode, windows: [rear, front]))
        checks["\(prefix)BringingRearWindowForwardRestoresPile"] = alphaSum(reordered, in: CGRect(x: 124, y: 80, width: 8, height: 4)) > 0

        let raised = overlapFixture(mode: mode, windows: [
            WindowGeometry(id: 8, x: 0, y: 80, width: 240, height: 100),
            WindowGeometry(id: 7, x: 20, y: 81, width: 200, height: 100)
        ])
        let raisedRaster = try render(raised)
        checks["\(prefix)CoveredBaselineRetainsVisibleRidge"] = raised.simulation.surfaces.last?.segments.isEmpty == true
            && alphaSum(raisedRaster, in: CGRect(x: 100, y: 76, width: 8, height: 4)) > 0
        checks["\(prefix)CoveredBaselineDoesNotLeakIntoBody"] = alphaSum(raisedRaster, in: CGRect(x: 100, y: 81, width: 8, height: 8)) == 0

        let multiple = try render(overlapFixture(mode: mode, windows: [
            WindowGeometry(id: 8, x: 100, y: 60, width: 100, height: 100, cornerRadius: 16),
            WindowGeometry(id: 9, x: 120, y: 65, width: 100, height: 100, cornerRadius: 16), rear
        ]))
        checks["\(prefix)OverlappingOccludersDoNotReopenHole"] = alphaSum(multiple, in: CGRect(x: 124, y: 80, width: 8, height: 8)) == 0
        let fullyCovered = overlapFixture(mode: mode, windows: [
            WindowGeometry(id: 8, x: 0, y: 0, width: 240, height: 140), rear
        ])
        checks["\(prefix)EntireMoundBehindWindowHidden"] = alphaSum(try render(fullyCovered), in: fullyCovered.bounds) == 0
    }

    private static func overlapFixture(mode: WeatherMode, windows: [WindowGeometry]) -> WeatherView {
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        view.showSnowman = false
        view.windowGeometry = windows
        view.simulation.mode = mode
        view.simulation.setSurfaces(visibleTopSegments(for: windows))
        guard var rear = view.simulation.piles.first(where: { $0.surfaceID == 7 }) else { return view }
        if mode.hasSettledParticles {
            view.simulation.inheritSettledParticles(from: [104.0, 128.0].enumerated().map { index, x in
                SettledParticle(id: UInt64(index + 1), mode: mode, surfaceID: rear.surfaceID,
                                position: (x - rear.x) / rear.width, offsetY: 3,
                                size: mode == .fireflies ? 2.4 : mode == .stardust ? 4 : mode == .confetti ? 8 : 10,
                                rotation: 0, variant: index, life: mode == .fireflies ? 3 : 5)
            })
        } else {
            rear.heights = Array(repeating: mode == .snow ? 8 : 4, count: rear.heights.count)
            view.simulation.inheritAccumulation(from: [rear])
        }
        return view
    }

    private static func fixture(mode: WeatherMode, radius: Double) -> WeatherView {
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        view.showSnowman = false
        view.simulation.mode = mode
        view.simulation.setSurfaces([Surface(id: 7, x: 30, y: 50, width: 180, cornerRadius: radius)])
        if mode.hasSettledParticles {
            let size = mode == .fireflies ? 2.4 : mode == .stardust ? 4 : mode == .confetti ? 8.0 : 10.0
            view.simulation.inheritSettledParticles(from: [4.0, 176.0].enumerated().map { index, x in
                SettledParticle(id: UInt64(index + 1), mode: mode, surfaceID: 7, position: x / 180,
                                offsetY: 3, size: size, rotation: 0, variant: index, life: mode == .fireflies ? 3 : 5)
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
            context.setBlendMode(.destinationOver)
            let windows = view.windowGeometry.isEmpty ? [
                WindowGeometry(id: 7, x: 30, y: 50, width: 180, height: 120,
                               cornerRadius: WindowTracker.estimatedCornerRadius)
            ] : view.windowGeometry
            for window in windows {
                for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                    context.setFillColor(color.cgColor)
                    context.fillEllipse(in: CGRect(x: window.x + 18 + Double(index) * 17,
                                                  y: window.y + 15, width: 11, height: 11))
                }
                context.setFillColor(NSColor(calibratedWhite: 0.28, alpha: 1).cgColor)
                context.addPath(CGPath(roundedRect: CGRect(x: window.x, y: window.y, width: window.width, height: window.height),
                                      cornerWidth: window.cornerRadius, cornerHeight: window.cornerRadius, transform: nil))
                context.fillPath()
            }
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
            "note": "Synthetic 26-point single corners and 16-point overlapping-window occlusion. Does not measure another app's true corner shape."
        ]
        if let error { report["error"] = error }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("corner-validation.json"))
    }
}
