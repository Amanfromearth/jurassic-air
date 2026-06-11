import XCTest
import SpriteKit
@testable import Quackpilot

/// Scene state machine. We don't render anything to the screen; we just spawn
/// nodes into an SKScene and inspect the tree to verify spawn/dismiss
/// invariants — including the bug we'd hit if a second spawn leaked nodes
/// from a previous flight.
final class PlaneSceneTests: XCTestCase {

    private func makeScene() -> PlaneScene {
        let scene = PlaneScene(size: CGSize(width: 1440, height: 900))
        scene.scaleMode = .resizeFill
        return scene
    }

    private func sampleEvent(_ title: String = "Test") -> ReminderEvent {
        ReminderEvent(title: title, urlString: "https://example.com")
    }

    // MARK: - spawn

    func testSpawnAddsPlaneRopeAndBanner() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        // Plane, rope, banner = 3 children added.
        XCTAssertEqual(scene.children.count, 3)
        XCTAssertTrue(scene.children.contains { $0 is PlaneNode })
        XCTAssertTrue(scene.children.contains { $0 is BannerRibbon })
    }

    func testSecondSpawnReplacesFirstInsteadOfStacking() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent("first"))
        scene.spawn(event: sampleEvent("second"))
        // Still only 3 children — the previous flight is removed before the new
        // one is added.
        XCTAssertEqual(scene.children.count, 3,
                       "second spawn should replace, not stack on top of, the first")
        XCTAssertEqual(scene.children.filter { $0 is PlaneNode }.count, 1)
        XCTAssertEqual(scene.children.filter { $0 is BannerRibbon }.count, 1)
    }

    func testPlaneIsZAbovesRope() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        let plane = scene.children.first { $0 is PlaneNode }!
        let rope = scene.children.first {
            // The only non-plane, non-banner sprite is the rope (a plain SKSpriteNode).
            $0 is SKSpriteNode && !($0 is PlaneNode) && !($0 is BannerRibbon)
        }!
        let banner = scene.children.first { $0 is BannerRibbon }!
        XCTAssertGreaterThan(plane.zPosition, rope.zPosition,
                             "plane must draw on top of the rope (tucks into fuselage)")
        XCTAssertGreaterThan(rope.zPosition, banner.zPosition,
                             "rope must draw in front of the banner")
    }

    // MARK: - cursor hit testing

    func testCursorOverPlaneIsInteractive() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        let plane = scene.children.first { $0 is PlaneNode }!
        XCTAssertTrue(scene.cursorIsOverInteractive(plane.position),
                      "plane center must register as interactive")
    }

    func testCursorOverBannerIsInteractive() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        let banner = scene.children.first { $0 is BannerRibbon }!
        XCTAssertTrue(scene.cursorIsOverInteractive(banner.position))
    }

    func testCursorAwayFromAnyNodeIsNotInteractive() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        // Far corner of the scene — way away from where the plane spawned.
        XCTAssertFalse(scene.cursorIsOverInteractive(CGPoint(x: 5_000, y: 5_000)))
    }

    func testCursorIsNotInteractiveWithNoActiveFlight() {
        let scene = makeScene()
        XCTAssertFalse(scene.cursorIsOverInteractive(.zero))
    }

    // MARK: - hasActiveFlight

    func testHasActiveFlightFalseBeforeSpawn() {
        let scene = makeScene()
        XCTAssertFalse(scene.hasActiveFlight)
    }

    func testHasActiveFlightTrueAfterSpawn() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        XCTAssertTrue(scene.hasActiveFlight)
    }

    // MARK: - reloadAssets

    func testReloadAssetsClearsCachesAndDoesNotCrashWithoutFlight() {
        let scene = makeScene()
        // No active flight — should still complete without crashing.
        scene.reloadAssets()
    }

    func testReloadAssetsRefreshesActivePlane() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        let planeBefore = scene.children.first { $0 is PlaneNode } as! PlaneNode
        scene.reloadAssets()
        // The same node is still there — refresh re-skins, not re-creates.
        let planeAfter = scene.children.first { $0 is PlaneNode } as! PlaneNode
        XCTAssertIdentical(planeBefore, planeAfter)
    }
}
