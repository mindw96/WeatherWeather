import XCTest
@testable import WeatherCore

final class WindowGeometryTests: XCTestCase {
    func testForegroundWindowSplitsRearTopIntoLocalIntervals() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: 150, y: 20, width: 100, height: 150),
            WindowGeometry(id: 2, x: 100, y: 100, width: 300, height: 200)
        ])
        XCTAssertEqual(surfaces.map(\.id), [1, 2])
        XCTAssertEqual(surfaces[1].segments, [
            SurfaceSegment(minX: 0, maxX: 50),
            SurfaceSegment(minX: 150, maxX: 300)
        ])
        XCTAssertEqual(surfaces[1].x, 100)
        XCTAssertEqual(surfaces[1].y, 100)
    }

    func testFullOcclusionRetainsSurfaceWithNoVisibleSegments() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: -100, y: 0, width: 500, height: 300),
            WindowGeometry(id: 2, x: 0, y: 100, width: 200, height: 150)
        ])
        XCTAssertEqual(surfaces.count, 2)
        XCTAssertEqual(surfaces[1].segments, [])
    }

    func testMultipleOverlappingOccludersAreSubtractedOnce() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: 20, y: 0, width: 80, height: 300),
            WindowGeometry(id: 2, x: 80, y: 10, width: 90, height: 300),
            WindowGeometry(id: 3, x: 0, y: 100, width: 200, height: 150)
        ])
        XCTAssertEqual(surfaces[2].segments, [
            SurfaceSegment(minX: 0, maxX: 20),
            SurfaceSegment(minX: 170, maxX: 200)
        ])
    }

    func testForegroundBelowRearTopDoesNotHideIt() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: 0, y: 110, width: 300, height: 100),
            WindowGeometry(id: 2, x: 0, y: 100, width: 300, height: 200)
        ])
        XCTAssertEqual(surfaces[1].segments, [SurfaceSegment(minX: 0, maxX: 300)])
    }

    func testTouchingBottomAndSideEdgesRemainVisible() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: 100, y: 0, width: 100, height: 100),
            WindowGeometry(id: 2, x: 200, y: 0, width: 100, height: 200),
            WindowGeometry(id: 3, x: 0, y: 100, width: 200, height: 200)
        ])
        XCTAssertEqual(surfaces[2].segments, [SurfaceSegment(minX: 0, maxX: 200)])
    }

    func testEqualTopEdgesRespectFrontToBackOrdering() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: 50, y: 100, width: 50, height: 200),
            WindowGeometry(id: 2, x: 0, y: 100, width: 200, height: 200)
        ])
        XCTAssertEqual(surfaces[1].segments, [
            SurfaceSegment(minX: 0, maxX: 50),
            SurfaceSegment(minX: 100, maxX: 200)
        ])
    }

    func testInvalidBoundsAreNotSurfacesOrOccluders() {
        let surfaces = visibleTopSegments(for: [
            WindowGeometry(id: 1, x: .nan, y: 0, width: 200, height: 200),
            WindowGeometry(id: 2, x: 0, y: 0, width: 0, height: 200),
            WindowGeometry(id: 3, x: 0, y: 0, width: 200, height: -.infinity),
            WindowGeometry(id: 4, x: 0, y: 0, width: 200, height: 100),
            WindowGeometry(id: 5, x: 0, y: 100, width: 200, height: 200)
        ])
        XCTAssertEqual(surfaces.map(\.id), [4, 5])
        XCTAssertEqual(surfaces[1].segments, [SurfaceSegment(minX: 0, maxX: 200)])
    }
}
