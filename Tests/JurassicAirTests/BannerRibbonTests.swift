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

    /// Inspect actual ink, so missing/overlapping lines and uneven padding
    /// cannot pass simply because the outer banner has the right dimensions.
    private func inkBands(in image: CGImage) throws -> [CGRect] {
        let data = try XCTUnwrap(image.dataProvider?.data)
        let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
        let ink = ThemeCatalog.theme(id: "classic").text
        var bands: [CGRect] = []
        var current: CGRect?
        for y in 0..<image.height {
            let columns = (0..<image.width).filter { x in
                let i = y * image.bytesPerRow + x * 4
                return bytes[i] == ink.r && bytes[i + 1] == ink.g && bytes[i + 2] == ink.b
            }
            if let left = columns.first, let right = columns.last {
                let row = CGRect(x: left, y: y, width: right - left + 1, height: 1)
                current = current.map { $0.union(row) } ?? row
            } else if let band = current {
                bands.append(band)
                current = nil
            }
        }
        if let current { bands.append(current) }
        return bands
    }

    func testWrappedLinesStayVisibleAndCentered() throws {
        let banner = BannerRibbon(text: "Design review with the product team in 5 min", createsTexture: false)
        let image = try XCTUnwrap(banner.flatImage)
        let bands = try inkBands(in: image)
        XCTAssertEqual(bands.count, 3, "every wrapped line must remain visible")
        for band in bands {
            XCTAssertEqual(band.midX, CGFloat(image.width) / 2, accuracy: 1)
        }
        let top = try XCTUnwrap(bands.first)
        let bottom = try XCTUnwrap(bands.last)
        XCTAssertEqual(top.minY, CGFloat(image.height) - bottom.maxY, accuracy: 1)
        for pair in zip(bands, bands.dropFirst()) {
            XCTAssertEqual(pair.1.midY - pair.0.midY, 14, accuracy: 1)
        }
    }

    func testWrappingAvoidsOrphanedTimingWords() {
        let banner = BannerRibbon(text: "Design review with the product team in 5 min", createsTexture: false)
        XCTAssertEqual(banner.lines.count, 3)
        XCTAssertNotEqual(banner.lines.last, "min")
        XCTAssertTrue(banner.lines.allSatisfy { $0.contains(" ") })
        XCTAssertEqual(banner.lines.joined(separator: " "), banner.text)
    }

    func testCalendarCountdownStaysTogetherOnItsOwnLine() throws {
        let banner = BannerRibbon(text: "Daily algo\nStarts in 5 min", createsTexture: false)
        let image = try XCTUnwrap(banner.flatImage)
        let bands = try inkBands(in: image)
        XCTAssertEqual(bands.count, 2)
        let top = try XCTUnwrap(bands.first)
        let bottom = try XCTUnwrap(bands.last)
        XCTAssertEqual(top.minY, CGFloat(image.height) - bottom.maxY, accuracy: 1)
    }

    func testExplicitLinesAndWhitespaceAcrossFonts() throws {
        defer { AppSettings.shared.bannerFont = "pixel" }
        for font in FontCatalog.fonts {
            AppSettings.shared.bannerFont = font.id
            let banner = BannerRibbon(text: "  Daily   algo  \n\n Drink\twater \n Ship it! ", createsTexture: false)
            let image = try XCTUnwrap(banner.flatImage)
            let bands = try inkBands(in: image)
            XCTAssertEqual(bands.count, 3, "missing lines for \(font.id)")
            for band in bands {
                XCTAssertEqual(band.midX, CGFloat(image.width) / 2, accuracy: 1, font.id)
                XCTAssertGreaterThan(band.minY, 2, font.id)
                XCTAssertLessThan(band.maxY, CGFloat(image.height - 2), font.id)
            }
        }
    }

    // MARK: - Construction

    func testShortTextRendersOnOneLine() {
        let banner = BannerRibbon(text: "HI")
        // height = singleLineHeight (26) × pixelScale (4) = 104pt
        XCTAssertEqual(banner.size.height, 104, accuracy: 0.5)
    }

    func testLongTextWrapsToMultipleLines() {
        let banner = BannerRibbon(text: "THIS IS A VERY LONG REMINDER TITLE THAT MUST WRAP")
        // height = (singleLineHeight 26 + (lines - 1) × lineStep 14) × pixelScale 4.
        // Anything taller than one line (104pt) proves the text wrapped.
        XCTAssertGreaterThan(banner.size.height, 104)
        let extra = (banner.size.height / 4 - 26) / 14
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

    func testVeryLongWordStaysWithinMaximumWidth() {
        let banner = BannerRibbon(text: String(repeating: "X", count: 200))
        // The width is capped at maxBitmapWidth × pixelScale = 200 × 4 = 800pt.
        XCTAssertLessThanOrEqual(banner.size.width, 800)
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
