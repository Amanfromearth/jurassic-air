import XCTest
import AppKit
import SpriteKit
@testable import Quackpilot

/// Geometry math + asset-loading paths in SpriteAssets. No rendering — just the
/// constants and texture-loader functions.
final class SpriteAssetsTests: XCTestCase {

    // MARK: - planeRopeTipOffset

    func testRopeTipUsesQuakpitGeometry() {
        let size = CGSize(width: 200, height: 200)
        let offset = SpriteAssets.planeRopeTipOffset(displaySize: size)
        // relX = 0.123, relY = 0.438 (propeller hub line). For 200×200:
        //   x = (0.123 - 0.5) * 200 = -75.4
        //   y = (0.438 - 0.5) * 200 = -12.4
        XCTAssertEqual(offset.x, -75.4, accuracy: 0.05)
        XCTAssertEqual(offset.y, -12.4, accuracy: 0.05)
    }

    func testRopeTipScalesWithDisplaySize() {
        let small = SpriteAssets.planeRopeTipOffset(displaySize: .init(width: 100, height: 100))
        let large = SpriteAssets.planeRopeTipOffset(displaySize: .init(width: 400, height: 400))
        XCTAssertEqual(small.x * 4, large.x, accuracy: 0.01)
        XCTAssertEqual(small.y * 4, large.y, accuracy: 0.01)
    }

    func testRopeTipXAndYAreNegativeOfCentre() {
        // The rope tip sits to the LEFT of (and slightly BELOW) the plane's
        // visual center — both offsets should be negative.
        let offset = SpriteAssets.planeRopeTipOffset(displaySize: .init(width: 200, height: 200))
        XCTAssertLessThan(offset.x, 0, "rope should be LEFT of plane centre")
        XCTAssertLessThan(offset.y, 0, "rope should be BELOW plane centre (at propeller hub)")
    }

    // MARK: - ropeSize

    func testRopeSizeMatchesQuakpitProportions() {
        // 56/130 ≈ 0.4308 wide, 3/130 ≈ 0.0231 tall, on the plane's display width.
        let size = SpriteAssets.ropeSize(planeWidth: 130)
        XCTAssertEqual(size.width,  56.0, accuracy: 0.01)
        XCTAssertEqual(size.height, max(2, 3.0), accuracy: 0.01)
    }

    func testRopeSizeScales() {
        let small = SpriteAssets.ropeSize(planeWidth: 100)
        let big   = SpriteAssets.ropeSize(planeWidth: 400)
        XCTAssertEqual(big.width / small.width, 4.0, accuracy: 0.001)
    }

    func testRopeHeightHasMinimumOfTwo() {
        // For tiny scaled planes (e.g. 0.2× × 200pt = 40pt wide), 3/130 × 40 = 0.92pt
        // which would render as a sub-pixel line. Code clamps to 2pt minimum.
        let size = SpriteAssets.ropeSize(planeWidth: 40)
        XCTAssertGreaterThanOrEqual(size.height, 2)
    }

    // MARK: - ropeColor

    func testRopeColorMatchesQuakpitRGBA() {
        let c = SpriteAssets.ropeColor.usingColorSpace(.sRGB)!
        XCTAssertEqual(c.redComponent,   35.0/255, accuracy: 0.005)
        XCTAssertEqual(c.greenComponent, 35.0/255, accuracy: 0.005)
        XCTAssertEqual(c.blueComponent,  35.0/255, accuracy: 0.005)
        XCTAssertEqual(c.alphaComponent, 0.78,     accuracy: 0.005)
    }

    // MARK: - texture loaders

    func testEveryHeadIdLoadsAValidTexture() {
        for head in FlierCatalog.heads {
            let t = SpriteAssets.headTexture(headId: head.id)
            XCTAssertGreaterThan(t.size().width, 0, "head '\(head.id)' loaded an empty texture")
            XCTAssertGreaterThan(t.size().height, 0)
        }
    }

    func testEveryPlaneColorLoadsAValidTexture() {
        for color in FlierCatalog.colors {
            let t = SpriteAssets.planeBaseTexture(colorId: color.id)
            XCTAssertGreaterThan(t.size().width, 0, "plane '\(color.id)' loaded an empty texture")
            XCTAssertGreaterThan(t.size().height, 0)
        }
    }

    func testBladeTextureLoads() {
        let t = SpriteAssets.bladeTexture()
        XCTAssertGreaterThan(t.size().width, 0)
        XCTAssertGreaterThan(t.size().height, 0)
    }

    func testUnknownHeadIdReturnsEmptyTextureWithoutCrashing() {
        let t = SpriteAssets.headTexture(headId: "no-such-head")
        XCTAssertEqual(t.size().width, 0)
        XCTAssertEqual(t.size().height, 0)
    }

    func testReloadFromDiskClearsCaches() {
        // Prime the caches.
        _ = SpriteAssets.headTexture(headId: "duck")
        _ = SpriteAssets.planeBaseTexture(colorId: "red")
        _ = SpriteAssets.bladeTexture()
        // Reload. Subsequent loads should still work (i.e. the reload didn't
        // wedge the loader).
        SpriteAssets.reloadFromDisk()
        XCTAssertGreaterThan(SpriteAssets.headTexture(headId: "duck").size().width, 0)
        XCTAssertGreaterThan(SpriteAssets.planeBaseTexture(colorId: "red").size().width, 0)
        XCTAssertGreaterThan(SpriteAssets.bladeTexture().size().width, 0)
    }

    // MARK: - pixel font registration

    func testPixelFontRegistrationReturnsTheFont() {
        SpriteAssets.registerPixelFont()
        let f = SpriteAssets.pixelFont(size: 8)
        XCTAssertEqual(f.pointSize, 8, accuracy: 0.0001)
        // If the font failed to register the fallback would be a monospaced
        // system font, NOT the pixel font itself.
        XCTAssertEqual(f.fontName, SpriteAssets.pixelFontName)
    }
}
