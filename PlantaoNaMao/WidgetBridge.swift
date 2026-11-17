import Foundation
import WidgetKit

extension Notification.Name { static let widgetDateSelected = Notification.Name("plantao.widget.date") }
enum WidgetBridge {
    static var available: Bool { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetData.groupID) != nil }
    static func publish(_ shifts: [Shift]) {
        guard available else { return }
        let snapshot = WidgetSnapshot(shifts: shifts, appearance: UserDefaults.standard.string(forKey: "plantao-na-mao.appearance") ?? "system", updatedAt: Date())
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults(suiteName: WidgetData.groupID)?.set(data, forKey: WidgetData.key)
            WidgetCenter.shared.reloadTimelines(ofKind: "PlantaoNaMaoCalendar")
        }
    }
    static func refreshAppearance() {
        guard let data = UserDefaults.standard.data(forKey: "plantao-na-mao.shifts"), let shifts = try? JSONDecoder().decode([Shift].self, from: data) else { publish([]); return }
        publish(shifts)
    }
}
