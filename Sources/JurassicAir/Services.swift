/// Process-wide service singletons. Centralizing them here avoids fragile
/// lookups like `(NSApp.delegate as? AppDelegate)?.foo` from view code —
/// which returns nil under SwiftUI's `@NSApplicationDelegateAdaptor` on
/// recent macOS, even after the delegate has finished launching.
enum Services {
    static let calendar: CalendarService = EventKitCalendarService()
}
