import XCTest
@testable import WeatherCore

final class FullScreenPolicyTests: XCTestCase {
    private let policy = FullScreenPolicy(
        width: 1_440, height: 900,
        visibleArea: DisplayArea(x: 0, y: 24, width: 1_440, height: 816),
        safeArea: DisplayArea(x: 0, y: 0, width: 1_440, height: 900)
    )

    func testNativeFullScreenExcludesItsTopAndDisplayFloorByDefault() {
        let window = WindowGeometry(id: 1, x: 0, y: 0, width: 1_440, height: 900)
        XCTAssertTrue(policy.isScreenFilling(window))
        XCTAssertTrue(policy.surfaces(for: [window]).isEmpty)
    }

    func testNotchSafeAreaAndWorkAreaAreRecognized() {
        let notched = FullScreenPolicy(
            width: 1_512, height: 982,
            visibleArea: DisplayArea(x: 0, y: 38, width: 1_512, height: 884),
            safeArea: DisplayArea(x: 0, y: 38, width: 1_512, height: 944)
        )
        let safe = WindowGeometry(id: 2, x: 0, y: 38, width: 1_512, height: 944)
        let work = WindowGeometry(id: 3, x: 0, y: 38, width: 1_512, height: 884)
        XCTAssertTrue(notched.isScreenFilling(safe))
        XCTAssertTrue(notched.isScreenFilling(work))
        XCTAssertTrue(notched.surfaces(for: [safe]).isEmpty)
        XCTAssertTrue(notched.surfaces(for: [work]).isEmpty)
    }

    func testSideDockWorkAreaUsesAllFourEdges() {
        let dock = FullScreenPolicy(width: 1_440, height: 900,
                                   visibleArea: DisplayArea(x: 70, y: 24, width: 1_370, height: 876))
        XCTAssertTrue(dock.isScreenFilling(.init(id: 1, x: 70, y: 24, width: 1_370, height: 876)))
        XCTAssertFalse(dock.isScreenFilling(.init(id: 2, x: 70, y: 24, width: 1_360, height: 876)))
    }

    func testLargeNormalAndAdjacentDisplayWindowsRemainEligible() {
        let normal = WindowGeometry(id: 1, x: 12, y: 24, width: 1_416, height: 816)
        let adjacent = WindowGeometry(id: 2, x: -1_420, y: 24, width: 1_440, height: 816)
        XCTAssertFalse(policy.isScreenFilling(normal))
        XCTAssertFalse(policy.isScreenFilling(adjacent))
        let surfaces = policy.surfaces(for: [normal, adjacent])
        XCTAssertTrue(surfaces.contains { $0.id == normal.id })
        XCTAssertTrue(surfaces.contains { $0.id == 0 })
    }

    func testEdgeToleranceDoesNotBecomePercentageHeuristic() {
        XCTAssertTrue(policy.isScreenFilling(.init(id: 1, x: 1, y: 25, width: 1_438, height: 814)))
        XCTAssertFalse(policy.isScreenFilling(.init(id: 2, x: 3, y: 24, width: 1_434, height: 816)))
        XCTAssertFalse(policy.isScreenFilling(.init(id: 3, x: 0, y: 24, width: 1_440, height: 800)))
    }

    func testExcludedWindowStillOccludesRearAccumulation() {
        let front = WindowGeometry(id: 1, x: 0, y: 24, width: 1_440, height: 816)
        let rear = WindowGeometry(id: 2, x: 200, y: 160, width: 600, height: 500)
        let surfaces = policy.surfaces(for: [front, rear])
        XCTAssertFalse(surfaces.contains { $0.id == front.id || $0.id == 0 })
        XCTAssertEqual(surfaces.first { $0.id == rear.id }?.segments, [])
    }

    func testEnabledOptionIncludesWorkAreaWindowAndFloor() {
        let window = WindowGeometry(id: 1, x: 0, y: 24, width: 1_440, height: 816)
        let enabled = policy.surfaces(for: [window], accumulateOnFullScreen: true)
        XCTAssertEqual(enabled.map(\.id), [1, 0])
        XCTAssertEqual(enabled.first?.y, 24)
        XCTAssertEqual(enabled.first?.segments, [.init(minX: 0, maxX: 1_440)])
    }

    func testEnabledNativeFullScreenUsesVisibleInsetWithoutMovingNormalWindows() {
        let floating = WindowGeometry(id: 2, x: 100, y: 8, width: 320, height: 240)
        let fullScreen = WindowGeometry(id: 1, x: 0, y: 0, width: 1_440, height: 900)
        let surfaces = policy.surfaces(for: [floating, fullScreen], accumulateOnFullScreen: true)
        XCTAssertEqual(surfaces.first { $0.id == 1 }?.y, 20)
        XCTAssertEqual(surfaces.first { $0.id == 2 }?.y, 8)
        XCTAssertTrue(surfaces.contains { $0.id == 0 })
    }

    func testDisablingOptionRemovesExistingPilesWithoutRestoringSnapshot() {
        let window = WindowGeometry(id: 1, x: 0, y: 24, width: 1_440, height: 816)
        let simulation = WeatherSimulation(width: 1_440, height: 900)
        simulation.setSurfaces(policy.surfaces(for: [window], accumulateOnFullScreen: true))
        for _ in 0..<100 { simulation.update(deltaTime: 0.1) }
        XCTAssertTrue(simulation.piles.contains { $0.surfaceID == 1 && $0.heights.contains { $0 > 0 } })
        let oldSnapshot = simulation.piles
        simulation.setSurfaces(policy.surfaces(for: [window], accumulateOnFullScreen: false))
        simulation.inheritAccumulation(from: oldSnapshot)
        XCTAssertTrue(simulation.piles.isEmpty)
        simulation.setSurfaces(policy.surfaces(for: [window], accumulateOnFullScreen: true))
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }

    func testInvalidAreasAndWindowsDoNotSuppressTheFloor() {
        let invalid = FullScreenPolicy(width: 1_440, height: 900,
                                      visibleArea: DisplayArea(x: .nan, y: 24, width: 1_440, height: 816))
        XCTAssertFalse(invalid.isScreenFilling(.init(id: 1, x: .nan, y: 24, width: 1_440, height: 816)))
        XCTAssertEqual(invalid.surfaces(for: []).map(\.id), [0])
        XCTAssertTrue(FullScreenPolicy(width: .infinity, height: 900).surfaces(for: []).isEmpty)
    }
}
