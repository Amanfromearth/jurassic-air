import XCTest
@testable import JurassicAir

final class CustomReminderFormTests: XCTestCase {

    func testEmptyURLStaysEmpty() {
        XCTAssertEqual(CustomReminderFormView.normalizedURLString("   "), "")
    }

    func testBareHostGetsHTTPS() {
        XCTAssertEqual(CustomReminderFormView.normalizedURLString("zoom.us/j/123"), "https://zoom.us/j/123")
    }

    func testExistingSchemesAreKept() {
        XCTAssertEqual(CustomReminderFormView.normalizedURLString("https://example.com"), "https://example.com")
        XCTAssertEqual(CustomReminderFormView.normalizedURLString("imessage://"), "imessage://")
    }

    func testWhitespaceIsTrimmed() {
        XCTAssertEqual(CustomReminderFormView.normalizedURLString("  https://a.b  \n"), "https://a.b")
    }
}
