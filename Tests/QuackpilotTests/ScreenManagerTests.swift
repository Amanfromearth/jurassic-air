import XCTest
import AppKit
@testable import Quackpilot

/// Smoke tests for the diff-based rebuild. We can't fake NSScreen instances
/// in unit tests (NSScreen is opaque + system-owned), so these tests just
/// confirm the contract at the boundaries reachable headlessly.
final class ScreenManagerTests: XCTestCase {

    func testStartCreatesAControllerPerCurrentScreen() {
        let manager = ScreenManager()
        manager.start()
        XCTAssertEqual(manager.controllers.count, NSScreen.screens.count,
                       "should have one OverlayWindowController per attached screen")
    }

    func testControllerForMainScreenReturnsSomethingWhenScreensExist() {
        let manager = ScreenManager()
        manager.start()
        guard !NSScreen.screens.isEmpty else {
            return // headless host with no screens — skip
        }
        XCTAssertNotNil(manager.controllerForMainScreen())
    }

    func testControllerForMainScreenPicksPrimaryDisplay() {
        let manager = ScreenManager()
        manager.start()
        guard let primary = NSScreen.screens.first else {
            return // no screens attached
        }
        let picked = manager.controllerForMainScreen()
        XCTAssertEqual(picked?.overlayWindow.screen, primary,
                       "main-screen controller should be the one attached to NSScreen.screens.first")
    }

    func testRebuildIsIdempotent() {
        // Triggering didChangeScreenParameters without any actual screen change
        // shouldn't tear down existing controllers (the diff finds all current
        // screens already present).
        let manager = ScreenManager()
        manager.start()
        let firstControllers = manager.controllers
        NotificationCenter.default.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        // The controller instances should be identical objects (kept, not recreated).
        XCTAssertEqual(manager.controllers.count, firstControllers.count)
        for (a, b) in zip(manager.controllers, firstControllers) {
            XCTAssertIdentical(a, b,
                               "unchanged screens should keep their controller instances")
        }
    }
}
