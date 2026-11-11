import XCTest
@testable import WeatherCore

final class AccumulationSynchronizationTests: XCTestCase {
    func testOwnedSnowHeightReplacesStaleCopyIncludingZero() throws {
        let left = scene(x: 0), right = scene(x: -300)
        left.inheritAccumulation(from: [pile(x: 0, height: 8)])
        right.inheritAccumulation(from: [pile(x: -300, height: 3)])
        synchronize(left, right)
        XCTAssertEqual(left.piles[0].height(at: 150), 8, accuracy: 0.001)
        XCTAssertEqual(left.piles[0].height(at: 450), 3, accuracy: 0.001)
        XCTAssertEqual(right.piles[0].heights, left.piles[0].heights)
        left.clearAccumulation()
        synchronize(left, right)
        XCTAssertEqual(right.piles[0].height(at: 150), 0, accuracy: 0.001,
                       "The owner's cleared section must not be restored from the other display")
        XCTAssertEqual(left.piles[0].height(at: 450), 3, accuracy: 0.001)
    }

    func testMovingSnowIsShedAfterSynchronizationAndIsNotRestoredNextRefresh() {
        let left = scene(x: 0), right = scene(x: -300)
        left.inheritAccumulation(from: [pile(x: 0, height: 8)])
        right.inheritAccumulation(from: [pile(x: -300, height: 8)])
        let snapshots = [left.accumulationSnapshot, right.accumulationSnapshot]
        left.setSurfaces([Surface(id: 10, x: 20, y: 100, width: 600)], inheriting: snapshots)
        right.setSurfaces([Surface(id: 10, x: -280, y: 100, width: 600)], inheriting: snapshots)
        XCTAssertFalse(left.splashes.isEmpty)
        let reduced = left.piles[0].heights
        XCTAssertTrue(reduced.prefix(20).contains { $0 < 8 })
        synchronize(left, right)
        XCTAssertEqual(Array(left.piles[0].heights.prefix(20)), Array(reduced.prefix(20)))
        XCTAssertEqual(Array(right.piles[0].heights.prefix(20)), Array(reduced.prefix(20)))
    }

    func testLiftedParticleDoesNotReappearFromOffDisplayCopy() {
        let left = scene(x: 0, mode: .autumn), right = scene(x: -300, mode: .autumn)
        let item = SettledParticle(id: 123, mode: .autumn, surfaceID: 10, position: 0.25,
                                   offsetY: 3, size: 8, rotation: 0, variant: 0, life: 40)
        left.inheritSettledParticles(from: [item])
        synchronize(left, right)
        XCTAssertEqual(right.settledParticles.count, 1)
        right.wind = 1
        for _ in 0..<20 { right.update(deltaTime: 0.1) }
        XCTAssertTrue(right.particles.isEmpty, "Off-display copies must not independently lift")
        left.wind = 1
        for _ in 0..<500 where left.particles.isEmpty { left.update(deltaTime: 0.1) }
        XCTAssertFalse(left.particles.isEmpty)
        XCTAssertFalse(left.settledParticles.contains { $0.id == item.id })
        synchronize(left, right)
        XCTAssertFalse(right.settledParticles.contains { $0.id == item.id })
        XCTAssertFalse(left.settledParticles.contains { $0.id == item.id })
    }

    func testHandoffUsesLastSourceSnapshotEvenAfterWindowLeavesSource() {
        let source = scene(x: 0), destination = WeatherSimulation(width: 300, height: 400)
        source.inheritAccumulation(from: [pile(x: 0, height: 7)])
        let snapshot = source.accumulationSnapshot
        source.setSurfaces([])
        destination.setSurfaces([Surface(id: 10, x: 20, y: 100, width: 600)], inheriting: [snapshot])
        XCTAssertTrue(source.piles.isEmpty)
        XCTAssertEqual(destination.piles[0].height(at: 100), 7, accuracy: 0.001)
        XCTAssertTrue(destination.splashes.isEmpty, "First registration is not a window drag")
    }

