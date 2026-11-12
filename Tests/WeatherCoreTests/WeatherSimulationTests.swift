import XCTest
@testable import WeatherCore

final class WeatherSimulationTests: XCTestCase {
    func testFastParticleHitsFirstExposedEdge() throws {
        let simulation = WeatherSimulation(width: 400, height: 400)
        simulation.setSurfaces([
            Surface(id: 2, x: 0, y: 200, width: 400),
            Surface(id: 1, x: 0, y: 100, width: 400)
        ])
        let hit = try XCTUnwrap(simulation.firstCollision(fromX: 100, y: 10, toX: 140, y: 300))
        XCTAssertEqual(simulation.piles[hit.pileIndex].surfaceID, 1)
        XCTAssertEqual(hit.y, 100, accuracy: 0.0001)
        XCTAssertEqual(hit.x, 100 + 40 * 90 / 290, accuracy: 0.0001)
    }

    func testOccludedPartDoesNotInterceptParticle() throws {
        let simulation = WeatherSimulation(width: 400, height: 400)
        simulation.setSurfaces([
            Surface(id: 1, x: 0, y: 100, width: 400,
                    segments: [.init(minX: 0, maxX: 50), .init(minX: 250, maxX: 400)]),
            Surface(id: 2, x: 0, y: 200, width: 400)
        ])
        let hit = try XCTUnwrap(simulation.firstCollision(fromX: 100, y: 10, toX: 100, y: 300))
        XCTAssertEqual(simulation.piles[hit.pileIndex].surfaceID, 2)
        XCTAssertNil(simulation.firstCollision(fromX: 100, y: 10, toX: 100, y: 150))
        XCTAssertNil(simulation.firstCollision(fromX: 10, y: 200, toX: 10, y: 100))
    }

    func testSweptCollisionIncludesMaximumRidgeAndHorizontalCrossing() throws {
        let cases: [(WeatherMode, Double)] = [
            (.snow, WeatherSimulation.maximumSnowHeight),
            (.rain, WeatherSimulation.maximumWaterHeight),
            (.autumn, WeatherSimulation.maximumLeafHeight),
            (.cherryBlossom, WeatherSimulation.maximumPetalHeight),
            (.bubbles, WeatherSimulation.maximumBubbleHeight),
            (.confetti, WeatherSimulation.maximumConfettiHeight)
        ]
        for (mode, maximum) in cases {
            let simulation = WeatherSimulation(width: 500, height: 400)
            simulation.mode = mode
            simulation.setSurfaces([Surface(id: 10, x: 100, y: 100, width: 200)])
            simulation.inheritAccumulation(from: [samplePile(id: 10, mode: mode, heights: [maximum, maximum, maximum])])
            let top = 100 - maximum
            // Both horizontal endpoints lie outside the window, but the sweep crosses it.
            let crossing = try XCTUnwrap(simulation.firstCollision(fromX: 50, y: 60, toX: 350, y: 120))
            XCTAssertEqual(crossing.y, top, accuracy: 0.0001)
            let onBoundary = try XCTUnwrap(simulation.firstCollision(fromX: 100, y: top, toX: 100, y: top + 1))
            XCTAssertEqual(onBoundary.fraction, 0, accuracy: 0.0001)
            XCTAssertNil(simulation.firstCollision(fromX: 150, y: top - 2, toX: 150, y: top - 1))
            XCTAssertNil(simulation.firstCollision(fromX: 150, y: 101, toX: 150, y: 200))
            XCTAssertNil(simulation.firstCollision(fromX: 20, y: 0, toX: 99, y: 200))
        }
    }

    func testSnowMovesAndResizesWithStableWindowID() {
        let simulation = populatedSimulation(mode: .snow)
        let old = simulation.piles[0]
        XCTAssertGreaterThan(old.heights.max() ?? 0, 0)
        simulation.setSurfaces([Surface(id: 10, x: 40, y: 130, width: 1_400)])
        let moved = simulation.piles[0]
        XCTAssertEqual(moved.surfaceID, old.surfaceID)
        XCTAssertEqual(moved.x, 40)
        XCTAssertEqual(moved.y, 130)
        XCTAssertEqual(moved.height(at: 700), old.height(at: 500), accuracy: 0.08)
        XCTAssertGreaterThan(moved.heights.max() ?? 0, 0)
        simulation.setSurfaces([])
        XCTAssertTrue(simulation.piles.isEmpty)
    }

