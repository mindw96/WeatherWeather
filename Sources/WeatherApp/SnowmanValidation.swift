import AppKit
import WeatherCore

/// Draws generated artwork only; no desktop capture or active GUI session needed.
enum SnowmanValidation {
    static func run(to directory: String) {
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        var checks: [String: Bool] = [:]
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            checkPreferences(into: &checks)
            try checkRendering(output: output, checks: &checks)
            checkLayout(into: &checks)
            checkPanelRouting(into: &checks)
            try writeReport(checks: checks, output: output)
        } catch {
            try? writeReport(checks: checks, output: output, error: error.localizedDescription)
            fputs("Snowman validation failed: \(error)\n", stderr)
        }
    }

    private static func checkPreferences(into checks: inout [String: Bool]) {
        let name = "org.windowweather.snowman-validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        checks["snowmanDefaultsOn"] = preferences.showSnowman
        preferences.showSnowman = false
        checks["snowmanOffSurvivesReload"] = !Preferences(defaults: defaults).showSnowman
        preferences.showSnowman = true
        preferences.mode = .rain
        preferences.accumulation = false
        checks["snowmanChoiceSurvivesModeAndAccumulationChanges"] = Preferences(defaults: defaults).showSnowman
        let first = SnowmanPosition(x: 0.2, y: 0.8), second = SnowmanPosition(x: 0.7, y: 0.3)
        preferences.setSnowmanPosition(first, for: "validation-display-A")
        preferences.setSnowmanPosition(second, for: "validation-display-B")
        let reloaded = Preferences(defaults: defaults)
        checks["snowmanPositionsPersistSeparatelyForEachDisplay"] = reloaded.snowmanPosition(for: "validation-display-A") == first
            && reloaded.snowmanPosition(for: "validation-display-B") == second
        reloaded.setSnowmanPosition(.init(x: 0.4, y: 0.6), for: "validation-display-A")
        checks["movingOneDisplayDoesNotOverwriteAnotherPosition"] = Preferences(defaults: defaults).snowmanPosition(for: "validation-display-B") == second
    }

    private static func checkRendering(output: URL, checks: inout [String: Bool]) throws {
        let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 640, height: 400))
        view.simulation.mode = .snow
        view.showSnowman = true
        // No simulation steps: any visible pixel belongs to the snowman.
        let visible = try render(view)
        let frame = SnowmanRenderer.frame(in: view.bounds)
        let ink = visible.occupiedBounds
        checks["snowmanAppearsImmediatelyAtBottomRight"] = !ink.isEmpty
            && ink.minX >= view.bounds.midX && ink.maxY >= view.bounds.height * 0.9
            && frame.insetBy(dx: -2, dy: -2).contains(ink)
        try visible.png.write(to: output.appendingPathComponent("snowman-on.png"))

        view.showSnowman = false
        let hidden = try render(view)
        checks["snowmanOffRemovesAllArtwork"] = hidden.alphaSum(in: view.bounds) == 0
        try hidden.png.write(to: output.appendingPathComponent("snowman-off.png"))
        view.showSnowman = true
        checks["snowmanOnRestoresSameArtwork"] = try render(view).pixels == visible.pixels

        var otherModesClear = true
        for mode in WeatherMode.allCases where mode != .snow {
            view.simulation.mode = mode
            otherModesClear = try render(view).alphaSum(in: view.bounds) == 0 && otherModesClear
        }
        checks["snowmanOnlyAppearsInSnowMode"] = otherModesClear
        view.simulation.mode = .snow
        checks["returningToSnowRestoresSnowman"] = try render(view).pixels == visible.pixels

        let cover = frame.insetBy(dx: -4, dy: -4)
        view.hiddenFocusedWindow = WindowGeometry(id: 71, x: cover.minX, y: cover.minY,
                                                  width: cover.width, height: cover.height)
        checks["focusedWindowCanFullyHideSnowman"] = try render(view).alphaSum(in: view.bounds) == 0
        let partialCover = CGRect(x: 0, y: 0, width: frame.midX, height: view.bounds.height)
        view.hiddenFocusedWindow = WindowGeometry(id: 71, x: partialCover.minX, y: partialCover.minY,
                                                  width: partialCover.width, height: partialCover.height)
        let partial = try render(view)
        checks["focusedWindowClipsOnlyOverlappingPart"] = partial.alphaSum(in: partialCover.insetBy(dx: 1, dy: 1)) == 0
            && partial.alphaSum(in: view.bounds) > 0
            && partial.alphaSum(in: view.bounds) < visible.alphaSum(in: view.bounds)
        view.hiddenFocusedWindow = WindowGeometry(id: 71, x: 10, y: 10, width: 100, height: 80)
        checks["unrelatedFocusedWindowLeavesSnowmanVisible"] = try render(view).pixels == visible.pixels
        view.hiddenFocusedWindow = nil

        view.simulation.accumulationEnabled = false
        checks["snowmanIndependentOfSnowAccumulation"] = try render(view).pixels == visible.pixels
        view.simulation.clearAccumulation()
        checks["clearingSnowDoesNotDisableSnowman"] = try render(view).pixels == visible.pixels

        let detail = SnowmanView(frame: NSRect(x: 0, y: 0, width: 200, height: 232))
        let panelArtwork = try render(detail)
        checks["snowmanPanelRendererPaintsArtwork"] = panelArtwork.alphaSum(in: detail.bounds) > 0
        try panelArtwork.png.write(to: output.appendingPathComponent("snowman-detail.png"))
        detail.hiddenRect = CGRect(x: 0, y: 0, width: 100, height: 232)
        let panelClipped = try render(detail)
        checks["snowmanPanelRendererHonorsFocusMask"] = panelClipped.alphaSum(in: CGRect(x: 0, y: 0, width: 99, height: 232)) == 0
            && panelClipped.alphaSum(in: detail.bounds) > 0
            && panelClipped.alphaSum(in: detail.bounds) < panelArtwork.alphaSum(in: detail.bounds)
    }

    private static func checkLayout(into checks: inout [String: Bool]) {
        let bounds = [CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
                      CGRect(x: 0, y: 0, width: 640, height: 1_200),
                      CGRect(x: 0, y: 0, width: 40, height: 400),
                      CGRect(x: 0, y: 0, width: 402, height: 160),
                      CGRect(x: 13, y: 17, width: 80, height: 70)]
        checks["snowmanStaysWithinTallNarrowAndPreviewBounds"] = bounds.allSatisfy {
            let frame = SnowmanRenderer.frame(in: $0)
            return !frame.isEmpty && $0.contains(frame)
        }
        let invalid = [CGRect.zero, CGRect.null, CGRect.infinite,
                       CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100)]
        checks["snowmanRejectsEmptyAndInvalidBounds"] = invalid.allSatisfy {
            let frame = SnowmanRenderer.frame(in: $0)
            return frame.isEmpty || frame.isNull
        }
    }

    /// Native view methods are invoked directly on an unshown panel. This tests
    /// coordinate conversion and callback wiring, not Window Server event routing.
    private static func checkPanelRouting(into checks: inout [String: Bool]) {
        guard let screen = NSScreen.screens.first else {
            checks["snowmanPanelDisplayAvailable"] = false
            return
        }
        let name = "org.windowweather.snowman-panel-validation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        let overlay = SnowmanOverlay(screen: screen, preferences: preferences)
        defer { overlay.close() }
        checks["snowmanPanelDoesNotTakeKeyboardFocus"] = !overlay.panel.canBecomeKey
            && !overlay.panel.canBecomeMain && !overlay.panel.isOpaque
            && !overlay.view.acceptsFirstResponder && !overlay.view.needsPanelToBecomeKey
        let body = CGPoint(x: overlay.view.bounds.width * 0.54, y: overlay.view.bounds.height * 92 / 116)
        checks["snowmanHitTestAcceptsBodyButNotTransparentCorner"] = overlay.view.canGrab(at: body)
            && !overlay.view.canGrab(at: .zero)
        overlay.view.hiddenRect = CGRect(x: body.x - 4, y: body.y - 4, width: 8, height: 8)
        checks["snowmanHiddenPixelsCannotStartDrag"] = !overlay.view.canGrab(at: body)
        overlay.view.hiddenRect = nil

        let before = overlay.panel.frame
        let location = overlay.view.convert(body, to: nil)
        if let down = event(.leftMouseDown, location: location, panel: overlay.panel),
           let dragged = event(.leftMouseDragged, location: CGPoint(x: location.x - 24, y: location.y + 16), panel: overlay.panel),
           let up = event(.leftMouseUp, location: location, panel: overlay.panel) {
            overlay.view.mouseDown(with: down)
            let began = overlay.isDragging
            overlay.view.mouseDragged(with: dragged)
            let translated = nearlyEqual(overlay.panel.frame.minX, before.minX - 24)
                && nearlyEqual(overlay.panel.frame.minY, before.minY + 16)
            overlay.view.mouseUp(with: up)
            checks["snowmanNativeViewDragCallbacksMoveAndFinish"] = began && translated && !overlay.isDragging
        } else {
            checks["snowmanNativeViewDragCallbacksMoveAndFinish"] = false
        }

        let restored = SnowmanOverlay(screen: screen, preferences: Preferences(defaults: defaults))
        checks["snowmanPanelRestoresSavedDragAfterReload"] = nearlyEqual(restored.panel.frame.minX, overlay.panel.frame.minX)
            && nearlyEqual(restored.panel.frame.minY, overlay.panel.frame.minY)
        restored.close()

        overlay.beginDrag(at: .zero)
        overlay.drag(to: CGPoint(x: -1_000_000, y: -1_000_000))
        overlay.endDrag()
        let lowerClamp = nearlyEqual(overlay.panel.frame.minX, screen.frame.minX)
            && nearlyEqual(overlay.panel.frame.minY, screen.frame.minY)
        overlay.beginDrag(at: .zero)
        overlay.drag(to: CGPoint(x: 1_000_000, y: 1_000_000))
        overlay.endDrag()
        checks["snowmanPanelDragClampsToItsDisplay"] = lowerClamp
            && nearlyEqual(overlay.panel.frame.maxX, screen.frame.maxX)
            && nearlyEqual(overlay.panel.frame.maxY, screen.frame.maxY)
        checks["snowmanPanelFixtureRemainsUnshown"] = !overlay.panel.isVisible
    }

    private static func event(_ type: NSEvent.EventType, location: CGPoint, panel: NSWindow) -> NSEvent? {
        NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                          timestamp: ProcessInfo.processInfo.systemUptime,
                          windowNumber: panel.windowNumber, context: nil,
                          eventNumber: 1, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)
    }

    private static func nearlyEqual(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { abs(lhs - rhs) < 0.5 }

    private static func writeReport(checks: [String: Bool], output: URL, error: String? = nil) throws {
        var report: [String: Any] = [
            "passed": error == nil && !checks.isEmpty && checks.values.allSatisfy { $0 },
            "checks": checks,
            "note": "Generated offscreen WeatherView artwork, isolated preferences, and directly invoked native view drag callbacks on an unshown panel. Does not prove Window Server mouse routing, physical dragging, desktop panel composition, or display transitions."
        ]
        if let error { report["error"] = error }
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("snowman-validation.json"))
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

        var occupiedBounds: CGRect {
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height { for x in 0..<width where pixels[y * bytesPerRow + x * 4 + alphaOffset] > 0 {
                minX = min(minX, x); minY = min(minY, y)
                maxX = max(maxX, x); maxY = max(maxY, y)
            } }
            guard maxX >= minX, maxY >= minY else { return .zero }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }

    private static func render(_ view: NSView) throws -> Raster {
        let width = Int(view.bounds.width), height = Int(view.bounds.height)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32),
              let context = NSGraphicsContext(bitmapImageRep: bitmap), let bytes = bitmap.bitmapData else {
            throw NSError(domain: "SnowmanValidation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create bitmap"])
        }
        bytes.initialize(repeating: 0, count: bitmap.bytesPerRow * height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.translateBy(x: 0, y: CGFloat(height))
        context.cgContext.scaleBy(x: 1, y: -1)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "SnowmanValidation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to encode bitmap"])
        }
        return Raster(width: width, height: height, bytesPerRow: bitmap.bytesPerRow,
                      alphaOffset: bitmap.bitmapFormat.contains(.alphaFirst) ? 0 : 3,
                      pixels: Array(UnsafeBufferPointer(start: bytes, count: bitmap.bytesPerRow * height)), png: png)
    }
}
