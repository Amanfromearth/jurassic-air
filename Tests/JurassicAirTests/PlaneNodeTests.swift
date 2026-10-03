import XCTest
import SpriteKit
@testable import JurassicAir

/// PlaneNode is the composited rig (plane base + head + blade). These tests
/// verify the composite is wired up correctly and the public API (rope tip,
/// refresh) behaves.
final class PlaneNodeTests: XCTestCase {

    func testPlaneHasComposedChildren() {
        let plane = PlaneNode()
        // We don't know which child is which from the outside, but we expect
        // EXACTLY two children — head (z=2) and blade (z=3) — over the plane's
        // own texture.
        XCTAssertEqual(plane.children.count, 2,
                       "PlaneNode should contain head + blade children only")
    }

    func testBladeHasHubAnchor() {
        let plane = PlaneNode()
        // The blade is the higher-z child (z=3).
        let sorted = plane.children.compactMap { $0 as? SKSpriteNode }
                                   .sorted { $0.zPosition < $1.zPosition }
        guard let blade = sorted.last else {
            return XCTFail("expected at least one sprite child")
        }
        XCTAssertEqual(blade.anchorPoint.x, 0.945, accuracy: 0.001)
        XCTAssertEqual(blade.anchorPoint.y, 0.438, accuracy: 0.001)
    }

    func testRefreshAppearanceDoesNotChangeStructure() {
        let plane = PlaneNode()
        let originalChildCount = plane.children.count
        plane.refreshAppearance()
        XCTAssertEqual(plane.children.count, originalChildCount)
    }

    func testRopeTipPositionAccountsForPlanePosition() {
        let plane = PlaneNode()
        plane.position = CGPoint(x: 500, y: 300)
        let tip = plane.ropeTipPosition()
        let expectedOffset = SpriteAssets.planeRopeTipOffset(displaySize: plane.size)
        XCTAssertEqual(tip.x, 500 + expectedOffset.x, accuracy: 0.01)
        XCTAssertEqual(tip.y, 300 + expectedOffset.y, accuracy: 0.01)
    }

    func testBladeSpinAnimationIsRunning() {
        let plane = PlaneNode()
        let sorted = plane.children.compactMap { $0 as? SKSpriteNode }
                                   .sorted { $0.zPosition < $1.zPosition }
        guard let blade = sorted.last else {
            return XCTFail("expected blade child")
        }
        XCTAssertNotNil(blade.action(forKey: "spin"),
                        "blade should have a 'spin' action registered on creation")
    }

    func testIdleBobAnimationIsRunning() {
        let plane = PlaneNode()
        XCTAssertNotNil(plane.action(forKey: "bob"),
                        "plane should have a 'bob' idle animation")
    }
}
