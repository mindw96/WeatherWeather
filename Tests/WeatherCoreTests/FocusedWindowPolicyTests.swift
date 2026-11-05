import XCTest
@testable import WeatherCore

final class FocusedWindowPolicyTests: XCTestCase {
    private func window(_ id: UInt32, owner: Int32? = 100,
                        x: Double = 20, y: Double = 40,
                        width: Double = 300, height: Double = 200) -> WindowGeometry {
        WindowGeometry(id: id, x: x, y: y, width: width, height: height,
                       ownerProcessID: owner)
    }

    func testChoosesActiveApplicationsFrontmostWindowDespiteAnotherAppAboveIt() {
        let windows = [window(1, owner: 200), window(2), window(3)]
        XCTAssertEqual(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 100), 2)
    }

    func testSwitchingWindowsWithinSameApplicationChangesOnlyTheHiddenTarget() {
        let first = window(1), second = window(2)
        for windows in [[first, second], [second, first]] {
            let focused = FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 100)
            XCTAssertEqual(focused, windows[0].id)
            XCTAssertEqual(FocusedWindowPolicy.hiddenWindow(in: windows, focusedWindowID: focused,
                                                            showEffectsOnFocusedWindow: false), windows[0])
        }
    }

    func testSwitchingActiveApplicationDoesNotRetainPreviousWindow() {
        let windows = [window(1, owner: 100), window(2, owner: 200)]
        XCTAssertEqual(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 100), 1)
        XCTAssertEqual(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 200), 2)
    }

    func testMissingOrInvalidActiveProcessDoesNotFallBackToAnotherWindow() {
        let windows = [window(1)]
        for processID: Int32? in [nil, 0, -1, 200] {
            XCTAssertNil(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: processID))
        }
        XCTAssertNil(FocusedWindowPolicy.focusedWindowID(in: [], frontmostProcessID: 100))
    }

    func testMissingOwnerMetadataCannotBeMistakenForActiveApplication() {
        let windows = [window(1, owner: nil), window(2, owner: 100)]
        XCTAssertEqual(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 100), 2)
        XCTAssertNil(FocusedWindowPolicy.focusedWindowID(in: [windows[0]], frontmostProcessID: 100))
    }

    func testInvalidWindowGeometryIsSkippedBeforeSelectingWorkingWindow() {
        let windows = [
            window(1, x: .nan),
            window(2, y: .infinity),
            window(3, width: 0),
            window(4, height: -10),
            window(5, x: .greatestFiniteMagnitude, width: .greatestFiniteMagnitude),
            window(6)
        ]
        XCTAssertEqual(FocusedWindowPolicy.focusedWindowID(in: windows, frontmostProcessID: 100), 6)
    }

    func testEnabledOptionLeavesWorkingWindowVisible() {
        XCTAssertNil(FocusedWindowPolicy.hiddenWindow(in: [window(1)], focusedWindowID: 1,
                                                     showEffectsOnFocusedWindow: true))
    }

    func testDisabledOptionReturnsMatchingWindowWithDisplayLocalCoordinates() {
        let localWindow = window(2, x: -80, y: -15, width: 600, height: 450)
        XCTAssertEqual(FocusedWindowPolicy.hiddenWindow(in: [window(1), localWindow], focusedWindowID: 2,
                                                       showEffectsOnFocusedWindow: false), localWindow)
    }

    func testNoTargetOnDisplayDoesNotHideOtherWindows() {
        for focusedID: UInt32? in [nil, 2] {
            XCTAssertNil(FocusedWindowPolicy.hiddenWindow(in: [window(1)], focusedWindowID: focusedID,
                                                         showEffectsOnFocusedWindow: false))
        }
    }

    func testInvalidHiddenWindowBoundsNeverProduceAnExclusionRegion() {
        XCTAssertNil(FocusedWindowPolicy.hiddenWindow(in: [window(1, height: .infinity)], focusedWindowID: 1,
                                                     showEffectsOnFocusedWindow: false))
    }
}
