import SwiftUI

/// List of user-defined reminders + an Add button. Add/Edit opens
/// CustomReminderFormView as a .sheet.
struct CustomRemindersListView: View {
    @ObservedObject var store: CustomRemindersStore = .shared

    @State private var showingAddSheet = false
    @State private var editingReminder: CustomReminder?
    @State private var deletingReminder: CustomReminder?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Form {
            Section {
                LabeledContent("Custom reminders", value: "\(store.reminders.count)")
                Button { showingAddSheet = true } label: { Label("Add Reminder…", systemImage: "plus") }
            }
            if store.reminders.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No Reminders").font(.headline)
                        Text("Add a reminder and a plane will bring it to you.")
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                Section("Scheduled") {
                    ForEach(store.reminders) { reminder in row(for: reminder) }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAddSheet) {
            CustomReminderFormView(
                existing: nil,
                onSave: { reminder in
                    store.add(reminder)
                    showingAddSheet = false
                },
                onCancel: { showingAddSheet = false }
            )
        }
        .sheet(item: $editingReminder) { reminder in
            CustomReminderFormView(
                existing: reminder,
                onSave: { updated in
                    store.update(updated)
                    editingReminder = nil
                },
                onCancel: { editingReminder = nil }
            )
        }
        .confirmationDialog(
            "Delete reminder?",
            isPresented: Binding(
                get: { deletingReminder != nil },
                set: { if !$0 { deletingReminder = nil } }
            ),
            presenting: deletingReminder
        ) { reminder in
            Button("Delete \(reminder.title.isEmpty ? "this reminder" : "“\(reminder.title)”")", role: .destructive) {
                store.delete(id: reminder.id)
                deletingReminder = nil
            }
            Button("Cancel", role: .cancel) { deletingReminder = nil }
        } message: { _ in
            Text("This cannot be undone.")
        }
    }

    @ViewBuilder
    private func row(for r: CustomReminder) -> some View {
        HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { r.enabled },
                    set: { store.setEnabled(id: r.id, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                    Text(r.title.isEmpty ? "(untitled)" : r.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle(for: r))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer()
                if let host = URL(string: r.urlString)?.host, !host.isEmpty {
                    Label(host, systemImage: "link")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .help(r.urlString)
                }
                Button {
                    editingReminder = r
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Edit")

                Button {
                    deletingReminder = r
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
            .opacity(r.enabled ? 1 : 0.55)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { editingReminder = r }
            .accessibilityAction(named: "Edit") { editingReminder = r }
    }

    /// "Daily · next today 9:00 AM", "Once · done", "Every 5 min · paused".
    private func subtitle(for r: CustomReminder) -> String {
        let rule = r.repeatRule.label
        guard r.enabled else { return "\(rule) · paused" }
        guard let next = r.nextDueDate(now: Date()) else { return "\(rule) · done" }
        return "\(rule) · next \(Self.describe(next))"
    }

    private static func describe(_ date: Date) -> String {
        let cal = Calendar.current
        if date <= Date() { return "now" }
        if cal.isDateInToday(date) { return "today \(timeFormatter.string(from: date))" }
        if cal.isDateInTomorrow(date) { return "tomorrow \(timeFormatter.string(from: date))" }
        return dateTimeFormatter.string(from: date)
    }
}
