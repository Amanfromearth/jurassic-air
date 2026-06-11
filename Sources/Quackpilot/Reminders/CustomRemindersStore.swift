import Combine
import Foundation

/// Persisted store of user-defined reminders. Backed by UserDefaults via JSON.
final class CustomRemindersStore: ObservableObject {
    static let shared = CustomRemindersStore(defaults: .standard)

    @Published private(set) var reminders: [CustomReminder] = []

    private let defaults: UserDefaults
    private let defaultsKey = "customReminders.v1"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        load()
    }

    // MARK: - CRUD

    func add(_ reminder: CustomReminder) {
        reminders.append(reminder)
        save()
    }

    func update(_ reminder: CustomReminder) {
        guard let idx = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[idx] = reminder
        save()
    }

    func delete(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    func setEnabled(id: UUID, _ enabled: Bool) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].enabled = enabled
        save()
    }

    /// Called by the scheduler when a reminder actually fires — updates lastFiredAt
    /// so the next-due calculation moves forward.
    func markFired(id: UUID, at date: Date) {
        guard let idx = reminders.firstIndex(where: { $0.id == id }) else { return }
        reminders[idx].lastFiredAt = date
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: defaultsKey) else { return }
        do {
            reminders = try JSONDecoder().decode([CustomReminder].self, from: data)
        } catch {
            NSLog("CustomRemindersStore decode failed: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(reminders)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            NSLog("CustomRemindersStore encode failed: \(error)")
        }
    }
}
