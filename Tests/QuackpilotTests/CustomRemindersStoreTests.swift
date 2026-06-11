import XCTest
@testable import Quackpilot

final class CustomRemindersStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "quackpilot.store.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func sampleReminder(_ title: String = "Drink water") -> CustomReminder {
        CustomReminder(
            title: title,
            urlString: "https://example.com",
            firstFireAt: Date(timeIntervalSince1970: 1_768_521_600),
            repeatRule: .hourly
        )
    }

    func testFreshStoreIsEmpty() {
        let store = CustomRemindersStore(defaults: defaults)
        XCTAssertTrue(store.reminders.isEmpty)
    }

    func testAddAppendsReminder() {
        let store = CustomRemindersStore(defaults: defaults)
        let r = sampleReminder()
        store.add(r)
        XCTAssertEqual(store.reminders.count, 1)
        XCTAssertEqual(store.reminders.first?.id, r.id)
    }

    func testAddPersistsAcrossRecreate() {
        do {
            let store = CustomRemindersStore(defaults: defaults)
            store.add(sampleReminder("first"))
            store.add(sampleReminder("second"))
        }
        let reloaded = CustomRemindersStore(defaults: defaults)
        XCTAssertEqual(reloaded.reminders.map(\.title), ["first", "second"])
    }

    func testUpdateReplacesMatchingId() {
        let store = CustomRemindersStore(defaults: defaults)
        var r = sampleReminder("orig")
        store.add(r)
        r.title = "edited"
        store.update(r)
        XCTAssertEqual(store.reminders.first?.title, "edited")
    }

    func testUpdateIgnoresUnknownId() {
        let store = CustomRemindersStore(defaults: defaults)
        store.add(sampleReminder("kept"))
        let unknown = sampleReminder("never-added")
        store.update(unknown)
        XCTAssertEqual(store.reminders.count, 1)
        XCTAssertEqual(store.reminders.first?.title, "kept")
    }

    func testDeleteRemovesById() {
        let store = CustomRemindersStore(defaults: defaults)
        let r1 = sampleReminder("a")
        let r2 = sampleReminder("b")
        store.add(r1)
        store.add(r2)
        store.delete(id: r1.id)
        XCTAssertEqual(store.reminders.map(\.title), ["b"])
    }

    func testSetEnabledTogglesFlag() {
        let store = CustomRemindersStore(defaults: defaults)
        let r = sampleReminder()
        store.add(r)
        XCTAssertTrue(store.reminders.first?.enabled ?? false)
        store.setEnabled(id: r.id, false)
        XCTAssertFalse(store.reminders.first?.enabled ?? true)
        store.setEnabled(id: r.id, true)
        XCTAssertTrue(store.reminders.first?.enabled ?? false)
    }

    func testMarkFiredUpdatesLastFiredAt() {
        let store = CustomRemindersStore(defaults: defaults)
        let r = sampleReminder()
        store.add(r)
        let fireTime = Date()
        store.markFired(id: r.id, at: fireTime)
        XCTAssertEqual(store.reminders.first?.lastFiredAt, fireTime)
    }

    func testDeletingFromEmptyStoreIsNoOp() {
        let store = CustomRemindersStore(defaults: defaults)
        store.delete(id: UUID())
        XCTAssertTrue(store.reminders.isEmpty)
    }
}
