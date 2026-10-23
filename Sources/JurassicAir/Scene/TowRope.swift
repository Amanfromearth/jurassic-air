import SpriteKit

/// A lightly tensioned cord, with fixed ends and wind moving through its slack.
final class TowRope: SKNode {
    private let outline = SKShapeNode()
    private let cord = SKShapeNode()
    private let fibers = SKShapeNode()
    private var startTime: TimeInterval?
    private var lastGeometryTime: TimeInterval = -.infinity
    private var lastEnd: CGPoint?
    private var lastScale: CGFloat?

    override init() {
        super.init()
        for stroke in [outline, cord, fibers] {
            stroke.lineCap = .round
            stroke.lineJoin = .round
            stroke.isAntialiased = true
            addChild(stroke)
        }
        outline.strokeColor = SKColor(srgbRed: 0.18, green: 0.14, blue: 0.10, alpha: 0.9)
        cord.strokeColor = SKColor(srgbRed: 0.67, green: 0.53, blue: 0.34, alpha: 1)
        fibers.strokeColor = SKColor(srgbRed: 0.94, green: 0.83, blue: 0.61, alpha: 0.85)
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(planeTip: CGPoint, bannerTip: CGPoint, scale: CGFloat, currentTime: TimeInterval) {
        if startTime == nil { startTime = currentTime }
        let time = CGFloat(currentTime - (startTime ?? currentTime))
        position = planeTip
        let end = CGPoint(x: bannerTip.x - planeTip.x, y: bannerTip.y - planeTip.y)
        // Move with the plane at display rate, but avoid retessellating three
        // shape paths twice per visual sample. Endpoint changes stay immediate.
        let endpointMoved = lastEnd.map { hypot(end.x - $0.x, end.y - $0.y) > 0.1 } ?? true
        guard currentTime - lastGeometryTime >= 1.0 / 30.0
                || endpointMoved || scale != lastScale else { return }
        lastGeometryTime = currentTime
        lastEnd = end
        lastScale = scale
        let length = hypot(end.x, end.y)
        let sag = min(length * 0.11, 10 * scale)
        let path = CGMutablePath()
        let twist = CGMutablePath()
        let segments = 16
        var previous = CGPoint.zero

        for index in 0...segments {
            let t = CGFloat(index) / CGFloat(segments)
            // The envelope keeps both knots pinned while the middle breathes.
            let envelope = sin(.pi * t)
            let flutter = sin(t * 2 * .pi - time * 3.4) * 1.5 * scale
                + sin(t * 4 * .pi - time * 5.1) * 0.4 * scale
            let point = CGPoint(
                x: end.x * t,
                y: end.y * t - sag * 4 * t * (1 - t) + flutter * envelope
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
                // Broken diagonal glints suggest the lay of twisted fibers.
                if index % 3 == 0 {
                    twist.move(to: CGPoint(x: previous.x, y: previous.y + 0.55 * scale))
                    twist.addLine(to: CGPoint(x: point.x, y: point.y - 0.35 * scale))
                }
            }
            previous = point
        }

        outline.path = path
        outline.lineWidth = 3.2 * scale
        cord.path = path
        cord.lineWidth = 1.9 * scale
        fibers.path = twist
        fibers.lineWidth = 0.7 * scale
    }
}
