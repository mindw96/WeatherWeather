import XCTest
@testable import WeatherCore

final class CurvedSurfaceTests: XCTestCase {
    func testRoundedBaselineUsesOneSymmetricProfileForDrawingAndCollision() throws {
        let simulation = roundedSimulation()
        let pile = try XCTUnwrap(simulation.piles.first)
        XCTAssertEqual(pile.baselineY(at: 0), 120)
        XCTAssertEqual(pile.baselineY(at: 200), 120)
        XCTAssertEqual(pile.baselineY(at: 20), 100)
        XCTAssertEqual(pile.baselineY(at: 100), 100)
        XCTAssertEqual(pile.baselineY(at: 2), 120 - sqrt(76), accuracy: 1e-10)
        XCTAssertEqual(pile.baselineY(at: 198), pile.baselineY(at: 2), accuracy: 1e-10)
        XCTAssertEqual(pile.baselineY(at: 1), (pile.baselineY(at: 0) + pile.baselineY(at: 2)) / 2,
                       accuracy: 1e-10)
        XCTAssertEqual(pile.baselineY(at: .nan), 100)
    }

    func testAllEffectsHitCurvedCornersWithoutAnInvisibleFlatLedge() throws {
        for mode in WeatherMode.allCases {
            let simulation = roundedSimulation(mode: mode)
            XCTAssertNil(simulation.firstCollision(fromX: 102, y: 90, toX: 102, y: 105), "\(mode)")
            let hit = try XCTUnwrap(simulation.firstCollision(fromX: 102, y: 105, toX: 102, y: 140))
            XCTAssertEqual(hit.y, 120 - sqrt(76), accuracy: 1e-10, "\(mode)")
            let center = try XCTUnwrap(simulation.firstCollision(fromX: 150, y: 90, toX: 150, y: 140))
            XCTAssertEqual(center.y, 100)
            XCTAssertNil(simulation.firstCollision(fromX: 99, y: 90, toX: 99, y: 140))
            XCTAssertNil(simulation.firstCollision(fromX: 102, y: 125, toX: 102, y: 140))
        }
    }

    func testFastDiagonalSweepFindsCurveEvenWhenBothEndpointsMissItsRectangleTop() throws {
        let simulation = roundedSimulation(mode: .rain)
        let pile = try XCTUnwrap(simulation.piles.first)
        for (startX, endX) in [(90.0, 310.0), (310.0, 90.0)] {
            let hit = try XCTUnwrap(simulation.firstCollision(fromX: startX, y: 110, toX: endX, y: 111))
            XCTAssertEqual(hit.y, pile.baselineY(at: hit.x - pile.x), accuracy: 1e-9)
            XCTAssertGreaterThan(hit.fraction, 0)
            XCTAssertLessThan(hit.fraction, 0.2)
        }
        let diagonal = try XCTUnwrap(simulation.firstCollision(fromX: 88, y: 80, toX: 140, y: 120))
        XCTAssertEqual(diagonal.y, pile.baselineY(at: diagonal.x - pile.x), accuracy: 1e-9)
    }

    func testNearestCurvedSurfaceWinsAndOccludedCornerDoesNotIntercept() throws {
        let simulation = roundedSimulation()
        simulation.setSurfaces([
            Surface(id: 2, x: 100, y: 140, width: 200, cornerRadius: 20),
            Surface(id: 1, x: 100, y: 100, width: 200, cornerRadius: 20)
        ])
        let hit = try XCTUnwrap(simulation.firstCollision(fromX: 102, y: 50, toX: 102, y: 200))
        XCTAssertEqual(simulation.piles[hit.pileIndex].surfaceID, 1)
        simulation.setSurfaces([
            Surface(id: 1, x: 100, y: 100, width: 200,
                    segments: [.init(minX: 25, maxX: 175)], cornerRadius: 20)
        ])
        XCTAssertNil(simulation.firstCollision(fromX: 102, y: 50, toX: 102, y: 200))
        XCTAssertNotNil(simulation.firstCollision(fromX: 150, y: 50, toX: 150, y: 200))
    }

