import AppKit
import Combine
import SpriteKit

final class OverlayWindowController: NSWindowController {
    let overlayWindow: OverlayWindow
    let skView: SKView
    let scene: PlaneScene
    private var passthroughTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

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

        // Cursor tracking only matters while a plane is on screen.
        s.onFlightActivityChange = { [weak self] active in
            if active { self?.startCursorTracking() } else { self?.stopCursorTracking() }
        }
        AppSettings.shared.$showRenderStats
            .sink { [weak view] show in
                view?.showsFPS = show
                view?.showsNodeCount = show
                view?.showsDrawCount = show
            }
            .store(in: &cancellables)
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

    /// Cursor-driven mouse passthrough. While a plane flies, we poll the cursor at
    /// 30 Hz against the scene's interactive nodes. When the cursor is over the plane
    /// or its banner, we disable the window's mouse-event ignore so clicks land in
    /// SpriteKit; otherwise we re-enable it so the desktop behind the overlay keeps
    /// receiving clicks. With no plane on screen the timer does not run at all.
    private func startCursorTracking() {
        guard passthroughTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.updatePassthrough()
        }
        t.tolerance = 1.0 / 120.0
        RunLoop.main.add(t, forMode: .common)
        passthroughTimer = t
    }

    private func stopCursorTracking() {
        passthroughTimer?.invalidate()
        passthroughTimer = nil
        overlayWindow.ignoresMouseEvents = true
    }

    private func updatePassthrough() {
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
