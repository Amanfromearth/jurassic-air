import AppKit

/// Banner colour theme — drives the pixel banner's body / stripe / border /
/// shadow / text colours. The five themes mirror QuakPit's free + Pro catalog
/// (Classic + Midnight, Sunset, Mint, Bubblegum). Stripe colours and text ink
/// roughly match the names; the matching border / shadow / body are derived
/// for the pixel renderer.

struct BannerTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let body: RGBA      // banner background
    let stripe: RGBA    // diagonal stripe
    let border: RGBA    // top/bottom/left/right fringe
    let shadow: RGBA    // 1px shadow line above the bottom border
    let text: RGBA      // banner text colour

    /// Background colour for the swatch tile in Settings.
    var swatchA: NSColor { stripe.nsColor }
    var swatchB: NSColor { body.nsColor }
}

struct RGBA: Hashable {
    let r: UInt8, g: UInt8, b: UInt8, a: UInt8
    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 0xFF) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255,
                green:    CGFloat(g) / 255,
                blue:     CGFloat(b) / 255,
                alpha:    CGFloat(a) / 255)
    }
}

enum ThemeCatalog {
    static let themes: [BannerTheme] = [
        BannerTheme(
            id: "classic", name: "Classic",
            body:   RGBA(0xFB, 0xEE, 0xC8),
            stripe: RGBA(0xE4, 0x3A, 0x3A),
            border: RGBA(0x6B, 0x21, 0x21),
            shadow: RGBA(0xC4, 0x9A, 0x6C),
            text:   RGBA(0x1F, 0x12, 0x12)
        ),
        BannerTheme(
            id: "midnight", name: "Midnight",
            body:   RGBA(0x1E, 0x1B, 0x4B),  // indigo
            stripe: RGBA(0x0F, 0x17, 0x2A),  // near-navy
            border: RGBA(0x05, 0x07, 0x18),
            shadow: RGBA(0x33, 0x2E, 0x6E),
            text:   RGBA(0xF8, 0xFA, 0xFC)   // near-white
        ),
        BannerTheme(
            id: "sunset", name: "Sunset",
            body:   RGBA(0xFD, 0xBA, 0x74),  // peach
            stripe: RGBA(0xEC, 0x48, 0x99),  // pink-magenta
            border: RGBA(0x9D, 0x17, 0x4D),
            shadow: RGBA(0xF9, 0x73, 0x16),  // orange
            text:   RGBA(0x44, 0x10, 0x29)
        ),
        BannerTheme(
            id: "mint", name: "Mint",
            body:   RGBA(0xEC, 0xFD, 0xF5),  // ice-mint
            stripe: RGBA(0x34, 0xD3, 0x99),  // mint-green
            border: RGBA(0x0F, 0x76, 0x4E),
            shadow: RGBA(0xA7, 0xF3, 0xD0),
            text:   RGBA(0x05, 0x2E, 0x21)
        ),
        BannerTheme(
            id: "bubblegum", name: "Bubblegum",
            body:   RGBA(0xFD, 0xF2, 0xF8),  // light pink
            stripe: RGBA(0xF4, 0x72, 0xB6),  // bubblegum pink
            border: RGBA(0x9D, 0x17, 0x4D),
            shadow: RGBA(0xFB, 0xCF, 0xE8),
            text:   RGBA(0x4A, 0x04, 0x4E)
        )
    ]

    static func theme(id: String?) -> BannerTheme {
        themes.first { $0.id == id } ?? themes[0]
    }
}
