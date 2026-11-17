import Foundation
import CryptoKit

struct WidgetSnapshot: Codable, Equatable {
    var shifts: [Shift]
    var appearance: String
    var updatedAt: Date
}

// A compact projection for the keychain fallback. Never includes names, locations,
// amounts, notes, OAuth credentials or record identifiers.
struct WidgetCalendarDay: Codable, Equatable {
    let date: Date
    let colors: [ShiftColor]
}
struct WidgetCalendarPayload: Codable, Equatable {
    let days: [WidgetCalendarDay]
    let appearance: String
    let updatedAt: Date
    init(snapshot: WidgetSnapshot, calendar: Calendar = .current) {
        let first = calendar.dateInterval(of: .month, for: snapshot.updatedAt)!.start
        let start = calendar.date(byAdding: .month, value: -1, to: first)!
        let end = calendar.date(byAdding: .month, value: 2, to: first)!
        let grouped = Dictionary(grouping: snapshot.shifts.filter { $0.date >= start && $0.date < end }) { calendar.startOfDay(for: $0.date) }
        days = grouped.keys.sorted().map { day in WidgetCalendarDay(date: day, colors: grouped[day]!.map(\.color).sorted { $0.rawValue < $1.rawValue }) }
        appearance = snapshot.appearance
        updatedAt = snapshot.updatedAt
    }
    var fingerprint: String {
        let contents = appearance + "|" + days.map { "\(Int($0.date.timeIntervalSince1970)):\($0.colors.map(\.rawValue).joined(separator: ","))" }.joined(separator: "|")
        return SHA256.hash(data: Data(contents.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    var snapshot: WidgetSnapshot {
        WidgetSnapshot(shifts: days.flatMap { day in
            day.colors.map { color in Shift(date: day.date, title: "", location: "", start: day.date, end: day.date, color: color, createdAt: nil) }
        }, appearance: appearance, updatedAt: updatedAt)
    }
}
struct WidgetReadReceipt: Codable, Equatable {
    let fingerprint: String
    let readAt: Date
    let days: Int
    let source: String
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
    static var receiptURL: URL? { sharedFile?.url.deletingLastPathComponent().appendingPathComponent("plantao-widget-receipt.json") }
    static func load() -> WidgetSnapshot {
        var candidates: [(WidgetSnapshot, String)] = []
        if let snapshot = sharedFile?.load() { candidates.append((snapshot, "App Group")) }
        if let payload = WidgetKeychain.load() { candidates.append((payload.snapshot, "Chaves")) }
        if candidates.isEmpty, sharedFile != nil,
           let data = UserDefaults(suiteName: groupID)?.data(forKey: key),
           let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) { candidates.append((snapshot, "App Group")) }
        guard let latest = candidates.max(by: { $0.0.updatedAt < $1.0.updatedAt }) else {
            return WidgetSnapshot(shifts: [], appearance: "system", updatedAt: .distantPast)
        }
        // The app must never acknowledge its own write; only the extension can do so.
        if Bundle.main.bundleURL.pathExtension == "appex" {
            let payload = WidgetCalendarPayload(snapshot: latest.0)
            let receipt = WidgetReadReceipt(fingerprint: payload.fingerprint, readAt: Date(), days: payload.days.count, source: latest.1)
            if let url = receiptURL, let data = try? JSONEncoder().encode(receipt) { try? data.write(to: url, options: .atomic) }
            WidgetKeychain.acknowledge(receipt)
        }
        return latest.0
    }
    static func readReceipt() -> WidgetReadReceipt? {
        var receipts: [WidgetReadReceipt] = []
        if let url = receiptURL, let data = try? Data(contentsOf: url), let receipt = try? JSONDecoder().decode(WidgetReadReceipt.self, from: data) { receipts.append(receipt) }
        if let receipt = WidgetKeychain.receipt() { receipts.append(receipt) }
        return receipts.max { $0.readAt < $1.readAt }
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
