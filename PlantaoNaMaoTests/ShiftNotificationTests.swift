import XCTest
import UserNotifications
@testable import PlantaoNaMao

private final class ReminderCenterMock: ReminderCenter {
    var status: UNAuthorizationStatus = .authorized
    var requests: [String: UNNotificationRequest] = [:]
    var added = 0
    var fail = false
    var blockNextAdd = false
    var blockedAdd: CheckedContinuation<Void, Never>?
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { status != .denied }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { Array(requests.values) }
    func add(_ request: UNNotificationRequest) async throws {
        if fail { throw URLError(.unknown) }
        if blockNextAdd {
            blockNextAdd = false
            await withCheckedContinuation { blockedAdd = $0 }
        }
        requests[request.identifier] = request; added += 1
    }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { identifiers.forEach { requests.removeValue(forKey: $0) } }
    func deliveredNotifications() async -> [UNNotification] { [] }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

@MainActor
final class ShiftNotificationTests: XCTestCase {
    private func fixture() -> (UserDefaults, ShiftStore, ReminderCenterMock, ShiftNotifications, Shift) {
        let defaults = UserDefaults(suiteName: "reminder-tests-" + UUID().uuidString)!
        let store = ShiftStore(defaults: defaults)
        let center = ReminderCenterMock()
        let service = ShiftNotifications(defaults: defaults, center: center)
        let day = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let start = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: day)!
        let end = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
        let shift = Shift(date: day, title: "Noturno", location: "Hospital", start: start, end: end, notes: "Documentos", amountCents: 31632)
        return (defaults, store, center, service, shift)
    }
    func testEditDeleteAndDisableReplaceOrCancelRequests() async {
        let (_, store, center, service, shift) = fixture()
        XCTAssertFalse(service.enabled)
        service.start(store: store)
        store.save(shift)
        await service.setEnabled(true)
        await service.waitUntilSettled()
        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.values.first?.content.title, "Plantão: Noturno")
        XCTAssertTrue(center.requests.values.first!.content.body.contains("Documentos"))
        XCTAssertEqual(WidgetData.date(from: URL(string: center.requests.values.first!.content.userInfo["url"] as! String)!), Calendar.current.startOfDay(for: shift.date))
        let firstFire = (center.requests.values.first!.trigger as! UNCalendarNotificationTrigger).nextTriggerDate()
        service.setLead(.halfHour)
        await service.waitUntilSettled()
        let newFire = (center.requests.values.first!.trigger as! UNCalendarNotificationTrigger).nextTriggerDate()
        XCTAssertNotEqual(firstFire, newFire)
        var edited = shift; edited.title = "Editado"; edited.notes = "Novos detalhes"
        store.save(edited)
        await service.waitUntilSettled()
        XCTAssertEqual(center.requests.count, 1)
        XCTAssertEqual(center.requests.values.first?.content.title, "Plantão: Editado")
        let previousAdds = center.added
        let previousRevision = store.revision
        XCTAssertTrue(store.save(edited))
        XCTAssertEqual(store.revision, previousRevision, "Salvar sem mudanças não dispara sincronização")
        service.refresh(); await service.waitUntilSettled()
        XCTAssertEqual(center.added, previousAdds, "Retornar sem alteração não deve reagendar o mesmo aviso")
        store.remove(edited); await service.waitUntilSettled()
        XCTAssertTrue(center.requests.isEmpty)
        store.save(shift); await service.waitUntilSettled()
        await service.setEnabled(false); await service.waitUntilSettled()
        XCTAssertTrue(center.requests.isEmpty)
    }
    func testDeniedPermissionAndRemoteDeletionAndFailure() async throws {
        let (_, store, center, service, shift) = fixture()
        service.start(store: store); store.save(shift)
        center.status = .denied
        await service.setEnabled(true); await service.waitUntilSettled()
        XCTAssertTrue(service.denied); XCTAssertTrue(center.requests.isEmpty)
        center.status = .authorized; center.fail = true
        service.refresh(); await service.waitUntilSettled()
        XCTAssertNotNil(service.errorMessage)
        center.fail = false
        service.refresh(); await service.waitUntilSettled()
        XCTAssertEqual(service.queuedCount, 1); XCTAssertNil(service.errorMessage)
        try store.mergeRemote(SyncSnapshot(deletions: [SyncDeletion(id: shift.id, modifiedAt: Date().addingTimeInterval(60), writerID: "other-device")]))
        await service.waitUntilSettled()
        XCTAssertTrue(center.requests.isEmpty)
    }
    func testDisableWhileSchedulingDoesNotLeaveAnOrphanedReminder() async {
        let (_, store, center, service, shift) = fixture()
        service.start(store: store); store.save(shift)
        center.blockNextAdd = true
        await service.setEnabled(true)
        while center.blockedAdd == nil { await Task.yield() }
        await service.setEnabled(false)
        center.blockedAdd?.resume(); center.blockedAdd = nil
        await service.waitUntilSettled()
        XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(service.queuedCount, 0)
    }
    func testPreferencesSurviveRelaunchAndRapidDisableWins() async {
        let (defaults, store, center, service, shift) = fixture()
        service.start(store: store); store.save(shift)
        await service.setEnabled(true)
        service.setLead(.sixHours)
        await service.setEnabled(false)
        await service.waitUntilSettled()
        let restored = ShiftNotifications(defaults: defaults, center: center)
        XCTAssertFalse(restored.enabled); XCTAssertEqual(restored.lead, .sixHours)
        XCTAssertTrue(center.requests.isEmpty)
    }
}
