import AppKit
import SpriteKit

/// Procedurally-rendered pixel-art banner. The banner's width adapts to the
/// text length up to `maxBitmapWidth`; longer text wraps across as many lines
/// as needed (banner grows taller), with no truncation. Two-pass render each frame:
///   1) Draw a "flat" banner (body + border + stripes + N lines of text)
///      into a bottom-up RGBA buffer, cached until the text/theme/font changes.
///   2) Copy each column into the output buffer shifted by a sine offset so the
///      whole banner — text included — rides the wave together.
///
/// Output is upscaled by `pixelScale` with nearest-neighbor filtering to keep
/// pixel-art edges crisp.
///
/// Colours come from the selected `BannerTheme` (see `ThemeCatalog`); the body
/// font comes from the selected `BannerFont` (see `FontCatalog`).
final class BannerRibbon: SKSpriteNode {
    // MARK: - Layout constants (logical bitmap pixels, pre-upscale)

    private let pixelScale: CGFloat = 4
    /// Smallest banner width so very short text still has visible body around it.
    private let minBitmapWidth = 44
    /// Largest single-line banner width — text wider than this wraps to multiple lines.
    private let maxBitmapWidth = 180
    /// Banner height for a 1-line banner.
    private let singleLineHeight = 22
    /// Extra vertical pixels added per additional line beyond the first.
    private let lineStep = 14
    /// Horizontal padding inside the banner body (each side).
    private let horizontalPad = 6
    /// Font size for pixel fonts. Non-pixel fonts render larger (see fontSize).
    private let pixelFontSize: CGFloat = 8
    private let vectorFontSize: CGFloat = 11

    // MARK: - State

    private var bitmapWidth: Int = 44
    private var bitmapHeight: Int = 22
    /// One or two strings depending on whether wrapping was needed.
    private var lines: [String] = []
    private var flatBufferRGBA: [UInt8] = []
    private var startTime: TimeInterval = 0
    private(set) var text: String = ""
    /// Theme and font snapshot used to render the cached flat buffer — re-render
    /// when these change.
    private var renderedThemeId: String = ""
    private var renderedFontId: String = ""

    // MARK: - Init

