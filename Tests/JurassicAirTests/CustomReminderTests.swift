import XCTest
@testable import JurassicAir

/// Reminder timing math — every RepeatRule case, edge cases for sleep,
/// disabled reminders, ahead-of-time fires, and the defensive million-step
/// cap that protects against a per-second reminder + years of uptime gap.
final class CustomReminderTests: XCTestCase {

    /// A baseline date for deterministic tests — 2026-01-15 12:00:00 UTC.
    private let t0 = Date(timeIntervalSince1970: 1_768_521_600)

    private func make(
        rule: RepeatRule,
        firstFireAt: Date,
        lastFiredAt: Date? = nil,
        enabled: Bool = true,
        title: String = "Test"
    ) -> CustomReminder {
        var r = CustomReminder(
            title: title,
            urlString: "https://example.com",
            firstFireAt: firstFireAt,
            repeatRule: rule
        )
        r.lastFiredAt = lastFiredAt
        r.enabled = enabled
        return r
    }

    // MARK: - .once

    func testOnceNeverFiredReturnsFirstFireAtAsDue() {
        let r = make(rule: .once, firstFireAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(60)), t0)
        XCTAssertTrue(r.isDue(at: t0.addingTimeInterval(60)))
    }

    func testOnceNotYetReachedIsNotDue() {
        let r = make(rule: .once, firstFireAt: t0)
        XCTAssertFalse(r.isDue(at: t0.addingTimeInterval(-1)))
    }

    func testOnceAlreadyFiredHasNoNextDue() {
        let r = make(rule: .once, firstFireAt: t0, lastFiredAt: t0)
        XCTAssertNil(r.nextDueDate(now: t0.addingTimeInterval(60)))
        XCTAssertFalse(r.isDue(at: t0.addingTimeInterval(60)))
    }

    // MARK: - .everySeconds

    func testEverySecondsNeverFiredReturnsFirstFireAt() {
        let r = make(rule: .everySeconds(5), firstFireAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0), t0)
    }

    func testEverySecondsStepsForwardByInterval() {
        let r = make(rule: .everySeconds(5), firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(3)),
                       t0.addingTimeInterval(5))
    }

    func testEverySecondsClampsToOneSecondMinimum() {
        // 0-second interval would divide-by-zero in the math; the code coerces
        // to a 1-second minimum.
        let r = make(rule: .everySeconds(0), firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(0.5)),
                       t0.addingTimeInterval(1))
    }

    // MARK: - .everyMinutes / .hourly / .daily / .weekly

    func testEveryMinutesIntervalMath() {
        let r = make(rule: .everyMinutes(15), firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(60)),
                       t0.addingTimeInterval(15 * 60))
    }

    func testHourlyJumpsByOneHour() {
        let r = make(rule: .hourly, firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(1)),
                       t0.addingTimeInterval(3600))
    }

    func testDailyJumpsByOneDay() {
        let r = make(rule: .daily, firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(1)),
                       t0.addingTimeInterval(86_400))
    }

    func testWeeklyJumpsBySevenDays() {
        let r = make(rule: .weekly, firstFireAt: t0, lastFiredAt: t0)
        XCTAssertEqual(r.nextDueDate(now: t0.addingTimeInterval(1)),
                       t0.addingTimeInterval(86_400 * 7))
    }

    // MARK: - Edge: lastFiredAt before firstFireAt

    func testLastFiredAtBeforeFirstFireAtFallsBackToFirstFireAt() {
        // Clock skew / imported data scenario: lastFiredAt < firstFireAt should
        // be treated as "never fired yet from the schedule's perspective."
        let r = make(rule: .hourly, firstFireAt: t0, lastFiredAt: t0.addingTimeInterval(-1000))
        XCTAssertEqual(r.nextDueDate(now: t0), t0)
    }

    // MARK: - Defensive cap (sleep for years with sub-minute reminder)

    func testMillionStepCapJumpsToNowInsteadOfIterating() {
        // For the cap to trigger we need n = (lastFired - firstFireAt) / interval > 10M.
        // Construct that exactly: 1-second interval, lastFiredAt 1000 days past
        // firstFireAt → elapsed = 86.4M seconds → n ≈ 86.4M > 10M → fast path.
        let interval = 1.0
        let elapsedDays = 1000.0
        let elapsedSeconds = elapsedDays * 86_400
        let lastFired = t0.addingTimeInterval(elapsedSeconds)
        let now = lastFired.addingTimeInterval(60)
        let r = make(
            rule: .everySeconds(Int(interval)),
            firstFireAt: t0,
            lastFiredAt: lastFired
        )
        let next = r.nextDueDate(now: now)
        XCTAssertNotNil(next)
        // The fast path returns firstFireAt + ceil((now - firstFireAt)/interval)*interval,
        // which for integer-aligned now is just `now` itself.
        XCTAssertEqual(next!.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate,
                       accuracy: 1.0,
                       "fast-path next-due should be near `now`, not a date requiring 86.4M loop iterations")
    }

    func testMillionStepCapDoesNotApplyToReasonableIntervals() {
        // Hourly reminder, 1 year of uptime gap = 8760 steps. Well below cap.
        let lastFired = t0
        let now = t0.addingTimeInterval(365 * 86_400)
        let r = make(rule: .hourly, firstFireAt: t0, lastFiredAt: lastFired)
        let next = r.nextDueDate(now: now)
        XCTAssertNotNil(next)
    }

    // MARK: - Disabled

    func testDisabledReminderIsNeverDue() {
        let r = make(rule: .daily, firstFireAt: t0, enabled: false)
        XCTAssertNil(r.nextDueDate(now: t0.addingTimeInterval(86_400)))
        XCTAssertFalse(r.isDue(at: t0.addingTimeInterval(86_400)))
    }

    // MARK: - RepeatRule labels (UI surface)

    func testRepeatRuleLabelsAreUserFacing() {
        XCTAssertEqual(RepeatRule.once.label, "Once")
        XCTAssertEqual(RepeatRule.everySeconds(15).label, "Every 15 sec")
        XCTAssertEqual(RepeatRule.everyMinutes(5).label, "Every 5 min")
        XCTAssertEqual(RepeatRule.hourly.label, "Hourly")
        XCTAssertEqual(RepeatRule.daily.label, "Daily")
        XCTAssertEqual(RepeatRule.weekly.label, "Weekly")
    }

    // MARK: - Codable round-trip

    func testCodableSurvivesJSONRoundTrip() throws {
        let original = CustomReminder(
            title: "Pixel",
            urlString: "https://pix.el",
            firstFireAt: t0,
            repeatRule: .everyMinutes(7)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CustomReminder.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.urlString, original.urlString)
        XCTAssertEqual(decoded.firstFireAt, original.firstFireAt)
        XCTAssertEqual(decoded.repeatRule, original.repeatRule)
        XCTAssertEqual(decoded.enabled, original.enabled)
    }
}
