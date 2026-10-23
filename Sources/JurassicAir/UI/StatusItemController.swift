import AppKit

final class StatusItemController: NSObject, NSMenuDelegate {
    private var item: NSStatusItem?
    private var onTrigger: (() -> Void)?
    private var onSpawn: (() -> Void)?
    private var onSettings: (() -> Void)?
    private var onQuit: (() -> Void)?

    func install(
        onTrigger: @escaping () -> Void,
        onSpawn: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onTrigger = onTrigger
        self.onSpawn = onSpawn
        self.onSettings = onSettings
        self.onQuit = onQuit

        let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = it.button {
            button.image = Self.makeLogoImage()
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "Jurassic Air"
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Trigger Reminder", action: #selector(triggerAction), keyEquivalent: "2").target = self
        menu.addItem(withTitle: "Spawn Plane", action: #selector(spawnAction), keyEquivalent: "1").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settingsAction), keyEquivalent: "4").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Jurassic Air", action: #selector(quitAction), keyEquivalent: "q").target = self
        it.menu = menu
        self.item = it
    }

    @objc private func triggerAction()  { onTrigger?() }
    @objc private func spawnAction()    { onSpawn?() }
    @objc private func settingsAction() { onSettings?() }
    @objc private func quitAction()     { onQuit?() }

    /// A side-on propeller aircraft, drawn as a vector template at menu-bar size.
    private static func makeLogoImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 18), flipped: true) { _ in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            let body = NSBezierPath()
            body.move(to: NSPoint(x: 1.5, y: 5))
            body.line(to: NSPoint(x: 3, y: 5))
            body.line(to: NSPoint(x: 5, y: 8.5))
            body.line(to: NSPoint(x: 8.5, y: 8.5))
            body.curve(to: NSPoint(x: 13, y: 8.5),
                       controlPoint1: NSPoint(x: 9, y: 5),
                       controlPoint2: NSPoint(x: 12, y: 5))
            body.line(to: NSPoint(x: 16, y: 8.5))
            body.curve(to: NSPoint(x: 18.5, y: 10),
                       controlPoint1: NSPoint(x: 17.5, y: 8.5),
                       controlPoint2: NSPoint(x: 18.5, y: 9))
            body.curve(to: NSPoint(x: 16, y: 11.5),
                       controlPoint1: NSPoint(x: 18.5, y: 11),
                       controlPoint2: NSPoint(x: 17.5, y: 11.5))
            body.line(to: NSPoint(x: 12, y: 11.5))
            body.line(to: NSPoint(x: 8, y: 15))
            body.line(to: NSPoint(x: 5.5, y: 15))
            body.line(to: NSPoint(x: 8.5, y: 11.5))
            body.line(to: NSPoint(x: 3, y: 10.5))
            body.line(to: NSPoint(x: 1.5, y: 10.5))
            body.close()
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 9.75, y: 7, width: 2.1, height: 1.5),
                xRadius: 0.6, yRadius: 0.6
            ))
            body.windingRule = .evenOdd
            body.fill()

            // A single fine propeller and a small cockpit window keep the
            // aircraft recognizable without crowding the silhouette.
            let propeller = NSBezierPath()
            propeller.lineWidth = 1.25
            propeller.lineCapStyle = .round
            propeller.move(to: NSPoint(x: 20, y: 6.5))
            propeller.line(to: NSPoint(x: 20, y: 13.5))
            propeller.move(to: NSPoint(x: 18, y: 10))
            propeller.line(to: NSPoint(x: 20, y: 10))
            propeller.stroke()

            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Jurassic Air"
        return image
    }
}
