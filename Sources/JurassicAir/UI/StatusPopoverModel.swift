import AppKit
import Combine

/// Keeps the small menu panel ready between clicks. Calendar snapshots survive
/// dismissal, while the clock only ticks when the panel is visible.
final class StatusPopoverModel: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var now: Date
    @Published private(set) var isPresented = false
    @Published private(set) var canShowCalendar = false
    @Published private(set) var isRefreshing = false

    private let service: CalendarService
    private let settings: AppSettings
    private let clock: () -> Date
    private let tick = DeadlineTimer()
    private var subscriptions = Set<AnyCancellable>()
    private var lastRefresh: Date?
    private var generation = 0
    private(set) var refreshTask: Task<Void, Never>?
    var nextTickDate: Date? { tick.nextFireDate }

    init(service: CalendarService = Services.calendar, settings: AppSettings = .shared,
         clock: @escaping () -> Date = Date.init) {
        self.service = service
        self.settings = settings
        self.clock = clock
        self.now = clock()
    }

    func start() {
        guard subscriptions.isEmpty else { return }
        settings.$calendarEnabled.combineLatest(settings.$selectedCalendarIdentifiers)
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.events = []
                self?.refresh(force: true)
            }.store(in: &subscriptions)
        service.didChange
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] in self?.refresh(force: true) }
            .store(in: &subscriptions)
        refresh(force: true)
    }

    func setPresented(_ presented: Bool) {
        isPresented = presented
        tick.cancel()
        guard presented else { return }
        now = clock()
        scheduleTick()
        refresh()
    }

    /// Opening an already warm panel does no calendar I/O. Stale snapshots stay
    /// visible while an asynchronous refresh completes.
    func refresh(force: Bool = false) {
        let allowed = settings.calendarEnabled && service.authorizationStatus == .fullAccess
            && !settings.selectedCalendarIdentifiers.isEmpty
        if canShowCalendar != allowed { canShowCalendar = allowed }
        guard allowed else {
            generation += 1
            refreshTask?.cancel()
            refreshTask = nil
            lastRefresh = nil
            if !events.isEmpty { events = [] }
            isRefreshing = false
            return
        }
        if !force {
            guard refreshTask == nil else { return }
            if let lastRefresh, clock().timeIntervalSince(lastRefresh) < 60 { return }
        }
        generation += 1
        let request = generation
        let selected = settings.selectedCalendarIdentifiers
        refreshTask?.cancel()
        isRefreshing = true
        let service = self.service
        refreshTask = Task { @MainActor [weak self] in
            let fetched = await service.upcomingEvents(within: 86_400,
                                                       selectedCalendarIdentifiers: selected)
            guard let self, !Task.isCancelled, self.generation == request else { return }
            if self.events != fetched { self.events = fetched }
            self.lastRefresh = self.clock()
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    private func scheduleTick() {
        tick.schedule(at: clock().addingTimeInterval(30), tolerance: 2,
                      keepsAppResponsive: false) { [weak self] in
            guard let self, self.isPresented else { return }
            self.now = self.clock()
            self.refresh()
            self.scheduleTick()
        }
    }

    deinit { refreshTask?.cancel() }
}
