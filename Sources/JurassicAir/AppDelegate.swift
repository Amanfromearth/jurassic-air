import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// SwiftUI's @NSApplicationDelegateAdaptor doesn't expose us through
    /// `NSApp.delegate` reliably from view code (same root cause as the
    /// CalendarService bug). Views reach for `AppDelegate.shared` instead.
    static private(set) weak var shared: AppDelegate?

    let screenManager = ScreenManager()
    let dispatcher = ReminderDispatcher()
    let statusItem = StatusItemController()
    let scheduler = ReminderScheduler()
    lazy var calendarScheduler = CalendarAlertScheduler(service: Services.calendar)
    var settingsWindow: NSWindow?
    #if DEBUG
    private var bannerStressWindow: NSWindow?
    #endif
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        if CommandLine.arguments.contains("--banner-stress") || Bundle.main.bundleIdentifier == "com.anurag.jurassicair.banner-stress" {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                                  styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "Jurassic Air — Banner stress test (development only)"
            window.contentViewController = NSHostingController(rootView: BannerStressView())
            window.contentMinSize = NSSize(width: 900, height: 620)
            window.setContentSize(NSSize(width: 1100, height: 800))
            window.isReleasedWhenClosed = false
            window.center()
            window.makeKeyAndOrderFront(nil)
            bannerStressWindow = window
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        #endif

        dispatcher.screenManager = screenManager
        screenManager.start()

        scheduler.dispatcher = dispatcher
        scheduler.start()

        calendarScheduler.dispatcher = dispatcher
        calendarScheduler.start()

        statusItem.install(
            onTrigger: { [weak self] in self?.triggerRandomReminder() },
            onSpawn: { [weak self] in self?.spawnPlaceholderPlane() },
            onSettings: { [weak self] in self?.toggleSettingsPanel() },
            onQuit: { NSApp.terminate(nil) }
        )

        // Optional one-flight workload for repeatable Instruments/top profiling.
        if CommandLine.arguments.contains("--preview-flight") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.spawnPlaceholderPlane()
            }
        }
    }

    func triggerRandomReminder() {
        dispatcher.fire(MockReminderCatalog.random())
    }

    func spawnPlaceholderPlane() {
        dispatcher.fire(MockReminderCatalog.placeholder())
    }

    func reloadAssets() {
        SpriteAssets.reloadFromDisk()
        screenManager.controllers.forEach { $0.reloadAssets() }
    }

    func toggleSettingsPanel() {
        if let win = settingsWindow, win.isVisible {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // Reuse a visible window; closing releases its UI resources.
        let win: NSWindow
        if let existing = settingsWindow {
            win = existing
        } else {
            win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 900, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .visible
            win.contentMinSize = NSSize(width: 760, height: 560)
            win.toolbarStyle = .unified
            let panel = SettingsPanelView()
                .environmentObject(AppSettings.shared)
            win.title = "Jurassic Air Settings"
            win.contentViewController = NSHostingController(rootView: panel)
            win.setContentSize(NSSize(width: 900, height: 680))
            win.isReleasedWhenClosed = false
            win.delegate = self
            settingsWindow = win
        }
        // Always re-center on the primary display each time the user opens
        // Settings, even if it was previously dragged to another monitor.
        centerOnPrimaryScreen(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        // Preferences and navigation are persisted; the hidden SwiftUI view tree
        // and its drawing surfaces need not live for the rest of the session.
        settingsWindow = nil
    }

    private func centerOnPrimaryScreen(_ window: NSWindow) {
        guard let screen = NSScreen.screens.first else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        window.setFrame(frame, display: true)
    }
}
