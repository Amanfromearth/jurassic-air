import AppKit
import CoreText
import SpriteKit

enum SpriteAssets {
    /// Logical display width of the composited plane sprite on screen, in points.
    /// The supplied PNGs are 1088×1088 square; we render at ~200pt wide so the
    /// drawing inside the canvas roughly matches the old (618×404) plane sprite.
    static let planeDisplayWidth: CGFloat = 200

    /// Rope tip on the composited plane (where the rope meets the fuselage).
    /// X comes from QuakPit's `margin-right: -16px` (rope tip sits 16px inside
    /// the plane's left edge on a 130-px canvas → relX = 16/130 ≈ 0.123).
    /// Y is aligned to the **propeller hub** (relY = 0.438, mirror of the
    /// blade's `transform-origin: 56.2%` from-top) so the rope, the banner,
    /// and the spinning blade all share one horizontal axis through the
    /// fuselage. Origin is bottom-left of the rendered sprite.
    static func planeRopeTipOffset(displaySize: CGSize) -> CGPoint {
        let relX: CGFloat = 0.123
        let relY: CGFloat = 0.438
        return CGPoint(
            x: (relX - 0.5) * displaySize.width,
            y: (relY - 0.5) * displaySize.height
        )
    }

    /// Rope sprite size at scale 1.0. From QuakPit CSS: 56×3 on a 130-px-wide
    /// aircraft → width = 56/130, height = 3/130 of the plane display width.
    /// Rendered as a separate sprite that sits BEHIND the plane so its right
    /// end visually tucks into the fuselage.
    static func ropeSize(planeWidth: CGFloat) -> CGSize {
        CGSize(
            width:  planeWidth * (56.0 / 130.0),
            height: max(2, planeWidth * (3.0 / 130.0))
        )
    }

    /// Visible rope colour — matches QuakPit's `rgba(35, 35, 35, 0.78)`.
    static var ropeColor: NSColor {
        NSColor(srgbRed: 35.0/255, green: 35.0/255, blue: 35.0/255, alpha: 0.78)
    }

    // MARK: - Composite plane parts

    private static var planeTextureCache: [String: SKTexture] = [:]
    private static var headTextureCache: [String: SKTexture] = [:]
    private static var bladeTextureCache: SKTexture?

    static func planeBaseTexture(colorId: String) -> SKTexture {
        if let t = planeTextureCache[colorId] { return t }
        let resource = "plane-\(colorId)-base"
        guard let url = Bundle.module.url(forResource: resource, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return SKTexture()
        }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        planeTextureCache[colorId] = t
        return t
    }

    static func headTexture(headId: String) -> SKTexture {
        if let t = headTextureCache[headId] { return t }
        let resource = "head-\(headId)"
        guard let url = Bundle.module.url(forResource: resource, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return SKTexture()
        }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        headTextureCache[headId] = t
        return t
    }

    static func bladeTexture() -> SKTexture {
        if let t = bladeTextureCache { return t }
        guard let url = Bundle.module.url(forResource: "blade", withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            return SKTexture()
        }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        bladeTextureCache = t
        return t
    }

    static func reloadFromDisk() {
        planeTextureCache.removeAll()
        headTextureCache.removeAll()
        bladeTextureCache = nil
    }

    // MARK: - Pixel font

    static let pixelFontName = "PressStart2P-Regular"
    private static var fontRegistered = false

    static func registerPixelFont() {
        guard !fontRegistered else { return }
        fontRegistered = true
        guard let url = Bundle.module.url(forResource: "PressStart2P", withExtension: "ttf") else {
            NSLog("PressStart2P.ttf missing from bundle resources")
            return
        }
        var err: Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &err) {
            if let e = err?.takeRetainedValue() {
                NSLog("font registration failed: \(e)")
            }
        }
    }

    static func pixelFont(size: CGFloat) -> NSFont {
        registerPixelFont()
        return NSFont(name: pixelFontName, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
    }
}
