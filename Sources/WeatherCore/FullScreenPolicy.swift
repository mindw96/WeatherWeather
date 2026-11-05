import Foundation

/// A rectangle in display-local coordinates, with positive y pointing down.
public struct DisplayArea: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    fileprivate var isValid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && width > 0 && height > 0
            && (x + width).isFinite && (y + height).isFinite
    }
}

/// Geometry-based policy; it does not claim to read another app's native
/// full-screen state. A window filling the display, its safe area, or its
/// menu/Dock work area is treated as screen-filling. A 2-point edge tolerance
/// allows for coordinate rounding without treating large normal windows as full-screen.
public struct FullScreenPolicy: Sendable {
    public let width: Double
    public let height: Double
    private let areas: [DisplayArea]
    private static let edgeTolerance = 2.0

    public init(width: Double, height: Double,
                visibleArea: DisplayArea? = nil, safeArea: DisplayArea? = nil) {
        self.width = width
        self.height = height
        let frame = DisplayArea(x: 0, y: 0, width: width, height: height)
        areas = ([frame] + [visibleArea, safeArea].compactMap { $0 }).filter { area in
            frame.isValid && area.isValid
                && area.x >= -Self.edgeTolerance && area.y >= -Self.edgeTolerance
                && area.x + area.width <= width + Self.edgeTolerance
                && area.y + area.height <= height + Self.edgeTolerance
        }
    }

    public func isScreenFilling(_ window: WindowGeometry) -> Bool {
        let windowArea = DisplayArea(x: window.x, y: window.y, width: window.width, height: window.height)
        guard windowArea.isValid else { return false }
        return areas.contains { area in
            abs(window.x - area.x) <= Self.edgeTolerance
                && abs(window.y - area.y) <= Self.edgeTolerance
                && abs(window.x + window.width - area.x - area.width) <= Self.edgeTolerance
                && abs(window.y + window.height - area.y - area.height) <= Self.edgeTolerance
        }
    }

    /// Keep excluded windows in the occlusion calculation; only their own
    /// collision/accumulation surfaces are removed. The synthetic floor is
    /// removed on this display while any screen-filling window is present.
    /// When enabled, a screen-filling top above y=20 is moved inward to y=20
    /// so accumulation remains visible rather than growing outside the display.
    public func surfaces(for windows: [WindowGeometry], accumulateOnFullScreen: Bool = false) -> [Surface] {
        guard width.isFinite, height.isFinite, width > 0, height > 1 else { return [] }
        let screenFillingIDs = Set(windows.filter(isScreenFilling).map(\.id))
        let excludedIDs = accumulateOnFullScreen ? Set<UInt32>() : screenFillingIDs
        var surfaces = visibleTopSegments(for: windows).map { original in
            var surface = original
            if accumulateOnFullScreen, screenFillingIDs.contains(surface.id), surface.y < 20 {
                surface.y = min(20, height - 1)
            }
            return surface
        }.filter {
            !excludedIDs.contains($0.id) && $0.y >= 1 && $0.y < height
        }
        if excludedIDs.isEmpty {
            surfaces.append(Surface(id: 0, x: 0, y: height - 1, width: width))
        }
        return surfaces
    }
}
