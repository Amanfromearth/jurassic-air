#if DEBUG
import Foundation

/// Development fixtures only. Titles enter through the same ReminderEvent
/// boundary as saved reminders and calendar alerts; nothing is persisted.
enum BannerStressFixtures {
    struct Sample: Identifiable {
        let id: String
        let title: String
        var event: ReminderEvent { ReminderEvent(title: title, urlString: "https://example.com") }
    }

    static let demo: [Sample] = [
        .init(id: "algo", title: "Daily algo\nStarts in 5 min"),
        .init(id: "water", title: "Time for water"),
        .init(id: "review", title: "Design review\nStarting now")
    ]
    static let worst: [Sample] = [
        .init(id: "long-title", title: "Quarterly planning with Aleksandra Wiśniewska-Kowalczyk and the Platform Infrastructure team\nStarts in 10 min"),
        .init(id: "email", title: "Email bartholomew.fitzgerald@northwind-industries-holdings.example.com"),
        .init(id: "short", title: "J"),
        .init(id: "accents", title: "Đặng Thị Ngọc Hân — Kiểm tra tiến độ"),
        .init(id: "arabic", title: "اجتماع فريق التصميم مع نور الهدى"),
        .init(id: "cjk", title: "王秀英：产品设计评审与下季度规划会议"),
        .init(id: "emoji", title: "👩🏽‍💻 Priya & 🦊 Fox — launch review 🎉"),
        .init(id: "url", title: "https://example.com/workspaces/acme/projects/q3-launch/docs/9f8e7d6c5b4a?tab=comments&filter=unresolved"),
        .init(id: "german", title: "Benachrichtigungseinstellungen überprüfen"),
        .init(id: "whitespace", title: "  Daily\t algo  \r\n\r\n Starts in 1 min  "),
        .init(id: "literal", title: "Review <b>draft</b> &amp; **notes**"),
        .init(id: "pasted-notes", title: Array(repeating: "Planning notes: review onboarding feedback with the design team, agree on owners for accessibility improvements, and confirm launch dates before the next customer check-in.", count: 12).joined(separator: " "))
    ]
    static let empty: [Sample] = [.init(id: "empty", title: ""), .init(id: "blank", title: " \n\t ")]
}
#endif
