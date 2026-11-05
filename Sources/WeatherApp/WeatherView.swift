import AppKit
import WeatherCore

final class WeatherView: NSView {
    let simulation: WeatherSimulation
    var demoBackground = false
    var windowGeometry: [WindowGeometry] = []
    var hiddenFocusedWindow: WindowGeometry?
    // Used by previews. Desktop snowmen use their own small draggable panels.
    var showSnowman = true
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init(frame: NSRect, seed: UInt64 = 42) {
        simulation = WeatherSimulation(width: frame.width, height: frame.height, seed: seed)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        if demoBackground { drawDemo(in: context) }
        context.saveGState()
        defer { context.restoreGState() }
        if let hidden = hiddenFocusedWindow {
            // Clip entire shapes, including rain streaks and rotating leaves that
            // cross the boundary, rather than testing particle centers alone.
            let covered = bounds.intersection(CGRect(x: hidden.x, y: hidden.y,
                                                    width: hidden.width, height: hidden.height))
            if !covered.isNull, !covered.isEmpty {
                let visible = CGMutablePath()
                visible.addRect(bounds)
                visible.addRect(covered)
                context.addPath(visible)
                context.clip(using: .evenOdd)
            }
        }
        context.setLineCap(.round)
        let settledBySurface = Dictionary(grouping: simulation.settledParticles, by: \.surfaceID)

        for pile in simulation.piles {
            // Mounds and settled shapes extend above the window's rectangle.
            guard pile.surfaceID != hiddenFocusedWindow?.id else { continue }
            let settled = settledBySurface[pile.surfaceID] ?? []
            guard simulation.mode.isSeasonal ? !settled.isEmpty : pile.heights.contains(where: { $0 > 0.01 }) else { continue }
            context.saveGState()
            let clip = CGMutablePath()
            let foreground = pile.surfaceID == 0 ? windowGeometry[...] : windowGeometry.prefix { $0.id != pile.surfaceID }
            for segment in pile.segments {
                var regions = [CGRect(x: pile.x + segment.minX, y: pile.y - 36, width: segment.maxX - segment.minX, height: 44)]
                // Clip the full mound, including an occluder ending just above its baseline.
                for window in foreground {
                    let cover = CGRect(x: window.x, y: window.y, width: window.width, height: window.height)
                    regions = regions.flatMap { subtract(cover, from: $0) }
                }
                for region in regions { clip.addRect(region) }
            }
            context.addPath(clip)
            context.clip()
            if simulation.mode.isSeasonal {
                for item in settled {
                    drawSeasonal(in: context, mode: item.mode,
                                 x: pile.x + item.position * pile.width, y: pile.y - item.offsetY,
                                 size: item.size, rotation: item.rotation, variant: item.variant,
                                 opacity: min(1, item.life / 8), horizontalScale: 1)
                }
                context.restoreGState()
                continue
            }
            let step = pile.width / Double(max(1, pile.heights.count - 1))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: pile.x, y: pile.y + 0.4))
            for (index, height) in pile.heights.enumerated() {
                path.addLine(to: CGPoint(x: pile.x + Double(index) * step, y: pile.y - height))
            }
            path.addLine(to: CGPoint(x: pile.x + pile.width, y: pile.y + 0.4))
            path.closeSubpath()
            let snow = simulation.mode == .snow
            context.setFillColor((snow ? NSColor(calibratedRed: 0.94, green: 0.98, blue: 1, alpha: 0.96) : NSColor(calibratedRed: 0.48, green: 0.77, blue: 1, alpha: 0.46)).cgColor)
            context.addPath(path)
            context.fillPath()
            context.restoreGState()
        }

        if showSnowman, simulation.mode == .snow {
            SnowmanRenderer.draw(in: context, bounds: bounds)
        }

        for particle in simulation.particles {
            if simulation.mode.isSeasonal {
                let flip = 0.4 + 0.6 * abs(cos(particle.rotation * 0.7 + particle.phase))
                drawSeasonal(in: context, mode: simulation.mode,
                             x: particle.x, y: particle.y, size: particle.size,
                             rotation: particle.rotation, variant: particle.variant,
                             opacity: particle.opacity, horizontalScale: flip)
            } else if simulation.mode == .snow {
                context.setFillColor(NSColor(calibratedWhite: 1, alpha: particle.opacity).cgColor)
                context.fillEllipse(in: CGRect(x: particle.x - particle.size / 2, y: particle.y - particle.size / 2, width: particle.size, height: particle.size))
            } else {
                let length = 9 + particle.size * 4
                context.setStrokeColor(NSColor(calibratedRed: 0.68, green: 0.85, blue: 1, alpha: particle.opacity * 0.72).cgColor)
                context.setLineWidth(max(0.6, particle.size * 0.4))
                context.move(to: CGPoint(x: particle.x, y: particle.y))
                context.addLine(to: CGPoint(x: particle.x - particle.vx / max(1, particle.vy) * length, y: particle.y - length))
                context.strokePath()
            }
        }
        for splash in simulation.splashes {
            context.setFillColor(NSColor(calibratedRed: 0.72, green: 0.88, blue: 1, alpha: min(0.8, splash.life * 1.8)).cgColor)
            context.fillEllipse(in: CGRect(x: splash.x - 1, y: splash.y - 1, width: 2, height: 2.8))
        }
    }

    /// Original vector shapes; no textures or assets are needed for either season.
    private func drawSeasonal(in context: CGContext, mode: WeatherMode, x: Double, y: Double,
                              size: Double, rotation: Double, variant: Int,
                              opacity: Double, horizontalScale: Double) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.scaleBy(x: size * horizontalScale, y: size)
        if mode == .autumn {
            context.setFillColor(Self.autumnColors[abs(variant % Self.autumnColors.count)].withAlphaComponent(opacity).cgColor)
            context.addPath(variant % 3 == 2 ? Self.maplePath : Self.leafPath)
            context.fillPath()
            context.setStrokeColor(NSColor(calibratedRed: 0.36, green: 0.17, blue: 0.07, alpha: opacity * 0.52).cgColor)
            context.setLineWidth(0.045)
            context.move(to: CGPoint(x: 0, y: -0.42))
            context.addLine(to: CGPoint(x: 0.025, y: 0.68))
            context.move(to: CGPoint(x: 0, y: 0.04))
            context.addLine(to: CGPoint(x: 0.24, y: -0.16))
            context.move(to: CGPoint(x: 0, y: 0.18))
            context.addLine(to: CGPoint(x: -0.22, y: -0.03))
            context.strokePath()
        } else {
            context.setFillColor(Self.petalColors[abs(variant % Self.petalColors.count)].withAlphaComponent(opacity).cgColor)
            context.addPath(Self.petalPath)
            context.fillPath()
        }
        context.restoreGState()
    }

    // Geometry and base colors are identical for every particle and frame.
    private static let autumnColors = [
        NSColor(calibratedRed: 0.91, green: 0.37, blue: 0.12, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.19, alpha: 1),
        NSColor(calibratedRed: 0.74, green: 0.20, blue: 0.14, alpha: 1)
    ]
    private static let petalColors = [
        NSColor(calibratedRed: 1, green: 0.77, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.88, blue: 0.92, alpha: 1),
        NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.75, alpha: 1)
    ]
    private static let leafPath: CGPath = {
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: 0, y: -0.65))
        shape.addCurve(to: CGPoint(x: 0, y: 0.50), control1: CGPoint(x: 0.62, y: -0.25), control2: CGPoint(x: 0.46, y: 0.32))
        shape.addCurve(to: CGPoint(x: 0, y: -0.65), control1: CGPoint(x: -0.52, y: 0.21), control2: CGPoint(x: -0.41, y: -0.26))
        shape.closeSubpath()
        return shape
    }()
    private static let maplePath: CGPath = {
        let shape = CGMutablePath()
        let points: [CGPoint] = [
            .init(x: 0, y: -0.65), .init(x: 0.16, y: -0.28), .init(x: 0.34, y: -0.36),
            .init(x: 0.29, y: -0.04), .init(x: 0.55, y: -0.09), .init(x: 0.35, y: 0.20),
            .init(x: 0.41, y: 0.31), .init(x: 0.08, y: 0.36), .init(x: 0, y: 0.56),
            .init(x: -0.08, y: 0.36), .init(x: -0.41, y: 0.31), .init(x: -0.35, y: 0.20),
            .init(x: -0.55, y: -0.09), .init(x: -0.29, y: -0.04), .init(x: -0.34, y: -0.36),
            .init(x: -0.16, y: -0.28)
        ]
        shape.addLines(between: points)
        shape.closeSubpath()
        return shape
    }()
    private static let petalPath: CGPath = {
        let shape = CGMutablePath()
        // A petal's small notch and tapered base remain legible while tumbling.
        shape.move(to: CGPoint(x: 0, y: 0.60))
        shape.addCurve(to: CGPoint(x: -0.16, y: -0.54), control1: CGPoint(x: -0.57, y: 0.14), control2: CGPoint(x: -0.47, y: -0.64))
        shape.addLine(to: CGPoint(x: 0, y: -0.34))
        shape.addLine(to: CGPoint(x: 0.16, y: -0.54))
        shape.addCurve(to: CGPoint(x: 0, y: 0.60), control1: CGPoint(x: 0.47, y: -0.64), control2: CGPoint(x: 0.57, y: 0.14))
        shape.closeSubpath()
        return shape
    }()

    private func subtract(_ cover: CGRect, from source: CGRect) -> [CGRect] {
        let hit = source.intersection(cover)
        guard !hit.isNull, !hit.isEmpty else { return [source] }
        return [
            CGRect(x: source.minX, y: source.minY, width: source.width, height: hit.minY - source.minY),
            CGRect(x: source.minX, y: hit.maxY, width: source.width, height: source.maxY - hit.maxY),
            CGRect(x: source.minX, y: hit.minY, width: hit.minX - source.minX, height: hit.height),
            CGRect(x: hit.maxX, y: hit.minY, width: source.maxX - hit.maxX, height: hit.height)
        ].filter { $0.width > 0 && $0.height > 0 }
    }

    private func drawDemo(in context: CGContext) {
        context.setFillColor(NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.17, alpha: 1).cgColor)
        context.fill(bounds)
        for surface in simulation.surfaces where surface.id != 0 {
            let rect = CGRect(x: surface.x, y: surface.y, width: surface.width, height: bounds.height * 0.48)
            context.setFillColor(NSColor(calibratedRed: 0.13, green: 0.19, blue: 0.28, alpha: 1).cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: 10, cornerHeight: 10, transform: nil))
            context.fillPath()
            for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                context.setFillColor(color.withAlphaComponent(0.85).cgColor)
                context.fillEllipse(in: CGRect(x: rect.minX + 14 + Double(index) * 14, y: rect.minY + 13, width: 7, height: 7))
            }
            context.setFillColor(NSColor.white.withAlphaComponent(0.06).cgColor)
            for index in 0..<3 {
                context.fill(CGRect(x: rect.minX + 16, y: rect.minY + 45 + Double(index) * 20, width: rect.width * (index == 1 ? 0.6 : 0.78), height: 6))
            }
        }
    }
}

final class WeatherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        setAccessibilityElement(false)
    }
}
