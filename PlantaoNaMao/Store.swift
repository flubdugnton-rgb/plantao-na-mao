import SwiftUI

final class ShiftStore: ObservableObject {
    @Published private(set) var shifts: [Shift] = []
    @Published private(set) var storageError: String?
    private let defaults: UserDefaults
    private let key = "plantao-na-mao.shifts"
    var canWrite: Bool { storageError == nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do { shifts = try JSONDecoder().decode([Shift].self, from: data) }
        catch { storageError = "Não foi possível ler seus plantões. Os dados originais foram preservados. Feche e reabra o app ou restaure seu backup antes de fazer alterações." }
    }

    func save(_ shift: Shift) {
        guard canWrite else { return }
        var updated = shifts
        if let i = updated.firstIndex(where: { $0.id == shift.id }) { updated[i] = shift }
        else { updated.append(shift) }
        persist(updated.sorted { $0.interval.start < $1.interval.start })
    }
    func remove(_ shift: Shift) { guard canWrite else { return }; persist(shifts.filter { $0.id != shift.id }) }
    func togglePaid(_ shift: Shift) {
        var changed = shift; changed.isPaid.toggle(); save(changed)
    }
    func on(_ day: Date) -> [Shift] {
        shifts.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.interval.start < $1.interval.start }
    }
    var locations: [String] { Array(Set(shifts.map(\.location))).sorted { $0.localizedStandardCompare($1) == .orderedAscending } }
    private func persist(_ updated: [Shift]) {
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: key); shifts = updated
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
                            .overlay { if selection == color { Image(systemName: "checkmark").font(.headline).foregroundStyle(.white) } }
                        Text(color.name).font(.caption2).foregroundStyle(.primary)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain)
                    .accessibilityLabel(color.name).accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }.padding(.vertical, 8)
    }
}
