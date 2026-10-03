import SwiftUI

/// Form to create or edit a single CustomReminder. Used as a .sheet from the
/// settings panel. Uses SwiftUI's grouped `Form` / `Section` for a native
/// macOS settings-style layout.
struct CustomReminderFormView: View {
    @State private var draft: CustomReminder
    @State private var firingMode: FiringMode
    @State private var delaySeconds: Int
    @State private var delayMinutes: Int
    @State private var repeatKind: RepeatKind
    @State private var customSeconds: Int
    @State private var customMinutes: Int

    private let isNew: Bool
    /// Snapshot of the original schedule, captured at init, so we can reset
    /// `lastFiredAt` when the schedule changes on save.
    private let originalSchedule: (firstFireAt: Date, repeatRule: RepeatRule)?
    let onSave: (CustomReminder) -> Void
    let onCancel: () -> Void

    init(existing: CustomReminder?, onSave: @escaping (CustomReminder) -> Void, onCancel: @escaping () -> Void) {
        let initial = existing ?? CustomReminder(
            title: "",
            urlString: "",
            firstFireAt: Date().addingTimeInterval(60),
            repeatRule: .once,
            enabled: true
        )

        let (initialKind, initialSeconds, initialMinutes): (RepeatKind, Int, Int)
        switch initial.repeatRule {
        case .once:                initialKind = .once;         initialSeconds = 30; initialMinutes = 15
        case .everySeconds(let s): initialKind = .everySeconds; initialSeconds = s;  initialMinutes = 15
        case .everyMinutes(let m): initialKind = .everyMinutes; initialSeconds = 30; initialMinutes = m
        case .hourly:              initialKind = .hourly;       initialSeconds = 30; initialMinutes = 15
        case .daily:               initialKind = .daily;        initialSeconds = 30; initialMinutes = 15
        case .weekly:              initialKind = .weekly;       initialSeconds = 30; initialMinutes = 15
        }

        _draft = State(initialValue: initial)
        _firingMode = State(initialValue: .atTime)
        _delaySeconds = State(initialValue: 30)
        _delayMinutes = State(initialValue: 5)
        _repeatKind = State(initialValue: initialKind)
        _customSeconds = State(initialValue: initialSeconds)
        _customMinutes = State(initialValue: initialMinutes)

        self.isNew = (existing == nil)
        self.originalSchedule = existing.map { ($0.firstFireAt, $0.repeatRule) }
        self.onSave = onSave
        self.onCancel = onCancel
    }

    enum FiringMode: String, CaseIterable, Identifiable {
        case atTime = "At specific time"
        case afterSeconds = "In N seconds"
        case afterMinutes = "In N minutes"
        var id: String { rawValue }
    }

    enum RepeatKind: String, CaseIterable, Identifiable {
        case once = "Once"
        case everySeconds = "Every N seconds"
        case everyMinutes = "Every N minutes"
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                Section {
                    TextField("Title", text: $draft.title, prompt: Text("e.g. Stand up & stretch"))
                    TextField("URL", text: $draft.urlString, prompt: Text("https://… (optional)"))
                } header: {
                    Text("Details")
                } footer: {
                    Text("Click the banner to open the URL. A link without a scheme gets https://.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("When to fire") {
                    Picker("Fire", selection: $firingMode) {
                        ForEach(FiringMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch firingMode {
                    case .atTime:
                        DatePicker("Date & time", selection: $draft.firstFireAt,
                                   displayedComponents: [.date, .hourAndMinute])
                    case .afterSeconds:
                        Stepper(value: $delaySeconds, in: 1...3600) {
                            HStack {
                                Text("In")
                                Text("\(delaySeconds) seconds").monospacedDigit()
                            }
                        }
                    case .afterMinutes:
                        Stepper(value: $delayMinutes, in: 1...1440) {
                            HStack {
                                Text("In")
                                Text("\(delayMinutes) minutes").monospacedDigit()
                            }
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $repeatKind) {
                        ForEach(RepeatKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    switch repeatKind {
                    case .everySeconds:
                        Stepper(value: $customSeconds, in: 5...3600) {
                            HStack {
                                Text("Every")
                                Text("\(customSeconds) sec").monospacedDigit()
                            }
                        }
                    case .everyMinutes:
                        Stepper(value: $customMinutes, in: 1...1440) {
                            HStack {
                                Text("Every")
                                Text("\(customMinutes) min").monospacedDigit()
                            }
                        }
                    default:
                        EmptyView()
                    }
                }

                Section {
                    Toggle("Enabled", isOn: $draft.enabled)
                }
            }
            .formStyle(.grouped)
            Divider()
            footer
        }
        .frame(width: 440, height: 540)
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack {
            Text(isNew ? "New Reminder" : "Edit Reminder")
                .font(.title3).bold()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(isNew ? "Add" : "Save", action: handleSave)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Save

    private func handleSave() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.urlString = Self.normalizedURLString(draft.urlString)
        draft.repeatRule = composeRule()
        // Delay-based firing modes ignore the DatePicker and compute firstFireAt
        // from the current moment so "in 30 seconds" really means 30s from when
        // the user hits Add/Save.
        switch firingMode {
        case .atTime:
            break // draft.firstFireAt already bound to DatePicker
        case .afterSeconds:
            draft.firstFireAt = Date().addingTimeInterval(TimeInterval(delaySeconds))
        case .afterMinutes:
            draft.firstFireAt = Date().addingTimeInterval(TimeInterval(delayMinutes * 60))
        }
        // Reset lastFiredAt if the schedule changed on this edit, so the new
        // schedule actually fires (avoids the "edited .once but never fires
        // again" bug).
        if let original = originalSchedule,
           original.firstFireAt != draft.firstFireAt || original.repeatRule != draft.repeatRule {
            draft.lastFiredAt = nil
        }
        onSave(draft)
    }

    /// "zoom.us/j/1" opens nothing in NSWorkspace, so add https:// when the
    /// user typed a bare host. Strings that already have a scheme
    /// (https:, imessage:, zoommtg:) stay as typed.
    static func normalizedURLString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let url = URL(string: trimmed), url.scheme != nil { return trimmed }
        return "https://" + trimmed
    }

    private func composeRule() -> RepeatRule {
        switch repeatKind {
        case .once:         return .once
        case .everySeconds: return .everySeconds(customSeconds)
        case .everyMinutes: return .everyMinutes(customMinutes)
        case .hourly:       return .hourly
        case .daily:        return .daily
        case .weekly:       return .weekly
        }
    }
}
