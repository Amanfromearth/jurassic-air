import AppKit
import Combine
import SpriteKit

final class OverlayWindowController: NSWindowController {
    let overlayWindow: OverlayWindow
    let skView: SKView
    let scene: PlaneScene
    var onIdle: (() -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var displayFrame: CGRect
    private var contentHeight: CGFloat = 0

    init(screen: NSScreen) {
        displayFrame = screen.frame
        let window = OverlayWindow(screen: screen)
        overlayWindow = window
        let view = SKView(frame: NSRect(origin: .zero, size: window.frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        skView = view
        let scene = PlaneScene(size: window.frame.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        self.scene = scene
        view.presentScene(scene)
        view.isPaused = true
        super.init(window: window)
        window.contentView = view
        updateFrameRate()

        scene.onFlightActivityChange = { [weak self] active in
            guard let self else { return }
            self.skView.isPaused = !active
            if active {
                self.show()
            } else {
                self.overlayWindow.ignoresMouseEvents = true
                self.overlayWindow.orderOut(nil)
                self.onIdle?()
            }
        }
        // Hit testing shares SpriteKit's existing render loop; no 30 Hz timer.
        scene.onFrameUpdate = { [weak self] in self?.updatePassthrough() }
        scene.onContentHeightChange = { [weak self] height in
            guard let self else { return }
            self.contentHeight = height
            self.updateViewport()
        }
        AppSettings.shared.$showRenderStats.removeDuplicates()
            .sink { [weak view] show in
                view?.showsFPS = show
                view?.showsNodeCount = show
                view?.showsDrawCount = show
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateFrameRate() }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    func show() { overlayWindow.orderFrontRegardless() }
    func reloadAssets() { scene.reloadAssets() }

    func screenDidChange(to screen: NSScreen) {
        displayFrame = screen.frame
        updateViewport()
    }

    private func updateViewport() {
        let frame = OverlayWindow.viewportFrame(for: displayFrame, contentHeight: contentHeight)
        guard frame != overlayWindow.frame else { return }
        overlayWindow.setFrame(frame, display: true, animate: false)
        skView.frame = NSRect(origin: .zero, size: frame.size)
        scene.size = frame.size
    }

    private func updateFrameRate() {
        // A small desktop companion does not need a game-rate render loop.
        skView.preferredFramesPerSecond = ProcessInfo.processInfo.isLowPowerModeEnabled ? 20 : 30
    }

    private func updatePassthrough() {
        let cursor = NSEvent.mouseLocation
        let frame = overlayWindow.frame
        let point = CGPoint(x: cursor.x - frame.minX, y: cursor.y - frame.minY)
        let captures = frame.contains(cursor) && scene.cursorIsOverInteractive(point)
        scene.setHoverPaused(captures)
        if overlayWindow.ignoresMouseEvents == captures {
            overlayWindow.ignoresMouseEvents = !captures
        }
    }
}
