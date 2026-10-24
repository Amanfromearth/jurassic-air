import XCTest
import AppKit
@testable import JurassicAir

final class BannerStressTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let name = "jurassicair.stress.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return AppSettings(defaults: defaults)
    }

    func testWorstCasesStayBoundedAndLeaveRoomForTheWave() throws {
        let settings = makeSettings()
        for font in FontCatalog.fonts {
            settings.bannerFont = font.id
            for theme in ThemeCatalog.themes {
                settings.bannerTheme = theme.id
                for sample in BannerStressFixtures.demo + BannerStressFixtures.worst + BannerStressFixtures.empty {
                    let banner = BannerRibbon(text: sample.event.title.uppercased(), createsTexture: false, settings: settings)
                    let image = try XCTUnwrap(banner.flatImage)
                    XCTAssertLessThanOrEqual(banner.lines.count, 4, sample.id)
                    XCTAssertLessThanOrEqual(image.width, 200, sample.id)
                    XCTAssertLessThanOrEqual(image.height, 120, sample.id)
                    let data = try XCTUnwrap(image.dataProvider?.data)
                    let bytes = try XCTUnwrap(CFDataGetBytePtr(data))
                    var inkCount = 0
                    for y in 0..<image.height {
                        for x in 0..<image.width {
                            let i = y * image.bytesPerRow + x * 4
                            if y < 4 || y >= image.height - 4 {
                                XCTAssertEqual(bytes[i + 3], 0, "wave clearance: \(font.id)/\(sample.id)")
                            }
                            if bytes[i] == theme.text.r && bytes[i + 1] == theme.text.g && bytes[i + 2] == theme.text.b {
                                inkCount += 1
                                XCTAssertGreaterThan(x, 1, sample.id)
                                XCTAssertLessThan(x, image.width - 2, sample.id)
                                XCTAssertGreaterThan(y, 4, sample.id)
                                XCTAssertLessThan(y, image.height - 5, sample.id)
                            }
                        }
                    }
                    XCTAssertGreaterThan(inkCount, 0, "no readable title: \(font.id)/\(sample.id)")
                }
            }
        }
    }

    func testLongCalendarTitleRetainsCountdownAndOriginalText() {
        let title = BannerStressFixtures.worst[0].title.uppercased()
        let banner = BannerRibbon(text: title, createsTexture: false, settings: makeSettings())
        XCTAssertTrue(banner.isTruncated)
        XCTAssertEqual(banner.lines.count, 4)
        XCTAssertEqual(banner.lines.last, "STARTS IN 10 MIN")
        XCTAssertTrue(banner.lines[2].hasSuffix("…"))
        XCTAssertEqual(banner.text, title, "full text remains available")
    }

    func testBlankAndInvisibleTitlesHaveReadableFallbacks() {
        for title in ["", " \n\t ", "\u{200B}\u{200D}"] {
            let banner = BannerRibbon(text: title, createsTexture: false, settings: makeSettings())
            XCTAssertEqual(banner.lines, ["Reminder"])
        }
    }

    func testEmojiAndTallScriptsUseReadableFallbackWithoutSplittingGraphemes() throws {
        let settings = makeSettings()
        for id in ["arabic", "cjk", "emoji"] {
            let sample = try XCTUnwrap(BannerStressFixtures.worst.first { $0.id == id })
            settings.bannerFont = "pixel"
            let pixel = BannerRibbon(text: sample.title, createsTexture: false, settings: settings)
            settings.bannerFont = "system"
            let system = BannerRibbon(text: sample.title, createsTexture: false, settings: settings)
            XCTAssertEqual(pixel.lines, system.lines, id)
            let pixelImage = try XCTUnwrap(pixel.flatImage)
            let systemImage = try XCTUnwrap(system.flatImage)
            XCTAssertEqual(pixelImage.width, systemImage.width, id)
            XCTAssertEqual(pixelImage.height, systemImage.height, id)
            XCTAssertEqual(pixelImage.dataProvider?.data as Data?, systemImage.dataProvider?.data as Data?, id)
            XCTAssertEqual(pixel.lines.joined().filter { !$0.isWhitespace }, sample.title.filter { !$0.isWhitespace }, id)
        }
    }

    func testExportStressRenders() throws {
        let settings = makeSettings()
        settings.bannerTheme = "classic"
        let folder = ProcessInfo.processInfo.environment["BANNER_STRESS_EXPORT"]
        for font in FontCatalog.fonts {
            settings.bannerFont = font.id
            for sample in BannerStressFixtures.demo + BannerStressFixtures.worst + BannerStressFixtures.empty {
                // Flights capitalize titles before passing them to the renderer.
                let banner = BannerRibbon(text: sample.event.title.uppercased(), createsTexture: false, settings: settings)
                let image = try XCTUnwrap(banner.flatImage)
                if let folder {
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(folder)/\(font.id)-\(sample.id).png"))
                    print("STRESS \(font.id) \(sample.id): \(image.width)x\(image.height)")
                }
                XCTAssertGreaterThan(image.width, 0)
            }
        }
    }
}
