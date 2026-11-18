import SwiftUI

final class ShiftStore: ObservableObject {
    @Published private(set) var shifts: [Shift] = []
    @Published private(set) var storageError: String?
    @Published private(set) var revision = 0
    private(set) var snapshot = SyncSnapshot()
    let deviceID: String
    private let defaults: UserDefaults
    private let key = "plantao-na-mao.shifts"
    private let syncKey = "plantao-na-mao.sync-state.v1"
    var canWrite: Bool { storageError == nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        deviceID = defaults.string(forKey: "plantao-na-mao.device-id") ?? UUID().uuidString
        defaults.set(deviceID, forKey: "plantao-na-mao.device-id")
        do {
            if let data = defaults.data(forKey: syncKey) {
                snapshot = try JSONDecoder().decode(SyncSnapshot.self, from: data).validated()
            } else if let data = defaults.data(forKey: key) {
                let legacy = try JSONDecoder().decode([Shift].self, from: data)
                snapshot = SyncMerge.combine([SyncSnapshot(records: legacy.map {
                    SyncRecord(shift: $0, modifiedAt: Date(timeIntervalSince1970: 0), writerID: deviceID)
                })])
            }
            shifts = snapshot.visibleShifts
            WidgetBridge.publish(shifts)
        }
        catch { storageError = "Não foi possível ler seus plantões. Os dados originais foram preservados. Feche e reabra o app ou restaure seu backup antes de fazer alterações." }
    }

    @discardableResult
    func save(_ shift: Shift) -> Bool {
        guard canWrite else { return false }
        if snapshot.records.first(where: { $0.shift.id == shift.id })?.shift == shift { return true }
        var updated = snapshot
        updated.records.removeAll { $0.shift.id == shift.id }
        updated.records.append(SyncRecord(shift: shift, modifiedAt: timestamp(for: shift.id), writerID: deviceID))
        persist(updated, localChange: true)
        return canWrite && shifts.contains(where: { $0.id == shift.id })
    }
    func remove(_ shift: Shift) {
        guard canWrite else { return }
        var updated = snapshot
        updated.deletions.removeAll { $0.id == shift.id }
        updated.deletions.append(SyncDeletion(id: shift.id, modifiedAt: timestamp(for: shift.id), writerID: deviceID))
        persist(updated, localChange: true)
    }
    func mergeRemote(_ remote: SyncSnapshot) throws {
        guard canWrite else { throw SyncFailure.invalidData }
        persist(SyncMerge.combine([snapshot, try remote.validated()]), localChange: false)
        if !canWrite { throw SyncFailure.invalidData }
    }
    func togglePaid(_ shift: Shift) {
        var changed = shift; changed.isPaid.toggle(); save(changed)
    }
    func on(_ day: Date) -> [Shift] {
        shifts.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.interval.start < $1.interval.start }
    }
    var recent: [Shift] {
        snapshot.records.sorted { ($0.shift.createdAt ?? $0.modifiedAt) > ($1.shift.createdAt ?? $1.modifiedAt) }.prefix(3).map(\.shift)
    }
    var locations: [String] { Array(Set(shifts.map(\.location))).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    private func timestamp(for id: UUID) -> Date {
        let edit = snapshot.records.first { $0.shift.id == id }?.modifiedAt ?? .distantPast
        let deletion = snapshot.deletions.first { $0.id == id }?.modifiedAt ?? .distantPast
        return max(Date(), max(edit, deletion).addingTimeInterval(0.001))
    }
    private func persist(_ updated: SyncSnapshot, localChange: Bool) {
        do {
            let normalized = SyncMerge.combine([updated])
            let data = try JSONEncoder().encode(normalized)
            let legacy = try JSONEncoder().encode(normalized.visibleShifts)
            defaults.set(data, forKey: syncKey)
            defaults.set(legacy, forKey: key)
            snapshot = normalized; shifts = normalized.visibleShifts
            WidgetBridge.publish(shifts)
            if localChange { revision += 1 }
        } catch { storageError = "Não foi possível salvar. Seus plantões anteriores continuam preservados." }
    }
}

