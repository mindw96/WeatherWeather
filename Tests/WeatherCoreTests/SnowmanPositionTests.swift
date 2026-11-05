import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import WeatherCore

final class SnowmanPositionTests: XCTestCase {
    private let display = CGRect(x: -300, y: 80, width: 500, height: 300)
    private let size = CGSize(width: 100, height: 80)

    func testEdgePositionsKeepEntireSnowmanInsideDisplay() {
        XCTAssertEqual(SnowmanPosition(x: 0, y: 0).frame(in: display, size: size),
                       CGRect(x: -300, y: 80, width: 100, height: 80))
        XCTAssertEqual(SnowmanPosition(x: 1, y: 1).frame(in: display, size: size),
                       CGRect(x: 100, y: 300, width: 100, height: 80))
    }

    func testDragOutsideDisplayClampsToNearestEdges() {
        let dragged = CGRect(x: -900, y: 900, width: 100, height: 80)
        let position = SnowmanPosition.normalized(frame: dragged, in: display)
        XCTAssertEqual(position, SnowmanPosition(x: 0, y: 1))
        XCTAssertEqual(position?.frame(in: display, size: size),
                       CGRect(x: -300, y: 300, width: 100, height: 80))
    }

    func testRelativePositionSurvivesDisplayResizeAndOriginChange() {
        let original = SnowmanPosition(x: 0.75, y: 0.4)
        let restored = SnowmanPosition.normalized(frame: original.frame(in: display, size: size), in: display)
        XCTAssertEqual(restored, original)
        let smallerDisplay = CGRect(x: 0, y: -100, width: 200, height: 100)
        XCTAssertEqual(restored?.frame(in: smallerDisplay, size: size),
                       CGRect(x: 75, y: -92, width: 100, height: 80))
    }

    func testOversizedSnowmanShrinksWithoutOverflow() {
        let tinyDisplay = CGRect(x: -40, y: 20, width: 50, height: 30)
        let frame = SnowmanPosition(x: 1, y: 1).frame(in: tinyDisplay, size: size)
        XCTAssertEqual(frame, tinyDisplay)
        XCTAssertEqual(SnowmanPosition.normalized(frame: frame, in: tinyDisplay), SnowmanPosition(x: 0, y: 0))
    }

    func testMalformedPositionsCannotPlaceSnowmanOffscreen() {
        var position = SnowmanPosition(x: -10, y: 9)
        XCTAssertEqual(position, SnowmanPosition(x: 0, y: 1))
        position.x = .nan
        position.y = .infinity
        XCTAssertEqual(position.frame(in: display, size: size),
                       CGRect(x: -300, y: 80, width: 100, height: 80))
    }

    func testInvalidGeometryIsRejected() {
        let position = SnowmanPosition(x: 0.5, y: 0.5)
        for invalid in [CGRect.zero, CGRect.null, CGRect.infinite, CGRect(x: CGFloat.infinity, y: 0, width: 10, height: 10),
                        CGRect(x: 0, y: 0, width: -10, height: 10),
                        CGRect(x: 0, y: 0, width: 10, height: CGFloat.nan)] {
            XCTAssertEqual(position.frame(in: invalid, size: size), .zero)
            XCTAssertNil(SnowmanPosition.normalized(frame: display, in: invalid))
            XCTAssertNil(SnowmanPosition.normalized(frame: invalid, in: display))
        }
        XCTAssertEqual(position.frame(in: display, size: CGSize(width: CGFloat.infinity, height: 80)), .zero)
    }

    func testCodableRoundTripPreservesPlacement() throws {
        let positions = ["display-A": SnowmanPosition(x: 0.25, y: 0.8), "display-B": SnowmanPosition(x: 1, y: 0)]
        XCTAssertEqual(try JSONDecoder().decode([String: SnowmanPosition].self,
                                              from: JSONEncoder().encode(positions)), positions)
    }
}
