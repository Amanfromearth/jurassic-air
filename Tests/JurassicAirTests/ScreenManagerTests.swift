import XCTest
import AppKit
@testable import JurassicAir

final class ScreenManagerTests: XCTestCase {
    private let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testCursorSelectsExternalDisplayInsteadOfPrimary() {
        let external = CGRect(x: 1440, y: 0, width: 2560, height: 1440)
        XCTAssertEqual(ScreenManager.screenIndex(containing: CGPoint(x: 1800, y: 500),
                                                frames: [primary, external]), 1)
    }

    func testDisplaysToLeftAboveAndBelowPrimary() {
        let frames = [primary,
                      CGRect(x: -1920, y: 0, width: 1920, height: 1080),
                      CGRect(x: 0, y: 900, width: 1920, height: 1080),
                      CGRect(x: 0, y: -1080, width: 1920, height: 1080)]
        for (point, expected) in [(CGPoint(x: -800, y: 400), 1),
                                  (CGPoint(x: 800, y: 1200), 2),
                                  (CGPoint(x: 800, y: -400), 3)] {
            XCTAssertEqual(ScreenManager.screenIndex(containing: point, frames: frames), expected)
        }
    }

    func testSharedEdgeSelectsOnlyOneDisplay() {
        let external = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        XCTAssertEqual(ScreenManager.screenIndex(containing: CGPoint(x: 1440, y: 300),
                                                frames: [primary, external]), 1)
    }

    func testCursorOutsideDisplaysFallsBackToPrimary() {
        XCTAssertEqual(ScreenManager.screenIndex(containing: CGPoint(x: -5000, y: 5000),
                                                frames: [primary]), 0)
        XCTAssertNil(ScreenManager.screenIndex(containing: .zero, frames: []))
    }

    func testStartCreatesOnlyTheCursorDisplaysOverlay() {
        let manager = ScreenManager()
        manager.start()
        defer { manager.controllers.forEach { $0.close() } }
        XCTAssertEqual(manager.controllers.count, NSScreen.screens.isEmpty ? 0 : 1)
        manager.start()
        XCTAssertEqual(manager.controllers.count, NSScreen.screens.isEmpty ? 0 : 1)
    }

    func testRepeatedFlightsReuseTheSameDisplayController() throws {
        guard let screen = NSScreen.screens.first else { throw XCTSkip("Requires a connected display") }
        let manager = ScreenManager()
        manager.start()
        defer { manager.controllers.forEach { $0.close() } }
        let point = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        let first = try XCTUnwrap(manager.controllerForCursorScreen(at: point))
        let second = manager.controllerForCursorScreen(at: point)
        XCTAssertIdentical(first, second)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertIdentical(first, manager.controllerForCursorScreen(at: point))
    }

    func testDifferentDisplaysKeepIndependentOverlays() throws {
        let screens = NSScreen.screens
        guard screens.count > 1 else { throw XCTSkip("Requires two connected displays") }
        let manager = ScreenManager()
        manager.start()
        defer { manager.controllers.forEach { $0.close() } }
        let firstFrame = screens[0].frame
        let secondFrame = screens[1].frame
        let first = try XCTUnwrap(manager.controllerForCursorScreen(
            at: CGPoint(x: firstFrame.midX, y: firstFrame.midY)))
        let second = try XCTUnwrap(manager.controllerForCursorScreen(
            at: CGPoint(x: secondFrame.midX, y: secondFrame.midY)))
        XCTAssertFalse(first === second)
        XCTAssertEqual(first.overlayWindow.frame, firstFrame)
        XCTAssertEqual(second.overlayWindow.frame, secondFrame)
        XCTAssertGreaterThanOrEqual(manager.controllers.count, 2)
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        XCTAssertEqual(first.overlayWindow.frame, firstFrame)
        XCTAssertEqual(second.overlayWindow.frame, secondFrame)
        XCTAssertIdentical(first, manager.controllerForCursorScreen(
            at: CGPoint(x: firstFrame.midX, y: firstFrame.midY)))
    }
}
