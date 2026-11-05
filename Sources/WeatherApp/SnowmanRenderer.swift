import AppKit

/// Original vector artwork, drawn in the view's top-left coordinate system.
/// The host decides whether the decoration is visible and applies focus clipping.
enum SnowmanRenderer {
    private static let artworkSize = CGSize(width: 100, height: 116)

    static func frame(in bounds: CGRect) -> CGRect {
        guard isValid(bounds) else { return .zero }
        let rightMargin = min(24, bounds.width * 0.06)
        let bottomMargin = min(2, bounds.height * 0.02)
        let availableWidth = bounds.width - rightMargin * 2
        let height = min(116, bounds.height * 0.48, availableWidth * artworkSize.height / artworkSize.width)
        let width = height * artworkSize.width / artworkSize.height
        return CGRect(x: bounds.maxX - rightMargin - width,
                      y: bounds.maxY - bottomMargin - height,
                      width: width, height: height)
    }

    static func draw(in context: CGContext, bounds: CGRect) {
        draw(in: context, frame: frame(in: bounds))
    }

    /// Paints into an exact frame, for a separately positioned draggable panel.
    /// No desktop-edge margin is applied by this overload.
    static func draw(in context: CGContext, frame: CGRect) {
        guard isValid(frame) else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.clip(to: frame)
        context.translateBy(x: frame.minX, y: frame.minY)
        context.scaleBy(x: frame.width / artworkSize.width, y: frame.height / artworkSize.height)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // A soft grounding shadow and thin snow cushion keep the figure rooted
        // at the display edge without covering a large strip of the desktop.
        context.setFillColor(color(0.24, 0.40, 0.51, 0.14))
        context.fillEllipse(in: CGRect(x: 17, y: 108, width: 72, height: 7))
        context.setFillColor(color(0.89, 0.96, 1, 0.72))
        context.fillEllipse(in: CGRect(x: 20, y: 108, width: 66, height: 5))

        // Twig arms sit behind the snowballs. All their tips stay inside frame.
        context.setStrokeColor(color(0.36, 0.24, 0.18))
        context.setLineWidth(3.2)
        stroke([CGPoint(x: 38, y: 68), CGPoint(x: 15, y: 55), CGPoint(x: 7, y: 46)], in: context)
        stroke([CGPoint(x: 15, y: 55), CGPoint(x: 5, y: 56)], in: context)
        stroke([CGPoint(x: 18, y: 57), CGPoint(x: 12, y: 63)], in: context)
        stroke([CGPoint(x: 70, y: 68), CGPoint(x: 88, y: 53), CGPoint(x: 89, y: 44)], in: context)
        stroke([CGPoint(x: 88, y: 53), CGPoint(x: 96, y: 50)], in: context)

        snowball(CGRect(x: 24, y: 71, width: 59, height: 42), in: context)
        snowball(CGRect(x: 31, y: 48, width: 45, height: 39), in: context)
        snowball(CGRect(x: 36, y: 25, width: 35, height: 32), in: context)

        // Three charcoal buttons follow the slightly rounded body.
        context.setFillColor(color(0.16, 0.23, 0.29))
        for center in [CGPoint(x: 53, y: 64), CGPoint(x: 54, y: 77), CGPoint(x: 54, y: 93)] {
            context.fillEllipse(in: CGRect(x: center.x - 1.8, y: center.y - 1.8, width: 3.6, height: 3.6))
        }

        // Teal scarf with a loose tail and a small knot.
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 59, y: 52))
        tail.addCurve(to: CGPoint(x: 64, y: 78), control1: CGPoint(x: 62, y: 60), control2: CGPoint(x: 58, y: 70))
        tail.addQuadCurve(to: CGPoint(x: 73, y: 76), control: CGPoint(x: 69, y: 80))
        tail.addCurve(to: CGPoint(x: 67, y: 51), control1: CGPoint(x: 67, y: 69), control2: CGPoint(x: 73, y: 59))
        tail.closeSubpath()
        context.setFillColor(color(0.07, 0.49, 0.51))
        context.addPath(tail)
        context.fillPath()
        fillRoundedRect(CGRect(x: 33, y: 49, width: 40, height: 8), radius: 4, color: color(0.10, 0.59, 0.60), in: context)
        context.setStrokeColor(color(0.44, 0.82, 0.80))
        context.setLineWidth(1.4)
        stroke([CGPoint(x: 37, y: 51), CGPoint(x: 60, y: 52)], in: context)
        stroke([CGPoint(x: 63, y: 70), CGPoint(x: 69, y: 69)], in: context)
        stroke([CGPoint(x: 64, y: 74), CGPoint(x: 70, y: 73)], in: context)
        fillRoundedRect(CGRect(x: 60, y: 50, width: 9, height: 9), radius: 3.5, color: color(0.08, 0.52, 0.54), in: context)

        // A navy top hat with a snowy lip, angled just enough to feel friendly.
        context.saveGState()
        context.translateBy(x: 52, y: 28)
        context.rotate(by: -0.07)
        context.translateBy(x: -52, y: -28)
        fillRoundedRect(CGRect(x: 37, y: 7, width: 32, height: 25), radius: 3.5, color: color(0.14, 0.22, 0.31), in: context)
        fillRoundedRect(CGRect(x: 38, y: 23, width: 30, height: 5), radius: 1.2, color: color(0.18, 0.61, 0.63), in: context)
        fillRoundedRect(CGRect(x: 29, y: 29, width: 48, height: 6), radius: 3, color: color(0.10, 0.17, 0.25), in: context)
        fillRoundedRect(CGRect(x: 38, y: 6, width: 30, height: 3.5), radius: 1.8, color: color(0.96, 0.99, 1), in: context)
        context.restoreGState()

        // Warm cheeks, bright coal eyes, carrot nose, and a little coal smile.
        context.setFillColor(color(0.96, 0.65, 0.58, 0.38))
        context.fillEllipse(in: CGRect(x: 40, y: 41, width: 7, height: 4))
        context.fillEllipse(in: CGRect(x: 61, y: 41, width: 6, height: 4))
        context.setFillColor(color(0.12, 0.20, 0.27))
        context.fillEllipse(in: CGRect(x: 45, y: 37, width: 3.3, height: 3.6))
        context.fillEllipse(in: CGRect(x: 58, y: 37, width: 3.3, height: 3.6))
        let carrot = CGMutablePath()
        carrot.move(to: CGPoint(x: 53, y: 41))
        carrot.addQuadCurve(to: CGPoint(x: 70, y: 43), control: CGPoint(x: 61, y: 40))
        carrot.addQuadCurve(to: CGPoint(x: 54, y: 46), control: CGPoint(x: 62, y: 47))
        carrot.closeSubpath()
        context.setFillColor(color(0.95, 0.47, 0.17))
        context.addPath(carrot)
        context.fillPath()
        context.setFillColor(color(0.17, 0.24, 0.29))
        for center in [CGPoint(x: 47, y: 45), CGPoint(x: 49, y: 47), CGPoint(x: 52, y: 48)] {
            context.fillEllipse(in: CGRect(x: center.x - 0.7, y: center.y - 0.7, width: 1.4, height: 1.4))
        }
    }

    /// The snowballs, hat, and twigs are draggable; transparent panel corners
    /// and the decorative ground shadow can continue passing mouse input through.
    static func contains(_ point: CGPoint, in frame: CGRect) -> Bool {
        guard isValid(frame), point.x.isFinite, point.y.isFinite, frame.contains(point) else { return false }
        let local = CGPoint(x: (point.x - frame.minX) * artworkSize.width / frame.width,
                            y: (point.y - frame.minY) * artworkSize.height / frame.height)
        return hitPath.contains(local)
    }

    private static let hitPath: CGPath = {
        let path = CGMutablePath()
        for ball in [CGRect(x: 24, y: 71, width: 59, height: 42),
                     CGRect(x: 31, y: 48, width: 45, height: 39),
                     CGRect(x: 36, y: 25, width: 35, height: 32)] {
            path.addEllipse(in: ball)
        }
        let hat = CGMutablePath()
        hat.addRoundedRect(in: CGRect(x: 37, y: 6, width: 32, height: 26), cornerWidth: 3, cornerHeight: 3)
        hat.addRoundedRect(in: CGRect(x: 29, y: 29, width: 48, height: 6), cornerWidth: 3, cornerHeight: 3)
        let transform = CGAffineTransform(translationX: 52, y: 28)
            .rotated(by: -0.07).translatedBy(x: -52, y: -28)
        path.addPath(hat, transform: transform)
        let arms = CGMutablePath()
        for points in [
            [CGPoint(x: 38, y: 68), CGPoint(x: 15, y: 55), CGPoint(x: 7, y: 46)],
            [CGPoint(x: 15, y: 55), CGPoint(x: 5, y: 56)],
            [CGPoint(x: 18, y: 57), CGPoint(x: 12, y: 63)],
            [CGPoint(x: 70, y: 68), CGPoint(x: 88, y: 53), CGPoint(x: 89, y: 44)],
            [CGPoint(x: 88, y: 53), CGPoint(x: 96, y: 50)]
        ] {
            arms.move(to: points[0])
            for point in points.dropFirst() { arms.addLine(to: point) }
        }
        path.addPath(arms.copy(strokingWithWidth: 5, lineCap: .round, lineJoin: .round, miterLimit: 1))
        return path
    }()

    private static func isValid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite
            && rect.maxX.isFinite && rect.maxY.isFinite && rect.width > 0 && rect.height > 0
    }

    private static func snowball(_ rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.addEllipse(in: rect)
        context.clip()
        let colors = [color(1, 1, 1), color(0.91, 0.97, 1), color(0.73, 0.86, 0.94)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
            context.drawLinearGradient(gradient,
                                       start: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY),
                                       end: CGPoint(x: rect.maxX, y: rect.maxY),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        } else {
            context.setFillColor(color(0.94, 0.98, 1))
            context.fill(rect)
        }
        context.restoreGState()
        context.setStrokeColor(color(0.69, 0.83, 0.91, 0.55))
        context.setLineWidth(0.7)
        context.strokeEllipse(in: rect.insetBy(dx: 0.35, dy: 0.35))
    }

    private static func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor, in context: CGContext) {
        context.setFillColor(color)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
    }

    private static func stroke(_ points: [CGPoint], in context: CGContext) {
        context.beginPath()
        context.addLines(between: points)
        context.strokePath()
    }

    private static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha).cgColor
    }
}
