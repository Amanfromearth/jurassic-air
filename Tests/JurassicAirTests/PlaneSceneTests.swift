import XCTest
import SpriteKit
@testable import JurassicAir

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

    func testLongReminderKeepsFullTitleForHover() throws {
        let scene = makeScene()
        let title = BannerStressFixtures.worst[0].title
        scene.spawn(event: sampleEvent(title))
        let banner = try XCTUnwrap(scene.children.first { $0 is BannerRibbon } as? BannerRibbon)
        XCTAssertTrue(banner.isTruncated)
        XCTAssertEqual(scene.reminderTooltip, title)
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
            $0 is TowRope
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

    func testHoverPauseResumesWithoutMouseMovedEvents() {
        let scene = makeScene()
        scene.spawn(event: sampleEvent())
        let plane = scene.children.first { $0 is PlaneNode }!
        scene.update(1)
        let start = plane.position.x
        scene.setHoverPaused(true)
        scene.update(1.02)
        XCTAssertEqual(plane.position.x, start)
        scene.setHoverPaused(false)
        scene.update(1.04)
        XCTAssertGreaterThan(plane.position.x, start)
    }

    func testFlightCompletionNotifiesOverlayToReleaseRenderingResources() {
        let scene = PlaneScene(size: CGSize(width: 10, height: 360))
        var activity: [Bool] = []
        scene.onFlightActivityChange = { activity.append($0) }
        scene.spawn(event: sampleEvent())
        for frame in 0..<1000 where scene.hasActiveFlight {
            scene.update(Double(frame) / 60 + 1)
        }
        XCTAssertFalse(scene.hasActiveFlight)
        XCTAssertEqual(activity, [true, false])
        XCTAssertTrue(scene.children.isEmpty)
    }

    func testCrossingTimeMatchesOnLaptopUltrawideAndSuperUltrawide() {
        let settings = AppSettings.shared
        let originalSpeed = settings.flightSpeed
        let originalPreset = settings.speedPreset
        defer {
            settings.flightSpeed = originalSpeed
            settings.speedPreset = originalPreset
        }
        settings.flightSpeed = 400
        for preset in SpeedCatalog.presets {
            settings.speedPreset = preset.id
            let crossingFrames = [1440.0, 3440.0, 5120.0].map { width in
                let scene = PlaneScene(size: CGSize(width: width, height: 360))
                scene.spawn(event: sampleEvent())
                var frame = 0
                while scene.hasActiveFlight && frame < 1000 {
                    scene.update(Double(frame) / 60 + 1)
                    frame += 1
                }
                XCTAssertFalse(scene.hasActiveFlight)
                return frame
            }
            XCTAssertLessThanOrEqual(crossingFrames.max()! - crossingFrames.min()!, 1,
                                     "Crossing time must match across widths for \(preset.id)")
        }
    }

    func testUltrawideSpeedStillRespondsToLiveControls() {
        let settings = AppSettings.shared
        let originalSpeed = settings.flightSpeed
        let originalPreset = settings.speedPreset
        defer {
            settings.flightSpeed = originalSpeed
            settings.speedPreset = originalPreset
        }
        settings.flightSpeed = 110
        settings.speedPreset = "normal"
        let scene = PlaneScene(size: CGSize(width: 3440, height: 360))
        scene.spawn(event: sampleEvent())
        let plane = scene.children.first { $0 is PlaneNode }!
        scene.update(1)
        let start = plane.position.x
        scene.update(1.02)
        let normalDistance = plane.position.x - start
        settings.flightSpeed = 220
        settings.speedPreset = "fast"
        let beforeChange = plane.position.x
        scene.update(1.04)
        XCTAssertEqual(plane.position.x - beforeChange, normalDistance * 3, accuracy: 0.001)
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
