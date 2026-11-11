import AppKit
import WeatherCore

/// Deterministic renderer checks. These draw only generated weather into local
/// bitmaps; they do not capture the desktop or require an unlocked GUI session.
enum FocusedWindowValidation {
    static func run(to directory: String) {
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        var checks: [String: Bool] = [:]
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            checkPreferences(into: &checks)
            for mode in WeatherMode.allCases {
                try checkRendering(mode: mode, output: output, checks: &checks)
            }
            let report: [String: Any] = [
                "passed": checks.values.allSatisfy { $0 }, "checks": checks,
                "note": "Generated offscreen weather only. Does not prove external-app focus tracking or physical input behavior."
            ]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: output.appendingPathComponent("focus-validation.json"))
        } catch {
            let report: [String: Any] = ["passed": false, "checks": checks, "error": error.localizedDescription]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: output.appendingPathComponent("focus-validation.json"))
            }
            fputs("Focused-window validation failed: \(error)\n", stderr)
        }
    }

    private static func checkPreferences(into checks: inout [String: Bool]) {
        let name = "org.windowweather.focus-validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = Preferences(defaults: defaults)
        checks["missingPreferencePreservesVisibleEffects"] = settings.showEffectsOnFocusedWindow
        settings.showEffectsOnFocusedWindow = false
        checks["hiddenPreferenceSurvivesReload"] = !Preferences(defaults: defaults).showEffectsOnFocusedWindow
        settings.accumulation = false
        settings.accumulateOnFullScreen = true
        checks["focusPreferenceIndependentOfAccumulation"] = !settings.showEffectsOnFocusedWindow
        settings.showEffectsOnFocusedWindow = true
        checks["visiblePreferenceSurvivesReload"] = Preferences(defaults: defaults).showEffectsOnFocusedWindow
        for mode in [WeatherMode.bubbles, .confetti, .fireflies, .stardust] {
            settings.mode = mode
            checks["\(mode.rawValue)SelectionSurvivesReload"] = Preferences(defaults: defaults).mode == mode
        }
    }

    private static func checkRendering(mode: WeatherMode, output: URL, checks: inout [String: Bool]) throws {
        let prefix = mode.rawValue
        let target = WindowGeometry(id: 51, x: 260, y: 100, width: 250, height: 250)
        let rect = CGRect(x: target.x, y: target.y, width: target.width, height: target.height)
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 640, height: 400), seed: 817)
        view.simulation.mode = mode
        view.simulation.intensity = 1
        // No collision surface inside this rectangle: objects cross its interior.
        for _ in 0..<600 { view.simulation.update(deltaTime: 1 / 30.0) }
        let particles = view.simulation.particles
        let visible = try render(view)
        view.hiddenFocusedWindow = target
        let hidden = try render(view)
        checks["\(prefix)InteriorActuallyContainedEffects"] = visible.alphaSum(in: rect.insetBy(dx: 1, dy: 1)) > 0
        checks["\(prefix)FocusedInteriorIsTransparent"] = hidden.alphaSum(in: rect.insetBy(dx: 1, dy: 1)) == 0
        checks["\(prefix)OtherAreasStayVisible"] = hidden.alphaSum(in: CGRect(x: 0, y: 0, width: 200, height: 400)) > 0
            && visible.matches(hidden, outside: rect.insetBy(dx: -1, dy: -1))
        view.hiddenFocusedWindow = nil
        checks["\(prefix)ShowingAgainRestoresSameFrame"] = try render(view).pixels == visible.pixels
        checks["\(prefix)HidingDoesNotDeleteFallingObjects"] = particles == view.simulation.particles
        let secondExcluded = WindowGeometry(id: 52, x: 400, y: 180, width: 160, height: 180)
        view.hiddenWindows = [target, secondExcluded]
        let excluded = try render(view)
        checks["\(prefix)ExcludedAppWindowsHideTheirUnion"] = excluded.alphaSum(in: rect.insetBy(dx: 1, dy: 1)) == 0
            && excluded.alphaSum(in: CGRect(x: 401, y: 181, width: 158, height: 178)) == 0
        checks["\(prefix)OverlappingAppExclusionsNeverReopenPixels"] = excluded.alphaSum(in: CGRect(x: 401, y: 181, width: 108, height: 168)) == 0
        checks["\(prefix)AppExclusionsPreserveOtherEffects"] = excluded.alphaSum(in: CGRect(x: 0, y: 0, width: 200, height: 400)) > 0
            && particles == view.simulation.particles
        let front = WindowGeometry(id: 80, x: 300, y: 140, width: 140, height: 150, cornerRadius: 16)
        view.windowGeometry = [front, target]
        view.hiddenWindows = [target]
        let foregroundArea = CGRect(x: 320, y: 160, width: 100, height: 110)
        let visibleFront = try render(view)
        checks["\(prefix)ExcludedBackgroundDoesNotHideForegroundAppEffects"] = visible.alphaSum(in: foregroundArea) > 0
            && visibleFront.alphaSum(in: foregroundArea) == visible.alphaSum(in: foregroundArea)
        view.windowGeometry = []
        view.hiddenWindows = []
        try visible.png.write(to: output.appendingPathComponent("\(prefix)-focus-visible.png"))
        try hidden.png.write(to: output.appendingPathComponent("\(prefix)-focus-hidden.png"))

        // Transfer settled state into a clean view, excluding falling particles
        // and splashes so the mound above the window is independently testable.
        let surfaces = [Surface(id: 51, x: 260, y: 170, width: 250), Surface(id: 52, x: 35, y: 290, width: 150)]
        let seed = WeatherSimulation(width: 640, height: 400, seed: 91)
        seed.mode = mode
        seed.intensity = 1
        seed.setSurfaces(surfaces)
        for _ in 0..<900 { seed.update(deltaTime: 0.1) }
        let piles = WeatherView(frame: view.frame)
        piles.simulation.mode = mode
        piles.simulation.setSurfaces(surfaces)
        piles.simulation.inheritAccumulation(from: seed.piles)
        piles.simulation.inheritSettledParticles(from: seed.settledParticles)
        let focused = WindowGeometry(id: 51, x: 260, y: 170, width: 250, height: 220)
        piles.windowGeometry = [focused, WindowGeometry(id: 52, x: 35, y: 290, width: 150, height: 100)]
        let pileState = piles.simulation.piles
        let settledState = piles.simulation.settledParticles
        let pileVisible = try render(piles)
        piles.hiddenFocusedWindow = focused
        let pileHidden = try render(piles)
        let focusedMound = CGRect(x: 250, y: 134, width: 270, height: 44)
        let otherMound = CGRect(x: 25, y: 254, width: 170, height: 44)
        checks["\(prefix)FocusedPileHiddenAboveWindow"] = pileVisible.alphaSum(in: focusedMound) > 0
            && pileHidden.alphaSum(in: focusedMound) == 0
        checks["\(prefix)OtherPileUnchanged"] = pileHidden.alphaSum(in: otherMound) > 0
            && pileHidden.alphaSum(in: otherMound) == pileVisible.alphaSum(in: otherMound)
        checks["\(prefix)AccumulationPreservedWhileHidden"] = pileState == piles.simulation.piles
            && settledState == piles.simulation.settledParticles
        piles.hiddenFocusedWindow = nil
        checks["\(prefix)PileRestoredWithoutResimulation"] = try render(piles).pixels == pileVisible.pixels
        piles.hiddenWindows = [focused]
        let excludedPile = try render(piles)
        checks["\(prefix)AppExclusionAlsoHidesPileAboveItsWindow"] = excludedPile.alphaSum(in: focusedMound) == 0
            && excludedPile.alphaSum(in: otherMound) == pileVisible.alphaSum(in: otherMound)
        let background = WindowGeometry(id: 90, x: 200, y: 120, width: 400, height: 260)
        let originalGeometry = piles.windowGeometry
        piles.windowGeometry.append(background)
        piles.hiddenWindows = [background]
        let foregroundPile = try render(piles)
        checks["\(prefix)ForegroundPileAboveFrameSurvivesExcludedBackground"] = foregroundPile.alphaSum(in: focusedMound)
            == pileVisible.alphaSum(in: focusedMound)
        piles.windowGeometry = originalGeometry
        piles.hiddenWindows = []
        try pileVisible.png.write(to: output.appendingPathComponent("\(prefix)-pile-visible.png"))
        try pileHidden.png.write(to: output.appendingPathComponent("\(prefix)-pile-hidden.png"))

        if mode == .rain {
            let rain = WeatherView(frame: view.frame, seed: 118)
            rain.simulation.mode = .rain
            rain.simulation.intensity = 1
            rain.simulation.setSurfaces([Surface(id: 51, x: 20, y: 200, width: 600)])
            for _ in 0..<300 { rain.simulation.update(deltaTime: 1 / 30.0) }
            checks["rainFixtureContainsRipplesAndMergingDrops"] = !rain.simulation.ripples.isEmpty && !rain.simulation.rainDrops.isEmpty
            let wetArea = CGRect(x: 0, y: 150, width: 640, height: 250)
            checks["rainSplashFixtureContainsVisibleDroplets"] = rain.simulation.splashes.contains {
                wetArea.contains(CGPoint(x: $0.x, y: $0.y))
            }
            rain.hiddenFocusedWindow = WindowGeometry(id: 51, x: 0, y: 150, width: 640, height: 250)
            checks["rainSplashesAlsoHiddenInFocusedWindow"] = try render(rain).alphaSum(in: wetArea.insetBy(dx: 1, dy: 1)) == 0
        }
    }

    private struct Raster {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let alphaOffset: Int
        let pixels: [UInt8]
        let png: Data

        func alphaSum(in rect: CGRect) -> Int {
            let x0 = max(0, Int(rect.minX)), x1 = min(width, Int(rect.maxX))
            let y0 = max(0, Int(rect.minY)), y1 = min(height, Int(rect.maxY))
            guard x0 < x1, y0 < y1 else { return 0 }
            var total = 0
            for y in y0..<y1 { for x in x0..<x1 { total += Int(pixels[y * bytesPerRow + x * 4 + alphaOffset]) } }
            return total
        }

        func matches(_ other: Raster, outside rect: CGRect) -> Bool {
            guard width == other.width, height == other.height, bytesPerRow == other.bytesPerRow else { return false }
            for y in 0..<height {
                for x in 0..<width where !rect.contains(CGPoint(x: x, y: y)) {
                    let offset = y * bytesPerRow + x * 4
                    if pixels[offset..<(offset + 4)] != other.pixels[offset..<(offset + 4)] { return false }
                }
            }
            return true
        }
    }

    private static func render(_ view: WeatherView) throws -> Raster {
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: bitmap), let bytes = bitmap.bitmapData else {
            throw NSError(domain: "FocusedWindowValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
        }
        bytes.initialize(repeating: 0, count: bitmap.bytesPerRow * height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.translateBy(x: 0, y: CGFloat(height))
        context.cgContext.scaleBy(x: 1, y: -1)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "FocusedWindowValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode bitmap"])
        }
        return Raster(width: width, height: height, bytesPerRow: bitmap.bytesPerRow,
                      alphaOffset: bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : 3,
                      pixels: Array(UnsafeBufferPointer(start: bytes, count: bitmap.bytesPerRow * height)), png: png)
    }
}
