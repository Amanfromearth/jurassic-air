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
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Access") {
                FormRow(
                    "Calendar access",
                    subtitle: accessSubtitle,
                    isFirst: true
                ) {
                    accessControl
                }
                if status == .fullAccess {
                    FormRow("Enable calendar reminders") {
                        Toggle("", isOn: $settings.calendarEnabled).labelsHidden()
                    }
                }
            }

            if status == .fullAccess {
                Group {
                    SettingsCard(
                        "Calendars",
                        footer: calendars.isEmpty ? "No calendars found in Calendar.app." : nil
                    ) {
                        if calendars.isEmpty {
                            FormRowFullWidth(isFirst: true) {
                                Text("Connect calendars in Calendar.app to see them here.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            ForEach(Array(calendars.enumerated()), id: \.element.id) { idx, cal in
                                FormRow(cal.displayName, isFirst: idx == 0) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(cal.color))
                                            .frame(width: 9, height: 9)
                                        Toggle("", isOn: binding(for: cal))
                                            .labelsHidden()
                                            .toggleStyle(.switch)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }

                    SettingsCard(
                        "Alerts",
                        footer: "Each enabled offset fires its own plane before the meeting. 0 = right at the meeting start."
                    ) {
                        FormRowFullWidth(isFirst: true) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Alert me before each meeting")
                                    .font(.system(size: 13))
                                FlowLayout(spacing: 6) {
                                    ForEach(offsetChoices, id: \.self) { minutes in
                                        chip(for: minutes)
                                    }
                                }
                            }
                        }
                    }
                }
                .disabled(!settings.calendarEnabled)
                .opacity(settings.calendarEnabled ? 1 : 0.5)
                .animation(.easeOut(duration: 0.15), value: settings.calendarEnabled)
            }
        }
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
            statusLabel
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

    private func chip(for minutes: Int) -> some View {
        let isOn = settings.alertOffsetsMinutes.contains(minutes)
        return Button(action: { toggleOffset(minutes) }) {
            Text(minutes == 0 ? "At start" : "\(minutes) min")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(isOn ? Color.accentColor : Color.primary.opacity(0.06))
                .foregroundColor(isOn ? .white : .primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        isOn ? Color.accentColor : Color.primary.opacity(0.12),
                        lineWidth: 0.5
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func toggleOffset(_ m: Int) {
        var current = Set(settings.alertOffsetsMinutes)
        if current.contains(m) { current.remove(m) } else { current.insert(m) }
        settings.alertOffsetsMinutes = current.sorted(by: >)
    }

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

/// Minimal flow layout for the offset chips. Lays out children left-to-right,
/// wrapping when they don't fit on the current row.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
