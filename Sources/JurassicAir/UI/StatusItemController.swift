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

        let it = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = it.button {
            button.image = Self.makeLogoImage()
            button.imagePosition = .imageOnly
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

    /// Load the bundled pixel-art propeller plane and treat it as a 2x-density
    /// template image — solid black on transparent so macOS auto-recolors it for
    /// menu bar style (light text on dark menu bar / dark text on light menu bar).
    private static func makeLogoImage() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "logo@2x", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        // Loaded data is 50x36 pixels (logo@2x.png). Halve the logical size so that
        // pixel art maps 1:1 to physical pixels on Retina displays — keeps edges crisp.
        image.size = NSSize(width: image.size.width / 2, height: image.size.height / 2)
        image.isTemplate = true
        return image
    }
}
