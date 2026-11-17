import Foundation

enum ShiftColor: String, Codable, CaseIterable, Identifiable {
    // Preserve the four identifiers used by version 1.0.
    case mint, sage, emerald, lime, blue, indigo, purple, pink, red, orange, amber, teal
    case yellow, brown, gray, monochrome, sky, cyan, lavender, coral, rose, navy, forest, peach
    var id: String { rawValue }
    var name: String {
        switch self {
        case .mint: return "Menta"
        case .sage: return "Sálvia"
        case .emerald: return "Esmeralda"
        case .lime: return "Lima"
        case .blue: return "Azul"
        case .indigo: return "Índigo"
        case .purple: return "Roxo"
        case .pink: return "Rosa"
        case .red: return "Vermelho"
        case .orange: return "Laranja"
        case .amber: return "Âmbar"
        case .teal: return "Petróleo"
        case .yellow: return "Amarelo"
        case .brown: return "Marrom"
        case .gray: return "Cinza"
        case .monochrome: return "Preto / branco"
        case .sky: return "Azul-céu"
        case .cyan: return "Ciano"
        case .lavender: return "Lavanda"
        case .coral: return "Coral"
        case .rose: return "Rosé"
        case .navy: return "Azul-marinho"
        case .forest: return "Floresta"
        case .peach: return "Pêssego"
        }
    }
}

struct Shift: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var location: String
    var start: Date
    var end: Date
    var color: ShiftColor = .mint
    var notes = ""
    var amountCents = 0
    var paymentDate: Date?
    var isPaid = false

    enum CodingKeys: String, CodingKey {
        case id, date, title, location, start, end, color, notes, amountCents, paymentDate, isPaid
    }

    init(id: UUID = UUID(), date: Date, title: String, location: String, start: Date, end: Date,
         color: ShiftColor = .mint, notes: String = "", amountCents: Int = 0,
         paymentDate: Date? = nil, isPaid: Bool = false) {
        self.id = id; self.date = date; self.title = title; self.location = location
        self.start = start; self.end = end; self.color = color; self.notes = notes
        self.amountCents = amountCents; self.paymentDate = paymentDate; self.isPaid = isPaid
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        title = try c.decode(String.self, forKey: .title)
        location = try c.decode(String.self, forKey: .location)
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decode(Date.self, forKey: .end)
        color = try c.decodeIfPresent(ShiftColor.self, forKey: .color) ?? .mint
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        amountCents = max(0, try c.decodeIfPresent(Int.self, forKey: .amountCents) ?? 0)
        paymentDate = try c.decodeIfPresent(Date.self, forKey: .paymentDate)
        isPaid = try c.decodeIfPresent(Bool.self, forKey: .isPaid) ?? false
    }

    var interval: DateInterval { ShiftRules.interval(day: date, start: start, end: end) }
    var minutes: Int { Int(interval.duration / 60) }
    var duration: String { "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)min")" }
    var amount: String { Money.format(amountCents) }
    func overdue(on today: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard !isPaid, amountCents > 0, let paymentDate else { return false }
        return calendar.startOfDay(for: paymentDate) < calendar.startOfDay(for: today)
    }
}

enum Money {
    static func parse(_ text: String) -> Int? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty { return 0 }
        // Some iPhone keyboards use a decimal point even with a Portuguese UI.
        if !cleaned.contains(","), cleaned.contains(".") {
            let groups = cleaned.split(separator: ".", omittingEmptySubsequences: false)
            if groups.count == 2, (1...2).contains(groups[1].count) {
                cleaned = groups.joined(separator: ",")
            }
        }
        let pieces = cleaned.split(separator: ",", omittingEmptySubsequences: false)
        guard pieces.count <= 2 else { return nil }
        let groups = pieces[0].split(separator: ".", omittingEmptySubsequences: false)
        if groups.count > 1 {
            guard (1...3).contains(groups[0].count), groups.dropFirst().allSatisfy({ $0.count == 3 }) else { return nil }
        }
        let whole = groups.joined()
        let fraction = pieces.count == 2 ? String(pieces[1]) : ""
        guard !whole.isEmpty, whole.allSatisfy({ $0.isASCII && $0.isNumber }),
              fraction.count <= 2, fraction.allSatisfy({ $0.isASCII && $0.isNumber }),
              let units = Int(whole), units <= 999_999_999,
              let cents = Int(fraction.padding(toLength: 2, withPad: "0", startingAt: 0)) else { return nil }
        return units * 100 + cents
    }
    static func input(_ cents: Int) -> String { String(format: "%d,%02d", cents / 100, cents % 100) }
    static func format(_ cents: Int) -> String {
        let f = NumberFormatter(); f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency; f.currencyCode = "BRL"
        return f.string(from: NSNumber(value: Double(cents) / 100)) ?? "R$ 0,00"
    }
}

enum ShiftRules {
    static func interval(day: Date, start: Date, end: Date, calendar: Calendar = .current) -> DateInterval {
        func time(_ value: Date) -> Date {
            let t = calendar.dateComponents([.hour, .minute], from: value)
            return calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day) ?? day
        }
        let first = time(start); var last = time(end)
        if last <= first { last = calendar.date(byAdding: .day, value: 1, to: last) ?? last }
        return DateInterval(start: first, end: last)
    }
    static func paymentDate(for date: Date, day: Int, nextMonth: Bool, calendar: Calendar = .current) -> Date {
        let month = calendar.date(byAdding: .month, value: nextMonth ? 1 : 0, to: date) ?? date
        var parts = calendar.dateComponents([.year, .month], from: month)
        let last = calendar.range(of: .day, in: .month, for: month)?.count ?? 28
        parts.day = min(max(day, 1), last)
        return calendar.date(from: parts) ?? month
    }
    static func inMonth(_ date: Date, month: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }
}

enum ReportKind: String, CaseIterable, Identifiable {
    case schedule = "Escala de plantões", payments = "Pagamentos"
    var id: String { rawValue }
}

enum PaymentFilter: String, CaseIterable, Identifiable {
    case all = "Todos", pending = "A receber", paid = "Recebidos"
    var id: String { rawValue }
    func includes(_ shift: Shift) -> Bool {
        switch self { case .all: return true; case .pending: return !shift.isPaid; case .paid: return shift.isPaid }
    }
}

enum Reports {
    static func select(_ shifts: [Shift], kind: ReportKind, month: Date?, filter: PaymentFilter = .all) -> [Shift] {
        shifts.filter { shift in
            guard kind == .schedule || shift.amountCents > 0 else { return false }
            guard filter.includes(shift) else { return false }
            guard let month else { return true }
            if kind == .schedule { return ShiftRules.inMonth(shift.date, month: month) }
            guard let due = shift.paymentDate else { return false }
            return ShiftRules.inMonth(due, month: month)
        }.sorted {
            let a = kind == .schedule ? $0.interval.start : ($0.paymentDate ?? .distantFuture)
            let b = kind == .schedule ? $1.interval.start : ($1.paymentDate ?? .distantFuture)
            return a == b ? $0.title < $1.title : a < b
        }
    }
}
