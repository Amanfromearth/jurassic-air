import XCTest
import Combine
@testable import JurassicAir

@MainActor
final class CalendarSchedulingTests: XCTestCase {
    private final class Service: CalendarService {
        var authorizationStatus: CalendarAuthorizationStatus = .fullAccess
        let changes = PassthroughSubject<Void, Never>()
        var didChange: AnyPublisher<Void, Never> { changes.eraseToAnyPublisher() }
        var events: [CalendarEvent] = []
        var queries = 0
        var onQuery: (() -> Void)?
        var suspend = false
        var continuation: CheckedContinuation<[CalendarEvent], Never>?
        func requestAccess() async -> Bool { true }
        func availableCalendars() async -> [CalendarMetadata] { [] }
        func upcomingEvents(within: TimeInterval, selectedCalendarIdentifiers: Set<String>) async -> [CalendarEvent] {
            queries += 1
            onQuery?()
            if suspend { return await withCheckedContinuation { continuation = $0 } }
            return events
        }
    }
    private func event(at date: Date) -> CalendarEvent {
        CalendarEvent(id: "event", title: "Meeting", startDate: date,
                      endDate: date.addingTimeInterval(1800), url: nil,
                      calendarIdentifier: "work", calendarTitle: "Work", isAllDay: false)
    }
    private func context() -> (UserDefaults, AppSettings, Service) {
        let defaults = UserDefaults(suiteName: "CalendarSchedulingTests.\(UUID())")!
        let settings = AppSettings(defaults: defaults)
        settings.calendarEnabled = true
        settings.selectedCalendarIdentifiers = ["work"]
        settings.alertOffsetsMinutes = [5, 0]
        return (defaults, settings, Service())
    }

    func testDisabledCalendarPerformsNoQueriesAndSchedulesNothing() async {
        let (defaults, settings, service) = context()
        settings.calendarEnabled = false
        let scheduler = CalendarAlertScheduler(service: service, settings: settings, defaults: defaults)
        scheduler.start()
        defer { scheduler.stop() }
        XCTAssertEqual(service.queries, 0)
        XCTAssertNil(scheduler.nextAlertDate)
        XCTAssertNil(scheduler.nextRefreshDate)
    }
    func testKnownMeetingUsesExactAlertAndInfrequentRefresh() async {
        let (defaults, settings, service) = context()
        let now = Date()
        service.events = [event(at: now.addingTimeInterval(600))]
        let scheduler = CalendarAlertScheduler(service: service, settings: settings, defaults: defaults, now: { now })
        scheduler.start()
        await scheduler.refreshTask?.value
        defer { scheduler.stop() }
        XCTAssertEqual(service.queries, 1)
        XCTAssertEqual(scheduler.nextAlertDate, now.addingTimeInterval(300))
        XCTAssertEqual(scheduler.nextRefreshDate, now.addingTimeInterval(900))
    }
    func testEmptyCalendarHasNoPreciseAlertDeadline() async {
        let (defaults, settings, service) = context()
        let scheduler = CalendarAlertScheduler(service: service, settings: settings, defaults: defaults)
        scheduler.start()
        await scheduler.refreshTask?.value
        defer { scheduler.stop() }
        XCTAssertNil(scheduler.nextAlertDate)
        XCTAssertNotNil(scheduler.nextRefreshDate)
    }
    func testMeetingDedupPersistsOnlyWhenAlertsActuallyChange() async {
        let (defaults, settings, service) = context()
        settings.alertOffsetsMinutes = [0]
        let now = Date()
        service.events = [event(at: now)]
        let scheduler = CalendarAlertScheduler(service: service, settings: settings, defaults: defaults, now: { now })
        scheduler.start()
        await scheduler.refreshTask?.value
        let saved = defaults.data(forKey: "calendar.firedAlerts.v1")
        XCTAssertNotNil(saved)
        scheduler.refresh()
        await scheduler.refreshTask?.value
        XCTAssertEqual(defaults.data(forKey: "calendar.firedAlerts.v1"), saved)
        XCTAssertNil(scheduler.nextAlertDate)
        scheduler.stop()
    }
    func testStoppedSchedulerDiscardsAnInFlightQuery() async {
        let (defaults, settings, service) = context()
        service.suspend = true
        let scheduler = CalendarAlertScheduler(service: service, settings: settings, defaults: defaults)
        scheduler.start()
        let task = scheduler.refreshTask
        let started = expectation(description: "Query started")
        service.onQuery = { started.fulfill() }
        await fulfillment(of: [started], timeout: 1)
        scheduler.stop()
        service.continuation?.resume(returning: [event(at: Date().addingTimeInterval(600))])
        await task?.value
        XCTAssertNil(scheduler.nextAlertDate)
        XCTAssertNil(scheduler.nextRefreshDate)
        XCTAssertNil(defaults.data(forKey: "calendar.firedAlerts.v1"))
    }
}