    init(text: String) {
        super.init(texture: nil, color: .clear, size: .zero)
        // Anchor at the RIGHT edge (vertical center): the banner attaches to the rope tip
        // on its right side and trails to the LEFT as the plane flies left-to-right.
        anchorPoint = CGPoint(x: 1.0, y: 0.5)
        setText(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setText(_ newText: String) {
        if newText == text && !flatBufferRGBA.isEmpty && themeAndFontUnchanged() { return }
        text = newText
        relayoutAndRender()
    }

    private func themeAndFontUnchanged() -> Bool {
        let s = AppSettings.shared
        return renderedThemeId == s.bannerTheme && renderedFontId == s.bannerFont
    }

    private func relayoutAndRender() {
        let layout = computeLayout(for: text)
        lines = layout.lines
        bitmapWidth = layout.width
        bitmapHeight = layout.height
        flatBufferRGBA = renderFlatBanner()
        let s = AppSettings.shared
        renderedThemeId = s.bannerTheme
        renderedFontId = s.bannerFont
        size = CGSize(
            width: CGFloat(bitmapWidth) * pixelScale,
            height: CGFloat(bitmapHeight) * pixelScale
        )
    }

    func tick(currentTime: TimeInterval) {
        if startTime == 0 { startTime = currentTime }
        // If the theme or font changed since last render, redraw the flat buffer.
        if !themeAndFontUnchanged() { relayoutAndRender() }
        if flatBufferRGBA.isEmpty { relayoutAndRender() }
        let t = currentTime - startTime
        texture = renderWavedTexture(time: t)
    }

    // MARK: - Layout

    private struct Layout {
        let width: Int
        let height: Int
        let lines: [String]
    }

    private var activeFont: BannerFont { FontCatalog.font(id: AppSettings.shared.bannerFont) }
    private var activeFontSize: CGFloat {
        activeFont.isPixel ? pixelFontSize : vectorFontSize
    }
    private var activeTheme: BannerTheme { ThemeCatalog.theme(id: AppSettings.shared.bannerTheme) }

    private func computeLayout(for text: String) -> Layout {
        let pad = horizontalPad * 2
        let singleW = max(minBitmapWidth, measureWidth(text) + pad)

        if singleW <= maxBitmapWidth {
            return Layout(width: singleW, height: singleLineHeight, lines: [text])
        }

        let maxInnerW = maxBitmapWidth - pad
        let wrapped = wrapToLines(text, maxWidth: maxInnerW)
        let widest = wrapped.map(measureWidth).max() ?? 0
        let w = min(maxBitmapWidth, max(minBitmapWidth, widest + pad))
        let h = singleLineHeight + max(0, wrapped.count - 1) * lineStep
        return Layout(width: w, height: h, lines: wrapped)
    }

    /// Greedy word wrap. Words that themselves exceed `maxWidth` (e.g. a long
    /// URL) are hard-broken at the character level so nothing is lost.
    private func wrapToLines(_ text: String, maxWidth: Int) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard !words.isEmpty else { return [text] }

        var lines: [String] = []
        var current = ""
        for word in words {
            let candidate = current.isEmpty ? word : current + " " + word
            if measureWidth(candidate) <= maxWidth {
                current = candidate
                continue
            }
            if !current.isEmpty { lines.append(current) }
            if measureWidth(word) > maxWidth {
                let pieces = hardBreak(word, maxWidth: maxWidth)
                lines.append(contentsOf: pieces.dropLast())
                current = pieces.last ?? ""
            } else {
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

    private func hardBreak(_ word: String, maxWidth: Int) -> [String] {
        var pieces: [String] = []
        var current = ""
        for ch in word {
            let candidate = current + String(ch)
            if measureWidth(candidate) <= maxWidth {
                current = candidate
            } else {
                if !current.isEmpty { pieces.append(current) }
                current = String(ch)
            }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    /// Measure the typographic width of `text` in logical pixels using the
    /// currently selected banner font.
    private func measureWidth(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: activeFont.resolve(activeFontSize),
            .kern: activeFont.isPixel ? 1 : 0
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        let bounds = CTLineGetImageBounds(line, nil)
        return Int(ceil(bounds.width + bounds.origin.x))
    }

    // MARK: - Pass 1: flat banner

    private func renderFlatBanner() -> [UInt8] {
        let theme = activeTheme
        let w = bitmapWidth, h = bitmapHeight
        let bodyTop = h - 3
        let bodyBottom = 2
        var buf = [UInt8](repeating: 0, count: w * h * 4)

        for x in 0..<w {
            for y in 0..<h {
                guard y >= bodyBottom && y <= bodyTop else { continue }
                let isTopBorder = (y == bodyTop)
                let isBottomBorder = (y == bodyBottom)
                let isRightFringe = (x == w - 1)
                let isLeftFringe = (x == 0)
                let color: RGBA
                if isTopBorder || isBottomBorder || isRightFringe || isLeftFringe {
                    color = theme.border
                } else if y == bodyBottom + 1 {
                    color = theme.shadow
                } else {
                    let stripePhase = (x - y) % 8
                    color = (stripePhase == 0 || stripePhase == 1) ? theme.stripe : theme.body
                }
                writePixel(&buf, x: x, y: y, w: w, h: h, color: color)
            }
        }

        // Stamp text mask (1 or 2 lines) over the body.
        let textMask = renderTextMask()
        for x in 0..<w {
            for y in 0..<h {
                guard textMask[x + y * w] else { continue }
                guard y >= bodyBottom + 1 && y <= bodyTop - 1 else { continue }
                writePixel(&buf, x: x, y: y, w: w, h: h, color: theme.text)
            }
        }

        return buf
    }

    /// Render the (already-wrapped) lines into a w×h boolean grid using CoreText.
    /// Returned mask is stored bottom-up (matches the flat-buffer Y convention).
    private func renderTextMask() -> [Bool] {
        let w = bitmapWidth, h = bitmapHeight
        var mask = [Bool](repeating: false, count: w * h)
        guard !lines.isEmpty, !lines.allSatisfy({ $0.isEmpty }) else { return mask }

        let cs = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w,
            space: cs, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return mask }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        let attrs: [NSAttributedString.Key: Any] = [
            .font: activeFont.resolve(activeFontSize),
            .foregroundColor: NSColor.white,
            .kern: activeFont.isPixel ? 1 : 0
        ]

        let bodyCenterY = CGFloat(2 + (h - 3 - 2)) / 2 + 1
        // Pixel fonts are 8px tall (8pt glyph + 2px gap). Vector fonts are taller —
        // give them a bit more headroom between lines.
        let lineHeight: CGFloat = activeFont.isPixel ? 10 : 13

        for (i, lineText) in lines.enumerated() where !lineText.isEmpty {
            let str = NSAttributedString(string: lineText, attributes: attrs)
            let ct = CTLineCreateWithAttributedString(str)
            let bounds = CTLineGetImageBounds(ct, ctx)

            // Center horizontally inside the body.
            let leftPad = CGFloat(horizontalPad)
            let availableW = CGFloat(w) - 2 * leftPad
            let xPos = leftPad + max(0, (availableW - bounds.width) / 2) - bounds.origin.x

            // Vertical placement:
            //   1 line  → centered on bodyCenterY
            //   2 lines → line[0] above center, line[1] below
            let baselineCenter: CGFloat
            if lines.count == 1 {
                baselineCenter = bodyCenterY
            } else {
                // i=0 is the FIRST line (visually on top → higher Y in bottom-up coords)
                baselineCenter = bodyCenterY + (CGFloat(lines.count - 1) / 2 - CGFloat(i)) * lineHeight
            }
            let yPos = baselineCenter - bounds.height / 2 - bounds.origin.y

            ctx.textPosition = CGPoint(x: round(xPos), y: round(yPos))
            CTLineDraw(ct, ctx)
        }

        guard let data = ctx.data else { return mask }
        let bytes = data.assumingMemoryBound(to: UInt8.self)
        // CG memory rows are top-down; convert to bottom-up so it matches the flat buffer.
        for y in 0..<h {
            for x in 0..<w {
                let srcRow = h - 1 - y
                let v = bytes[x + srcRow * w]
                mask[x + y * w] = v > 96
            }
        }
        return mask
    }

    private func writePixel(_ buf: inout [UInt8], x: Int, y: Int, w: Int, h: Int, color: RGBA) {
        let i = (y * w + x) * 4
        buf[i] = color.r
        buf[i + 1] = color.g
        buf[i + 2] = color.b
        buf[i + 3] = color.a
    }

    // MARK: - Pass 2: wave shear

    private func renderWavedTexture(time: TimeInterval) -> SKTexture {
        let w = bitmapWidth, h = bitmapHeight
        let amplitude: CGFloat = max(0, CGFloat(AppSettings.shared.bannerAmplitude))
        let frequency: CGFloat = max(0.1, CGFloat(AppSettings.shared.bannerFrequency))
        let phaseStep: CGFloat = CGFloat(AppSettings.shared.bannerPhaseStep)

        var out = [UInt8](repeating: 0, count: w * h * 4)
        for x in 0..<w {
            let phase = CGFloat(time) * frequency + CGFloat(x) * phaseStep
            let yOff = Int(round(amplitude * sin(phase)))
            for y in 0..<h {
                let srcY = y - yOff
                guard srcY >= 0 && srcY < h else { continue }
                let srcI = (srcY * w + x) * 4
                let dstRow = h - 1 - y
                let dstI = (dstRow * w + x) * 4
                out[dstI]     = flatBufferRGBA[srcI]
                out[dstI + 1] = flatBufferRGBA[srcI + 1]
                out[dstI + 2] = flatBufferRGBA[srcI + 2]
                out[dstI + 3] = flatBufferRGBA[srcI + 3]
            }
        }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: NSData(bytes: out, length: out.count)) else {
            return SKTexture()
        }
        guard let cg = CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return SKTexture() }
        let t = SKTexture(cgImage: cg)
        t.filteringMode = .nearest
        return t
    }
}
