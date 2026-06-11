import AppKit
import Combine
import Foundation

/// Polls the calendar service every 60s (and on every store-change push), then
/// fires one plane per (event, offset) combination at the configured times.
///
/// Dedup: a persisted `[eventID:offsetMinutes -> Date]` map prevents a given
/// alert from firing twice — survives quit/restart so a meeting that already
/// got its 10-min ping never re-pings it. Old entries (>1 day) prune on each tick.
final class CalendarAlertScheduler {
    weak var dispatcher: ReminderDispatcher?
    private let service: CalendarService
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    /// NotificationCenter tokens installed by `start()`; tracked so `stop()`
    /// can deregister them. Without this every start()/stop() cycle leaks two
    /// observers and the next event would fire `tick()` multiple times.
    private var observerTokens: [NSObjectProtocol] = []
    private var firedKeys: [String: Date] = [:]
    private let firedKeysDefaultsKey = "calendar.firedAlerts.v1"
    private let tickInterval: TimeInterval = 60
    /// Tolerance for "now is past the fire time but not too late." A tick that
    /// lands a few seconds late still fires; one that lands minutes late (e.g.
    /// after wake-from-sleep) treats the alert as stale and skips it.
    private let lateness: TimeInterval = 90

    init(service: CalendarService) {
        self.service = service
        loadFiredKeys()
        service.didChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.tick() }
            .store(in: &cancellables)
    }

    func start() {
        stop()
        tick()
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        // Catch-up triggers for when the Timer was throttled or the Mac was asleep.
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        let active = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
        observerTokens = [wake, active]
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for token in observerTokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        observerTokens.removeAll()
    }

    deinit { stop() }

    // MARK: - Tick

    private func tick() {
        guard AppSettings.shared.calendarEnabled else { return }
        guard service.authorizationStatus == .fullAccess else { return }
        let offsets = AppSettings.shared.alertOffsetsMinutes
        let selected = AppSettings.shared.selectedCalendarIdentifiers
        guard !offsets.isEmpty, !selected.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let maxOffsetSeconds = TimeInterval((offsets.max() ?? 0) * 60)
            let horizon = maxOffsetSeconds + 120 // small safety margin
            let events = await self.service.upcomingEvents(
                within: horizon,
                selectedCalendarIdentifiers: selected
            )
            self.fireDueAlerts(events: events, offsets: offsets, now: Date())
            self.pruneAndPersist(now: Date())
        }
    }

    private func fireDueAlerts(events: [CalendarEvent], offsets: [Int], now: Date) {
        for event in events {
            for offset in offsets where offset >= 0 {
                let fireAt = event.startDate.addingTimeInterval(-TimeInterval(offset * 60))
                let key = "\(event.id):\(offset)"
                let inWindow = now >= fireAt && now < fireAt.addingTimeInterval(lateness)
                guard inWindow, firedKeys[key] == nil else { continue }
                fire(event: event, offsetMinutes: offset)
                firedKeys[key] = now
            }
        }
    }

    private func fire(event: CalendarEvent, offsetMinutes: Int) {
        let title: String
        switch offsetMinutes {
        case 0:  title = "\(event.title) — NOW"
        case 1:  title = "\(event.title) in 1 min"
        default: title = "\(event.title) in \(offsetMinutes) min"
        }
        let reminder = ReminderEvent(title: title, urlString: event.url?.absoluteString ?? "")
        dispatcher?.fire(reminder)
    }

    // MARK: - Dedup persistence

    private func pruneAndPersist(now: Date) {
        let cutoff = now.addingTimeInterval(-86_400) // 24h
        firedKeys = firedKeys.filter { $0.value >= cutoff }
        saveFiredKeys()
    }

    private func loadFiredKeys() {
        guard let data = UserDefaults.standard.data(forKey: firedKeysDefaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            firedKeys = decoded
        }
    }

    private func saveFiredKeys() {
        if let data = try? JSONEncoder().encode(firedKeys) {
            UserDefaults.standard.set(data, forKey: firedKeysDefaultsKey)
        }
    }
}
