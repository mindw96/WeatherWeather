import AppKit
import WeatherCore

enum WindowExclusionMask {
    static func paths(excluding windows: [WindowGeometry], orderedWindows: [WindowGeometry]) -> [CGPath] {
        windows.map { window in
            let rect = CGRect(x: window.x, y: window.y, width: window.width, height: window.height)
            var path = CGPath(rect: rect, transform: nil)
            if let index = orderedWindows.firstIndex(where: { $0.id == window.id }) {
                for front in orderedWindows.prefix(index) {
                    let cover = CGRect(x: front.x, y: front.y, width: front.width, height: front.height)
                    guard rect.intersects(cover) else { continue }
                    path = path.subtracting(CGPath(roundedRect: cover, cornerWidth: front.cornerRadius,
                                                   cornerHeight: front.cornerRadius, transform: nil))
                }
            }
            return path
        }
    }
}

final class WeatherView: NSView {
    let simulation: WeatherSimulation
    var demoBackground = false
    var windowGeometry: [WindowGeometry] = [] {
        didSet { if oldValue != windowGeometry { rebuildExclusions() } }
    }
    var hiddenFocusedWindow: WindowGeometry?
    var hiddenWindows: [WindowGeometry] = [] {
        didSet { if oldValue != hiddenWindows { rebuildExclusions() } }
    }
    private var excludedPaths: [CGPath] = []
    // Used by previews. Desktop snowmen use their own small draggable panels.
    var showSnowman = true
    var snowmanAppearance = SnowmanAppearance()
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    init(frame: NSRect, seed: UInt64 = 42) {
        simulation = WeatherSimulation(width: frame.width, height: frame.height, seed: seed)
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func rebuildExclusions() {
        excludedPaths = WindowExclusionMask.paths(excluding: hiddenWindows, orderedWindows: windowGeometry)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        if demoBackground { drawDemo(in: context) }
        context.saveGState()
        defer { context.restoreGState() }
        let excluded = hiddenWindows + (hiddenFocusedWindow.map { [$0] } ?? [])
        let excludedIDs = Set(excluded.map(\.id))
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
        let ripplesBySurface = Dictionary(grouping: simulation.ripples, by: \.surfaceID)
        let dropsBySurface = Dictionary(grouping: simulation.rainDrops, by: \.surfaceID)

        // Paint rear accumulation first, just like the windows carrying it.
        for pile in simulation.piles.reversed() {
            // Mounds and settled shapes extend above the window's rectangle.
            guard !excludedIDs.contains(pile.surfaceID) else { continue }
            let settled = settledBySurface[pile.surfaceID] ?? []
            let ripples = ripplesBySurface[pile.surfaceID] ?? []
            let drops = dropsBySurface[pile.surfaceID] ?? []
            guard simulation.mode.hasSettledParticles ? !settled.isEmpty
                : pile.heights.contains(where: { $0 > 0.01 }) || !ripples.isEmpty || !drops.isEmpty else { continue }
            context.saveGState()
            let band = CGRect(x: pile.x, y: pile.y - 36, width: pile.width, height: 44 + pile.cornerRadius)
            context.clip(to: band)
            let foreground = pile.surfaceID == 0 ? windowGeometry[...] : windowGeometry.prefix { $0.id != pile.surfaceID }
            // Baseline collision intervals cannot describe visibility above a mound.
            for window in foreground {
                let cover = CGRect(x: window.x, y: window.y, width: window.width, height: window.height)
                guard band.intersects(cover) else { continue }
                let visible = CGMutablePath()
                visible.addRect(band)
                visible.addRoundedRect(in: cover, cornerWidth: window.cornerRadius, cornerHeight: window.cornerRadius)
                context.addPath(visible)
                // Sequential clips subtract the union; one even-odd path would reopen overlaps.
                context.clip(using: .evenOdd)
            }
            guard !context.boundingBoxOfClipPath.isEmpty else { context.restoreGState(); continue }
            if simulation.mode.hasSettledParticles {
                for item in settled {
                    let localX = item.position * pile.width
                    let restingY = pile.baselineY(at: localX) - item.offsetY
                    if item.mode == .bubbles {
                        let pop = max(0, 1 - item.life / 0.45)
                        drawBubble(in: context, x: pile.x + localX,
                                   y: restingY, size: item.size * (1 + pop * 0.22),
                                   opacity: 0.85 * (1 - pop))
                    } else if item.mode.isGlowing {
                        drawGlow(in: context, mode: item.mode, x: pile.x + localX, y: restingY,
                                 size: item.size, rotation: item.rotation, variant: item.variant,
                                 opacity: min(1, item.life / 0.8), phase: item.life * 3 + Double(item.id % 19))
                    } else {
                        drawSeasonal(in: context, mode: item.mode,
                                     x: pile.x + localX, y: restingY,
                                     size: item.size, rotation: item.rotation, variant: item.variant,
                                     opacity: min(1, item.life / 8), horizontalScale: 1)
                    }
                }
                context.restoreGState()
                continue
            }
            let step = pile.width / Double(max(1, pile.heights.count - 1))
            let path = CGMutablePath()
            path.move(to: CGPoint(x: pile.x, y: pile.baselineY(at: 0) + 0.4))
            for (index, height) in pile.heights.enumerated() {
                let localX = Double(index) * step
                path.addLine(to: CGPoint(x: pile.x + localX, y: pile.baselineY(at: localX) - height))
            }
            // Close along the same curve so the underside cannot bridge the empty corner.
            for index in pile.heights.indices.reversed() {
                let localX = Double(index) * step
                path.addLine(to: CGPoint(x: pile.x + localX, y: pile.baselineY(at: localX) + 0.4))
            }
            path.closeSubpath()
            let snow = simulation.mode == .snow
            context.setFillColor((snow ? NSColor(calibratedRed: 0.94, green: 0.98, blue: 1, alpha: 0.96) : NSColor(calibratedRed: 0.34, green: 0.68, blue: 0.98, alpha: 0.46)).cgColor)
            context.addPath(path)
            context.fillPath()
            if !snow {
                drawRainDetails(in: context, pile: pile, ripples: ripples, drops: drops)
            }
            context.restoreGState()
        }

        // Foreground piles may rise above their own frames into an excluded rear
        // window. They already obey window order; only free objects use this mask.
        for path in excludedPaths {
            context.addRect(bounds)
            context.addPath(path)
            context.clip(using: .evenOdd)
        }

        if showSnowman, simulation.mode == .snow {
            SnowmanRenderer.draw(in: context, bounds: bounds, appearance: snowmanAppearance)
        }

        for particle in simulation.particles {
            if simulation.mode == .bubbles {
                drawBubble(in: context, x: particle.x, y: particle.y,
                           size: particle.size, opacity: particle.opacity)
            } else if simulation.mode.isGlowing {
                drawGlow(in: context, mode: simulation.mode, x: particle.x, y: particle.y,
                         size: particle.size, rotation: particle.rotation, variant: particle.variant,
                         opacity: particle.opacity * min(1, particle.life), phase: particle.phase + particle.life * 3)
            } else if simulation.mode.hasSettledParticles {
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
                context.setStrokeColor(NSColor(calibratedRed: 0.48, green: 0.75, blue: 1, alpha: particle.opacity * 0.72).cgColor)
                context.setLineWidth(max(0.6, particle.size * 0.4))
                context.move(to: CGPoint(x: particle.x, y: particle.y))
                context.addLine(to: CGPoint(x: particle.x - particle.vx / max(1, particle.vy) * length, y: particle.y - length))
                context.strokePath()
            }
        }
        for splash in simulation.splashes {
            let snow = simulation.mode == .snow
            context.setFillColor((snow ? NSColor.white.withAlphaComponent(min(0.95, splash.life * 2))
                                 : NSColor(calibratedRed: 0.52, green: 0.78, blue: 1, alpha: min(0.8, splash.life * 1.8))).cgColor)
            let width = snow ? splash.size : splash.size / 1.2 * 2
            context.fillEllipse(in: CGRect(x: splash.x - width / 2, y: splash.y - width / 2,
                                          width: width, height: snow ? width : width * 1.4))
        }
    }

    private func drawRainDetails(in context: CGContext, pile: Pile, ripples: [RainRipple], drops: [RainDrop]) {
        for ripple in ripples {
            let x = ripple.position * pile.width
            let y = pile.baselineY(at: x) - pile.height(at: x)
            context.setStrokeColor(NSColor(calibratedRed: 0.19, green: 0.59, blue: 0.94,
                                           alpha: min(0.65, ripple.life)).cgColor)
            context.setLineWidth(0.8)
            context.strokeEllipse(in: CGRect(x: pile.x + x - ripple.radius, y: y - ripple.radius * 0.3,
                                             width: ripple.radius * 2, height: ripple.radius * 0.6))
        }
        for drop in drops {
            let x = drop.position * pile.width
            let y = pile.baselineY(at: x) - pile.height(at: x) - drop.size * 0.55
            let rect = CGRect(x: pile.x + x - drop.size, y: y - drop.size,
                              width: drop.size * 2, height: drop.size * 1.6)
            context.setFillColor(NSColor(calibratedRed: 0.27, green: 0.65, blue: 0.97, alpha: 0.55).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(NSColor(calibratedRed: 0.10, green: 0.46, blue: 0.82, alpha: 0.6).cgColor)
            context.setLineWidth(0.55)
            context.strokeEllipse(in: rect)
            context.setFillColor(NSColor.white.withAlphaComponent(0.8).cgColor)
            context.fillEllipse(in: CGRect(x: rect.minX + drop.size * 0.4, y: rect.minY + drop.size * 0.25,
                                          width: max(0.7, drop.size * 0.65), height: max(0.5, drop.size * 0.3)))
        }
    }

    private func drawGlow(in context: CGContext, mode: WeatherMode, x: Double, y: Double,
                          size: Double, rotation: Double, variant: Int, opacity: Double, phase: Double) {
        context.saveGState()
        defer { context.restoreGState() }
        let pulse = 0.55 + 0.45 * (0.5 + 0.5 * sin(phase))
        context.setAlpha(opacity * pulse)
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.scaleBy(x: size, y: size)
        let silver = mode == .stardust && variant % 2 == 1
        if let gradient = silver ? Self.silverGlow : Self.warmGlow {
            context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                       endCenter: .zero, endRadius: mode == .fireflies ? 2.4 : 1.35, options: [])
        }
        if mode == .fireflies {
            context.setFillColor(NSColor(calibratedRed: 0.98, green: 1, blue: 0.62, alpha: 0.95).cgColor)
            context.fillEllipse(in: CGRect(x: -0.36, y: -0.36, width: 0.72, height: 0.72))
        } else {
            context.setFillColor((silver ? NSColor(calibratedRed: 0.86, green: 0.94, blue: 1, alpha: 1)
                                 : NSColor(calibratedRed: 1, green: 0.85, blue: 0.42, alpha: 1)).cgColor)
            context.addPath(Self.starPath)
            context.fillPath()
            context.setStrokeColor((silver ? NSColor(calibratedRed: 0.42, green: 0.55, blue: 0.70, alpha: 0.65)
                                   : NSColor(calibratedRed: 0.65, green: 0.43, blue: 0.12, alpha: 0.55)).cgColor)
            context.setLineWidth(0.07)
            context.addPath(Self.starPath)
            context.strokePath()
        }
    }

    private static let warmGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(calibratedRed: 0.95, green: 1, blue: 0.40, alpha: 0.55).cgColor,
        NSColor(calibratedRed: 0.95, green: 0.88, blue: 0.25, alpha: 0).cgColor
    ] as CFArray, locations: [0, 1])
    private static let silverGlow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(calibratedRed: 0.78, green: 0.91, blue: 1, alpha: 0.4).cgColor,
        NSColor(calibratedRed: 0.78, green: 0.91, blue: 1, alpha: 0).cgColor
    ] as CFArray, locations: [0, 1])
    private static let starPath: CGPath = {
        let path = CGMutablePath()
        for index in 0..<10 {
            let angle = Double(index) * .pi / 5 - .pi / 2
            let radius = index.isMultiple(of: 2) ? 0.6 : 0.26
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }()

    /// Original vector shapes share the existing fall and settlement rendering path.
    private func drawSeasonal(in context: CGContext, mode: WeatherMode, x: Double, y: Double,
                              size: Double, rotation: Double, variant: Int,
                              opacity: Double, horizontalScale: Double) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.scaleBy(x: size * horizontalScale, y: size)
        if mode == .confetti {
            context.setFillColor(Self.confettiColors[abs(variant % Self.confettiColors.count)].withAlphaComponent(opacity).cgColor)
            context.addPath(Self.confettiPaths[abs(variant % Self.confettiPaths.count)])
            context.fillPath()
        } else if mode == .autumn {
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

    private func drawBubble(in context: CGContext, x: Double, y: Double,
                            size: Double, opacity: Double) {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.scaleBy(x: size, y: size)
        context.setAlpha(opacity)
        context.setFillColor(Self.bubbleFilm)
        context.addPath(Self.bubbleOutline)
        context.fillPath()
        context.setLineWidth(max(0.75 / size, 0.045))
        context.setStrokeColor(Self.bubbleRim)
        context.addPath(Self.bubbleOutline)
        context.strokePath()
        context.setStrokeColor(Self.bubbleCyan)
        context.addPath(Self.bubbleCyanArc)
        context.strokePath()
        context.setStrokeColor(Self.bubblePink)
        context.addPath(Self.bubblePinkArc)
        context.strokePath()
        context.setStrokeColor(Self.bubbleHighlight)
        context.setLineWidth(max(1 / size, 0.055))
        context.addPath(Self.bubbleHighlightArc)
        context.strokePath()
        context.restoreGState()
    }

    // Geometry and base colors are identical for every particle and frame.
    private static let bubbleFilm = NSColor(calibratedRed: 0.76, green: 0.91, blue: 1, alpha: 0.06).cgColor
    private static let bubbleRim = NSColor(calibratedRed: 0.77, green: 0.91, blue: 1, alpha: 0.56).cgColor
    private static let bubbleCyan = NSColor(calibratedRed: 0.35, green: 0.94, blue: 0.95, alpha: 0.82).cgColor
    private static let bubblePink = NSColor(calibratedRed: 1, green: 0.65, blue: 0.85, alpha: 0.78).cgColor
    private static let bubbleHighlight = NSColor(calibratedWhite: 1, alpha: 0.9).cgColor
    private static let bubbleOutline = CGPath(ellipseIn: CGRect(x: -0.5, y: -0.5, width: 1, height: 1), transform: nil)
    private static let bubbleCyanArc: CGPath = {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 0.5, startAngle: -.pi * 0.35, endAngle: .pi * 0.18, clockwise: false)
        return path
    }()
    private static let bubblePinkArc: CGPath = {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 0.5, startAngle: .pi * 0.3, endAngle: .pi * 0.88, clockwise: false)
        return path
    }()
    private static let bubbleHighlightArc: CGPath = {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 0.36, startAngle: -.pi * 0.87, endAngle: -.pi * 0.58, clockwise: false)
        return path
    }()
    private static let confettiColors = [
        NSColor(calibratedRed: 1, green: 0.39, blue: 0.49, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.79, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.27, green: 0.86, blue: 0.85, alpha: 1),
        NSColor(calibratedRed: 0.37, green: 0.65, blue: 1, alpha: 1),
        NSColor(calibratedRed: 0.72, green: 0.52, blue: 0.98, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.58, blue: 0.8, alpha: 1)
    ]
    private static let confettiPaths = [
        CGPath(rect: CGRect(x: -0.36, y: -0.25, width: 0.72, height: 0.5), transform: nil),
        CGPath(rect: CGRect(x: -0.17, y: -0.48, width: 0.34, height: 0.96), transform: nil),
        CGPath(rect: CGRect(x: -0.31, y: -0.31, width: 0.62, height: 0.62), transform: nil)
    ]
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

    private func drawDemo(in context: CGContext) {
        context.setFillColor(NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.17, alpha: 1).cgColor)
        context.fill(bounds)
        for surface in simulation.surfaces where surface.id != 0 {
            let rect = CGRect(x: surface.x, y: surface.y, width: surface.width, height: bounds.height * 0.48)
            context.setFillColor(NSColor(calibratedRed: 0.13, green: 0.19, blue: 0.28, alpha: 1).cgColor)
            context.addPath(CGPath(roundedRect: rect, cornerWidth: surface.cornerRadius,
                                  cornerHeight: surface.cornerRadius, transform: nil))
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
