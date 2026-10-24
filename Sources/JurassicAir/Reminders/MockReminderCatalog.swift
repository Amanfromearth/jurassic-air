import Foundation

enum MockReminderCatalog {
    static let general: [ReminderEvent] = [
        .init(title: "Time for water", urlString: "https://www.hydrationforhealth.com/"),
        .init(title: "Time to stretch", urlString: "https://www.nhs.uk/live-well/exercise/sitting-exercises/"),
        .init(title: "Check in with Mom", urlString: "imessage://"),
        .init(title: "Ready? Ship it!", urlString: "https://github.com/")
    ]

    static let meetings: [ReminderEvent] = [
        .init(title: "Standup\nStarts in 5 min", urlString: "https://meet.google.com/"),
        .init(title: "Time for your 1:1", urlString: "https://zoom.us/"),
        .init(title: "Design review time", urlString: "https://meet.google.com/")
    ]

    static func placeholder() -> ReminderEvent {
        .init(title: "Hello, world!", urlString: "https://anthropic.com")
    }

    static func random() -> ReminderEvent {
        general.randomElement() ?? placeholder()
    }

    static func randomMeeting() -> ReminderEvent {
        meetings.randomElement() ?? placeholder()
    }
}
