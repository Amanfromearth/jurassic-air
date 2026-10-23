import AppKit
import Combine

/// Arms one deadline for the next reminder. Store edits, clock changes, and
/// wake notifications re-evaluate it; there is no periodic polling when idle.
final class ReminderScheduler {
    weak var dispatcher: ReminderDispatcher?
    private let store: CustomRemindersStore
    private let now: () -> Date
    private let deadline = DeadlineTimer()
    private var subscription: AnyCancellable?
    private var observers: [NSObjectProtocol] = []
    private(set) var isRunning = false
    var nextFireDate: Date? { deadline.nextFireDate }

    init(store: CustomRemindersStore = .shared, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.now = now
    }

    func start() {
        stop()
        isRunning = true
        // Published delivers the new snapshot before the store property changes.
        subscription = store.$reminders.sink { [weak self] reminders in
            self?.schedule(reminders)
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.processDueReminders() })
        for name in [NSApplication.didBecomeActiveNotification,
                     Notification.Name.NSSystemClockDidChange] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in self?.processDueReminders() })
        }
        processDueReminders()
    }

    func stop() {
        isRunning = false
        subscription?.cancel()
        subscription = nil
        deadline.cancel()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    func processDueReminders() {
        guard isRunning else { return }
        let date = now()
        for reminder in store.reminders where reminder.isDue(at: date) {
            dispatcher?.fire(ReminderEvent(title: reminder.title, urlString: reminder.urlString))
            store.markFired(id: reminder.id, at: date)
        }
        schedule(store.reminders)
    }

    private func schedule(_ reminders: [CustomReminder]) {
        guard isRunning else { return }
        let date = now()
        let next = reminders.compactMap { $0.nextDueDate(now: date) }.min()
        deadline.schedule(at: next) { [weak self] in self?.processDueReminders() }
    }

    deinit { stop() }
}
