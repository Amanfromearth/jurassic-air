import AppKit
import SpriteKit

final class OverlayWindowController: NSWindowController {
    let overlayWindow: OverlayWindow
    let skView: SKView
    let scene: PlaneScene
    private var passthroughTimer: Timer?

    init(screen: NSScreen) {
        let win = OverlayWindow(screen: screen)
        self.overlayWindow = win

        let view = SKView(frame: NSRect(origin: .zero, size: screen.frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        // Pixel-art friendly: no anti-aliased smoothing of textures we want crisp.
        // We still leave layer-level scaling alone; SKTexture.filteringMode handles per-texture.
        self.skView = view

        let s = PlaneScene(size: screen.frame.size)
        s.scaleMode = .resizeFill
        s.backgroundColor = .clear
        view.presentScene(s)
        self.scene = s

        super.init(window: win)
        win.contentView = view

        startCursorTracking()
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    func show() {
        overlayWindow.orderFrontRegardless()
    }

    func reloadAssets() {
        scene.reloadAssets()
    }

    func screenDidChange(to screen: NSScreen) {
        overlayWindow.setFrame(screen.frame, display: true, animate: false)
        skView.frame = NSRect(origin: .zero, size: screen.frame.size)
        scene.size = screen.frame.size
    }

    /// Cursor-driven mouse passthrough. We poll the cursor at 30 Hz against the scene's
    /// interactive nodes. When the cursor is over the plane or its banner, we disable
    /// the window's mouse-event ignore so clicks land in SpriteKit; otherwise we re-enable
    /// it so the desktop behind the overlay keeps receiving clicks.
    private func startCursorTracking() {
        passthroughTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updatePassthrough()
        }
        if let t = passthroughTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func updatePassthrough() {
        // Fast path: when no plane is flying there's nothing interactive on
        // this overlay, so we can skip the hit-test entirely and just make
        // sure the window stays click-through. Saves the ~30 Hz cursor +
        // node-bounds math while the app is idle in the menu bar.
        guard scene.hasActiveFlight else {
            if !overlayWindow.ignoresMouseEvents {
                overlayWindow.ignoresMouseEvents = true
            }
            return
        }

        let mouseScreen = NSEvent.mouseLocation
        guard let screen = overlayWindow.screen else { return }
        let frame = screen.frame
        let localX = mouseScreen.x - frame.origin.x
        let localY = mouseScreen.y - frame.origin.y
        let cursorInScreen = NSRect(origin: .zero, size: frame.size).contains(NSPoint(x: localX, y: localY))

        let shouldCapture = cursorInScreen && scene.cursorIsOverInteractive(NSPoint(x: localX, y: localY))
        if overlayWindow.ignoresMouseEvents == shouldCapture {
            overlayWindow.ignoresMouseEvents = !shouldCapture
        }
    }

    deinit {
        passthroughTimer?.invalidate()
    }
}
