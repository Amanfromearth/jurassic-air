import XCTest
import AppKit
import SpriteKit
@testable import JurassicAir

final class PixelArtImagesTests: XCTestCase {
    func testNativeTexturesUse64PixelCanvases() {
        for color in FlierCatalog.colors {
            XCTAssertEqual(SpriteAssets.planeBaseTexture(colorId: color.id).size(), CGSize(width: 64, height: 64))
        }
        for head in FlierCatalog.heads {
            XCTAssertEqual(SpriteAssets.headTexture(headId: head.id).size(), CGSize(width: 64, height: 64))
        }
        XCTAssertEqual(SpriteAssets.bladeTexture().size(), CGSize(width: 64, height: 64))
    }

    func testCompactionPreservesArtworkApartFromLegacyOnePixelMaskSeam() throws {
        let names = FlierCatalog.colors.map { "plane-\($0.id)-base" }
            + FlierCatalog.heads.map { "head-\($0.id)" } + ["blade"]
        for name in names {
            try autoreleasepool {
                let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "png"))
                let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
                let original = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
                let compact = try XCTUnwrap(PixelArtImages.image(named: name))
                let expected = pixels(original, width: original.width, height: original.height)
                let restored = pixels(compact, width: original.width, height: original.height)
                let legacy = ["plane-red-base", "plane-blue-base", "plane-green-base",
                              "plane-pink-base", "plane-black-base", "blade"].contains(name)
                // Original exports have a one-pixel mask seam at the propeller
                // edge, off the 17x grid. No other artwork may change.
                let changes = expected.indices.filter { expected[$0] != restored[$0] }
                XCTAssertTrue(changes.allSatisfy { index in
                    let pixel = index / 4
                    return legacy && pixel % original.width == 985
                        && (493..<748).contains(pixel / original.width)
                }, "\(name) changed outside the legacy export seam")
            }
        }
    }

    private func pixels(_ image: CGImage, width: Int, height: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Data(bytes: context.data!, count: context.bytesPerRow * height)
    }
}
