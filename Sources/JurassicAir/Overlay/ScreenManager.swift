import AppKit

/// Creates overlays as displays are used. Each flight stays on the display
/// where it started; the next flight uses the display containing the cursor.
final class ScreenManager {
    private var overlays: [CGDirectDisplayID: OverlayWindowController] = [:]
    private var observer: NSObjectProtocol?

    var controllers: [OverlayWindowController] {
        NSScreen.screens.compactMap { screen in
            screen.displayID.flatMap { overlays[$0] }
        }
    }

    func start() {
        guard observer == nil else { return }
        _ = controllerForCursorScreen()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.reconcileDisplays() }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func controllerForCursorScreen(at cursor: CGPoint = NSEvent.mouseLocation) -> OverlayWindowController? {
        let screens = NSScreen.screens
        guard let index = Self.screenIndex(containing: cursor, frames: screens.map(\.frame)),
              let id = screens[index].displayID else { return nil }
        if let existing = overlays[id] { return existing }

        let controller = OverlayWindowController(screen: screens[index])
        overlays[id] = controller
        controller.show()
        return controller
    }

    /// AppKit screen frames and mouseLocation share global bottom-left
    /// coordinates, including negative origins for displays left of or below
    /// the primary display. Fall back to the primary display during transitions.
    static func screenIndex(containing cursor: CGPoint, frames: [CGRect]) -> Int? {
        frames.firstIndex { $0.contains(cursor) } ?? (frames.isEmpty ? nil : 0)
    }

    private func reconcileDisplays() {
        let screens = NSScreen.screens
        let connected = Set(screens.compactMap(\.displayID))
        for id in Array(overlays.keys) where !connected.contains(id) {
            overlays.removeValue(forKey: id)?.close()
        }
        for screen in screens {
            guard let id = screen.displayID, let controller = overlays[id] else { continue }
            if controller.overlayWindow.frame != screen.frame {
                controller.screenDidChange(to: screen)
            }
            controller.show()
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}
