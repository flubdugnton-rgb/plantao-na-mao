import Foundation
import WidgetKit

extension Notification.Name { static let widgetDateSelected = Notification.Name("plantao.widget.date") }
enum WidgetBridge {
    static var available: Bool { WidgetData.sharedFile != nil }
    @discardableResult
    static func publish(_ shifts: [Shift]) -> Bool {
        guard let file = WidgetData.sharedFile else { return false }
        let snapshot = WidgetSnapshot(shifts: shifts, appearance: UserDefaults.standard.string(forKey: "plantao-na-mao.appearance") ?? "system", updatedAt: Date())
        do {
            // Finish writing before requesting a timeline; WidgetKit reads a complete snapshot.
            try file.save(snapshot)
            if let data = try? JSONEncoder().encode(snapshot) {
                UserDefaults(suiteName: WidgetData.groupID)?.set(data, forKey: WidgetData.key)
            }
            WidgetCenter.shared.reloadTimelines(ofKind: "PlantaoNaMaoCalendar")
            return true
        } catch { return false }
    }
    static func refreshAppearance() {
        guard let data = UserDefaults.standard.data(forKey: "plantao-na-mao.shifts"), let shifts = try? JSONDecoder().decode([Shift].self, from: data) else { publish([]); return }
        publish(shifts)
    }
}
