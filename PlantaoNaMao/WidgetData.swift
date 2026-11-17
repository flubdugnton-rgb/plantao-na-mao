import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var shifts: [Shift]
    var appearance: String
    var updatedAt: Date
}

// Atomic files avoid a preference-cache race between the app and WidgetKit.
// The defaults key remains a read fallback for widgets installed with 1.2.
struct WidgetSnapshotFile {
    let url: URL
    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        #endif
    }
    func load() -> WidgetSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

enum WidgetData {
    static var groupID: String { Bundle.main.object(forInfoDictionaryKey: "SharedAppGroupIdentifier") as? String ?? "group.com.plantaonamao.shared" }
    static let key = "plantao.widget.snapshot.v1"
    static var sharedFile: WidgetSnapshotFile? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else { return nil }
        return WidgetSnapshotFile(url: container.appendingPathComponent("plantao-widget-snapshot.json"))
    }
    static func load() -> WidgetSnapshot {
        if let snapshot = sharedFile?.load() { return snapshot }
        if let data = UserDefaults(suiteName: groupID)?.data(forKey: key), let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) { return snapshot }
        return WidgetSnapshot(shifts: [], appearance: "system", updatedAt: .distantPast)
    }
    static func date(from url: URL) -> Date? {
        guard url.scheme == "plantaonamao", url.host == "calendar",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "date" })?.value else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        return f.date(from: value)
    }
    static func url(for date: Date) -> URL {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        return URL(string: "plantaonamao://calendar?date=\(f.string(from: date))")!
    }
}
