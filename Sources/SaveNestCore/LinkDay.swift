import Foundation

public struct LinkDay: Identifiable {
    public let id: Date
    public let label: String
    public let links: [SavedLink]
    public init(id: Date, label: String, links: [SavedLink]) { self.id = id; self.label = label; self.links = links }
    public static func group(_ links: [SavedLink], now: Date = Date(), calendar: Calendar = .current) -> [LinkDay] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        let grouped = Dictionary(grouping: links) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { day in
            let label: String
            if day == today { label = "Today" }
            else if day == yesterday { label = "Yesterday" }
            else {
                let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone
                formatter.setLocalizedDateFormatFromTemplate(calendar.component(.year, from: day) == calendar.component(.year, from: now) ? "EEEE MMM d" : "MMM d yyyy")
                label = formatter.string(from: day)
            }
            return LinkDay(id: day, label: label, links: grouped[day]!.sorted { $0.createdAt > $1.createdAt })
        }
    }
}
