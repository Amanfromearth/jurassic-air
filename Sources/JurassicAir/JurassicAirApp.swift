import AppKit
import SwiftUI

@main
struct JurassicAirApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Settings…") { AppDelegate.shared?.toggleSettingsPanel() }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
