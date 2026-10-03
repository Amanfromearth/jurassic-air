import SpriteKit

/// A composited plane sprite: a plane BASE (colour-swappable) + a character HEAD
/// in the cockpit + a spinning BLADE on top. All three source images share a
/// 1088×1088 canvas so they overlay cleanly at the same display size.
///
/// Reflects the current `flierColor` / `flierHead` selection from `AppSettings`;
/// call `refreshAppearance()` to re-skin a node that's already on-screen.
final class PlaneNode: SKSpriteNode {
    private let head: SKSpriteNode
    private let blade: SKSpriteNode

    init() {
        let settings = AppSettings.shared
        let planeTexture = SpriteAssets.planeBaseTexture(colorId: settings.flierColor)
        let headTexture = SpriteAssets.headTexture(headId: settings.flierHead)
        let bladeTexture = SpriteAssets.bladeTexture()

        // Source canvas is square; pick the on-screen height to match the
        // display width so the parts overlay 1:1.
        let displaySize = CGSize(
            width: SpriteAssets.planeDisplayWidth,
            height: SpriteAssets.planeDisplayWidth
        )

        head = SKSpriteNode(texture: headTexture, size: displaySize)
        head.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        head.zPosition = 2

        blade = SKSpriteNode(texture: bladeTexture, size: displaySize)
        // Pivot the blade around its hub so the spin animation rotates around
        // the propeller axle, not the canvas centre. QuakPit's CSS uses
        // `transform-origin: 94.5% 56.2%` (top-down); in SpriteKit's bottom-up
        // anchor convention that's (0.945, 0.438). The blade's position is then
        // shifted by (anchor - 0.5) * size so the image still aligns with the
        // plane base pixel-for-pixel.
        let bladeHub = CGPoint(x: 0.945, y: 0.438)
        blade.anchorPoint = bladeHub
        blade.position = CGPoint(
            x: (bladeHub.x - 0.5) * displaySize.width,
            y: (bladeHub.y - 0.5) * displaySize.height
        )
        blade.zPosition = 3

        super.init(texture: planeTexture, color: .clear, size: displaySize)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        addChild(head)
        addChild(blade)

        startIdleBob()
        startBladeSpin()
    }

    required init?(coder: NSCoder) { fatalError() }

    func startIdleBob() {
        let up = SKAction.moveBy(x: 0, y: 6, duration: 0.55)
        up.timingMode = .easeInEaseOut
        let down = up.reversed()
        run(.repeatForever(.sequence([up, down])), withKey: "bob")
    }

    /// Simulate QuakPit's CSS `animation: spin 0.3s linear infinite` —
    /// `rotateX(360deg)` from a side view becomes a continuous yScale = cos(angle)
    /// in 2D, pivoting around the hub anchor. Smooth (no flicker) and lets the
    /// blade pass through edge-on (yScale=0) and a mirrored half-cycle (yScale<0).
    private func startBladeSpin() {
        let period: TimeInterval = 0.3
        let spin = SKAction.customAction(withDuration: period) { node, elapsed in
            let angle = (Double(elapsed) / period) * 2 * .pi
            node.yScale = CGFloat(cos(angle))
        }
        blade.run(.repeatForever(spin), withKey: "spin")
    }

    /// Re-skin without rebuilding the node — used when the user picks a new
    /// head or plane colour in Settings while a plane is on-screen.
    func refreshAppearance() {
        let settings = AppSettings.shared
        texture = SpriteAssets.planeBaseTexture(colorId: settings.flierColor)
        head.texture = SpriteAssets.headTexture(headId: settings.flierHead)
        blade.texture = SpriteAssets.bladeTexture()
    }

    func ropeTipPosition() -> CGPoint {
        let offset = SpriteAssets.planeRopeTipOffset(displaySize: size)
        return CGPoint(x: position.x + offset.x, y: position.y + offset.y)
    }
}
