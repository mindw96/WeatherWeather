import XCTest
@testable import WeatherCore

final class SeasonalDynamicsTests: XCTestCase {
    func testSnowDragShedsBoundedChunksButNotInitialResizeOrTeleport() {
        let simulation = snowyWindow()
        XCTAssertTrue(simulation.splashes.isEmpty)
        let before = simulation.piles[0].heights.reduce(0, +)
        simulation.setSurfaces([Surface(id: 10, x: 35, y: 105, width: 300)])
        XCTAssertFalse(simulation.splashes.isEmpty)
        XCTAssertTrue(simulation.splashes.allSatisfy { (2...5).contains($0.size) && $0.life <= 0.9 })
        XCTAssertLessThan(simulation.piles[0].heights.reduce(0, +), before)
        XCTAssertLessThanOrEqual(simulation.splashes.count, 6)
        let count = simulation.splashes.count
        simulation.setSurfaces([Surface(id: 10, x: 36, y: 105, width: 300)])
        XCTAssertEqual(simulation.splashes.count, count, "Subpixel tracking noise must not emit repeatedly")
        for kind in 0..<3 {
            let quiet = snowyWindow()
            if kind == 0 { quiet.movementReactionEnabled = false }
            quiet.setSurfaces([Surface(id: 10, x: kind == 1 ? 800 : 35, y: 105,
                                      width: kind == 2 ? 400 : 300)])
            XCTAssertTrue(quiet.splashes.isEmpty)
        }
    }

    func testStrongWindLiftsLeavesAndPetalsThenTheyLandAgain() {
        for mode in [WeatherMode.autumn, .cherryBlossom] {
            let simulation = WeatherSimulation(width: 1_000, height: 700, seed: 71)
            simulation.mode = mode
            simulation.intensity = 0
            simulation.setSurfaces([Surface(id: 10, x: 0, y: 250, width: 1_000)])
            let items = (0..<60).map { i in
                SettledParticle(id: UInt64(i + 1), mode: mode, surfaceID: 10, position: 0.15 + Double(i) / 100,
                                offsetY: 3, size: 8, rotation: 0, variant: i % 3, life: 40)
            }
            simulation.inheritSettledParticles(from: items)
            simulation.wind = 0.6
            for _ in 0..<10 { simulation.update(deltaTime: 0.1) }
            XCTAssertTrue(simulation.particles.isEmpty, "Gentle wind must leave the pile at rest")
            simulation.wind = 1
            for _ in 0..<10 { simulation.update(deltaTime: 0.1) }
            XCTAssertFalse(simulation.particles.isEmpty)
            XCTAssertTrue(simulation.particles.contains { $0.vy < 0 })
            let restingAfterGust = simulation.settledParticles.count
            simulation.wind = 0
            for _ in 0..<100 { simulation.update(deltaTime: 0.1) }
            XCTAssertTrue(simulation.particles.isEmpty)
            XCTAssertGreaterThan(simulation.settledParticles.count, restingAfterGust)
            XCTAssertTrue(simulation.settledParticles.allSatisfy { $0.life < 40 }, "Landing must not renew lifespan")
            for _ in 0..<450 { simulation.update(deltaTime: 0.1) }
            XCTAssertTrue(simulation.settledParticles.isEmpty)
        }
    }