    func testHiddenWindowRetainsAccumulationButHasNoCollision() {
        let simulation = populatedSimulation(mode: .snow)
        let before = simulation.piles[0].heights
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 10, width: 1_000, segments: [])])
        XCTAssertEqual(simulation.piles[0].heights, before)
        XCTAssertNil(simulation.firstCollision(fromX: 500, y: -50, toX: 500, y: 50))
    }

    func testModeChangeResetsWeatherAndPreservesGeometry() {
        let simulation = populatedSimulation(mode: .snow)
        let surfaces = simulation.surfaces
        simulation.mode = .rain
        XCTAssertTrue(simulation.particles.isEmpty)
        XCTAssertTrue(simulation.splashes.isEmpty)
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
        XCTAssertEqual(simulation.surfaces, surfaces)
        XCTAssertTrue(simulation.piles.allSatisfy { $0.mode == .rain })
    }

    func testRainPoolsEvaporateAndStayWithinCap() {
        let simulation = populatedSimulation(mode: .rain)
        let before = simulation.piles[0].heights.reduce(0, +)
        XCTAssertGreaterThan(before, 0)
        XCTAssertLessThanOrEqual(simulation.piles[0].heights.max() ?? 0, 1.5)
        XCTAssertTrue(simulation.splashes.isEmpty)
        simulation.intensity = 0
        for _ in 0..<100 { simulation.update(deltaTime: 0.1) }
        XCTAssertLessThan(simulation.piles[0].heights.reduce(0, +), before)
        XCTAssertTrue(simulation.splashes.isEmpty)
    }

    func testDisablingAccumulationClearsWaterAndKeepsFallingRain() {
        let simulation = populatedSimulation(mode: .rain)
        simulation.accumulationEnabled = false
        for _ in 0..<30 { simulation.update(deltaTime: 1.0 / 30) }
        XCTAssertTrue(simulation.piles[0].heights.allSatisfy { $0 == 0 })
        XCTAssertFalse(simulation.particles.isEmpty)
        XCTAssertTrue(simulation.splashes.isEmpty)
    }

    func testSeededSimulationIsReproducible() {
        let left = populatedSimulation(mode: .snow, seed: 17)
        let right = populatedSimulation(mode: .snow, seed: 17)
        XCTAssertEqual(left.particles, right.particles)
        XCTAssertEqual(left.piles, right.piles)
        XCTAssertEqual(left.splashes, right.splashes)
    }

    func testUnchangedWindowRefreshKeepsEveryWeatherState() {
        for mode in WeatherMode.allCases {
            let simulation = populatedSimulation(mode: mode)
            let particles = simulation.particles
            let piles = simulation.piles
            let splashes = simulation.splashes
            let settled = simulation.settledParticles
            simulation.setSurfaces(simulation.surfaces)
            XCTAssertEqual(simulation.particles, particles)
            XCTAssertEqual(simulation.piles, piles)
            XCTAssertEqual(simulation.splashes, splashes)
            XCTAssertEqual(simulation.settledParticles, settled)
        }
    }

    func testInvalidAndLongFrameTimesDoNotBurst() {
        let left = WeatherSimulation(width: 1_000, height: 800, seed: 42)
        let right = WeatherSimulation(width: 1_000, height: 800, seed: 42)
        left.update(deltaTime: .nan)
        left.update(deltaTime: .infinity)
        left.update(deltaTime: -1)
        XCTAssertTrue(left.particles.isEmpty)
        left.update(deltaTime: 3_600)
        right.update(deltaTime: 0.1)
        XCTAssertEqual(left.particles, right.particles)
    }

    func testParticleBudgetAndInvalidSettingsRemainFinite() {
        let simulation = WeatherSimulation(width: 32_768, height: 32_768)
        simulation.intensity = 100
        simulation.wind = .infinity
        for _ in 0..<600 { simulation.update(deltaTime: 0.1) }
        XCTAssertEqual(simulation.particles.count, WeatherSimulation.maximumParticles)
        XCTAssertTrue(simulation.particles.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.vx.isFinite && $0.vy.isFinite
        })
        simulation.resize(width: .nan, height: -.infinity)
        XCTAssertEqual(simulation.width, 1)
        XCTAssertEqual(simulation.height, 1)
        simulation.intensity = .nan
        simulation.update(deltaTime: 0.1)
        XCTAssertLessThanOrEqual(simulation.particles.count, WeatherSimulation.maximumParticles)
    }

    func testInvalidAndDuplicateSurfacesAreRejected() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.setSurfaces([
            Surface(id: 1, x: 10, y: 20, width: 100),
            Surface(id: 1, x: 10, y: 20, width: 100),
            Surface(id: 2, x: .nan, y: 20, width: 100),
            Surface(id: 3, x: 10, y: .infinity, width: 100),
            Surface(id: 4, x: 10, y: 20, width: -100),
            Surface(id: 5, x: 10, y: 20, width: 100,
                    segments: [.init(minX: -20, maxX: 200), .init(minX: .nan, maxX: 10)])
        ])
        XCTAssertEqual(simulation.surfaces.map(\.id), [1, 5])
        XCTAssertEqual(simulation.surfaces[1].segments, [.init(minX: 0, maxX: 100)])
    }

    func testAccumulationTransfersToAnotherDisplayAndResizes() {
        let first = populatedSimulation(mode: .snow)
        let snapshot = first.piles
        let second = WeatherSimulation(width: 1_920, height: 1_080)
        second.setSurfaces([Surface(id: 10, x: 90, y: 160, width: 1_400)])
        XCTAssertTrue(second.piles[0].heights.allSatisfy { $0 == 0 })
        second.inheritAccumulation(from: snapshot)
        XCTAssertGreaterThan(second.piles[0].heights.max() ?? 0, 0)
        XCTAssertEqual(second.piles[0].height(at: 700), snapshot[0].height(at: 500), accuracy: 0.08)
        XCTAssertEqual(second.piles[0].x, 90)
        XCTAssertEqual(second.piles[0].y, 160)
        first.setSurfaces([])
        XCTAssertTrue(first.piles.isEmpty)
        XCTAssertGreaterThan(second.piles[0].heights.max() ?? 0, 0)
    }

    func testPartialDisplayPilesMergeByMaximumWithoutDoubleCounting() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 12)])
        let left = samplePile(id: 10, heights: [7, 2, 0])
        let right = samplePile(id: 10, heights: [0, 4, 6])
        simulation.inheritAccumulation(from: [left, right])
        XCTAssertEqual(simulation.piles[0].heights, [7, 4, 6])
        simulation.inheritAccumulation(from: [left, right])
        XCTAssertEqual(simulation.piles[0].heights, [7, 4, 6])
    }

    func testTransferIgnoresOtherModesFloorsAndMissingIDs() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.setSurfaces([
            Surface(id: 0, x: 0, y: 499, width: 500),
            Surface(id: 10, x: 0, y: 100, width: 12)
        ])
        simulation.inheritAccumulation(from: [
            samplePile(id: 0, heights: [8, 8, 8]),
            samplePile(id: 10, mode: .rain, heights: [4, 4, 4]),
            samplePile(id: 999, heights: [8, 8, 8])
        ])
        XCTAssertEqual(simulation.piles.map(\.surfaceID), [0, 10])
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }

    func testTransferSanitizesHeightsAndRespectsModeCap() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.mode = .rain
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 24)])
        simulation.inheritAccumulation(from: [
            samplePile(id: 10, mode: .rain, heights: [.nan, .infinity, -5, 90, 2])
        ])
        XCTAssertEqual(simulation.piles[0].heights, [0, 0, 0, 1.5, 1.5])
    }

    func testDisabledAccumulationCannotBeRestoredByTransfer() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 12)])
        simulation.accumulationEnabled = false
        simulation.inheritAccumulation(from: [samplePile(id: 10, heights: [8, 8, 8])])
        XCTAssertEqual(simulation.piles[0].heights, [0, 0, 0])
    }

    func testFreshSnapshotsAfterGlobalClearDoNotRestoreAccumulation() {
        let first = populatedSimulation(mode: .snow)
        let second = WeatherSimulation(width: 500, height: 500)
        second.setSurfaces([Surface(id: 10, x: 0, y: 100, width: 500)])
        second.inheritAccumulation(from: first.piles)
        XCTAssertGreaterThan(second.piles[0].heights.max() ?? 0, 0)
        first.clearAccumulation()
        second.clearAccumulation()
        let freshSnapshot = first.piles + second.piles
        first.inheritAccumulation(from: freshSnapshot)
        second.inheritAccumulation(from: freshSnapshot)
        XCTAssertTrue((first.piles + second.piles).allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }

    func testLongRunningSnowKeepsAnUnevenRidgeAndTaperedEdges() throws {
        let simulation = WeatherSimulation(width: 1_000, height: 200, seed: 321)
        simulation.intensity = 1
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 10, width: 1_000)])
        // Four simulated minutes is enough to expose a uniform global-cap plateau.
        for _ in 0..<2_400 { simulation.update(deltaTime: 0.1) }
        let heights = try XCTUnwrap(simulation.piles.first).heights
        let interior = Array(heights.dropFirst(3).dropLast(3))
        XCTAssertGreaterThan(try XCTUnwrap(interior.min()), 8)
        XCTAssertGreaterThan(try XCTUnwrap(interior.max()) - XCTUnwrap(interior.min()), 2)
        XCTAssertLessThanOrEqual(try XCTUnwrap(heights.max()), WeatherSimulation.maximumSnowHeight)
        XCTAssertEqual(try XCTUnwrap(heights.first), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(heights.last), 0, accuracy: 0.001)
        XCTAssertLessThan(heights[1], heights[2])
        XCTAssertLessThan(heights[heights.count - 2], heights[heights.count - 3])
    }

    func testSeasonalModesHaveDistinctFallingShapesAndMotion() throws {
        for mode in [WeatherMode.autumn, .cherryBlossom] {
            let simulation = WeatherSimulation(width: 1_000, height: 1_000, seed: 51)
            simulation.mode = mode
            simulation.intensity = 1
            for _ in 0..<10 { simulation.update(deltaTime: 0.1) }
            XCTAssertFalse(simulation.particles.isEmpty)
            let leaf = mode == .autumn
            XCTAssertTrue(simulation.particles.allSatisfy {
                (leaf ? 7...14 : 5...9).contains($0.size)
                    && (leaf ? 40...95 : 25...65).contains($0.vy)
                    && $0.rotation.isFinite && $0.phase.isFinite
                    && (0...2).contains($0.variant)
            })
            let first = try XCTUnwrap(simulation.particles.first)
            simulation.update(deltaTime: 0.1)
            XCTAssertNotEqual(try XCTUnwrap(simulation.particles.first).rotation, first.rotation)
            XCTAssertNotEqual(try XCTUnwrap(simulation.particles.first).x, first.x)
            XCTAssertTrue(simulation.splashes.isEmpty)
        }
    }

    func testSeasonalParticlesSettleDeterministicallyAndFollowTheirWindow() {
        for mode in [WeatherMode.autumn, .cherryBlossom] {
            let simulation = populatedSimulation(mode: mode, seed: 55)
            let duplicate = populatedSimulation(mode: mode, seed: 55)
            let items = simulation.settledParticles
            XCTAssertFalse(items.isEmpty)
            XCTAssertEqual(items, duplicate.settledParticles)
            XCTAssertTrue(items.allSatisfy { $0.mode == mode && $0.surfaceID == 10 && (0...1).contains($0.position) })
            simulation.setSurfaces([Surface(id: 10, x: 75, y: 140, width: 1_700)])
            XCTAssertEqual(simulation.settledParticles, items)
            XCTAssertEqual(simulation.piles[0].x, 75)
            XCTAssertEqual(simulation.piles[0].width, 1_700)
            simulation.setSurfaces([])
            XCTAssertTrue(simulation.settledParticles.isEmpty)
        }
    }

    func testSeasonalTransferKeepsUniqueItemsAndDoesNotExtendLifetime() {
        let first = populatedSimulation(mode: .autumn)
        let second = WeatherSimulation(width: 1_200, height: 800, seed: 10)
        second.mode = .autumn
        second.setSurfaces([Surface(id: 10, x: 40, y: 200, width: 1_400)])
        second.inheritAccumulation(from: first.piles)
        second.inheritSettledParticles(from: first.settledParticles)
        XCTAssertEqual(second.settledParticles, first.settledParticles)
        second.intensity = 0
        second.update(deltaTime: 0.1)
        let aged = second.settledParticles
        second.inheritSettledParticles(from: first.settledParticles + first.settledParticles)
        XCTAssertEqual(second.settledParticles, aged)
        XCTAssertEqual(Set(second.settledParticles.map(\.id)).count, second.settledParticles.count)
        second.mode = .cherryBlossom
        second.inheritSettledParticles(from: first.settledParticles)
        XCTAssertTrue(second.settledParticles.isEmpty)
    }

    func testSeasonalClearDisableAndModeChangeRemoveRestingShapes() {
        let simulation = populatedSimulation(mode: .cherryBlossom)
        let snapshot = simulation.settledParticles
        XCTAssertFalse(snapshot.isEmpty)
        simulation.clearAccumulation()
        XCTAssertTrue(simulation.settledParticles.isEmpty)
        simulation.inheritSettledParticles(from: snapshot)
        XCTAssertFalse(simulation.settledParticles.isEmpty)
        simulation.accumulationEnabled = false
        for _ in 0..<60 { simulation.update(deltaTime: 0.1) }
        simulation.inheritSettledParticles(from: snapshot)
        XCTAssertTrue(simulation.settledParticles.isEmpty)
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
        simulation.accumulationEnabled = true
        simulation.inheritSettledParticles(from: snapshot)
        simulation.mode = .snow
        XCTAssertTrue(simulation.settledParticles.isEmpty)
        XCTAssertTrue(simulation.particles.isEmpty)
    }

    func testSeasonalRestingShapesExpireWithoutAnInvisibleCollisionRidge() {
        for mode in [WeatherMode.autumn, .cherryBlossom] {
            let simulation = populatedSimulation(mode: mode)
            XCTAssertFalse(simulation.settledParticles.isEmpty)
            simulation.intensity = 0
            for _ in 0..<1_000 { simulation.update(deltaTime: 0.1) }
            XCTAssertTrue(simulation.settledParticles.isEmpty)
            XCTAssertTrue(simulation.particles.isEmpty)
            XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
        }
    }

    func testSeasonalTransferRejectsFloorsUnknownSurfacesAndInvalidValues() throws {
        let source = populatedSimulation(mode: .autumn)
        let item = try XCTUnwrap(source.settledParticles.first)
        let destination = WeatherSimulation(width: 800, height: 500)
        destination.mode = .autumn
        destination.setSurfaces([
            Surface(id: 0, x: 0, y: 499, width: 800),
            Surface(id: 10, x: 20, y: 100, width: 500)
        ])
        var floor = item; floor.surfaceID = 0
        var unknown = item; unknown.surfaceID = 999
        var expired = item; expired.life = 0
        var invalid = item; invalid.position = .nan
        var oversized = item; oversized.size = .infinity
        destination.inheritSettledParticles(from: [floor, unknown, expired, invalid, oversized])
        XCTAssertTrue(destination.settledParticles.isEmpty)
        destination.inheritSettledParticles(from: [item])
        XCTAssertEqual(destination.settledParticles, [item])
    }

    func testHeavySeasonalWeatherRespectsRestingShapeAndHeightBudgets() {
        for mode in [WeatherMode.autumn, .cherryBlossom] {
            let simulation = WeatherSimulation(width: 8_000, height: 200, seed: 33)
            simulation.mode = mode
            simulation.intensity = 1
            simulation.setSurfaces([Surface(id: 10, x: 0, y: 10, width: 8_000)])
            for _ in 0..<600 { simulation.update(deltaTime: 0.1) }
            XCTAssertEqual(simulation.settledParticles.count, WeatherSimulation.maximumSettledParticles)
            XCTAssertLessThanOrEqual(simulation.particles.count, WeatherSimulation.maximumParticles)
            let cap = mode == .autumn ? WeatherSimulation.maximumLeafHeight : WeatherSimulation.maximumPetalHeight
            XCTAssertLessThanOrEqual(simulation.piles[0].heights.max() ?? 0, cap)
            XCTAssertTrue(simulation.settledParticles.allSatisfy { $0.offsetY.isFinite && $0.rotation.isFinite })
        }
    }

    func testBubblesAndConfettiHaveDistinctMotionAndSizes() throws {
        for mode in [WeatherMode.bubbles, .confetti] {
            let simulation = WeatherSimulation(width: 1_000, height: 1_000, seed: 51)
            simulation.mode = mode
            simulation.intensity = 1
            simulation.wind = 0.4
            for _ in 0..<10 { simulation.update(deltaTime: 0.1) }
            let bubble = mode == .bubbles
            XCTAssertFalse(simulation.particles.isEmpty)
            XCTAssertTrue(simulation.particles.allSatisfy {
                (bubble ? 10...20 : 5...9).contains($0.size)
                    && (bubble ? 18...38 : 45...100).contains($0.vy)
                    && (0..<(bubble ? 3 : 6)).contains($0.variant)
            })
            let first = try XCTUnwrap(simulation.particles.first)
            simulation.update(deltaTime: 0.1)
            let moved = try XCTUnwrap(simulation.particles.first)
            XCTAssertGreaterThan(moved.y, first.y)
            XCTAssertNotEqual(moved.x, first.x)
            XCTAssertNotEqual(moved.rotation, first.rotation)
            XCTAssertTrue(simulation.splashes.isEmpty)
        }
    }

    func testNewEffectsSettleDeterministicallyAndFollowMovingWindows() {
        for mode in [WeatherMode.bubbles, .confetti] {
            let simulation = populatedSimulation(mode: mode, seed: 55)
            let duplicate = populatedSimulation(mode: mode, seed: 55)
            let items = simulation.settledParticles
            XCTAssertFalse(items.isEmpty)
            XCTAssertEqual(items, duplicate.settledParticles)
            XCTAssertTrue(items.allSatisfy {
                $0.mode == mode && $0.surfaceID == 10 && (0...1).contains($0.position)
                    && $0.life > 0 && $0.life <= (mode == .bubbles ? 10 : 45)
            })
            if mode == .bubbles {
                XCTAssertTrue(items.allSatisfy { $0.offsetY >= $0.size / 2 })
            }
            simulation.setSurfaces([Surface(id: 10, x: 75, y: 140, width: 1_700)])
            XCTAssertEqual(simulation.settledParticles, items)
            XCTAssertEqual(simulation.piles[0].x, 75)
            simulation.setSurfaces([])
            XCTAssertTrue(simulation.settledParticles.isEmpty)
        }
    }

    func testNewEffectsExpireWithoutLeavingInvisibleCollisionRidges() {
        for mode in [WeatherMode.bubbles, .confetti] {
            let simulation = populatedSimulation(mode: mode)
            XCTAssertFalse(simulation.settledParticles.isEmpty)
            simulation.intensity = 0
            for _ in 0..<(mode == .bubbles ? 200 : 550) { simulation.update(deltaTime: 0.1) }
            XCTAssertTrue(simulation.particles.isEmpty)
            XCTAssertTrue(simulation.settledParticles.isEmpty)
            XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
        }
    }

    func testNewEffectsClearDisableAndModeChangeRemoveRestingParticles() {
        for mode in [WeatherMode.bubbles, .confetti] {
            let simulation = populatedSimulation(mode: mode)
            let snapshot = simulation.settledParticles
            XCTAssertFalse(snapshot.isEmpty)
            simulation.clearAccumulation()
            XCTAssertTrue(simulation.settledParticles.isEmpty)
            simulation.inheritSettledParticles(from: snapshot)
            XCTAssertFalse(simulation.settledParticles.isEmpty)
            simulation.accumulationEnabled = false
            for _ in 0..<60 { simulation.update(deltaTime: 0.1) }
            simulation.inheritSettledParticles(from: snapshot)
            XCTAssertTrue(simulation.settledParticles.isEmpty)
            XCTAssertFalse(simulation.particles.isEmpty)
            XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
            simulation.accumulationEnabled = true
            simulation.inheritSettledParticles(from: snapshot)
            simulation.mode = .snow
            XCTAssertTrue(simulation.settledParticles.isEmpty)
            XCTAssertTrue(simulation.particles.isEmpty)
        }
    }

    func testNewEffectTransferKeepsAllVariantsWithoutExtendingLifetime() {
        for mode in [WeatherMode.bubbles, .confetti] {
            let destination = WeatherSimulation(width: 1_200, height: 800)
            destination.mode = mode
            destination.intensity = 0
            destination.setSurfaces([Surface(id: 10, x: 40, y: 200, width: 1_400)])
            let count = mode == .bubbles ? 3 : 6
            let items = (0..<count).map { variant in
                SettledParticle(id: UInt64(variant), mode: mode, surfaceID: 10,
                                position: Double(variant) / Double(count), offsetY: 10,
                                size: mode == .bubbles ? 16 : 7, rotation: 0,
                                variant: variant, life: mode == .bubbles ? 10 : 45)
            }
            destination.inheritSettledParticles(from: items)
            XCTAssertEqual(destination.settledParticles, items)
            destination.update(deltaTime: 0.1)
            let aged = destination.settledParticles
            destination.inheritSettledParticles(from: items + items)
            XCTAssertEqual(destination.settledParticles, aged)
            destination.mode = .snow
            destination.inheritSettledParticles(from: items)
            XCTAssertTrue(destination.settledParticles.isEmpty)
        }
    }

    func testNewEffectTransferRejectsInvalidVariantsSizesAndLifetimes() throws {
        for mode in [WeatherMode.bubbles, .confetti] {
            let item = try XCTUnwrap(populatedSimulation(mode: mode).settledParticles.first)
            let destination = WeatherSimulation(width: 800, height: 500)
            destination.mode = mode
            destination.setSurfaces([Surface(id: 10, x: 20, y: 100, width: 500)])
            var badVariant = item; badVariant.variant = mode == .bubbles ? 3 : 6
            var tooLarge = item; tooLarge.size = mode == .bubbles ? 21 : 10
            var tooOld = item; tooOld.life = mode == .bubbles ? 11 : 46
            var invalid = item; invalid.position = .nan
            var floor = item; floor.surfaceID = 0
            var unknown = item; unknown.surfaceID = 999
            destination.inheritSettledParticles(from: [badVariant, tooLarge, tooOld, invalid, floor, unknown])
            XCTAssertTrue(destination.settledParticles.isEmpty)
            destination.inheritSettledParticles(from: [item])
            XCTAssertEqual(destination.settledParticles, [item])
        }
    }

    func testHeavyNewEffectsRespectParticleAndHeightBudgets() {
        for mode in [WeatherMode.bubbles, .confetti] {
            let simulation = WeatherSimulation(width: 8_000, height: 200, seed: 33)
            simulation.mode = mode
            simulation.intensity = 100
            simulation.wind = .infinity
            simulation.setSurfaces([Surface(id: 10, x: 0, y: 10, width: 8_000)])
            for _ in 0..<600 { simulation.update(deltaTime: 0.1) }
            XCTAssertFalse(simulation.settledParticles.isEmpty)
            XCTAssertLessThanOrEqual(simulation.settledParticles.count, WeatherSimulation.maximumSettledParticles)
            XCTAssertLessThanOrEqual(simulation.particles.count, WeatherSimulation.maximumParticles)
            let cap = mode == .bubbles ? WeatherSimulation.maximumBubbleHeight : WeatherSimulation.maximumConfettiHeight
            XCTAssertLessThanOrEqual(simulation.piles[0].heights.max() ?? 0, cap)
            XCTAssertTrue(simulation.settledParticles.allSatisfy { $0.offsetY.isFinite && $0.rotation.isFinite })
            XCTAssertTrue(simulation.particles.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
    }

    private func samplePile(id: UInt32, mode: WeatherMode = .snow, heights: [Double]) -> Pile {
        Pile(surfaceID: id, x: 0, y: 100, width: 12,
             heights: heights, segments: [.init(minX: 0, maxX: 12)], mode: mode)
    }

    private func populatedSimulation(mode: WeatherMode, seed: UInt64 = 123) -> WeatherSimulation {
        let simulation = WeatherSimulation(width: 1_000, height: 200, seed: seed)
        simulation.mode = mode
        simulation.intensity = 1
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 10, width: 1_000)])
        for _ in 0..<450 { simulation.update(deltaTime: 1.0 / 30) }
        return simulation
    }
}
