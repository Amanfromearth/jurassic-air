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
    var onFrameUpdate: (() -> Void)?
    var onContentHeightChange: ((CGFloat) -> Void)?
    private var reportedContentHeight: CGFloat = 0

    /// Read by the overlay controller's cursor-passthrough poll so it can skip
    /// the per-tick hit-test math when there's no plane on screen.
    var hasActiveFlight: Bool { activeFlight != nil }
    /// The rendered banner can shorten very long text; hover exposes it in full.
    var reminderTooltip: String? { activeFlight?.event.title }


    private struct ActiveFlight {
        let event: ReminderEvent
        let plane: PlaneNode
        let rope: TowRope
        let banner: BannerRibbon
        let endX: CGFloat
        let speedScale: CGFloat
        var paused: Bool
    }

    func spawn(event: ReminderEvent) {
        // The render loop sleeps while idle (see `update`). Wake it up.
        idleFrames = 0
        lastFrameTime = 0
        isDismissing = false
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

        let rope = TowRope()

        // The supplied sprite already faces RIGHT, so we fly LEFT → RIGHT and
        // do NOT mirror.
        let scale = CGFloat(AppSettings.shared.displayScale)
        plane.setScale(scale)
        banner.setScale(scale)
        reportContentHeight(plane: plane, banner: banner)

        // Compute visible plane width using the scaled frame.
        let visiblePlaneW = plane.frame.width
        let startX = -visiblePlaneW * 0.6
        let endX = size.width + visiblePlaneW * 0.6
        // Preserve the crossing time of a 1440-point display, including the
        // offscreen entry/exit distance. Wider displays need faster movement.
        let speedScale = (endX - startX) / (1440 + visiblePlaneW * 1.2)
        let margin = SpriteAssets.planeDisplayWidth * scale / 2 + 12
        let y = size.height > margin * 2
            ? CGFloat.random(in: margin...(size.height - margin)) : size.height / 2
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
            endX: endX,
            speedScale: speedScale,
            paused: false
        )

        // Match the audio's mid-flight one-shot to the actual crossing duration.
        let crossingDuration = TimeInterval((endX - startX) / flightSpeed(scale: speedScale))
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

        let dt = lastFrameDelta(currentTime: currentTime)
        if !flight.paused {
            // Read speed each frame so the settings slider tunes flight speed live.
            // Apply the active speed preset multiplier (normal / fast / ultra).
            let speed = flightSpeed(scale: flight.speedScale)
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

        flight.banner.tick(currentTime: currentTime)
        reportContentHeight(plane: flight.plane, banner: flight.banner)
        let margin = max(flight.plane.frame.height, flight.banner.frame.height) / 2 + 12
        if size.height > margin * 2 {
            flight.plane.position.y = min(max(flight.plane.position.y, margin), size.height - margin)
        }

        // Keep the cord tied to the fuselage and to the waving cloth.
        let visiblePlaneW = flight.plane.frame.width
        let visiblePlaneH = flight.plane.frame.height
        let ropeOffset = SpriteAssets.planeRopeTipOffset(
            displaySize: CGSize(width: visiblePlaneW, height: visiblePlaneH)
        )
        let tipX = flight.plane.position.x + ropeOffset.x
        let tipY = flight.plane.position.y + ropeOffset.y

        let ropeSize = SpriteAssets.ropeSize(planeWidth: visiblePlaneW)
        flight.banner.position = CGPoint(x: tipX - ropeSize.width, y: tipY)
        flight.rope.update(
            planeTip: CGPoint(x: tipX, y: tipY),
            bannerTip: flight.banner.ropeAttachmentPoint,
            scale: scale,
            currentTime: currentTime
        )
    }

    private func flightSpeed(scale: CGFloat) -> CGFloat {
        let multiplier = SpeedCatalog.preset(id: AppSettings.shared.speedPreset).multiplier
        return CGFloat(max(1, AppSettings.shared.flightSpeed * multiplier)) * scale
    }

    private func reportContentHeight(plane: PlaneNode, banner: BannerRibbon) {
        let height = max(plane.frame.height, banner.frame.height) + 24
        guard abs(height - reportedContentHeight) > 0.5 else { return }
        reportedContentHeight = height
        onContentHeightChange?(height)
    }

    override func didFinishUpdate() {
        if hasActiveFlight { onFrameUpdate?() }
    }

    func setHoverPaused(_ paused: Bool) {
        guard var flight = activeFlight, !isDismissing, flight.paused != paused else { return }
        flight.paused = paused
        activeFlight = flight
    }

    private var isDismissing = false

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

    private func openLinkAndDismiss(event: ReminderEvent) {
        if let url = URL(string: event.urlString) {
            NSWorkspace.shared.open(url)
        }
        guard var flight = activeFlight, !isDismissing else { return }
        isDismissing = true
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