    func testAccumulatedHeightAndSettledOffsetsFollowMovingResizedCurvedWindow() throws {
        for mode in WeatherMode.allCases {
            let simulation = roundedSimulation(mode: mode)
            simulation.inheritAccumulation(from: [
                Pile(surfaceID: 1, x: 0, y: 0, width: 200, heights: [3, 3, 3],
                     segments: [.init(minX: 0, maxX: 200)], mode: mode)
            ])
            simulation.setSurfaces([Surface(id: 1, x: 50, y: 150, width: 400, cornerRadius: 30)])
            let pile = try XCTUnwrap(simulation.piles.first)
            XCTAssertEqual(pile.cornerRadius, 30)
            XCTAssertEqual(pile.height(at: 200), 3, accuracy: 1e-10)
            let hit = try XCTUnwrap(simulation.firstCollision(fromX: 52, y: 140, toX: 52, y: 200))
            XCTAssertEqual(hit.y, pile.baselineY(at: 2) - 3, accuracy: 1e-10)
            if mode.hasSettledParticles {
                let item = SettledParticle(id: 1, mode: mode, surfaceID: 1, position: 0.005,
                                           offsetY: 6, size: mode == .bubbles ? 12 : 8, rotation: 0, variant: 0, life: 8)
                simulation.inheritSettledParticles(from: [item])
                simulation.setSurfaces([Surface(id: 1, x: 80, y: 200, width: 400, cornerRadius: 20)])
                XCTAssertEqual(simulation.settledParticles, [item])
                XCTAssertEqual(simulation.piles.first?.cornerRadius, 20)
            }
        }
    }

    func testCrossDisplayTransferPreservesDestinationCurveAndLocalHeight() throws {
        let source = roundedSimulation()
        source.inheritAccumulation(from: [
            Pile(surfaceID: 1, x: 0, y: 0, width: 200, heights: [2, 5, 3],
                 segments: [.init(minX: 0, maxX: 200)], mode: .snow)
        ])
        let destination = WeatherSimulation(width: 800, height: 600)
        destination.setSurfaces([Surface(id: 1, x: -100, y: 160, width: 400, cornerRadius: 30)])
        destination.inheritAccumulation(from: source.piles)
        let pile = try XCTUnwrap(destination.piles.first)
        XCTAssertEqual(pile.cornerRadius, 30)
        XCTAssertEqual(pile.x, -100)
        XCTAssertEqual(pile.baselineY(at: 0), 190)
        XCTAssertEqual(pile.height(at: 200), 5, accuracy: 1e-10)
        let before = destination.piles
        destination.inheritAccumulation(from: source.piles)
        XCTAssertEqual(destination.piles, before)
    }

    func testInvalidRadiiAreSanitizedAndFloorsRemainFlat() {
        let simulation = WeatherSimulation(width: 800, height: 600)
        var mutated = Surface(id: 4, x: 0, y: 0, width: 80)
        mutated.cornerRadius = .infinity
        simulation.setSurfaces([
            Surface(id: 0, x: 0, y: 500, width: 800, cornerRadius: 26),
            Surface(id: 1, x: 0, y: 100, width: 80, cornerRadius: -10),
            Surface(id: 2, x: 0, y: 200, width: 80, cornerRadius: .nan),
            Surface(id: 3, x: 0, y: 300, width: 80, cornerRadius: 1000), mutated
        ])
        XCTAssertEqual(simulation.surfaces.map(\.cornerRadius), [0, 0, 0, 40, 0])
        XCTAssertEqual(simulation.piles.map(\.cornerRadius), [0, 0, 0, 40, 0])
        XCTAssertEqual(simulation.piles[0].baselineY(at: 0), 500)
        XCTAssertTrue(simulation.piles.allSatisfy { $0.baselineY(at: 5).isFinite })
        XCTAssertNil(simulation.firstCollision(fromX: .nan, y: 0, toX: 5, y: 100))
    }

    func testWindowRadiusPropagationClampsHeightAndScreenFillingSurfacesStayFlat() {
        var window = WindowGeometry(id: 1, x: 10, y: 40, width: 200, height: 50, cornerRadius: 100)
        XCTAssertEqual(window.cornerRadius, 25)
        window.cornerRadius = 100
        XCTAssertEqual(visibleTopSegments(for: [window]).first?.cornerRadius, 25)
        let policy = FullScreenPolicy(width: 800, height: 600)
        let full = WindowGeometry(id: 2, x: 0, y: 0, width: 800, height: 600, cornerRadius: 26)
        let surfaces = policy.surfaces(for: [window, full], accumulateOnFullScreen: true)
        XCTAssertEqual(surfaces.first { $0.id == 1 }?.cornerRadius, 25)
        XCTAssertEqual(surfaces.first { $0.id == 2 }?.cornerRadius, 0)
        XCTAssertEqual(surfaces.first { $0.id == 0 }?.cornerRadius, 0)
        window.cornerRadius = .infinity
        XCTAssertEqual(visibleTopSegments(for: [window]).first?.cornerRadius, 0)
    }

    private func roundedSimulation(mode: WeatherMode = .snow) -> WeatherSimulation {
        let simulation = WeatherSimulation(width: 800, height: 600)
        simulation.mode = mode
        simulation.setSurfaces([Surface(id: 1, x: 100, y: 100, width: 200, cornerRadius: 20)])
        return simulation
    }
}
