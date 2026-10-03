import AppKit
import Foundation

/// Source-agnostic representation of a calendar event. EventKit-specific types
/// (EKEvent / EKCalendar) live behind `CalendarService` so a Google API
/// implementation can be added later without touching the scheduler or UI.
struct CalendarEvent: Identifiable, Hashable {
    /// EKEvent.eventIdentifier — unique per occurrence (each instance of a
    /// recurring event gets its own identifier), which is what the alert
    /// scheduler needs for correct dedup.
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let url: URL?
    let calendarIdentifier: String
    let calendarTitle: String
    let isAllDay: Bool
}

struct CalendarMetadata: Identifiable, Hashable {
    let id: String              // EKCalendar.calendarIdentifier
    let title: String           // "Work", "Personal"
    let sourceTitle: String     // "Google", "iCloud" — disambiguates same-named calendars
    let color: NSColor          // for the UI swatch

    /// "Personal (Google)" — used as the visible row label in settings.
    var displayName: String { "\(title) (\(sourceTitle))" }
}

enum CalendarAuthorizationStatus {
    case notDetermined, denied, restricted, fullAccess
}
