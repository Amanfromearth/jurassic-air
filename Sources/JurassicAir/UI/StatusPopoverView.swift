import SwiftUI

/// Reminder and calendar rows for the menu bar overview.
struct UpcomingFlight: Identifiable {
    let id: String
    let title: String
    let detail: String
    let date: Date
    let isMeeting: Bool

    static func make(reminders: [CustomReminder], now: Date) -> [UpcomingFlight] {
        reminders.compactMap { reminder -> UpcomingFlight? in
            guard let date = reminder.nextDueDate(now: now) else { return nil }
            return UpcomingFlight(id: "reminder:\(reminder.id)",
                                  title: reminder.title.isEmpty ? "Untitled reminder" : reminder.title,
                                  detail: reminder.repeatRule.label, date: date, isMeeting: false)
        }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

    static func todayEvents(_ events: [CalendarEvent], now: Date,
                            calendar: Calendar = .current) -> [UpcomingFlight] {
        events.filter { !$0.isAllDay && $0.startDate > now
            && calendar.isDate($0.startDate, inSameDayAs: now) }
            .map { UpcomingFlight(id: "calendar:\($0.id)", title: $0.title,
                                  detail: $0.calendarTitle, date: $0.startDate, isMeeting: true) }
            .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }
}

struct StatusPopoverView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var store = CustomRemindersStore.shared
    @ObservedObject var model: StatusPopoverModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    let onPreview: () -> Void
    let onSettings: (SettingsPanelView.Page?) -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Group {
                    if let artwork = PixelArtImages.image(named: "thumb-head-\(settings.flierHead)") {
                        Image(decorative: artwork, scale: 1)
                            .resizable().interpolation(.none).scaledToFit()
                    } else {
                        Image(systemName: "airplane")
                    }
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Jurassic Air").font(.system(size: 15, weight: .semibold))
                    Text("A little lift for your day.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onPreview) {
                    Image(systemName: "paperplane").font(.system(size: 14))
                }
                .help("Preview a flight")
                .accessibilityLabel("Preview a flight")
                .buttonStyle(.borderless)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            VStack(spacing: 16) {
                upcoming(now: model.now)
                Divider()
                calendarToday(now: model.now)
            }
            .padding(16)

            Divider().padding(.horizontal, 16)

            VStack(spacing: 12) {
                Toggle(isOn: $settings.audioEnabled) {
                    Label("Flight sounds", systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Toggle(isOn: $launchAtLogin) {
                    Label("Open at login", systemImage: "sunrise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!LaunchAtLogin.isAvailable)
                .onChange(of: launchAtLogin) { value in
                    if !LaunchAtLogin.setEnabled(value) {
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            }
            .font(.system(size: 12))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .padding(16)

            Divider()

            HStack {
                Button { onSettings(nil) } label: {
                    Label("All Settings…", systemImage: "gearshape")
                }
                .keyboardShortcut(",")
                Spacer()
                Button("Quit", action: onQuit).keyboardShortcut("q")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .buttonStyle(.borderless)
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .frame(width: 350)
        .background(.regularMaterial)
        .onChange(of: model.isPresented) { presented in
            if presented { launchAtLogin = LaunchAtLogin.isEnabled }
        }
    }

    private func upcoming(now: Date) -> some View {
        let flights = UpcomingFlight.make(reminders: store.reminders, now: now)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("UP NEXT").font(.system(size: 10, weight: .semibold))
                    .tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button { onSettings(.reminders) } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Manage reminders")
                .accessibilityLabel("Manage reminders")
            }

            if flights.isEmpty {
                VStack(spacing: 7) {
                    Image(systemName: "bell").font(.system(size: 23, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Clear skies ahead").font(.system(size: 13, weight: .medium))
                    Text("Your next reminders will appear here.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("Add a Reminder…") { onSettings(.reminders) }
                        .controlSize(.small).padding(.top, 3)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
            } else {
                ForEach(Array(flights.prefix(3))) { flight in
                    flightRow(flight, now: now)
                }
                Button("View Reminders…") { onSettings(.reminders) }
                    .font(.system(size: 11)).buttonStyle(.borderless)
            }
        }
    }

    private func calendarToday(now: Date) -> some View {
        let meetings = UpcomingFlight.todayEvents(model.events, now: now)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("CALENDAR · TODAY").font(.system(size: 10, weight: .semibold))
                    .tracking(1).foregroundStyle(.secondary)
                Spacer()
                Button { onSettings(.calendar) } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless)
                    .help("Calendar settings")
                    .accessibilityLabel("Calendar settings")
            }
            if !model.canShowCalendar {
                Text("See your day at a glance. Choose the calendars to show.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Set Up Calendar…") { onSettings(.calendar) }
                    .font(.system(size: 11)).buttonStyle(.borderless)
            } else if meetings.isEmpty {
                Text(model.isRefreshing ? "Loading today’s events…" : "No more events today.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(meetings) { flightRow($0, now: now) }
                    }
                }
                .frame(height: min(CGFloat(meetings.count) * 48 - 14, 160))
            }
        }
    }

    private func flightRow(_ flight: UpcomingFlight, now: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: flight.isMeeting ? "calendar" : "bell")
                .foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(flight.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text(flight.detail).font(.system(size: 10)).foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(flight.date <= now ? "Now" : flight.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .medium)).monospacedDigit()
                Text(dayLabel(flight.date, now: now))
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .help("\(flight.title) · \(flight.date.formatted())")
    }

    private func dayLabel(_ date: Date, now: Date) -> String {
        if date <= now { return "Due" }
        if Calendar.current.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
           Calendar.current.isDate(date, inSameDayAs: tomorrow) { return "Tomorrow" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}
