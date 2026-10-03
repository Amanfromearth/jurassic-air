import XCTest
import SpriteKit
@testable import JurassicAir

/// Renders the banner through the real SpriteKit + Metal pipeline off-screen
/// and checks the wave shader output against a CPU reference of the same
/// column-shift formula.
final class BannerShaderRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppSettings.shared.bannerTheme = "classic"
        AppSettings.shared.bannerFont = "pixel"
    }

    override func tearDown() {
        AppSettings.shared.resetToDefaults()
        super.tearDown()
    }

    /// Render `banner` at 1 point per bitmap pixel and return RGBA rows, top-down.
    private func render(_ banner: BannerRibbon, image: CGImage) throws -> [UInt8] {
        let w = image.width, h = image.height
        let scene = SKScene(size: CGSize(width: w, height: h))
        scene.backgroundColor = .clear
        banner.setScale(0.25) // undo pixelScale so 1 bitmap pixel = 1 point
        banner.position = CGPoint(x: CGFloat(w), y: CGFloat(h) / 2)
        scene.addChild(banner)
        let view = SKView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        view.presentScene(scene)
        let texture = try XCTUnwrap(view.texture(from: scene, crop: CGRect(x: 0, y: 0, width: w, height: h)))
        let cg = texture.cgImage()
        return Self.rgba(of: cg, width: w, height: h)
    }

    private static func rgba(of image: CGImage, width w: Int, height h: Int) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return out
    }

    /// Fraction of pixels whose four channels all match the reference within
    /// a small tolerance (colour-space conversion can shift values slightly).
    private func pixelMatch(_ a: [UInt8], _ b: [UInt8]) -> Double {
        var same = 0, total = 0
        for i in stride(from: 0, to: a.count, by: 4) {
            total += 1
            if (0..<4).allSatisfy({ abs(Int(a[i + $0]) - Int(b[i + $0])) < 24 }) { same += 1 }
        }
        return Double(same) / Double(total)
    }

    func testZeroAmplitudeMatchesFlatBanner() throws {
        AppSettings.shared.bannerAmplitude = 0
        let banner = BannerRibbon(text: "HELLO")
        banner.tick(currentTime: 1)
        let flat = try XCTUnwrap(banner.flatImage)
        let rendered = try render(banner, image: flat)
        let reference = Self.rgba(of: flat, width: flat.width, height: flat.height)
        XCTAssertGreaterThan(pixelMatch(rendered, reference), 0.99)
    }

    func testWaveMatchesCPUReference() throws {
        let s = AppSettings.shared
        s.bannerAmplitude = 2
        s.bannerFrequency = 3
        s.bannerPhaseStep = 0.3
        let banner = BannerRibbon(text: "WAVE")
        banner.tick(currentTime: 10)      // start time
        banner.tick(currentTime: 10.4)    // t = 0.4 s
        let flat = try XCTUnwrap(banner.flatImage)
        let w = flat.width, h = flat.height
        let rendered = try render(banner, image: flat)

        // CPU reference, in top-down rows (the old per-frame renderer's math).
        let src = Self.rgba(of: flat, width: w, height: h)
        var reference = [UInt8](repeating: 0, count: src.count)
        for x in 0..<w {
            let yOff = Int((2.0 * sin(0.4 * 3.0 + Double(x) * 0.3)).rounded())
            for yUp in 0..<h {
                let srcUp = yUp - yOff
                guard srcUp >= 0 && srcUp < h else { continue }
                let s = ((h - 1 - srcUp) * w + x) * 4
                let d = ((h - 1 - yUp) * w + x) * 4
                reference.replaceSubrange(d..<(d + 4), with: src[s..<(s + 4)])
            }
        }
        XCTAssertGreaterThan(pixelMatch(rendered, reference), 0.98)
        XCTAssertLessThan(pixelMatch(rendered, src), 0.98, "the wave must actually move pixels")
    }
}