    func testMissingDisplayRetainsCopiesAndFloorsStayIndependent() {
        let left = scene(x: 0, includeFloor: true), right = scene(x: -300, includeFloor: true)
        left.inheritAccumulation(from: [pile(x: 0, height: 7)])
        right.inheritAccumulation(from: [pile(x: -300, height: 2)])
        synchronize(left, right)
        let before = right.piles.first { $0.surfaceID == 10 }!.heights
        right.setSurfaces(right.surfaces, inheriting: [right.accumulationSnapshot])
        XCTAssertEqual(right.piles.first { $0.surfaceID == 10 }!.heights, before)
        let maliciousFloor = Pile(surfaceID: 0, x: 0, y: 399, width: 300, heights: [18, 18],
                                 segments: [.init(minX: 0, maxX: 300)], mode: .snow)
        let snapshot = AccumulationSnapshot(displayWidth: 300, displayHeight: 400, piles: [maliciousFloor], settledParticles: [])
        right.setSurfaces(right.surfaces, inheriting: [snapshot])
        XCTAssertTrue(right.piles.first { $0.surfaceID == 0 }!.heights.allSatisfy { $0 == 0 })
        XCTAssertFalse(left.accumulationSnapshot.piles.contains { $0.surfaceID == 0 })
    }

    func testOccludedOwnerStillPreservesItsLocalAccumulation() {
        let left = scene(x: 0), right = scene(x: -300)
        left.inheritAccumulation(from: [pile(x: 0, height: 7)])
        left.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 600, segments: [])])
        synchronize(left, right)
        XCTAssertEqual(right.piles[0].height(at: 150), 7, accuracy: 0.001)
        left.clearAccumulation()
        synchronize(left, right)
        XCTAssertEqual(right.piles[0].height(at: 150), 0, accuracy: 0.001)
    }

    func testVerticallyStackedDisplaysChooseOwnerUsingCurvedBaseline() {
        let top = WeatherSimulation(width: 300, height: 200)
        let bottom = WeatherSimulation(width: 300, height: 200)
        top.setSurfaces([Surface(id: 10, x: 30, y: 180, width: 200, cornerRadius: 40)])
        bottom.setSurfaces([Surface(id: 10, x: 30, y: -20, width: 200, cornerRadius: 40)])
        top.inheritAccumulation(from: [Pile(surfaceID: 10, x: 30, y: 180, width: 200,
            heights: [8, 8], segments: [.init(minX: 0, maxX: 200)], mode: .snow)])
        bottom.inheritAccumulation(from: [Pile(surfaceID: 10, x: 30, y: -20, width: 200,
            heights: [2, 2], segments: [.init(minX: 0, maxX: 200)], mode: .snow)])
        synchronize(top, bottom)
        XCTAssertEqual(top.piles[0].height(at: 100), 8, accuracy: 0.001)
        XCTAssertEqual(top.piles[0].height(at: 0), 2, accuracy: 0.001,
                       "The rounded corner lies below the top display even though its center edge does not")
        XCTAssertEqual(bottom.piles[0].heights, top.piles[0].heights)
        bottom.clearAccumulation()
        synchronize(top, bottom)
        XCTAssertEqual(top.piles[0].height(at: 0), 0, accuracy: 0.001)
        XCTAssertEqual(top.piles[0].height(at: 100), 8, accuracy: 0.001)
    }

    func testNegativeTopEdgeCannotOverrideVisibleVerticalOwner() {
        let offscreen = WeatherSimulation(width: 300, height: 200)
        let visible = WeatherSimulation(width: 300, height: 200)
        offscreen.setSurfaces([Surface(id: 10, x: 0, y: -100, width: 200)])
        visible.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 200)])
        offscreen.inheritAccumulation(from: [Pile(surfaceID: 10, x: 0, y: -100, width: 200,
            heights: [12, 12], segments: [.init(minX: 0, maxX: 200)], mode: .snow)])
        synchronize(offscreen, visible)
        XCTAssertTrue(visible.piles[0].heights.allSatisfy { $0 == 0 })
        XCTAssertTrue(offscreen.piles[0].heights.allSatisfy { $0 == 0 })
    }

    private func scene(x: Double, mode: WeatherMode = .snow, includeFloor: Bool = false) -> WeatherSimulation {
        let simulation = WeatherSimulation(width: 300, height: 400, seed: 912)
        simulation.mode = mode
        simulation.intensity = 0
        var surfaces = [Surface(id: 10, x: x, y: 100, width: 600)]
        if includeFloor { surfaces.append(Surface(id: 0, x: 0, y: 399, width: 300)) }
        simulation.setSurfaces(surfaces)
        return simulation
    }

    private func pile(x: Double, height: Double) -> Pile {
        Pile(surfaceID: 10, x: x, y: 100, width: 600, heights: [height, height],
             segments: [.init(minX: 0, maxX: 600)], mode: .snow)
    }

    private func synchronize(_ left: WeatherSimulation, _ right: WeatherSimulation) {
        let snapshots = [left.accumulationSnapshot, right.accumulationSnapshot]
        left.setSurfaces(left.surfaces, inheriting: snapshots)
        right.setSurfaces(right.surfaces, inheriting: snapshots)
    }
}
