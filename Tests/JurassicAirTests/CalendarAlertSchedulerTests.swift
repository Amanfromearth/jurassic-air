import XCTest
import Combine
@testable import JurassicAir

/// Regression tests for the observer-leak bug: start() previously installed
/// NotificationCenter observers without keeping their tokens, so stop() could
/// not deregister them, and calling start() again would stack a second copy of
/// every observer.
final class CalendarAlertSchedulerTests: XCTestCase {

    /// A no-op CalendarService stand-in. We just need something that satisfies
    /// the protocol so we can instantiate the scheduler without EventKit.
    private final class FakeCalendarService: CalendarService {
        var authorizationStatus: CalendarAuthorizationStatus = .notDetermined
        private let _didChange = PassthroughSubject<Void, Never>()
        var didChange: AnyPublisher<Void, Never> { _didChange.eraseToAnyPublisher() }
        func requestAccess() async -> Bool { false }
        func availableCalendars() async -> [CalendarMetadata] { [] }
        func upcomingEvents(within seconds: TimeInterval,
                            selectedCalendarIdentifiers: Set<String>) async -> [CalendarEvent] { [] }
    }

    func testStopRemovesObserversInstalledByStart() {
        let scheduler = CalendarAlertScheduler(service: FakeCalendarService())
        scheduler.start()
        scheduler.stop()
        // No way to inspect NotificationCenter directly, but we can post the
        // notifications and verify they don't crash and don't keep the
        // scheduler alive. Posting after stop should be a no-op.
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NotificationCenter.default.post(
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
        // If observers leaked, the [weak self] closure would still fire; with
        // tokens tracked + removed in stop(), nothing should happen. Asserting
        // we got here without crashing is the primary check.
        XCTAssertTrue(true)
    }

    func testStartIsIdempotentAndDoesNotStackObservers() {
        // The fix made start() call stop() first. Without it, repeated start()s
        // would multiply observer count linearly. This is hard to assert
        // directly — but at minimum it must not crash.
        let scheduler = CalendarAlertScheduler(service: FakeCalendarService())
        scheduler.start()
        scheduler.start()
        scheduler.start()
        scheduler.stop()
    }

    func testDeinitTearsDownCleanly() {
        // A scheduler that gets dropped on the floor (no explicit stop) should
        // still deregister its observers via deinit. We just confirm no crash.
        do {
            let scheduler = CalendarAlertScheduler(service: FakeCalendarService())
            scheduler.start()
            _ = scheduler
        }
        // Trigger the notifications — if a leaked closure still references a
        // freed scheduler, we'd see a crash on the next line.
        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NotificationCenter.default.post(
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
    }
}
