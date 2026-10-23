import AppKit
import SwiftUI

struct CalendarSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var status: CalendarAuthorizationStatus = .notDetermined
    @State private var calendars: [CalendarMetadata] = []
    @State private var refreshTick = 0   // bumped to trigger re-read after permission change

    /// Common offset chips. Anything custom can be added via the +/- in the row.
    private let offsetChoices: [Int] = [30, 15, 10, 5, 2, 1, 0]

    var body: some View {
        Form {
            Section {
                LabeledContent("Calendar access") { statusLabel }
                if status != .fullAccess { accessControl }
                if status == .fullAccess {
                    Toggle("Show meeting reminders", isOn: $settings.calendarEnabled)
                }
            } header: { Text("Access") } footer: { Text(accessSubtitle) }

            if status == .fullAccess {
                Section("Calendars") {
                    if calendars.isEmpty {
                        Text("Add an account in Calendar to see your calendars here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(calendars) { calendar in
                            Toggle(isOn: binding(for: calendar)) {
                                Label {
                                    Text(calendar.displayName)
                                } icon: {
                                    Circle().fill(Color(calendar.color)).frame(width: 9, height: 9)
                                }
                            }
                        }
                    }
                }
                .disabled(!settings.calendarEnabled)
                Section {
                    ForEach(offsetChoices, id: \.self) { minutes in
                        Toggle(minutes == 0 ? "At the start" : "\(minutes) minutes before", isOn: Binding(
                            get: { settings.alertOffsetsMinutes.contains(minutes) },
                            set: { enabled in
                                var offsets = Set(settings.alertOffsetsMinutes)
                                if enabled { offsets.insert(minutes) } else { offsets.remove(minutes) }
                                settings.alertOffsetsMinutes = offsets.sorted(by: >)
                            }
                        ))
                    }
                } header: { Text("Alert times") } footer: {
                    Text("A separate flight appears for each selected alert time.")
                }
                .disabled(!settings.calendarEnabled)
            }
        }
        .formStyle(.grouped)
        .onAppear { refresh() }
        // Pick up a permission change made in System Settings while away.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
        .task(id: refreshTick) { await reloadCalendars() }
    }

    // MARK: - Access row

    private var accessSubtitle: String {
        switch status {
        case .fullAccess:    return "Jurassic Air can read your calendars."
        case .denied:        return "Access denied in System Settings → Privacy & Security → Calendars."
        case .restricted:    return "Calendar access is restricted on this device."
        case .notDetermined: return "Grant access to schedule planes before meetings."
        }
    }

    @ViewBuilder
    private var accessControl: some View {
        HStack(spacing: 10) {
            switch status {
            case .notDetermined:
                Button("Request Access") {
                    Log.write("Request Access button tapped")
                    NSApp.activate(ignoringOtherApps: true)
                    Task {
                        let granted = await calendarService.requestAccess()
                        Log.write("requestAccess returned granted=\(granted)")
                        await MainActor.run { refresh() }
                        if granted {
                            await reloadCalendars()
                            await MainActor.run {
                                if settings.selectedCalendarIdentifiers.isEmpty {
                                    settings.selectedCalendarIdentifiers = Set(calendars.map(\.id))
                                }
                            }
                        }
                    }
                }
            case .denied, .restricted:
                Button("Open System Settings…") { openSystemPrivacySettings() }
            case .fullAccess:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch status {
        case .fullAccess:    return .green
        case .denied:        return .red
        case .restricted:    return .red
        case .notDetermined: return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .fullAccess:    return "Granted"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not determined"
        }
    }

    // MARK: - Calendars

    private func binding(for cal: CalendarMetadata) -> Binding<Bool> {
        Binding(
            get: { settings.selectedCalendarIdentifiers.contains(cal.id) },
            set: { isOn in
                if isOn { settings.selectedCalendarIdentifiers.insert(cal.id) }
                else    { settings.selectedCalendarIdentifiers.remove(cal.id) }
            }
        )
    }

    // MARK: - Offsets

    // MARK: - Refresh

    private var calendarService: CalendarService { Services.calendar }

    private func refresh() {
        status = calendarService.authorizationStatus
        refreshTick &+= 1
    }

    private func reloadCalendars() async {
        guard status == .fullAccess else {
            calendars = []
            return
        }
        calendars = await calendarService.availableCalendars()
            .sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private func openSystemPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
