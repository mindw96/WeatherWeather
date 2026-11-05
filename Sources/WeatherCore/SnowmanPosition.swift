import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Fractions of the space through which a snowman can move on its own display.
/// The caller keeps the same coordinate orientation when saving and restoring.
public struct SnowmanPosition: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = Self.unit(x)
        self.y = Self.unit(y)
    }

    /// Returns a contained frame, shrinking an oversized requested size as needed.
    /// Invalid or empty geometry has no drawable frame.
    public func frame(in displayBounds: CGRect, size: CGSize) -> CGRect {
        guard Self.valid(displayBounds), size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return .zero }
        let width = min(size.width, displayBounds.width)
        let height = min(size.height, displayBounds.height)
        return CGRect(x: displayBounds.minX + CGFloat(Self.unit(x)) * (displayBounds.width - width),
                      y: displayBounds.minY + CGFloat(Self.unit(y)) * (displayBounds.height - height),
                      width: width, height: height)
    }

    /// Converts a drag result into fractions after constraining it to the display.
    public static func normalized(frame: CGRect, in displayBounds: CGRect) -> SnowmanPosition? {
        guard valid(frame), valid(displayBounds) else { return nil }
        let width = min(frame.width, displayBounds.width)
        let height = min(frame.height, displayBounds.height)
        let travelX = displayBounds.width - width
        let travelY = displayBounds.height - height
        let originX = min(max(frame.minX, displayBounds.minX), displayBounds.maxX - width)
        let originY = min(max(frame.minY, displayBounds.minY), displayBounds.maxY - height)
        return SnowmanPosition(x: travelX > 0 ? Double((originX - displayBounds.minX) / travelX) : 0,
                               y: travelY > 0 ? Double((originY - displayBounds.minY) / travelY) : 0)
    }

    private static func unit(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0
    }

    private static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.size.width.isFinite && rect.size.height.isFinite
            && rect.size.width > 0 && rect.size.height > 0
            && rect.maxX.isFinite && rect.maxY.isFinite
    }
}
