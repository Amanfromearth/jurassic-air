import Foundation

enum MockReminderCatalog {
    static let general: [ReminderEvent] = [
        .init(title: "Drink some water", urlString: "https://www.hydrationforhealth.com/"),
        .init(title: "Stand up & stretch", urlString: "https://www.nhs.uk/live-well/exercise/sitting-exercises/"),
        .init(title: "Reply to mom", urlString: "imessage://"),
        .init(title: "Ship it!", urlString: "https://github.com/")
    ]

    static let meetings: [ReminderEvent] = [
        .init(title: "Standup in 5", urlString: "https://meet.google.com/"),
        .init(title: "1:1 with Lead", urlString: "https://zoom.us/"),
        .init(title: "Design review", urlString: "https://meet.google.com/")
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
