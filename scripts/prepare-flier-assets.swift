// Normalize generated source artwork to the existing 64-pixel sprite grid.
// Run from the repository root with: swift scripts/prepare-flier-assets.swift
import AppKit

let resources = "Sources/JurassicAir/Resources/"
func load(_ path: String) -> NSBitmapImageRep {
    let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let context = CGContext(data: nil, width: image.width, height: image.height,
        bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return NSBitmapImageRep(cgImage: context.makeImage()!)
}
func bounds(_ image: NSBitmapImageRep) -> CGRect {
    var left = image.pixelsWide, top = image.pixelsHigh, right = 0, bottom = 0
    for y in 0..<image.pixelsHigh {
        for x in 0..<image.pixelsWide where image.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
            left = min(left, x); right = max(right, x)
            top = min(top, y); bottom = max(bottom, y)
        }
    }
    return CGRect(x: left, y: top, width: right-left+1, height: bottom-top+1)
}
func bitmap(_ width: Int, _ height: Int) -> NSBitmapImageRep {
    let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32)!
    memset(image.bitmapData!, 0, image.bytesPerRow * height)
    return image
}
func save(_ image: NSBitmapImageRep, _ name: String) {
    try! image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}
let referenceHead = bounds(load(resources + "head-dino.png"))
let referencePlane = bounds(load(resources + "plane-red-base.png"))
for (source, asset, thumb, reference) in [
    ("porco-rosso", "head-porco", "thumb-head-porco", referenceHead),
    ("military-pilot", "head-aviator", "thumb-head-aviator", referenceHead),
    ("military-plane", "plane-military-base", "thumb-plane-military", referencePlane),
    ("shark-plane", "plane-shark-base", "thumb-plane-shark", referencePlane),
    ("navy-plane", "plane-navy-base", "thumb-plane-navy", referencePlane),
    ("navy-shark-plane", "plane-navy-shark-base", "thumb-plane-navy-shark", referencePlane)
] {
    let input = load("Assets/FlierSources/" + source + ".png")
    let crop = bounds(input)
    var target = reference
    // Levelled warbirds have a lower rear fuselage. Keep their nose and cockpit
    // registered to the existing rig instead of raising the whole plane again.
    if ["military-plane", "shark-plane", "navy-plane", "navy-shark-plane"].contains(source) {
        target = reference.offsetBy(dx: 0, dy: 34)
    }
    if source == "porco-rosso" {
        let scale = min(reference.width / crop.width, reference.height / crop.height)
        let w = max(17, (crop.width * scale / 17).rounded() * 17)
        let h = max(17, (crop.height * scale / 17).rounded() * 17)
        target = CGRect(x: ((reference.midX - w/2)/17).rounded()*17,
                        y: reference.maxY-h, width: w, height: h)
    }
    let output = bitmap(1088, 1088)
    for gy in 0..<64 {
        for gx in 0..<64 {
            let x = CGFloat(gx * 17) + 8.5, y = CGFloat(gy * 17) + 8.5
            guard target.contains(CGPoint(x: x, y: y)) else { continue }
            let sx = min(input.pixelsWide-1, Int(crop.minX + (x-target.minX)/target.width*crop.width))
            let sy = min(input.pixelsHigh-1, Int(crop.minY + (y-target.minY)/target.height*crop.height))
            let color = input.colorAt(x: sx, y: sy)!
            guard color.alphaComponent > 0.5 else { continue }
            let opaque = color.withAlphaComponent(1)
            for dy in 0..<17 { for dx in 0..<17 {
                output.setColor(opaque, atX: gx*17+dx, y: gy*17+dy)
            }}
        }
    }
    save(output, resources + asset + ".png")
    let visible = bounds(output)
    let thumbnail = bitmap(Int(visible.width), Int(visible.height))
    for y in 0..<thumbnail.pixelsHigh { for x in 0..<thumbnail.pixelsWide {
        thumbnail.setColor(output.colorAt(x: x+Int(visible.minX), y: y+Int(visible.minY))!, atX: x, y: y)
    }}
    save(thumbnail, resources + thumb + ".png")
    print("Prepared \(asset): \(visible)")
}
