import Foundation

/// A window rectangle in screen-local coordinates (positive y points down).
public struct WindowGeometry: Equatable, Sendable {
    public var id: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var ownerProcessID: Int32?

    public init(id: UInt32, x: Double, y: Double, width: Double, height: Double,
                ownerProcessID: Int32? = nil) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.ownerProcessID = ownerProcessID
    }

    var valid: Bool {
        x.isFinite && y.isFinite && width.isFinite && height.isFinite
            && width > 0 && height > 0
            && (x + width).isFinite && (y + height).isFinite
    }

}

/// Finds exposed top-edge intervals from a front-to-back window list.
///
/// The returned intervals are local to each surface, while its origin remains
/// screen-local. Fully covered tops are retained with an empty interval list so
/// callers can preserve accumulation while another window temporarily covers it.
/// Rectangles use half-open bounds: a top exactly at another window's bottom is
/// exposed, while equal top edges are occluded by the frontmost window.
public func visibleTopSegments(for windows: [WindowGeometry]) -> [Surface] {
    let validWindows = windows.filter(\.valid)
    var foreground: [WindowGeometry] = []
    var result: [Surface] = []
    result.reserveCapacity(validWindows.count)

    for window in validWindows {
        var intervals = [SurfaceSegment(minX: 0, maxX: window.width)]

        for occluder in foreground {
            guard occluder.y <= window.y,
                  window.y < occluder.y + occluder.height else { continue }

            let coveredStart = max(0, occluder.x - window.x)
            let coveredEnd = min(window.width, occluder.x + occluder.width - window.x)
            guard coveredStart < coveredEnd else { continue }

            var remaining: [SurfaceSegment] = []
            for interval in intervals {
                if coveredEnd <= interval.minX || coveredStart >= interval.maxX {
                    remaining.append(interval)
                    continue
                }
                if interval.minX < coveredStart {
                    remaining.append(SurfaceSegment(minX: interval.minX, maxX: coveredStart))
                }
                if coveredEnd < interval.maxX {
                    remaining.append(SurfaceSegment(minX: coveredEnd, maxX: interval.maxX))
                }
            }
            intervals = remaining
            if intervals.isEmpty { break }
        }

        result.append(Surface(id: window.id, x: window.x, y: window.y,
                              width: window.width, segments: intervals))
        foreground.append(window)
    }
    return result
}
