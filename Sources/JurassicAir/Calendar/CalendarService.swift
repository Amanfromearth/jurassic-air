import Combine
import Foundation

/// Abstraction over a calendar data source. v1 ships only an EventKit
/// implementation (which transparently reads Google Calendar if the user has
/// added their Google account to Calendar.app). A `GoogleCalendarService`
/// could be slotted in later without touching `CalendarAlertScheduler` or the
/// settings UI.
protocol CalendarService: AnyObject {
    var authorizationStatus: CalendarAuthorizationStatus { get }
    func requestAccess() async -> Bool

    /// Events starting within `[now, now + horizon]`, filtered to
    /// `selectedCalendarIdentifiers`. All-day events are filtered out.
    func upcomingEvents(within horizon: TimeInterval,
                        selectedCalendarIdentifiers: Set<String>) async -> [CalendarEvent]

    func availableCalendars() async -> [CalendarMetadata]

    /// Fires when the underlying store changes (event added / edited / deleted).
    /// The scheduler subscribes so it can re-fetch immediately instead of
    /// waiting for the next polling tick.
    var didChange: AnyPublisher<Void, Never> { get }
}
