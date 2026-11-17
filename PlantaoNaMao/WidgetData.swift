import Foundation

struct WidgetSnapshot: Codable {
    var shifts: [Shift]
    var appearance: String
    var updatedAt: Date
}
enum WidgetData {
    static var groupID: String { Bundle.main.object(forInfoDictionaryKey: "SharedAppGroupIdentifier") as? String ?? "group.com.plantaonamao.shared" }
    static let key = "plantao.widget.snapshot.v1"
    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: key), let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot(shifts: [], appearance: "system", updatedAt: .distantPast)
        }
        return snapshot
    }
    static func url(for date: Date) -> URL {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return URL(string: "plantaonamao://calendar?date=\(f.string(from: date))")!
    }
}
