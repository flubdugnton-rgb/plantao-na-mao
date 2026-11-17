import Foundation
import WidgetKit

extension Notification.Name { static let widgetDateSelected = Notification.Name("plantao.widget.date") }
enum WidgetBridge {
    private static var lastPayload: WidgetCalendarPayload?
    private static var lastTransport: String?
    private static var keychainStatus: Int32 = 0
    static var available: Bool { WidgetData.sharedFile != nil || lastTransport != nil }
    static var statusSummary: String {
        guard let payload = lastPayload, let transport = lastTransport else {
            return "A assinatura não permitiu compartilhar o calendário. Código das Chaves: \(keychainStatus). App e widget precisam ter um grupo de Chaves ou App Group em comum."
        }
        if let receipt = WidgetData.readReceipt(), receipt.fingerprint == payload.fingerprint {
            return "O widget confirmou a leitura de \(receipt.days) dias com aros às \(receipt.readAt.clock24), via \(receipt.source)."
        }
        return "Calendário gravado via \(transport). Aguardando o widget confirmar a leitura. Se continuar vazio, app e extensão podem ter grupos diferentes na assinatura."
    }
    @discardableResult
    static func publish(_ shifts: [Shift]) -> Bool {
        let snapshot = WidgetSnapshot(shifts: shifts, appearance: UserDefaults.standard.string(forKey: "plantao-na-mao.appearance") ?? "system", updatedAt: Date())
        let payload = WidgetCalendarPayload(snapshot: snapshot)
        var fileSaved = false
        if let file = WidgetData.sharedFile {
            do {
                try file.save(snapshot)
                fileSaved = true
                if let data = try? JSONEncoder().encode(snapshot) { UserDefaults(suiteName: WidgetData.groupID)?.set(data, forKey: WidgetData.key) }
            } catch { }
        }
        keychainStatus = WidgetKeychain.save(payload)
        lastPayload = payload
        lastTransport = fileSaved ? "App Group" : keychainStatus == 0 ? "Chaves" : nil
        guard lastTransport != nil else { return false }
        WidgetCenter.shared.reloadTimelines(ofKind: "PlantaoNaMaoCalendar")
        return true
    }
    static func refreshAppearance() {
        guard let data = UserDefaults.standard.data(forKey: "plantao-na-mao.shifts"), let shifts = try? JSONDecoder().decode([Shift].self, from: data) else { publish([]); return }
        publish(shifts)
    }
}
