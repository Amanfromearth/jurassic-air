import AppKit
import Combine
import EventKit
import Foundation

final class EventKitCalendarService: CalendarService {
    private let store = EKEventStore()
    private let changeSubject = PassthroughSubject<Void, Never>()
    var didChange: AnyPublisher<Void, Never> { changeSubject.eraseToAnyPublisher() }

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: store
        )
    }

    @objc private func storeChanged() {
        changeSubject.send(())
    }

    var authorizationStatus: CalendarAuthorizationStatus {
        let raw = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            switch raw {
            case .notDetermined: return .notDetermined
            case .denied:        return .denied
            case .restricted:    return .restricted
            case .fullAccess:    return .fullAccess
            case .writeOnly:     return .denied // we need read; treat as denied for our purposes
            case .authorized:    return .fullAccess // legacy
            @unknown default:    return .notDetermined
            }
        }
        switch raw {
        case .notDetermined: return .notDetermined
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .authorized:    return .fullAccess
        // .fullAccess / .writeOnly are macOS 14+; not reachable on macOS 13
        // (handled by the @available branch above) but exhaustiveness requires them.
        default:             return .notDetermined
        }
    }

    func requestAccess() async -> Bool {
        Log.write("requestAccess called; status=\(authorizationStatus); bundleID=\(Bundle.main.bundleIdentifier ?? "<nil>")")
        if #available(macOS 14.0, *) {
            do {
                let granted = try await store.requestFullAccessToEvents()
                Log.write("requestFullAccessToEvents returned granted=\(granted)")
                return granted
            } catch {
                Log.write("requestFullAccessToEvents threw: \(error)")
                return false
            }
        }
        return await withCheckedContinuation { cont in
            store.requestAccess(to: .event) { granted, err in
                if let err {
                    Log.write("legacy requestAccess error: \(err)")
                }
                cont.resume(returning: granted)
            }
        }
    }

    func availableCalendars() async -> [CalendarMetadata] {
        guard authorizationStatus == .fullAccess else { return [] }
        return store.calendars(for: .event).map { cal in
            CalendarMetadata(
                id: cal.calendarIdentifier,
                title: cal.title,
                sourceTitle: cal.source?.title ?? "Unknown",
                color: NSColor(cgColor: cal.cgColor) ?? .systemBlue
            )
        }
    }

    func upcomingEvents(
        within horizon: TimeInterval,
        selectedCalendarIdentifiers: Set<String>
    ) async -> [CalendarEvent] {
        guard authorizationStatus == .fullAccess else { return [] }
        let calendars = store.calendars(for: .event)
            .filter { selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let now = Date()
        let pred = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(horizon),
            calendars: calendars
        )
        return store.events(matching: pred)
            .filter { !$0.isAllDay && $0.startDate > now.addingTimeInterval(-90) }
            .map(Self.normalize)
    }

    // MARK: - Normalization + URL extraction

    private static func normalize(_ ek: EKEvent) -> CalendarEvent {
        let url = ek.url
            ?? extractMeetingURL(from: ek.location)
            ?? extractMeetingURL(from: ek.notes)
        return CalendarEvent(
            id: ek.eventIdentifier,
            title: ek.title ?? "(no title)",
            startDate: ek.startDate,
            endDate: ek.endDate,
            url: url,
            calendarIdentifier: ek.calendar.calendarIdentifier,
            calendarTitle: ek.calendar.title,
            isAllDay: ek.isAllDay
        )
    }

    /// Look for a meeting URL anywhere in `text`. Prefers well-known providers
    /// over arbitrary http URLs so a Zoom link in the notes beats an attendee's
    /// LinkedIn URL pasted nearby.
    /// Building an NSDataDetector compiles its patterns, so build it one time.
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    private static func extractMeetingURL(from text: String?) -> URL? {
        guard let text, !text.isEmpty else { return nil }
        let matches = linkDetector?.matches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        ) ?? []
        let urls = matches.compactMap { $0.url }
        let preferredHosts = ["zoom.us", "meet.google.com", "teams.microsoft.com", "webex.com"]
        for host in preferredHosts {
            if let match = urls.first(where: { ($0.host ?? "").contains(host) }) {
                return match
            }
        }
        return urls.first
    }
}
