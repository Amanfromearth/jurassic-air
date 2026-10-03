import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
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
    /// Retained activity token that disables App Nap. Without this, macOS will
    /// throttle our polling Timer when the app has been idle in the menu bar
    /// (no windows, no recent user interaction), which made reminders only fire
    /// when the user happened to click the menu bar icon.
    private var antiNapActivity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.shared = self
        NSApp.setActivationPolicy(.accessory)

        // Keep the run loop and timers alive in the background. .userInitiated
        // opts out of App Nap; .latencyCritical disables timer coalescing so the
        // 15 s tick doesn't get lumped into multi-minute batches by the system.
        antiNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Jurassic Air fires scheduled reminders on time"
        )

        SpriteAssets.registerPixelFont()

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
            win.orderOut(nil)
            return
        }
        // Reuse the existing window AND hosting controller across close/reopen
        // so the selected sidebar tab + appearance sub-tab survive. Only on
        // first open do we build the SwiftUI view tree.
        let win: NSWindow
        if let existing = settingsWindow {
            win = existing
        } else {
            win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 940, height: 720),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            let panel = SettingsPanelView()
                .environmentObject(AppSettings.shared)
            win.title = "Jurassic Air Settings"
            win.contentViewController = NSHostingController(rootView: panel)
            win.isReleasedWhenClosed = false
            settingsWindow = win
        }
        // Always re-center on the primary display each time the user opens
        // Settings, even if it was previously dragged to another monitor.
        centerOnPrimaryScreen(win)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