    func testReactionToggleKeepsSettledLeavesInStrongWind() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.mode = .autumn
        simulation.intensity = 0
        simulation.wind = 1
        simulation.movementReactionEnabled = false
        simulation.setSurfaces([Surface(id: 1, x: 0, y: 200, width: 500)])
        simulation.inheritSettledParticles(from: [SettledParticle(id: 1, mode: .autumn, surfaceID: 1,
            position: 0.5, offsetY: 4, size: 8, rotation: 0, variant: 0, life: 40)])
        for _ in 0..<100 { simulation.update(deltaTime: 0.1) }
        XCTAssertEqual(simulation.settledParticles.count, 1)
        XCTAssertTrue(simulation.particles.isEmpty)
    }

    func testSustainedRainLeavesOnlyShallowWaterOnEachWindow() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.mode = .rain
        simulation.intensity = 1
        simulation.setSurfaces([Surface(id: 1, x: 0, y: 100, width: 240),
                                Surface(id: 2, x: 260, y: 200, width: 240)])
        for _ in 0..<600 {
            simulation.update(deltaTime: 0.1)
            XCTAssertTrue(simulation.splashes.isEmpty)
            XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { (0...1.5).contains($0) } })
        }
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.contains { $0 > 0 } })
        XCTAssertFalse(simulation.particles.isEmpty)
        simulation.clearAccumulation()
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }

    func testRainWithoutAccumulationKeepsStreaksWithoutImpactDroplets() {
        let simulation = WeatherSimulation(width: 500, height: 500)
        simulation.mode = .rain
        simulation.intensity = 1
        simulation.setSurfaces([Surface(id: 1, x: 0, y: 100, width: 500)])
        simulation.accumulationEnabled = false
        for _ in 0..<300 {
            simulation.update(deltaTime: 0.1)
            XCTAssertTrue(simulation.splashes.isEmpty)
        }
        XCTAssertFalse(simulation.particles.isEmpty)
        XCTAssertTrue(simulation.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
    }

    func testGlowingModesSettleBrieflyAndExpireWithoutResidualRidges() {
        for mode in [WeatherMode.fireflies, .stardust] {
            let left = glowingScene(mode), right = glowingScene(mode)
            XCTAssertFalse(left.settledParticles.isEmpty)
            XCTAssertEqual(left.settledParticles, right.settledParticles)
            XCTAssertEqual(left.particles, right.particles)
            XCTAssertTrue(left.particles.allSatisfy { $0.life.isFinite && $0.opacity > 0 && $0.opacity <= 1 })
            XCTAssertTrue(left.settledParticles.allSatisfy { $0.life <= (mode == .fireflies ? 4 : 8) })
            left.intensity = 0
            for _ in 0..<700 { left.update(deltaTime: 0.1) }
            XCTAssertTrue(left.particles.isEmpty)
            XCTAssertTrue(left.settledParticles.isEmpty)
            XCTAssertTrue(left.piles.allSatisfy { $0.heights.allSatisfy { $0 == 0 } })
        }
    }

    func testGlowingTransfersDoNotRenewLifetimeAndRespectSizeLimits() throws {
        for mode in [WeatherMode.fireflies, .stardust] {
            let source = glowingScene(mode)
            let item = try XCTUnwrap(source.settledParticles.first { $0.life > 1 })
            let destination = WeatherSimulation(width: 500, height: 500)
            destination.mode = mode
            destination.intensity = 0
            destination.setSurfaces([Surface(id: 10, x: 40, y: 100, width: 400)])
            var invalid = item; invalid.size = 10
            destination.inheritSettledParticles(from: [invalid])
            XCTAssertTrue(destination.settledParticles.isEmpty)
            destination.inheritSettledParticles(from: [item])
            destination.update(deltaTime: 0.1)
            let aged = destination.settledParticles
            destination.inheritSettledParticles(from: [item, item])
            XCTAssertEqual(destination.settledParticles, aged)
            destination.mode = .rain
            XCTAssertTrue(destination.settledParticles.isEmpty)
        }
    }

    func testNewDynamicsRemainBoundedWithHeavyRainAndStrongWind() {
        for mode in [WeatherMode.rain, .fireflies, .stardust, .autumn] {
            let simulation = WeatherSimulation(width: 8_000, height: 500)
            simulation.mode = mode
            simulation.intensity = 1
            simulation.wind = 1
            simulation.setSurfaces([Surface(id: 10, x: 0, y: 60, width: 8_000)])
            for _ in 0..<400 { simulation.update(deltaTime: 0.1) }
            XCTAssertLessThanOrEqual(simulation.splashes.count, WeatherSimulation.maximumSplashes)
            XCTAssertLessThanOrEqual(simulation.particles.count, WeatherSimulation.maximumParticles)
            XCTAssertLessThanOrEqual(simulation.settledParticles.count, WeatherSimulation.maximumSettledParticles)
            XCTAssertTrue(simulation.particles.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.life.isFinite })
        }
    }

    private func snowyWindow() -> WeatherSimulation {
        let simulation = WeatherSimulation(width: 1_000, height: 500)
        simulation.setSurfaces([Surface(id: 10, x: 20, y: 100, width: 300)])
        simulation.inheritAccumulation(from: [Pile(surfaceID: 10, x: 20, y: 100, width: 300,
            heights: [8, 8, 8], segments: [.init(minX: 0, maxX: 300)], mode: .snow)])
        return simulation
    }

    private func glowingScene(_ mode: WeatherMode) -> WeatherSimulation {
        let simulation = WeatherSimulation(width: 1_000, height: 300, seed: 44)
        simulation.mode = mode
        simulation.intensity = 1
        simulation.setSurfaces([Surface(id: 10, x: 0, y: 40, width: 1_000)])
        for _ in 0..<200 { simulation.update(deltaTime: 0.1) }
        return simulation
    }
}
