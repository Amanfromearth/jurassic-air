import XCTest
@testable import JurassicAir

/// Spot-checks on the canned reminder lists wired to the menu-bar "trigger
/// random" and "test meeting" actions.
final class MockReminderCatalogTests: XCTestCase {

    func testGeneralCatalogIsNonEmpty() {
        XCTAssertFalse(MockReminderCatalog.general.isEmpty)
    }

    func testMeetingCatalogIsNonEmpty() {
        XCTAssertFalse(MockReminderCatalog.meetings.isEmpty)
    }

    func testEveryCannedReminderHasATitle() {
        for r in MockReminderCatalog.general + MockReminderCatalog.meetings {
            XCTAssertFalse(r.title.isEmpty, "blank title in catalog")
        }
    }

    func testEveryCannedReminderHasAUrl() {
        for r in MockReminderCatalog.general + MockReminderCatalog.meetings {
            XCTAssertFalse(r.urlString.isEmpty, "blank URL in catalog")
        }
    }

    func testRandomReturnsSomethingFromGeneralCatalog() {
        for _ in 0..<50 {
            let pick = MockReminderCatalog.random()
            XCTAssertTrue(
                MockReminderCatalog.general.contains(where: { $0.title == pick.title })
                    || pick.title == MockReminderCatalog.placeholder().title,
                "random() returned something not from .general or the placeholder"
            )
        }
    }

    func testRandomMeetingReturnsSomethingFromMeetingsCatalog() {
        for _ in 0..<50 {
            let pick = MockReminderCatalog.randomMeeting()
            XCTAssertTrue(
                MockReminderCatalog.meetings.contains(where: { $0.title == pick.title })
                    || pick.title == MockReminderCatalog.placeholder().title
            )
        }
    }

    func testPlaceholderIsStable() {
        XCTAssertEqual(MockReminderCatalog.placeholder().title, "Hello, world!")
    }
}
