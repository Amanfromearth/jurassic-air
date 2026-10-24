import AppKit
import SpriteKit

/// Procedurally-rendered pixel-art banner. The banner's width adapts to the
/// text length up to `maxBitmapWidth`; longer text wraps to four lines.
/// Overflow is marked with an ellipsis; the overlay exposes the full title on hover. Two passes:
///   1) CPU: draw a "flat" banner (body + border + stripes + N lines of text)
///      into an RGBA bitmap. This runs only when the text/theme/font changes.
///   2) GPU: a fragment shader (`waveShaderSource`) shifts each column by a
///      sine offset so the whole banner, text included, rides the wave. Per
///      frame we only update a few shader uniforms, so there is no per-frame
///      bitmap, CGImage, or texture upload.
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
    private let maxBitmapWidth = 200
    /// Banner height for a 1-line banner.
    private let singleLineHeight = 26
    /// Extra vertical pixels added per additional line beyond the first.
    private let lineStep = 14
    /// Transparent rows keep the maximum supported wave inside the texture.
    private let waveMargin = 4
    private let maxLines = 4
    private let maxLayoutCharacters = 4096
    private var renderedLineStep = 14
    /// Horizontal padding inside the banner body (each side).
    private let horizontalPad = 6
    /// Font size for pixel fonts. Non-pixel fonts render larger (see fontSize).
    private let pixelFontSize: CGFloat = 8
    private let vectorFontSize: CGFloat = 11

    // MARK: - State

    private var bitmapWidth: Int = 44
    private var bitmapHeight: Int = 22
    /// Lines after whitespace normalization and wrapping.
    private(set) var lines: [String] = []
    private(set) var isTruncated = false
    private var startTime: TimeInterval = 0
    /// The un-waved banner as an image. Also used by the Settings preview.
    private(set) var flatImage: CGImage?
    private(set) var text: String = ""
    /// Theme and font snapshot used to render the cached flat buffer — re-render
    /// when these change.
    private var renderedThemeId: String = ""
    private var renderedFontId: String = ""
    private let createsTexture: Bool
    private let settings: AppSettings
    private static var previewKey: [String] = []
    private static var cachedPreview: CGImage?

    // MARK: - Init

    init(text: String, createsTexture: Bool = true, settings: AppSettings = .shared) {
        self.settings = settings
        self.createsTexture = createsTexture
        super.init(texture: nil, color: .clear, size: .zero)
        // Anchor at the RIGHT edge (vertical center): the banner attaches to the rope tip
        // on its right side and trails to the LEFT as the plane flies left-to-right.
        anchorPoint = CGPoint(x: 1.0, y: 0.5)
        if createsTexture { shader = waveShader }
        setText(text)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The flat (un-waved) banner for `text`, drawn with the current theme and
    /// font from `AppSettings.shared`. Used by the Settings preview so it
    /// shows exactly what will fly.
    static func previewImage(text: String) -> CGImage? {
        let key = [text, AppSettings.shared.bannerTheme, AppSettings.shared.bannerFont]
        if key == previewKey, let cachedPreview { return cachedPreview }
        let image = BannerRibbon(text: text, createsTexture: false).flatImage
        previewKey = key
        cachedPreview = image
        return image
    }

    func setText(_ newText: String) {
        if newText == text && flatImage != nil && themeAndFontUnchanged() { return }
        text = newText
        relayoutAndRender()
    }

    private func themeAndFontUnchanged() -> Bool {
        let s = settings
        return renderedThemeId == s.bannerTheme && renderedFontId == s.bannerFont
    }

    private func relayoutAndRender() {
        let s = settings
        let font = ResolvedFont(FontCatalog.font(id: s.bannerFont), pixelSize: pixelFontSize, vectorSize: vectorFontSize, text: String(text.prefix(maxLayoutCharacters)))
        let layout = computeLayout(for: text, font: font)
        lines = layout.lines
        isTruncated = layout.isTruncated
        renderedLineStep = layout.lineStep
        bitmapWidth = layout.width
        bitmapHeight = layout.height
        let buffer = renderFlatBanner(font: font, theme: ThemeCatalog.theme(id: s.bannerTheme))
        renderedThemeId = s.bannerTheme
        renderedFontId = s.bannerFont

        flatImage = makeImage(fromBottomUp: buffer, width: bitmapWidth, height: bitmapHeight)
        if let flatImage, createsTexture {
            let t = SKTexture(cgImage: flatImage)
            t.filteringMode = .nearest
            texture = t
        } else {
            texture = nil
        }
        sizeUniform.vectorFloat2Value = vector_float2(Float(bitmapWidth), Float(bitmapHeight))
        size = CGSize(
            width: CGFloat(bitmapWidth) * pixelScale,
            height: CGFloat(bitmapHeight) * pixelScale
        )
    }

    /// Advance the wave. Cheap: it only writes shader uniforms. The flat
    /// bitmap is re-rendered only when the theme or font changed.
    func tick(currentTime: TimeInterval) {
        if startTime == 0 { startTime = currentTime }
        if !themeAndFontUnchanged() || flatImage == nil { relayoutAndRender() }
        let s = settings
        timeUniform.floatValue = Float(currentTime - startTime)
        amplitudeUniform.floatValue = Float(min(Double(waveMargin), max(0, s.bannerAmplitude)))
        frequencyUniform.floatValue = Float(max(0.1, s.bannerFrequency))
        phaseStepUniform.floatValue = Float(s.bannerPhaseStep)
        // Custom shaders do not apply node alpha, so feed it in for fade-outs.
        alphaUniform.floatValue = Float(alpha)
    }

    /// Actual center of the waving rightmost column, in the parent's coordinates.
    /// Use the shader's quantized offset so the cord stays attached to the cloth.
    var ropeAttachmentPoint: CGPoint {
        let column = Float(bitmapWidth - 1)
        let phase = timeUniform.floatValue * frequencyUniform.floatValue
            + column * phaseStepUniform.floatValue
        let offset = floor(amplitudeUniform.floatValue * sin(phase) + 0.5)
        return convert(CGPoint(x: -pixelScale / 2, y: CGFloat(offset) * pixelScale), to: parent ?? self)
    }

    // MARK: - Wave shader

    private let timeUniform = SKUniform(name: "u_wave_time", float: 0)
    private let amplitudeUniform = SKUniform(name: "u_amplitude", float: 0)
    private let frequencyUniform = SKUniform(name: "u_frequency", float: 1)
    private let phaseStepUniform = SKUniform(name: "u_phase_step", float: 0)
    private let alphaUniform = SKUniform(name: "u_alpha", float: 1)
    private let sizeUniform = SKUniform(name: "u_bitmap_size", vectorFloat2: vector_float2(1, 1))

    private lazy var waveShader: SKShader = SKShader(
        source: Self.waveShaderSource,
        uniforms: [timeUniform, amplitudeUniform, frequencyUniform, phaseStepUniform, alphaUniform, sizeUniform]
    )

    /// Per column: yOff = round(amplitude * sin(time * frequency + column * phaseStep)).
    /// The output row `y` samples source row `y - yOff`; rows that fall off
    /// the bitmap are transparent. Row 0 is the bottom (SpriteKit texture space).
    static let waveShaderSource = """
    void main() {
        float col = floor(v_tex_coord.x * u_bitmap_size.x);
        float row = floor(v_tex_coord.y * u_bitmap_size.y);
        float yOff = floor(u_amplitude * sin(u_wave_time * u_frequency + col * u_phase_step) + 0.5);
        float srcRow = row - yOff;
        float inside = step(0.0, srcRow) * step(srcRow, u_bitmap_size.y - 1.0);
        vec2 src = vec2((col + 0.5) / u_bitmap_size.x, (srcRow + 0.5) / u_bitmap_size.y);
        gl_FragColor = texture2D(u_texture, src) * (inside * u_alpha);
    }
    """

    // MARK: - Layout

    private struct Layout {
        let width: Int
        let height: Int
        let lines: [String]
        let lineStep: Int
        let isTruncated: Bool
    }

    /// The banner font resolved one time per layout pass. Measuring re-uses
    /// these attributes instead of resolving the NSFont for every candidate
    /// string (word wrap measures many strings).
    private struct ResolvedFont {
        let attributes: [NSAttributedString.Key: Any]

        init(_ font: BannerFont, pixelSize: CGFloat, vectorSize: CGFloat, text: String) {
            let resolved = font.resolve(font.isPixel ? pixelSize : vectorSize)
            let characters = Array(text.utf16).filter { $0 > 32 }
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            let ctFont = CTFontCreateWithName(resolved.fontName as CFString, resolved.pointSize, nil)
            let needsFallback = font.isPixel && !characters.isEmpty
                && !CTFontGetGlyphsForCharacters(ctFont, characters, &glyphs, characters.count)
            // Pixel tracking and an 8pt fallback make Arabic/CJK illegible.
            // Keep a consistent, readable size for the entire mixed-script title.
            attributes = [
                .font: needsFallback ? NSFont.systemFont(ofSize: vectorSize, weight: .heavy) : resolved,
                .foregroundColor: NSColor.white,
                .kern: font.isPixel && !needsFallback ? 1 : 0
            ]
        }

        func line(_ text: String) -> CTLine {
            CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        }

        func bounds(_ text: String) -> CGRect {
            let bounds = CTLineGetImageBounds(line(text), nil)
            return bounds.isNull || !bounds.width.isFinite || !bounds.height.isFinite ? .zero : bounds
        }

        /// Ink width of `text` in logical pixels, independent of side bearings.
        func width(_ text: String) -> Int {
            guard !text.isEmpty else { return 0 }
            return Int(ceil(bounds(text).width))
        }
    }

    private func computeLayout(for text: String, font: ResolvedFont) -> Layout {
        let measureWidth = font.width
        let pad = horizontalPad * 2
        let maxInnerW = maxBitmapWidth - pad
        // Honor explicit line breaks, but ignore accidental blank lines and
        // normalize tabs/repeated spaces before measuring or drawing.
        let bounded = String(text.prefix(maxLayoutCharacters))
        let paragraphs = bounded.components(separatedBy: .newlines).map {
            $0.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }.filter { !$0.isEmpty }
        var wrapped = paragraphs.flatMap {
            wrapToLines($0, maxWidth: maxInnerW, measureWidth: measureWidth)
        }
        if wrapped.isEmpty || wrapped.allSatisfy({ font.width($0) == 0 }) { wrapped = ["Reminder"] }
        let truncated = wrapped.count > maxLines || bounded.count < text.count
        // Keep a short final paragraph (calendar timing) visible even when
        // the meeting title fills more than the available lines.
        let keepsFooter = truncated && bounded.count == text.count && paragraphs.count > 1
            && paragraphs.last.map { measureWidth($0) <= maxInnerW } == true
        let footer = keepsFooter ? wrapped.last : nil
        wrapped = Array(wrapped.prefix(maxLines - (keepsFooter ? 1 : 0)))
        if truncated, var last = wrapped.last {
            while !last.isEmpty && measureWidth(last + "…") > maxInnerW { last.removeLast() }
            wrapped[wrapped.count - 1] = last.trimmingCharacters(in: .whitespaces) + "…"
        }
        if let footer { wrapped.append(footer) }
        let inkHeight = Int(ceil(wrapped.map { font.bounds($0).height }.max() ?? 0))
        let advance = max(lineStep, inkHeight + 3)
        let widest = wrapped.map(measureWidth).max() ?? 0
        let w = min(maxBitmapWidth, max(minBitmapWidth, widest + pad))
        let h = max(singleLineHeight, inkHeight + waveMargin * 2 + 8) + max(0, wrapped.count - 1) * advance
        return Layout(width: w, height: h, lines: wrapped, lineStep: advance, isTruncated: truncated)
    }

    /// Prefer an even distribution of words across the fewest possible lines.
    /// Measuring complete candidates preserves kerning and shaping. Explicit
    /// paragraphs (including calendar timing) are balanced independently.
    private func wrapToLines(_ text: String, maxWidth: Int, measureWidth: (String) -> Int) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [text] }
        // Unbreakable identifiers still use grapheme-safe hard breaks.
        guard words.allSatisfy({ measureWidth($0) <= maxWidth }) else {
            return greedyWrapToLines(text, maxWidth: maxWidth, measureWidth: measureWidth)
        }
        let count = words.count
        var lineCounts = [Int](repeating: Int.max, count: count + 1)
        var costs = [Int](repeating: Int.max, count: count + 1)
        var nextBreak = [Int](repeating: count, count: count)
        lineCounts[count] = 0
        costs[count] = 0
        for start in stride(from: count - 1, through: 0, by: -1) {
            var candidate = ""
            for end in start..<count {
                candidate += (candidate.isEmpty ? "" : " ") + words[end]
                let width = measureWidth(candidate)
                if width > maxWidth { break }
                let lines = 1 + lineCounts[end + 1]
                let slack = maxWidth - width
                let cost = slack * slack + costs[end + 1]
                if lines < lineCounts[start] || (lines == lineCounts[start] && cost < costs[start]) {
                    lineCounts[start] = lines
                    costs[start] = cost
                    nextBreak[start] = end + 1
                }
            }
        }
        var result: [String] = []
        var start = 0
        while start < count {
            let end = nextBreak[start]
            result.append(words[start..<end].joined(separator: " "))
            start = end
        }
        return result
    }

    /// Greedy word wrap. Words that themselves exceed `maxWidth` (e.g. a long
    /// URL) are hard-broken at the character level so nothing is lost.
    private func greedyWrapToLines(_ text: String, maxWidth: Int, measureWidth: (String) -> Int) -> [String] {
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
                let pieces = hardBreak(word, maxWidth: maxWidth, measureWidth: measureWidth)
                lines.append(contentsOf: pieces.dropLast())
                current = pieces.last ?? ""
            } else {
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines.isEmpty ? [text] : lines
    }

    private func hardBreak(_ word: String, maxWidth: Int, measureWidth: (String) -> Int) -> [String] {
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

    // MARK: - Pass 1: flat banner

    private func renderFlatBanner(font: ResolvedFont, theme: BannerTheme) -> [UInt8] {
        let w = bitmapWidth, h = bitmapHeight
        let bodyTop = h - waveMargin - 1
        let bodyBottom = waveMargin
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

        // Stamp all lines of the text mask over the body.
        let textMask = renderTextMask(font: font)
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
    private func renderTextMask(font: ResolvedFont) -> [Bool] {
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

        let bodyCenterY = CGFloat(h - 1) / 2

        for (i, lineText) in lines.enumerated() where !lineText.isEmpty {
            let ct = font.line(lineText)
            // A drawing context includes its current text position in the
            // bounds. Measure independently so earlier lines cannot shift or
            // clip subsequent lines.
            let bounds = font.bounds(lineText)

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
                baselineCenter = bodyCenterY + (CGFloat(lines.count - 1) / 2 - CGFloat(i)) * CGFloat(renderedLineStep)
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

    // MARK: - Image

    /// Wrap a bottom-up RGBA buffer in a CGImage (CGImage rows are top-down).
    private func makeImage(fromBottomUp buffer: [UInt8], width w: Int, height h: Int) -> CGImage? {
        let rowBytes = w * 4
        var topDown = [UInt8](repeating: 0, count: buffer.count)
        for y in 0..<h {
            let src = y * rowBytes
            let dst = (h - 1 - y) * rowBytes
            topDown.replaceSubrange(dst..<(dst + rowBytes), with: buffer[src..<(src + rowBytes)])
        }
        guard let provider = CGDataProvider(data: Data(topDown) as CFData) else { return nil }
        return CGImage(
            width: w, height: h,
            bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
