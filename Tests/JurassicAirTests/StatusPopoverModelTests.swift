import Combine
import XCTest
@testable import JurassicAir

@MainActor
final class StatusPopoverModelTests: XCTestCase {
    private final class Service: CalendarService {
        var authorizationStatus: CalendarAuthorizationStatus = .fullAccess
        var didChange: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
        var queries = 0
        var suspend = false
        var continuation: CheckedContinuation<[CalendarEvent], Never>?
        var events: [CalendarEvent] = []
        func requestAccess() async -> Bool { true }
        func availableCalendars() async -> [CalendarMetadata] { [] }
        func upcomingEvents(within: TimeInterval, selectedCalendarIdentifiers: Set<String>) async -> [CalendarEvent] {
            queries += 1
            if suspend { return await withCheckedContinuation { continuation = $0 } }
            return events
        }
    }

    func testRepeatedOpeningUsesWarmCalendarAndStopsClockWhenClosed() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.calendarEnabled = true
        settings.selectedCalendarIdentifiers = ["work"]
        let service = Service()
        let model = StatusPopoverModel(service: service, settings: settings)
        model.start()
        await model.refreshTask?.value
        XCTAssertEqual(service.queries, 1)
        for _ in 0..<20 {
            model.setPresented(true)
            XCTAssertNotNil(model.nextTickDate)
            model.setPresented(false)
            XCTAssertNil(model.nextTickDate)
        }
        XCTAssertEqual(service.queries, 1, "Warm opens must not fetch the calendar again")
    }

    func testRefreshKeepsCachedEventsVisibleAndRejectsDisabledCalendarResult() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = AppSettings(defaults: defaults)
        settings.calendarEnabled = true
        settings.selectedCalendarIdentifiers = ["work"]
        let service = Service()
        service.events = [CalendarEvent(id: "meeting", title: "Standup", startDate: Date(),
                                       endDate: Date(), url: nil, calendarIdentifier: "work",
                                       calendarTitle: "Work", isAllDay: false)]
        let model = StatusPopoverModel(service: service, settings: settings)
        model.start()
        await model.refreshTask?.value
        service.suspend = true
        model.refresh(force: true)
        let pending = model.refreshTask
        while service.continuation == nil { await Task.yield() }
        XCTAssertEqual(model.events.count, 1, "Refresh must not blank the cached list")
        settings.calendarEnabled = false
        model.refresh(force: true)
        service.continuation?.resume(returning: service.events)
        await pending?.value
        XCTAssertTrue(model.events.isEmpty)
        XCTAssertFalse(model.canShowCalendar)
    }
}
