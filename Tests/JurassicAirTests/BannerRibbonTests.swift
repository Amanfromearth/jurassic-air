import XCTest
import AppKit
import SpriteKit
@testable import JurassicAir

/// Banner layout + render robustness. The banner is a procedural pixel-art
/// renderer — these tests don't compare pixels, they verify the layout
/// invariants (wrap threshold, truncation, theme/font switch invalidation)
/// and confirm the renderer doesn't crash on edge inputs.
final class BannerRibbonTests: XCTestCase {

    private var settings: AppSettings!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "jurassicair.banner.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = AppSettings(defaults: defaults)
        // Banner reads from AppSettings.shared, so make sure shared's defaults
        // are also pristine for the appearance the renderer will pick up.
        AppSettings.shared.bannerTheme = "classic"
        AppSettings.shared.bannerFont  = "pixel"
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        settings = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Construction

    func testShortTextRendersOnOneLine() {
        let banner = BannerRibbon(text: "HI")
        // height = singleLineHeight (22) × pixelScale (4) = 88pt
        XCTAssertEqual(banner.size.height, 88, accuracy: 0.5)
    }

    func testLongTextWrapsToMultipleLines() {
        let banner = BannerRibbon(text: "THIS IS A VERY LONG REMINDER TITLE THAT MUST WRAP")
        // height = (singleLineHeight 22 + (lines - 1) × lineStep 14) × pixelScale 4.
        // Anything taller than one line (88pt) proves the text wrapped.
        XCTAssertGreaterThan(banner.size.height, 88)
        let extra = (banner.size.height / 4 - 22) / 14
        XCTAssertEqual(extra, extra.rounded(), accuracy: 0.001,
                       "height must be a whole number of extra lines")
    }

    func testBannerHasRightEdgeAnchor() {
        let banner = BannerRibbon(text: "any")
        XCTAssertEqual(banner.anchorPoint.x, 1.0)
        XCTAssertEqual(banner.anchorPoint.y, 0.5)
    }

    // MARK: - Edge inputs

    func testEmptyTextDoesNotCrash() {
        let banner = BannerRibbon(text: "")
        XCTAssertGreaterThan(banner.size.width, 0,
                             "even empty text should produce a minimum-width banner")
    }

    func testWhitespaceTextDoesNotCrash() {
        _ = BannerRibbon(text: "   ")
    }

    func testVeryLongWordTruncatesWithEllipsis() {
        let banner = BannerRibbon(text: String(repeating: "X", count: 200))
        // The width is capped at maxBitmapWidth × pixelScale = 180 × 4 = 720pt.
        XCTAssertLessThanOrEqual(banner.size.width, 720)
    }

    func testUnicodeTextDoesNotCrash() {
        _ = BannerRibbon(text: "Meeting 🎉 with @Adi — café ✈️")
    }

    // MARK: - tick / texture generation

    func testInitRendersFlatTextureAndShader() {
        let banner = BannerRibbon(text: "HELLO")
        // The flat banner renders at init; the wave runs in a shader, so the
        // texture must exist before the first tick.
        XCTAssertNotNil(banner.texture)
        XCTAssertNotNil(banner.shader)
        let image = try! XCTUnwrap(banner.flatImage)
        XCTAssertEqual(CGFloat(image.width) * 4, banner.size.width)
        XCTAssertEqual(CGFloat(image.height) * 4, banner.size.height)
    }

    func testTickKeepsTheSameTextureWhenNothingChanged() {
        let banner = BannerRibbon(text: "HELLO")
        let first = banner.texture
        banner.tick(currentTime: 0)
        banner.tick(currentTime: 0.5)
        XCTAssertIdentical(banner.texture, first,
                           "ticks must not re-upload a texture; only shader uniforms change")
    }

    func testTickDoesNotResetSize() {
        let banner = BannerRibbon(text: "HELLO")
        let beforeSize = banner.size
        banner.tick(currentTime: 0)
        banner.tick(currentTime: 1.0)
        banner.tick(currentTime: 2.0)
        XCTAssertEqual(banner.size.width, beforeSize.width)
        XCTAssertEqual(banner.size.height, beforeSize.height)
    }

    // MARK: - Theme + font invalidation

    func testThemeChangeReRendersOnNextTick() {
        let banner = BannerRibbon(text: "PIXEL")
        banner.tick(currentTime: 0)
        let first = banner.texture
        AppSettings.shared.bannerTheme = "midnight"
        banner.tick(currentTime: 1.0)
        XCTAssertNotIdentical(banner.texture, first,
                              "swapping the theme should produce a fresh texture")
        AppSettings.shared.bannerTheme = "classic"
    }

    func testFontChangeReRendersOnNextTick() {
        let banner = BannerRibbon(text: "PIXEL")
        banner.tick(currentTime: 0)
        let first = banner.texture
        AppSettings.shared.bannerFont = "serif"
        banner.tick(currentTime: 1.0)
        XCTAssertNotIdentical(banner.texture, first)
        AppSettings.shared.bannerFont = "pixel"
    }

    // MARK: - setText

    func testSetTextChangesSize() {
        let banner = BannerRibbon(text: "HI")
        let shortSize = banner.size
        banner.setText(String(repeating: "LONGER ", count: 30))
        XCTAssertGreaterThan(banner.size.width, shortSize.width)
    }

    func testSetTextIsIdempotent() {
        let banner = BannerRibbon(text: "SAME")
        let size1 = banner.size
        banner.setText("SAME")
        XCTAssertEqual(banner.size, size1)
    }
}
