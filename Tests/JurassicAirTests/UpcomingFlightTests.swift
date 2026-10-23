import XCTest
@testable import JurassicAir

final class UpcomingFlightTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 12))!
    }

    func testRemindersExcludePausedAndCompletedAndSortByDueTime() {
        let reminders = [
            CustomReminder(title: "Later", urlString: "", firstFireAt: now.addingTimeInterval(600), repeatRule: .once),
            CustomReminder(title: "Next", urlString: "", firstFireAt: now.addingTimeInterval(300), repeatRule: .daily),
            CustomReminder(title: "Paused", urlString: "", firstFireAt: now, repeatRule: .daily, enabled: false),
            CustomReminder(title: "Done", urlString: "", firstFireAt: now, repeatRule: .once, lastFiredAt: now)
        ]
        XCTAssertEqual(UpcomingFlight.make(reminders: reminders, now: now).map(\.title), ["Next", "Later"])
    }

    func testTodayEventsUseMeetingTimesAndExcludeTomorrowPastAndAllDay() {
        let flights = UpcomingFlight.todayEvents([
            meeting(id: "later", start: 3600),
            meeting(id: "soon", start: 120),
            meeting(id: "past", start: -60),
            meeting(id: "tomorrow", start: 86_400),
            meeting(id: "all-day", start: 3600, allDay: true)
        ], now: now, calendar: calendar)
        XCTAssertEqual(flights.map(\.id), ["calendar:soon", "calendar:later"])
        XCTAssertEqual(flights.first?.date, now.addingTimeInterval(120))
        XCTAssertTrue(flights.allSatisfy(\.isMeeting))
    }

    func testTodayUsesLocalCalendarDayRatherThanNext24Hours() {
        var local = calendar
        local.timeZone = TimeZone(secondsFromGMT: 13 * 3600)!
        // At 01:00 local time, these UTC dates belong to different local days.
        let flights = UpcomingFlight.todayEvents([
            meeting(id: "today", start: 3600),
            meeting(id: "next-day", start: 23 * 3600)
        ], now: now, calendar: local)
        XCTAssertEqual(flights.map(\.id), ["calendar:today"])
    }

    private func meeting(id: String, start: TimeInterval, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: id, title: "Meeting", startDate: now.addingTimeInterval(start),
                      endDate: now.addingTimeInterval(start + 1800), url: nil,
                      calendarIdentifier: "work", calendarTitle: "Work", isAllDay: allDay)
    }
}
