import AppKit
import Combine

/// Cache upcoming meetings on store/settings changes and occasional refreshes;
/// fire known alerts from exact deadlines without fetching EventKit every minute.
final class CalendarAlertScheduler {
    weak var dispatcher: ReminderDispatcher?
    private let service: CalendarService
    private let settings: AppSettings
    private let defaults: UserDefaults
    private let now: () -> Date
    private let alert = DeadlineTimer()
    private let refreshDeadline = DeadlineTimer()
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private(set) var refreshTask: Task<Void, Never>?
    private var generation = 0
    private var events: [CalendarEvent] = []
    private var firedKeys: [String: Date] = [:]
    private let defaultsKey = "calendar.firedAlerts.v1"
    private let refreshInterval: TimeInterval = 15 * 60
    private let lateness: TimeInterval = 90
    private(set) var isRunning = false
    var nextAlertDate: Date? { alert.nextFireDate }
    var nextRefreshDate: Date? { refreshDeadline.nextFireDate }

    init(service: CalendarService, settings: AppSettings = .shared,
         defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.service = service
        self.settings = settings
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: Date].self, from: data) {
            firedKeys = saved
        }
    }

    func start() {
        stop()
        isRunning = true
        service.didChange
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] in self?.refresh() }
            .store(in: &subscriptions)
        settings.$calendarEnabled.combineLatest(settings.$selectedCalendarIdentifiers,
                                                settings.$alertOffsetsMinutes)
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.alert.cancel()
                self?.events.removeAll()
                self?.refresh()
            }
            .store(in: &subscriptions)
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() })
        for name in [NSApplication.didBecomeActiveNotification,
                     Notification.Name.NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in self?.refresh() })
        }
        refresh()
    }

    func stop() {
        isRunning = false
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        alert.cancel()
        refreshDeadline.cancel()
        events.removeAll()
        subscriptions.removeAll()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    private var canSchedule: Bool {
        settings.calendarEnabled && service.authorizationStatus == .fullAccess
            && !settings.selectedCalendarIdentifiers.isEmpty
            && settings.alertOffsetsMinutes.contains { $0 >= 0 }
    }

    func refresh() {
        guard isRunning else { return }
        generation += 1
        refreshTask?.cancel()
        guard canSchedule else {
            events.removeAll()
            alert.cancel()
            refreshDeadline.cancel()
            refreshTask = nil
            return
        }
        let request = generation
        let selected = settings.selectedCalendarIdentifiers
        let offsets = settings.alertOffsetsMinutes
        let horizon = TimeInterval(max(0, offsets.max() ?? 0) * 60) + 86_400
        let service = self.service
        refreshTask = Task { @MainActor [weak self] in
            let upcoming = await service.upcomingEvents(within: horizon,
                                                       selectedCalendarIdentifiers: selected)
            guard let self, !Task.isCancelled, self.isRunning,
                  self.generation == request, self.canSchedule,
                  self.settings.selectedCalendarIdentifiers == selected,
                  self.settings.alertOffsetsMinutes == offsets else { return }
            self.events = upcoming
            self.processAlerts()
            self.refreshDeadline.schedule(at: self.now().addingTimeInterval(self.refreshInterval),
                                          tolerance: 60, keepsAppResponsive: false) { [weak self] in
                self?.refresh()
            }
            self.refreshTask = nil
        }
    }

    private func processAlerts() {
        guard isRunning, canSchedule else { alert.cancel(); return }
        let date = now()
        var changed = false
        var next: Date?
        for event in events {
            for offset in settings.alertOffsetsMinutes where offset >= 0 {
                let fireAt = event.startDate.addingTimeInterval(-TimeInterval(offset * 60))
                let key = "\(event.id):\(offset)"
                guard firedKeys[key] == nil else { continue }
                if date >= fireAt && date < fireAt.addingTimeInterval(lateness) {
                    let timing = offset == 0 ? "Starting now" : "Starts in \(offset) min"
                    let title = "\(event.title)\n\(timing)"
                    dispatcher?.fire(ReminderEvent(title: title, urlString: event.url?.absoluteString ?? ""))
                    firedKeys[key] = date
                    changed = true
                } else if fireAt > date {
                    next = min(next ?? fireAt, fireAt)
                }
            }
        }
        let cutoff = date.addingTimeInterval(-86_400)
        let count = firedKeys.count
        firedKeys = firedKeys.filter { $0.value >= cutoff }
        if changed || count != firedKeys.count,
           let data = try? JSONEncoder().encode(firedKeys) {
            defaults.set(data, forKey: defaultsKey)
        }
        alert.schedule(at: next) { [weak self] in self?.processAlerts() }
    }

    deinit { stop() }
}
