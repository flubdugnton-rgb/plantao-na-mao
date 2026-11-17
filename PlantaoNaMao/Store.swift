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
        }
        catch { storageError = "Não foi possível ler seus plantões. Os dados originais foram preservados. Feche e reabra o app ou restaure seu backup antes de fazer alterações." }
    }

    func save(_ shift: Shift) {
        guard canWrite else { return }
        var updated = snapshot
        updated.records.removeAll { $0.shift.id == shift.id }
        updated.records.append(SyncRecord(shift: shift, modifiedAt: timestamp(for: shift.id), writerID: deviceID))
        persist(updated, localChange: true)
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
            if localChange { revision += 1 }
        } catch { storageError = "Não foi possível salvar. Seus plantões anteriores continuam preservados." }
    }
}

extension ShiftColor {
    var value: Color {
        switch self {
        case .mint: return Color(red: 0.04, green: 0.57, blue: 0.43)
        case .sage: return Color(red: 0.38, green: 0.56, blue: 0.34)
        case .emerald: return Color(red: 0.03, green: 0.52, blue: 0.32)
        case .lime: return Color(red: 0.43, green: 0.58, blue: 0.08)
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return Color(red: 0.84, green: 0.32, blue: 0.08)
        case .amber: return Color(red: 0.65, green: 0.43, blue: 0.02)
        case .teal: return .teal
        case .yellow: return Color(red: 0.92, green: 0.72, blue: 0.02)
        case .brown: return .brown
        case .gray: return .gray
        case .monochrome: return .primary
        case .sky: return Color(red: 0.12, green: 0.65, blue: 0.91)
        case .cyan: return .cyan
        case .lavender: return Color(red: 0.57, green: 0.46, blue: 0.85)
        case .coral: return Color(red: 0.96, green: 0.37, blue: 0.31)
        case .rose: return Color(red: 0.72, green: 0.31, blue: 0.48)
        case .navy: return Color(red: 0.17, green: 0.29, blue: 0.57)
        case .forest: return Color(red: 0.13, green: 0.42, blue: 0.26)
        case .peach: return Color(red: 0.94, green: 0.62, blue: 0.42)
        }
    }
}

struct ColorChoices: View {
    @Binding var selection: ShiftColor
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
            ForEach(ShiftColor.allCases) { color in
                Button { selection = color } label: {
                    VStack(spacing: 6) {
                        Circle().fill(color.value).frame(width: 38, height: 38)
                            .overlay { if selection == color { Image(systemName: "checkmark").font(.headline).foregroundStyle(color == .yellow || color == .peach ? Color.black : Color.white) } }
                        Text(color.name).font(.caption2).foregroundStyle(.primary)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
                    .accessibilityLabel(color.name).accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }.padding(.vertical, 8)
    }
}
