import XCTest
import AppKit
@testable import JurassicAir

final class ReminderSchedulerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: CustomRemindersStore!
    private var date: Date!
    private var scheduler: ReminderScheduler!

    override func setUp() {
        defaults = UserDefaults(suiteName: "ReminderSchedulerTests.\(UUID())")!
        store = CustomRemindersStore(defaults: defaults)
        date = Date(timeIntervalSince1970: 1_800_000_000)
        scheduler = ReminderScheduler(store: store, now: { [unowned self] in self.date })
    }
    override func tearDown() { scheduler.stop(); scheduler = nil; store = nil; defaults = nil }
    private func reminder(_ offset: TimeInterval, rule: RepeatRule = .once, enabled: Bool = true) -> CustomReminder {
        CustomReminder(title: "Test", urlString: "", firstFireAt: date.addingTimeInterval(offset),
                       repeatRule: rule, enabled: enabled)
    }

    func testEmptyOrDisabledRemindersDoNotArmATimer() {
        scheduler.start()
        XCTAssertNil(scheduler.nextFireDate)
        store.add(reminder(60, enabled: false))
        XCTAssertNil(scheduler.nextFireDate)
    }
    func testOneDeadlineTracksEarliestReminderAndLiveEdits() {
        let later = reminder(300)
        let earlier = reminder(60)
        store.add(later)
        scheduler.start()
        XCTAssertEqual(scheduler.nextFireDate, later.firstFireAt)
        store.add(earlier)
        XCTAssertEqual(scheduler.nextFireDate, earlier.firstFireAt)
        store.setEnabled(id: earlier.id, false)
        XCTAssertEqual(scheduler.nextFireDate, later.firstFireAt)
        store.delete(id: later.id)
        XCTAssertNil(scheduler.nextFireDate)
    }
    func testDueOneShotFiresOnceAndReleasesDeadline() {
        store.add(reminder(-5))
        scheduler.start()
        XCTAssertEqual(store.reminders[0].lastFiredAt, date)
        XCTAssertNil(scheduler.nextFireDate)
        date = date.addingTimeInterval(10)
        scheduler.processDueReminders()
        XCTAssertNotEqual(store.reminders[0].lastFiredAt, date)
    }
    func testWakeCatchesUpOnceAndPreservesRecurringSchedule() {
        store.add(reminder(10, rule: .everySeconds(5)))
        let anchor = store.reminders[0].firstFireAt
        scheduler.start()
        date = date.addingTimeInterval(24)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertEqual(store.reminders[0].lastFiredAt, date)
        XCTAssertEqual(scheduler.nextFireDate, anchor.addingTimeInterval(15))
    }
    func testStoppedSchedulerIgnoresWakeAndEdits() {
        scheduler.start()
        scheduler.stop()
        store.add(reminder(-5))
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertNil(store.reminders[0].lastFiredAt)
        XCTAssertNil(scheduler.nextFireDate)
    }
}
