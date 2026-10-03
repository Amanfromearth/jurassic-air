import AppKit

/// Banner typography. The default `pixel` font is the bundled PressStart2P
/// (matches Jurassic Air's pixel-art aesthetic). The remaining choices mirror
/// QuakPit's five system-stack fonts — they render at a slightly larger size
/// because they aren't bitmap fonts.
struct BannerFont: Identifiable, Hashable {
    let id: String
    let name: String
    /// Whether this is the bundled pixel font. Pixel fonts render at 8pt with
    /// kerning; vector fonts render larger so they read at the same banner size.
    let isPixel: Bool
    /// Resolves the NSFont for the banner renderer.
    let resolve: (CGFloat) -> NSFont

    static func == (lhs: BannerFont, rhs: BannerFont) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum FontCatalog {
    static let fonts: [BannerFont] = [
        BannerFont(id: "pixel", name: "Pixel", isPixel: true, resolve: { size in
            SpriteAssets.pixelFont(size: size)
        }),
        BannerFont(id: "system", name: "System", isPixel: false, resolve: { size in
            NSFont.systemFont(ofSize: size, weight: .heavy)
        }),
        BannerFont(id: "rounded", name: "Rounded", isPixel: false, resolve: { size in
            if let f = NSFont(name: "SF Pro Rounded", size: size) { return f }
            if let f = NSFont(name: "Arial Rounded MT Bold", size: size) { return f }
            return NSFont.systemFont(ofSize: size, weight: .heavy)
        }),
        BannerFont(id: "serif", name: "Serif", isPixel: false, resolve: { size in
            if let f = NSFont(name: "Georgia-Bold", size: size) { return f }
            if let f = NSFont(name: "Georgia", size: size) { return f }
            return NSFont.systemFont(ofSize: size, weight: .heavy)
        }),
        BannerFont(id: "mono", name: "Mono", isPixel: false, resolve: { size in
            if let f = NSFont(name: "Menlo-Bold", size: size) { return f }
            return NSFont.monospacedSystemFont(ofSize: size, weight: .heavy)
        }),
        BannerFont(id: "condensed", name: "Condensed", isPixel: false, resolve: { size in
            if let f = NSFont(name: "HelveticaNeue-CondensedBold", size: size) { return f }
            if let f = NSFont(name: "Helvetica-Bold", size: size) { return f }
            return NSFont.systemFont(ofSize: size, weight: .heavy)
        })
    ]

    static func font(id: String?) -> BannerFont {
        fonts.first { $0.id == id } ?? fonts[0]
    }
}

/// Flight speed preset (multiplier on top of `AppSettings.flightSpeed`).
struct SpeedPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let multiplier: Double
}

enum SpeedCatalog {
    static let presets: [SpeedPreset] = [
        SpeedPreset(id: "normal", name: "Normal", multiplier: 1.0),
        SpeedPreset(id: "fast",   name: "Fast",   multiplier: 1.5),
        SpeedPreset(id: "ultra",  name: "Ultra",  multiplier: 2.0)
    ]
    static func preset(id: String?) -> SpeedPreset {
        presets.first { $0.id == id } ?? presets[0]
    }
}
