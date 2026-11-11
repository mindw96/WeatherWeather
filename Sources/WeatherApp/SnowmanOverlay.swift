import AppKit
import WeatherCore

/// A small interactive panel; the full-display weather panel stays click-through.
final class SnowmanOverlay {
    let panel: SnowmanPanel
    let view: SnowmanView
    private let screen: NSScreen
    private let preferences: Preferences
    private let displayID: String
    private var dragOrigin: CGPoint?
    private var dragFrame: CGRect?
    private var hiddenWindow: WindowGeometry?
    private var hiddenWindows: [WindowGeometry] = []
    private var windowGeometry: [WindowGeometry] = []
    private var exclusionPaths: [CGPath] = []
    private(set) var isDragging = false

    init(screen: NSScreen, preferences: Preferences) {
        self.screen = screen
        self.preferences = preferences
        let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        let serial = CGDisplaySerialNumber(number)
        displayID = "\(CGDisplayVendorNumber(number))-\(CGDisplayModelNumber(number))-\(serial == 0 ? number : serial)"
        let local = SnowmanRenderer.frame(in: CGRect(origin: .zero, size: screen.frame.size), appearance: preferences.snowmanAppearance)
        let initial = CGRect(x: screen.frame.minX + local.minX, y: screen.frame.maxY - local.maxY,
                             width: local.width, height: local.height)
        let frame = preferences.snowmanPosition(for: displayID)?.frame(in: screen.frame, size: local.size) ?? initial
        panel = SnowmanPanel(contentRect: frame)
        view = SnowmanView(frame: CGRect(origin: .zero, size: frame.size))
        view.snowmanAppearance = preferences.snowmanAppearance
        panel.contentView = view
        view.onDown = { [weak self] point in self?.beginDrag(at: point) }
        view.onDrag = { [weak self] point in self?.drag(to: point) }
        view.onUp = { [weak self] in self?.endDrag() }
    }

    func update(running: Bool, mode: WeatherMode, enabled: Bool, hiddenWindow: WindowGeometry?,
                appearance: SnowmanAppearance = .init(), hiddenWindows: [WindowGeometry] = [],
                windowGeometry: [WindowGeometry] = []) {
        self.hiddenWindow = hiddenWindow
        if self.hiddenWindows != hiddenWindows || self.windowGeometry != windowGeometry {
            self.hiddenWindows = hiddenWindows
            self.windowGeometry = windowGeometry
            exclusionPaths = WindowExclusionMask.paths(excluding: hiddenWindows, orderedWindows: windowGeometry)
        }
        if view.snowmanAppearance != appearance {
            endDrag()
            let position = SnowmanPosition.normalized(frame: panel.frame, in: screen.frame)
            let size = SnowmanRenderer.frame(in: CGRect(origin: .zero, size: screen.frame.size), appearance: appearance).size
            if let position {
                panel.setFrame(position.frame(in: screen.frame, size: size), display: false)
                view.setFrameSize(size)
            }
            view.snowmanAppearance = appearance
            view.needsDisplay = true
        }
        updateMask()
        if running && mode == .snow && enabled {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else {
            endDrag()
            panel.orderOut(nil)
        }
        updateHitTesting()
    }

    func updateHitTesting() {
        if isDragging, NSEvent.pressedMouseButtons & 1 == 0 { endDrag() }
        let pointer = NSEvent.mouseLocation
        let local = CGPoint(x: pointer.x - panel.frame.minX, y: panel.frame.maxY - pointer.y)
        let ignoresMouse = !panel.isVisible || (!isDragging && !view.canGrab(at: local))
        if panel.ignoresMouseEvents != ignoresMouse { panel.ignoresMouseEvents = ignoresMouse }
    }

    // These methods also allow deterministic tests of drag translation and saving.
    func beginDrag(at point: CGPoint) {
        dragOrigin = point
        dragFrame = panel.frame
        isDragging = true
        panel.ignoresMouseEvents = false
    }

    func drag(to point: CGPoint) {
        guard let origin = dragOrigin, let frame = dragFrame else { return }
        let proposed = frame.offsetBy(dx: point.x - origin.x, dy: point.y - origin.y)
        guard let normalized = SnowmanPosition.normalized(frame: proposed, in: screen.frame) else { return }
        panel.setFrame(normalized.frame(in: screen.frame, size: frame.size), display: true)
        updateMask()
    }

    func endDrag() {
        guard isDragging else { return }
        isDragging = false
        dragOrigin = nil
        dragFrame = nil
        if let position = SnowmanPosition.normalized(frame: panel.frame, in: screen.frame) {
            preferences.setSnowmanPosition(position, for: displayID)
        }
        updateHitTesting()
    }

    private func updateMask() {
        func localRect(_ hidden: WindowGeometry) -> CGRect {
            let globalTop = screen.frame.maxY - hidden.y
            return CGRect(x: screen.frame.minX + hidden.x - panel.frame.minX,
                          y: panel.frame.maxY - globalTop, width: hidden.width, height: hidden.height)
        }
        let mask = hiddenWindow.map(localRect)
        var translation = CGAffineTransform(translationX: screen.frame.minX - panel.frame.minX,
                                             y: panel.frame.maxY - screen.frame.maxY)
        let paths = exclusionPaths.compactMap { $0.copy(using: &translation) }
        if view.hiddenRect != mask || view.hiddenPaths != paths {
            view.hiddenRect = mask
            view.hiddenPaths = paths
            view.needsDisplay = true
        }
    }

    func close() {
        endDrag()
        panel.close()
    }
}

final class SnowmanPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
    }
}

final class SnowmanView: NSView {
    var hiddenRect: CGRect?
    var hiddenRects: [CGRect] = []
    var hiddenPaths: [CGPath] = []
    var snowmanAppearance = SnowmanAppearance()
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: (() -> Void)?
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override var needsPanelToBecomeKey: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func canGrab(at point: CGPoint) -> Bool {
        !(hiddenRect?.contains(point) ?? false) && !hiddenRects.contains(where: { $0.contains(point) })
            && !hiddenPaths.contains(where: { $0.contains(point) })
            && SnowmanRenderer.contains(point, in: bounds)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.saveGState()
        defer { context.restoreGState() }
        for rect in hiddenRects + (hiddenRect.map { [$0] } ?? []) {
            let cover = rect.intersection(bounds)
            guard !cover.isNull, !cover.isEmpty else { continue }
            context.addRect(bounds)
            context.addRect(cover)
            context.clip(using: .evenOdd)
        }
        for path in hiddenPaths {
            context.addRect(bounds)
            context.addPath(path)
            context.clip(using: .evenOdd)
        }
        SnowmanRenderer.draw(in: context, frame: bounds, appearance: snowmanAppearance)
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }

    override func mouseDown(with event: NSEvent) {
        guard canGrab(at: convert(event.locationInWindow, from: nil)), let window else { return }
        onDown?(window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        onDrag?(window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) { onUp?() }
}
