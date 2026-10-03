import AppKit
import SpriteKit

final class PlaneScene: SKScene {
    private var activeFlight: ActiveFlight? {
        didSet {
            let isActive = activeFlight != nil
            if (oldValue != nil) != isActive { onFlightActivityChange?(isActive) }
        }
    }
    private let audio = PlaneAudioPlayer()
    /// Count of `update` calls with no flight. Used to pause the view's
    /// render loop after the cleared frame reaches the screen.
    private var idleFrames = 0

    /// Called with `true` when a flight starts and `false` when the last one
    /// ends. The overlay controller uses it to run cursor tracking only
    /// while something is on screen.
    var onFlightActivityChange: ((Bool) -> Void)?

    /// Read by the overlay controller's cursor-passthrough poll so it can skip
    /// the per-tick hit-test math when there's no plane on screen.
    var hasActiveFlight: Bool { activeFlight != nil }

    private struct ActiveFlight {
        let event: ReminderEvent
        let plane: PlaneNode
        let rope: SKSpriteNode
        let banner: BannerRibbon
        let startX: CGFloat
        let endX: CGFloat
        var paused: Bool
    }

    func spawn(event: ReminderEvent) {
        // The render loop sleeps while idle (see `update`). Wake it up.
        idleFrames = 0
        view?.isPaused = false

        if let existing = activeFlight {
            existing.plane.removeFromParent()
            existing.rope.removeFromParent()
            existing.banner.removeFromParent()
            activeFlight = nil
        }
        audio.stop()

        let plane = PlaneNode()
        let banner = BannerRibbon(text: event.title.uppercased())

        // The rope sits between the banner and the plane — anchored at its RIGHT
        // edge so its right tip meets the plane's rope point, with the body
        // trailing LEFT toward the banner. Drawn as a plain coloured sprite the
        // same colour as QuakPit's CSS rope (rgba(35,35,35,0.78)).
        let rope = SKSpriteNode(color: SpriteAssets.ropeColor, size: .zero)
        rope.anchorPoint = CGPoint(x: 1.0, y: 0.5)

        // The supplied sprite already faces RIGHT, so we fly LEFT → RIGHT and
        // do NOT mirror.
        let scale = CGFloat(AppSettings.shared.displayScale)
        plane.setScale(scale)
        banner.setScale(scale)

        // Compute visible plane width using the scaled frame.
        let visiblePlaneW = plane.frame.width
        let startX = -visiblePlaneW * 0.6
        let endX = size.width + visiblePlaneW * 0.6
        let y = size.height * CGFloat.random(in: 0.55...0.85)
        plane.position = CGPoint(x: startX, y: y)
        plane.zPosition = 10
        addChild(plane)

        // Rope BEHIND the plane so its right end visually tucks into the fuselage,
        // but in front of the banner (since the banner trails behind).
        rope.zPosition = 9.5
        addChild(rope)

        banner.zPosition = 9
        addChild(banner)

        activeFlight = ActiveFlight(
            event: event,
            plane: plane,
            rope: rope,
            banner: banner,
            startX: startX,
            endX: endX,
            paused: false
        )

        // Match the audio's mid-flight one-shot to the actual crossing duration.
        let speedMultiplier = SpeedCatalog.preset(id: AppSettings.shared.speedPreset).multiplier
        let speedPx = max(1, AppSettings.shared.flightSpeed * speedMultiplier)
        let crossingDuration = TimeInterval(abs(endX - startX) / CGFloat(speedPx))
        audio.start(flightDuration: crossingDuration)
    }

