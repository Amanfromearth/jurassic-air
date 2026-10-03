import Foundation

struct ReminderEvent: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let urlString: String
}
