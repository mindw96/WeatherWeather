import AppKit
import WeatherCore

/// Local validation hooks. Only our synthetic windows/artwork are written to disk.
enum Validation {
    private static var smokeDiagnostics: [String: Any] = [:]

    /// Can be called before overlay creation. Locked sessions do not provide a
    /// reliable interactive window-compositor test, even when APIs return bounds.
    @discardableResult
    static func blockGUIValidationIfNeeded(output: String) -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let locked = session?["CGSSessionScreenIsLocked"] as? Bool
        let onConsole = session?[kCGSessionOnConsoleKey as String] as? Bool
        let active = session?["CGSSessionUserIsActive"] as? Bool
        var diagnostics: [String: Any] = ["dictionaryAvailable": session != nil]
        if let locked { diagnostics["screenLocked"] = locked }
        if let onConsole { diagnostics["onConsole"] = onConsole }
        if let active { diagnostics["userIsActive"] = active }
        smokeDiagnostics["guiSession"] = diagnostics
        let reason: String?
        if locked == true {
            reason = "The GUI session is locked. Unlock it before running interactive validation."
        } else if onConsole == false {
            reason = "The GUI session is not on the active console. Interactive validation was not run."
        } else {
            reason = nil
        }
        // NSApp.isActive is intentionally not a precondition: accessory apps
        // normally start inactive and activate only when presenting their fixture.
        guard let reason else { return false }
        writeSmoke(checks: ["interactiveSessionAvailable": false], output: output, blockedReason: reason)
        NSApp.terminate(nil)
        return true
    }

    static func renderSettings(window: NSWindow, to directory: String, filename: String = "settings-preview.png") {
        guard let view = window.contentView else { return }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        do { try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(filename)) }
        catch { fputs("Settings preview failed: \(error)\n", stderr) }
    }

    static func renderPreviews(to directory: String) {
        do {
            let url = URL(fileURLWithPath: directory, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            for mode in WeatherMode.allCases {
                let view = WeatherView(frame: NSRect(x: 0, y: 0, width: 800, height: 480))
                view.demoBackground = true
                view.simulation.mode = mode
                view.simulation.intensity = 0.8
                view.simulation.wind = 0.2
                view.simulation.setSurfaces([
                    Surface(id: 1, x: 65, y: 270, width: 370, cornerRadius: WindowTracker.estimatedCornerRadius),
                    Surface(id: 2, x: 460, y: 170, width: 280, cornerRadius: WindowTracker.estimatedCornerRadius),
                    Surface(id: 0, x: 0, y: 479, width: 800)
                ])
                for _ in 0..<3600 { view.simulation.update(deltaTime: 1.0 / 30.0) }
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 800, pixelsHigh: 480, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
                      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { continue }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = context
                context.cgContext.translateBy(x: 0, y: 480)
                context.cgContext.scaleBy(x: 1, y: -1)
                view.draw(view.bounds)
                NSGraphicsContext.restoreGraphicsState()
                if let data = bitmap.representation(using: .png, properties: [:]) {
                    try data.write(to: url.appendingPathComponent("\(mode.rawValue)-preview.png"))
                }
            }
        } catch { fputs("Preview failed: \(error)\n", stderr) }
        CornerValidation.run(to: directory)
    }

    static func smokeTest(delegate: AppDelegate, output: String) {
        guard !blockGUIValidationIfNeeded(output: output) else { return }
        var checks: [String: Bool] = [:]
        guard let screen = NSScreen.main, let overlays = delegate.overlays else {
            writeSmoke(checks: ["displayAvailable": false], output: output)
            NSApp.terminate(nil)
            return
        }
        let frame = NSRect(x: screen.visibleFrame.minX + 100, y: screen.visibleFrame.minY + 120, width: 380, height: 250)
        let fixture = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        fixture.title = "Window Weather · local validation"
        fixture.isReleasedWhenClosed = false
        fixture.collectionBehavior = [.fullScreenPrimary, .moveToActiveSpace]
        NSApp.activate(ignoringOtherApps: true)
        fixture.makeKeyAndOrderFront(nil)
        let id = UInt32(fixture.windowNumber)
        checks["oneOverlayPerDisplay"] = overlays.displays.count == NSScreen.screens.count
        checks["clickThroughNonactivatingPanels"] = overlays.displays.allSatisfy {
            $0.panel.ignoresMouseEvents && !$0.panel.canBecomeKey && !$0.panel.canBecomeMain && !$0.panel.isOpaque
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            overlays.refreshSurfaces()
            checks["realWindowDetected"] = WindowTracker.windows().contains { $0.id == id }
            checks["windowSurfaceCreated"] = overlays.displays.contains { $0.view.simulation.surfaces.contains { $0.id == id } }
            let curvedSurface = overlays.displays.flatMap { $0.view.simulation.surfaces }.first { $0.id == id }
            checks["trackedWindowUsesEstimatedCurve"] = curvedSurface?.cornerRadius == WindowTracker.estimatedCornerRadius
            checks["screenFloorsRemainFlat"] = overlays.displays.flatMap { $0.view.simulation.piles }
                .filter { $0.surfaceID == 0 }.allSatisfy { $0.cornerRadius == 0 }
            let before = WindowTracker.windows().first { $0.id == id }
            let frameBeforeMove = fixture.frame
            fixture.setFrameOrigin(NSPoint(x: fixture.frame.minX + 45, y: fixture.frame.minY + 35))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                overlays.refreshSurfaces()
                let after = WindowTracker.windows().first { $0.id == id }
                // CG visible bounds can be inset from AppKit's decorated frame.
                let expectedX = (before?.x ?? 0) + fixture.frame.minX - frameBeforeMove.minX
                let expectedY = (before?.y ?? 0) - (fixture.frame.maxY - frameBeforeMove.maxY)
                checks["windowMoveTracked"] = before != nil && after != nil && (before!.x != after!.x || before!.y != after!.y)
                    && abs(after!.x - expectedX) < 2 && abs(after!.y - expectedY) < 2
                smokeDiagnostics["windowMove"] = ["before": before.map { [$0.x, $0.y] } ?? [],
                                                   "after": after.map { [$0.x, $0.y] } ?? [],
                                                   "expected": [expectedX, expectedY]]
                let frameBeforeResize = fixture.frame
                fixture.setContentSize(NSSize(width: 460, height: 270))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    overlays.refreshSurfaces()
                    let expectedWidth = (after?.width ?? 0) + fixture.frame.width - frameBeforeResize.width
                    checks["windowResizeTracked"] = after != nil && (WindowTracker.windows().first { $0.id == id }.map { abs($0.width - expectedWidth) < 2 } ?? false)
                    checks["animationProducedParticles"] = overlays.displays.contains { !$0.view.simulation.particles.isEmpty }
                    checkDisplayTransfer(fixture: fixture, overlays: overlays) { transferred in
                        if let transferred { checks["accumulationFollowsWindowBetweenDisplays"] = transferred }
                        checkFocusedWindowOption(fixture: fixture, delegate: delegate) { focusChecks in
                        checks.merge(focusChecks) { _, new in new }
                        checks.merge(checkDecorativeModes(delegate: delegate)) { _, new in new }
                        checkFullScreenOption(fixture: fixture, delegate: delegate) { fullScreenChecks in
                        checks.merge(fullScreenChecks) { _, new in new }
                        checkNativeFullScreen(fixture: fixture, delegate: delegate) { nativeChecks in
                        checks.merge(nativeChecks) { _, new in new }
                        delegate.preferences.paused = true
                        checks["pauseHidesOverlays"] = overlays.displays.allSatisfy { !$0.panel.isVisible }
                        delegate.preferences.paused = false
                        checks["resumeShowsOverlays"] = overlays.displays.allSatisfy { $0.panel.isVisible }
                        overlays.clear()
                        checks["clearRemovesAccumulation"] = overlays.displays.allSatisfy { $0.view.simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } } }
                        fixture.close()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            overlays.refreshSurfaces()
                            checks["closedWindowRemoved"] = overlays.displays.allSatisfy { !$0.view.simulation.surfaces.contains { $0.id == id } }
                            checkControllerAccess(delegate: delegate) { controllerChecks in
                                checks.merge(controllerChecks) { _, new in new }
                                DisplaySelectionValidation.run(overlays: overlays) { displayChecks in
                                    checks.merge(displayChecks) { _, new in new }
                                    writeSmoke(checks: checks, output: output)
                                    NSApp.terminate(nil)
                                }
                            }
                        }
                        }
                        }
                        }
                    }
                }
            }
        }
    }

    /// Exercises the actual menu actions and window lifecycle. This does not
    /// synthesize physical clicks on the system Dock or menu bar.
    private static func checkControllerAccess(delegate: AppDelegate,
                                              completion: @escaping ([String: Bool]) -> Void) {
        let settingsAction = #selector(AppDelegate.showSettings)
        func settingsItem(in menu: NSMenu?) -> NSMenuItem? {
            guard let menu else { return nil }
            for item in menu.items {
                if item.action == settingsAction { return item }
                if let nested = settingsItem(in: item.submenu) { return nested }
            }
            return nil
        }
        func invoke(_ item: NSMenuItem?) -> Bool {
            guard let item, let action = item.action else { return false }
            return NSApp.sendAction(action, to: item.target, from: item)
        }
        let appItem = settingsItem(in: NSApp.mainMenu)
        let statusItem = settingsItem(in: delegate.statusItem?.menu)
        let dockItem = settingsItem(in: delegate.applicationDockMenu(NSApp))
        var checks: [String: Bool] = [
            "dockActivationEnabled": NSApp.activationPolicy() == .regular
                && (Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool) != true,
            "menuBarControllerAvailable": delegate.statusItem?.isVisible == true
                && (delegate.statusItem?.button?.image != nil || !(delegate.statusItem?.button?.title ?? "").isEmpty),
            "applicationSettingsShortcutAvailable": appItem?.keyEquivalent == ","
                && appItem?.keyEquivalentModifierMask == .command
        ]
        delegate.settingsWindow?.close()
        let appActionSent = invoke(appItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let controller = delegate.settingsWindow else {
                checks["applicationMenuOpensController"] = false
                completion(checks)
                return
            }
            checks["applicationMenuOpensController"] = appActionSent && controller.isVisible
            controller.close()
            let statusActionSent = invoke(statusItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                checks["statusMenuReopensController"] = statusActionSent && controller.isVisible
                    && delegate.settingsWindow === controller
                controller.close()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    checks["closedControllerKeepsWeatherRunning"] = !controller.isVisible
                        && (delegate.overlays?.displays.allSatisfy { $0.panel.isVisible } ?? false)
                    let dockActionSent = invoke(dockItem)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        checks["dockMenuReopensController"] = dockActionSent && controller.isVisible
                            && delegate.settingsWindow === controller
                        controller.miniaturize(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            let wasMiniaturized = controller.isMiniaturized
                            let handled = delegate.applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                checks["dockReopenRestoresMinimizedController"] = wasMiniaturized && handled
                                    && !controller.isMiniaturized && controller.isVisible
                                    && delegate.settingsWindow === controller
                                checks["controllerIsKeyAfterReopen"] = controller.isKeyWindow
                                checks["controllerVisibleOnConnectedDisplay"] = NSScreen.screens.contains {
                                    $0.visibleFrame.intersects(controller.frame)
                                }
                                smokeDiagnostics["controllerAccess"] = [
                                    "activationPolicy": NSApp.activationPolicy().rawValue,
                                    "statusItemVisible": delegate.statusItem?.isVisible ?? false,
                                    "settingsFrame": [controller.frame.minX, controller.frame.minY,
                                                      controller.frame.width, controller.frame.height],
                                    "wasMiniaturized": wasMiniaturized,
                                    "note": "AppKit menu-action dispatch and reopen callbacks; physical Dock/menu-bar clicks are not injected."
                                ]
                                controller.close()
                                completion(checks)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func checkFocusedWindowOption(fixture: NSWindow, delegate: AppDelegate,
                                                 completion: @escaping ([String: Bool]) -> Void) {
        guard let overlays = delegate.overlays else { completion(["focusedWindowOverlaysAvailable": false]); return }
        let originalOption = delegate.preferences.showEffectsOnFocusedWindow
        let second = NSWindow(contentRect: fixture.frame.offsetBy(dx: 50, dy: 40),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        second.title = "Window Weather · focus validation"
        second.isReleasedWhenClosed = false
        second.orderFront(nil)
        fixture.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        delegate.preferences.showEffectsOnFocusedWindow = false
        var checks: [String: Bool] = [:]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let firstID = UInt32(fixture.windowNumber)
            let hidden = overlays.displays.compactMap { $0.view.hiddenFocusedWindow?.id }
            checks["focusedWindowOffHidesActiveWindow"] = !hidden.isEmpty && hidden.allSatisfy { $0 == firstID }
            checks["focusedWindowOffPreservesSurface"] = overlays.displays.contains {
                $0.view.simulation.surfaces.contains { $0.id == firstID }
            }
            second.makeKeyAndOrderFront(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let secondID = UInt32(second.windowNumber)
                let switched = overlays.displays.compactMap { $0.view.hiddenFocusedWindow?.id }
                checks["focusedWindowMaskFollowsKeyWindow"] = !switched.isEmpty && switched.allSatisfy { $0 == secondID }
                delegate.preferences.showEffectsOnFocusedWindow = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checks["focusedWindowOnRestoresAllEffects"] = overlays.displays.allSatisfy { $0.view.hiddenFocusedWindow == nil }
                    second.close()
                    fixture.makeKeyAndOrderFront(nil)
                    delegate.preferences.showEffectsOnFocusedWindow = originalOption
                    completion(checks)
                }
            }
        }
    }

    private static func checkNativeFullScreen(fixture: NSWindow, delegate: AppDelegate,
                                               completion: @escaping ([String: Bool]) -> Void) {
        guard let overlays = delegate.overlays else { completion(["nativeFullScreenAvailable": false]); return }
        let id = UInt32(fixture.windowNumber)
        transitionFullScreen(fixture, entering: true) { entered in
            guard entered else { completion(["nativeFullScreenEntered": false]); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                overlays.refreshSurfaces()
                recordWindowGeometry(fixture, overlays: overlays, key: "nativeFullScreenGeometry")
                var checks = ["nativeFullScreenEntered": true,
                              "nativeFullScreenOffExcludesSurface": overlays.displays.allSatisfy { !$0.view.simulation.surfaces.contains { $0.id == id } }]
                delegate.preferences.accumulateOnFullScreen = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    checks["nativeFullScreenOnRestoresVisibleSurface"] = overlays.displays.contains {
                        $0.view.simulation.surfaces.contains { $0.id == id && $0.y >= 20 }
                    }
                    delegate.preferences.accumulateOnFullScreen = false
                    transitionFullScreen(fixture, entering: false) { exited in
                        checks["nativeFullScreenExited"] = exited
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { completion(checks) }
                    }
                }
            }
        }
    }

    private static func transitionFullScreen(_ window: NSWindow, entering: Bool,
                                            completion: @escaping (Bool) -> Void) {
        let name: Notification.Name = entering ? NSWindow.didEnterFullScreenNotification : NSWindow.didExitFullScreenNotification
        let diagnosticKey = entering ? "nativeFullScreenEntryCompletion" : "nativeFullScreenExitCompletion"
        // A style-mask change starts during toggleFullScreen; it is not proof
        // that the window server has finished changing Spaces or geometry.
        guard window.styleMask.contains(.fullScreen) != entering else {
            smokeDiagnostics[diagnosticKey] = "unexpectedInitialStyleMask"
            completion(false)
            return
        }
        var observer: NSObjectProtocol?
        var timeout: DispatchWorkItem?
        var completed = false
        func finish(_ success: Bool) {
            guard !completed else { return }
            completed = true
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            timeout?.cancel()
            timeout = nil
            smokeDiagnostics[diagnosticKey] = success ? name.rawValue : "notificationTimeout"
            completion(success)
        }
        // Install first, so even an immediate completion cannot be missed.
        observer = NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { _ in
            finish(true)
        }
        let deadline = DispatchWorkItem { finish(false) }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: deadline)
        window.toggleFullScreen(nil)
    }

    private static func checkDecorativeModes(delegate: AppDelegate) -> [String: Bool] {
        guard let overlays = delegate.overlays else { return ["decorativeModesAvailable": false] }
        let previous = delegate.preferences.mode
        var checks: [String: Bool] = [:]
        for mode in WeatherMode.allCases where mode.hasSettledParticles {
            delegate.preferences.mode = mode
            for display in overlays.displays {
                for _ in 0..<300 { display.view.simulation.update(deltaTime: 0.1) }
            }
            checks["\(mode.rawValue)FallsAndSettles"] = overlays.displays.contains {
                $0.view.simulation.mode == mode && !$0.view.simulation.particles.isEmpty && !$0.view.simulation.settledParticles.isEmpty
            }
            overlays.clear()
            checks["\(mode.rawValue)ClearRemovesShapes"] = overlays.displays.allSatisfy { $0.view.simulation.settledParticles.isEmpty }
        }
        delegate.preferences.mode = previous
        return checks
    }

    /// Exercises an actual work-area-filling window; dedicated full-screen Space
    /// transitions remain distinct from this geometry/option integration check.
    private static func checkFullScreenOption(fixture: NSWindow, delegate: AppDelegate,
                                              completion: @escaping ([String: Bool]) -> Void) {
        guard let overlays = delegate.overlays, let screen = fixture.screen,
              let display = overlays.displays.first(where: { $0.screen == screen }) else {
            completion(["fullScreenOptionFixtureAvailable": false]); return
        }
        let id = UInt32(fixture.windowNumber)
        var checks = ["fullScreenAccumulationDefaultsOff": !delegate.preferences.accumulateOnFullScreen]
        fixture.setFrame(screen.visibleFrame, display: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            overlays.refreshSurfaces()
            recordWindowGeometry(fixture, overlays: overlays, key: "maximizedGeometry")
            checks["fullScreenOffExcludesWindowAndFloor"] = !display.view.simulation.surfaces.contains { $0.id == id || $0.id == 0 }
            checks["fullScreenWindowRemainsOccluder"] = display.view.windowGeometry.contains { $0.id == id }
            checks["fullScreenOccluderIsSquare"] = display.view.windowGeometry.first { $0.id == id }?.cornerRadius == 0
            delegate.preferences.accumulateOnFullScreen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Let the preference subscription refresh without a direct call.
                checks["fullScreenOnRestoresSurface"] = display.view.simulation.surfaces.contains { $0.id == id }
                for _ in 0..<240 { display.view.simulation.update(deltaTime: 0.1) }
                checks["fullScreenOnAccumulates"] = display.view.simulation.piles.first { $0.surfaceID == id }?.heights.contains { $0 > 0 } ?? false
                delegate.preferences.accumulateOnFullScreen = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checks["fullScreenOffRemovesExistingAccumulation"] = !display.view.simulation.piles.contains { $0.surfaceID == id || $0.surfaceID == 0 }
                    completion(checks)
                }
            }
        }
    }

    private static func recordWindowGeometry(_ window: NSWindow, overlays: OverlayController, key: String) {
        let id = UInt32(window.windowNumber)
        let windows = WindowTracker.windows()
        smokeDiagnostics[key] = overlays.displays.map { display -> [String: Any] in
            let local = WindowTracker.localWindows(windows, screen: display.screen).first { $0.id == id }
            let frame = display.screen.frame
            let visible = display.screen.visibleFrame
            return ["screen": [frame.minX, frame.minY, frame.width, frame.height],
                    "visible": [visible.minX, visible.minY, visible.width, visible.height],
                    "windowFrame": [window.frame.minX, window.frame.minY, window.frame.width, window.frame.height],
                    "localBounds": local.map { [$0.x, $0.y, $0.width, $0.height] } ?? [],
                    "classified": local.map { WindowTracker.fullScreenPolicy(screen: display.screen).isScreenFilling($0) } ?? false]
        }
    }

    private static func checkDisplayTransfer(fixture: NSWindow, overlays: OverlayController, completion: @escaping (Bool?) -> Void) {
        let center = NSPoint(x: fixture.frame.midX, y: fixture.frame.midY)
        guard let source = overlays.displays.first(where: { $0.screen.frame.contains(center) }),
              let target = overlays.displays.first(where: { $0.screen != source.screen }) else {
            completion(nil) // A single-display host cannot exercise this integration.
            return
        }
        let id = UInt32(fixture.windowNumber)
        overlays.refreshSurfaces()
        // Seed a known pile independently of other apps covering the fixture.
        // The integration under test is its transfer through the real window tracker.
        let seed = WeatherSimulation(width: fixture.frame.width, height: 100, seed: 735)
        seed.setSurfaces([Surface(id: id, x: 0, y: 10, width: fixture.frame.width)])
        seed.intensity = 1
        for _ in 0..<200 { seed.update(deltaTime: 0.1) }
        source.view.simulation.inheritAccumulation(from: seed.piles)
        let before = source.view.simulation.piles.first { $0.surfaceID == id }?.heights.reduce(0, +) ?? 0
        fixture.setFrameOrigin(NSPoint(x: target.screen.visibleFrame.midX - fixture.frame.width / 2,
                                       y: target.screen.visibleFrame.midY - fixture.frame.height / 2))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            overlays.refreshSurfaces()
            let after = target.view.simulation.piles.first { $0.surfaceID == id }?.heights.reduce(0, +) ?? 0
            smokeDiagnostics["displayTransfer"] = ["before": before, "after": after,
                "targetContainsWindowCenter": target.screen.frame.contains(NSPoint(x: fixture.frame.midX, y: fixture.frame.midY))]
            completion(before > 0 && after >= before * 0.9)
        }
    }

    private static func writeSmoke(checks: [String: Bool], output: String, blockedReason: String? = nil) {
        let passed = blockedReason == nil && checks.values.allSatisfy { $0 }
        var object: [String: Any] = [
            "status": blockedReason == nil ? (passed ? "passed" : "failed") : "blocked",
            "passed": passed, "checks": checks,
            "diagnostics": smokeDiagnostics,
            "note": "Synthetic native window + public metadata. Flags verify click-through configuration, not physical mouse interaction."
        ]
        if let blockedReason {
            object["blockedReason"] = blockedReason
        } else {
            object["displayCount"] = NSScreen.screens.count
            object["observedWindowCountAfterFixtureClosed"] = WindowTracker.windows().count
        }
        do {
            let url = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        } catch { fputs("Smoke report failed: \(error)\n", stderr) }
    }
}
