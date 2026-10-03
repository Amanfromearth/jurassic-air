import AppKit

/// Owns a single overlay window pinned to the MacBook's built-in display
/// (or the menu-bar screen in clamshell mode). Multi-monitor setups always
/// render the plane on the laptop screen — that is what the user is looking
/// at. When displays are reconfigured, the same window is reframed onto the
/// new target screen so in-flight planes are preserved.
final class ScreenManager {
    private(set) var controller: OverlayWindowController?
    private var observer: NSObjectProtocol?

    /// Exposed as an array for the few callers that broadcast to every overlay
    /// (e.g. `reloadAssets`). There's only ever one now.
    var controllers: [OverlayWindowController] { controller.map { [$0] } ?? [] }

    func start() {
        rebuild()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuild() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func controllerForMainScreen() -> OverlayWindowController? { controller }

    private func rebuild() {
        guard let target = Self.targetScreen() else {
            controller?.close()
            controller = nil
            return
        }
        if let c = controller {
            c.screenDidChange(to: target)
            c.show()
        } else {
            let c = OverlayWindowController(screen: target)
            c.show()
            controller = c
        }
    }

    /// Built-in MacBook display first; fall back to the menu-bar screen
    /// (clamshell mode, Mac mini, etc.).
    private static func targetScreen() -> NSScreen? {
        for screen in NSScreen.screens {
            if let id = screen.displayID, CGDisplayIsBuiltin(id) != 0 {
                return screen
            }
        }
        return NSScreen.screens.first
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let n = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(n.uint32Value)
    }
}