    override func update(_ currentTime: TimeInterval) {
        guard let flight = activeFlight else {
            // Nothing on screen. Let one more frame render so the cleared
            // scene is presented, then pause the view: an idle full-screen
            // SKView would otherwise keep rendering at 60 fps all day.
            idleFrames += 1
            if idleFrames >= 2 {
                lastFrameTime = 0
                view?.isPaused = true
            }
            return
        }
        idleFrames = 0

        // Live-tunable display scale via the settings panel slider.
        let scale = CGFloat(AppSettings.shared.displayScale)
        flight.plane.setScale(scale)
        flight.banner.setScale(scale)

        if !flight.paused {
            // Read speed each frame so the settings slider tunes flight speed live.
            // Apply the active speed preset multiplier (normal / fast / ultra).
            let multiplier = SpeedCatalog.preset(id: AppSettings.shared.speedPreset).multiplier
            let speed = CGFloat(max(0, AppSettings.shared.flightSpeed * multiplier))
            let dt = lastFrameDelta(currentTime: currentTime)
            flight.plane.position.x += speed * CGFloat(dt)

            if flight.plane.position.x >= flight.endX {
                flight.plane.removeFromParent()
                flight.rope.removeFromParent()
                flight.banner.removeFromParent()
                activeFlight = nil
                audio.stop()
                return
            }
        }

        // Rope tip in scene coords — the point on the plane where the rope's
        // right edge meets the fuselage. The rope is rendered at the plane's
        // current scaled size; its right edge sits at the rope tip, body trails
        // left, and the banner's right edge attaches at the rope's LEFT end.
        let visiblePlaneW = flight.plane.frame.width
        let visiblePlaneH = flight.plane.frame.height
        let ropeOffset = SpriteAssets.planeRopeTipOffset(
            displaySize: CGSize(width: visiblePlaneW, height: visiblePlaneH)
        )
        let tipX = flight.plane.position.x + ropeOffset.x
        let tipY = flight.plane.position.y + ropeOffset.y

        // Resize the rope each frame so the display-scale slider tunes it live.
        let ropeSize = SpriteAssets.ropeSize(planeWidth: visiblePlaneW)
        flight.rope.size = ropeSize
        flight.rope.position = CGPoint(x: tipX, y: tipY)

        // Banner attaches at the LEFT end of the rope (rope's left tip).
        flight.banner.position = CGPoint(x: tipX - ropeSize.width, y: tipY)
        flight.banner.tick(currentTime: currentTime)
    }

    private var lastFrameTime: TimeInterval = 0
    private func lastFrameDelta(currentTime: TimeInterval) -> TimeInterval {
        if lastFrameTime == 0 { lastFrameTime = currentTime; return 1.0 / 60.0 }
        let dt = currentTime - lastFrameTime
        lastFrameTime = currentTime
        return min(max(dt, 0), 0.05)
    }

    // MARK: - Hover / click

    func cursorIsOverInteractive(_ point: CGPoint) -> Bool {
        guard let flight = activeFlight else { return false }
        if flight.plane.frame.insetBy(dx: -4, dy: -4).contains(point) { return true }
        if flight.banner.frame.insetBy(dx: -2, dy: -4).contains(point) { return true }
        return false
    }

    override func mouseDown(with event: NSEvent) {
        guard let flight = activeFlight else { return }
        let pt = event.location(in: self)
        if cursorIsOverInteractive(pt) {
            openLinkAndDismiss(event: flight.event)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard var flight = activeFlight else { return }
        let pt = event.location(in: self)
        flight.paused = cursorIsOverInteractive(pt)
        activeFlight = flight
    }

    private func openLinkAndDismiss(event: ReminderEvent) {
        if let url = URL(string: event.urlString) {
            NSWorkspace.shared.open(url)
        }
        guard var flight = activeFlight else { return }
        let plane = flight.plane
        let rope = flight.rope
        let banner = flight.banner
        // Tag the deferred clear with this flight's id so a NEW spawn during
        // the 0.7s dismiss animation isn't accidentally wiped out below.
        let dismissedFlightId = flight.event.id
        let exit = SKAction.group([
            SKAction.moveBy(x: size.width * 0.7, y: size.height * 0.15, duration: 0.6),
            SKAction.fadeOut(withDuration: 0.6)
        ])
        plane.run(exit) {
            plane.removeFromParent()
            rope.removeFromParent()
            banner.removeFromParent()
        }
        rope.run(.fadeOut(withDuration: 0.6))
        banner.run(.fadeOut(withDuration: 0.6))
        flight.paused = true
        activeFlight = flight
        audio.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            if self.activeFlight?.event.id == dismissedFlightId {
                self.activeFlight = nil
            }
        }
    }

    func reloadAssets() {
        SpriteAssets.reloadFromDisk()
        activeFlight?.plane.refreshAppearance()
    }
}
