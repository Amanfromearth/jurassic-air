import AppKit
import ImageIO

/// The artwork is a 64-pixel grid exported at 17x. Retain only its native
/// pixels, preserving nearest-neighbor edges and the complete transparent canvas.
enum PixelArtImages {
    private final class Entry: NSObject {
        let image: CGImage
        init(_ image: CGImage) { self.image = image }
    }
    private static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.totalCostLimit = 2 * 1024 * 1024
        cache.countLimit = 64
        return cache
    }()

    static func image(named name: String) -> CGImage? {
        if let entry = cache.object(forKey: name as NSString) { return entry.image }
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let source = CGImageSourceCreateWithURL(url as CFURL,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateImageAtIndex(source, 0,
                  [kCGImageSourceShouldCache: false] as CFDictionary),
              let compact = compact(image) else { return nil }
        cache.setObject(Entry(compact), forKey: name as NSString,
                        cost: compact.bytesPerRow * compact.height)
        return compact
    }

    static func compact(_ image: CGImage) -> CGImage? {
        let width: Int
        let height: Int
        if image.width.isMultiple(of: 17), image.height.isMultiple(of: 17) {
            width = image.width / 17
            height = image.height / 17
        } else {
            let scale = min(1, 128 / Double(max(image.width, image.height)))
            width = max(1, Int(Double(image.width) * scale))
            height = max(1, Int(Double(image.height) * scale))
        }
        guard let context = CGContext(data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func removeAll() { cache.removeAllObjects() }
}
