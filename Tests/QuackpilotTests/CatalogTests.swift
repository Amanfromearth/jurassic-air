import XCTest
import AppKit
@testable import Quackpilot

/// Catalog coverage:
/// - every catalog returns the expected ids and falls back on nil
/// - every catalog entry has unique ids
/// - every catalog entry that names a bundled asset CAN actually find it in
///   the Resources bundle (catches missing/renamed assets)
final class CatalogTests: XCTestCase {

    // MARK: - FlierCatalog (heads + plane colours)

    func testHeadCatalogHasFiveEntries() {
        XCTAssertEqual(FlierCatalog.heads.count, 5)
        XCTAssertEqual(FlierCatalog.heads.map(\.id),
                       ["duck", "corgi", "dino", "pigeon", "capybara"])
    }

    func testHeadIdsAreUnique() {
        let ids = FlierCatalog.heads.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testHeadLookupReturnsCorrectEntry() {
        XCTAssertEqual(FlierCatalog.head(id: "dino").name, "Dino")
        XCTAssertEqual(FlierCatalog.head(id: "capybara").name, "Capybara")
    }

    func testHeadLookupFallsBackOnUnknownId() {
        let nothing = FlierCatalog.head(id: nil)
        let bogus   = FlierCatalog.head(id: "no-such-head")
        XCTAssertEqual(nothing.id, "duck") // first entry == fallback
        XCTAssertEqual(bogus.id,   "duck")
    }

    func testEveryHeadResolvesToARealSoundPack() {
        for head in FlierCatalog.heads {
            let pack = SoundCatalog.pack(id: head.sound)
            XCTAssertEqual(pack.id, head.sound,
                           "head '\(head.id)' references sound '\(head.sound)' which doesn't exist")
        }
    }

    func testEveryHeadHasBundledFullImage() {
        for head in FlierCatalog.heads {
            let url = Bundle.module.url(forResource: "head-\(head.id)", withExtension: "png")
            XCTAssertNotNil(url, "missing head-\(head.id).png")
        }
    }

    func testEveryHeadHasBundledThumbnail() {
        for head in FlierCatalog.heads {
            let url = Bundle.module.url(forResource: "thumb-head-\(head.id)", withExtension: "png")
            XCTAssertNotNil(url, "missing thumb-head-\(head.id).png")
        }
    }

    func testPlaneColorCatalogHasFiveEntries() {
        XCTAssertEqual(FlierCatalog.colors.count, 5)
        XCTAssertEqual(FlierCatalog.colors.map(\.id),
                       ["red", "blue", "green", "pink", "black"])
    }

    func testPlaneColorLookupFallsBackOnUnknownId() {
        XCTAssertEqual(FlierCatalog.color(id: nil).id, "red")
        XCTAssertEqual(FlierCatalog.color(id: "rainbow").id, "red")
    }

    func testEveryPlaneColorHasBundledBaseImage() {
        for color in FlierCatalog.colors {
            let url = Bundle.module.url(forResource: "plane-\(color.id)-base", withExtension: "png")
            XCTAssertNotNil(url, "missing plane-\(color.id)-base.png")
        }
    }

    func testEveryPlaneColorHasBundledThumbnail() {
        for color in FlierCatalog.colors {
            let url = Bundle.module.url(forResource: "thumb-plane-\(color.id)", withExtension: "png")
            XCTAssertNotNil(url, "missing thumb-plane-\(color.id).png")
        }
    }

    // MARK: - ThemeCatalog

    func testThemeCatalogHasFiveThemes() {
        XCTAssertEqual(ThemeCatalog.themes.count, 5)
        XCTAssertEqual(ThemeCatalog.themes.map(\.id),
                       ["classic", "midnight", "sunset", "mint", "bubblegum"])
    }

    func testThemeIdsAreUnique() {
        let ids = ThemeCatalog.themes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testThemeLookupFallsBackOnUnknownId() {
        XCTAssertEqual(ThemeCatalog.theme(id: nil).id, "classic")
        XCTAssertEqual(ThemeCatalog.theme(id: "neon-puke").id, "classic")
    }

    func testClassicThemeMatchesQuakpilotPalette() {
        let classic = ThemeCatalog.theme(id: "classic")
        XCTAssertEqual(classic.body.r,   0xFB)
        XCTAssertEqual(classic.body.g,   0xEE)
        XCTAssertEqual(classic.body.b,   0xC8)
        XCTAssertEqual(classic.stripe.r, 0xE4)
        XCTAssertEqual(classic.stripe.g, 0x3A)
        XCTAssertEqual(classic.stripe.b, 0x3A)
    }

    func testRGBAToNSColorPreservesChannels() {
        let rgba = RGBA(0x80, 0x40, 0xC0, 0xFF)
        let color = rgba.nsColor.usingColorSpace(.sRGB)!
        XCTAssertEqual(color.redComponent,   CGFloat(0x80) / 255, accuracy: 0.005)
        XCTAssertEqual(color.greenComponent, CGFloat(0x40) / 255, accuracy: 0.005)
        XCTAssertEqual(color.blueComponent,  CGFloat(0xC0) / 255, accuracy: 0.005)
        XCTAssertEqual(color.alphaComponent, 1.0, accuracy: 0.005)
    }

    // MARK: - SoundCatalog

    func testSoundCatalogHasFivePacks() {
        XCTAssertEqual(SoundCatalog.packs.count, 5)
        XCTAssertEqual(SoundCatalog.packs.map(\.id),
                       ["quack", "corgi", "dino", "pigeon", "capybara"])
    }

    func testSoundPackLookupFallsBackToQuack() {
        XCTAssertEqual(SoundCatalog.pack(id: nil).id, "quack")
        XCTAssertEqual(SoundCatalog.pack(id: "moo").id, "quack")
    }

    func testEverySoundPackHasBundledAudio() {
        for pack in SoundCatalog.packs {
            let url = Bundle.module.url(forResource: pack.resource, withExtension: pack.ext)
            XCTAssertNotNil(url, "missing \(pack.resource).\(pack.ext) for sound '\(pack.id)'")
        }
    }

    // MARK: - FontCatalog

    func testFontCatalogHasSixFonts() {
        XCTAssertEqual(FontCatalog.fonts.count, 6)
        XCTAssertEqual(FontCatalog.fonts.map(\.id),
                       ["pixel", "system", "rounded", "serif", "mono", "condensed"])
    }

    func testOnlyPixelFontIsMarkedPixel() {
        for font in FontCatalog.fonts {
            if font.id == "pixel" {
                XCTAssertTrue(font.isPixel, "pixel font should be marked isPixel")
            } else {
                XCTAssertFalse(font.isPixel, "\(font.id) should not be marked isPixel")
            }
        }
    }

    func testEveryFontResolvesToAValidNSFont() {
        for font in FontCatalog.fonts {
            let resolved = font.resolve(14)
            // A pointSize of zero would indicate fallback to a degenerate font.
            XCTAssertGreaterThan(resolved.pointSize, 0,
                                 "\(font.id) resolved to a degenerate NSFont")
        }
    }

    // MARK: - SpeedCatalog

    func testSpeedCatalogHasThreePresets() {
        XCTAssertEqual(SpeedCatalog.presets.count, 3)
        XCTAssertEqual(SpeedCatalog.presets.map(\.id), ["normal", "fast", "ultra"])
    }

    func testSpeedMultipliersMatchQuakPit() {
        XCTAssertEqual(SpeedCatalog.preset(id: "normal").multiplier, 1.0)
        XCTAssertEqual(SpeedCatalog.preset(id: "fast").multiplier,   1.5)
        XCTAssertEqual(SpeedCatalog.preset(id: "ultra").multiplier,  2.0)
    }

    func testSpeedPresetFallsBackOnUnknownId() {
        XCTAssertEqual(SpeedCatalog.preset(id: nil).id, "normal")
        XCTAssertEqual(SpeedCatalog.preset(id: "warp").id, "normal")
    }
}
