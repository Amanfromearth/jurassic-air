import Foundation

/// A user-defined reminder that fires at a scheduled time, optionally on repeat.
struct CustomReminder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var urlString: String
    /// The first (or only) time this reminder should fire.
    var firstFireAt: Date
    var repeatRule: RepeatRule
    var enabled: Bool = true
    /// Last time the scheduler actually fired this reminder. nil before first fire.
    var lastFiredAt: Date?
}

/// Repeat behavior. Codable enum with associated values — Swift synthesizes
/// Codable conformance for us.
enum RepeatRule: Codable, Hashable {
    case once
    case everySeconds(Int)
    case everyMinutes(Int)
    case hourly
    case daily
    case weekly

    /// Interval between fires, or nil for `.once`.
    var interval: TimeInterval? {
        switch self {
        case .once:                return nil
        case .everySeconds(let s): return TimeInterval(max(1, s))
        case .everyMinutes(let m): return TimeInterval(max(1, m) * 60)
        case .hourly:              return 3600
        case .daily:               return 86_400
        case .weekly:              return 86_400 * 7
        }
    }

    var label: String {
        switch self {
        case .once:                return "Once"
        case .everySeconds(let s): return "Every \(s) sec"
        case .everyMinutes(let m): return "Every \(m) min"
        case .hourly:              return "Hourly"
        case .daily:               return "Daily"
        case .weekly:              return "Weekly"
        }
    }
}

extension CustomReminder {
    /// Returns the next time this reminder should fire (≤ now means it's due NOW),
    /// or nil if it should never fire again (disabled, or one-time and already fired).
    ///
    /// For recurring rules the schedule is anchored to `firstFireAt`, not to
    /// `lastFiredAt`, so a "daily at 9 AM" reminder keeps firing at 9 AM each day
    /// even if the Mac was off for several days and lastFiredAt is stale.
    func nextDueDate(now: Date) -> Date? {
        guard enabled else { return nil }
        switch repeatRule {
        case .once:
            return lastFiredAt == nil ? firstFireAt : nil
        case .everySeconds, .everyMinutes, .hourly, .daily, .weekly:
            guard let interval = repeatRule.interval, interval > 0 else { return nil }
            // If never fired, the next due slot is firstFireAt itself.
            guard let last = lastFiredAt else { return firstFireAt }
            // If lastFiredAt somehow ended up before firstFireAt (clock skew or
            // imported data), treat firstFireAt as the next slot.
            if last < firstFireAt { return firstFireAt }
            // Step from firstFireAt by interval until strictly after lastFiredAt.
            let elapsed = last.timeIntervalSince(firstFireAt)
            let n = (elapsed / interval).rounded(.down) + 1
            // Defensive cap: if the Mac was off for years with a per-minute reminder,
            // skip ahead instead of iterating millions of steps.
            if n > 10_000_000 {
                let stepsToNow = (now.timeIntervalSince(firstFireAt) / interval).rounded(.up)
                return firstFireAt.addingTimeInterval(max(0, stepsToNow) * interval)
            }
            return firstFireAt.addingTimeInterval(n * interval)
        }
    }

    /// True if this reminder should fire at `now`.
    func isDue(at now: Date) -> Bool {
        guard let due = nextDueDate(now: now) else { return false }
        return now >= due
    }
}
