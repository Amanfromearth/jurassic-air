import AppKit

final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        let frame = Self.viewportFrame(for: screen.frame)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        setFrame(frame, display: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    /// A flight needs only a narrow strip, not a Retina backing surface for the
    /// entire desktop. Leave room for the largest supported sprite and bobbing.
    static func viewportFrame(for screen: CGRect, contentHeight: CGFloat = 0) -> CGRect {
        let height = min(screen.height, max(360, ceil(contentHeight)))
        let bottom = min(max(0, screen.height * 0.72 - height / 2), screen.height - height)
        return CGRect(x: screen.minX, y: (screen.minY + bottom).rounded(),
                      width: screen.width, height: height)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
