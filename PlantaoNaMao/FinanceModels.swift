import Foundation

enum PricingMode: String, Codable, CaseIterable, Identifiable {
    case shift = "Por plantão", hour = "Por hora"
    var id: String { rawValue }
    func total(rateCents: Int, minutes: Int) -> Int {
        self == .shift ? max(0, rateCents) : (max(0, rateCents) * max(0, minutes) + 30) / 60
    }
}

enum PeriodMode: String, CaseIterable, Identifiable {
    case dates = "Datas", competence = "Competências"
    var id: String { rawValue }
}
enum DateBasis: String, CaseIterable, Identifiable {
    case payment = "Pagamento", shift = "Plantão"
    var id: String { rawValue }
}

struct FinancePeriod {
    var start: Date
    var end: Date
    var mode: PeriodMode
    var basis: DateBasis
    var bounds: DateInterval? {
        let c = Calendar.current
        let first = mode == .dates ? c.startOfDay(for: start) : c.dateInterval(of: .month, for: start)!.start
        let last = mode == .dates ? c.date(byAdding: .day, value: 1, to: c.startOfDay(for: end))! : c.dateInterval(of: .month, for: end)!.end
        return first < last ? DateInterval(start: first, end: last) : nil
    }
    func select(_ shifts: [Shift]) -> [Shift] {
        guard let bounds else { return [] }
        return shifts.filter { shift in
            guard let date = basis == .shift ? shift.date : shift.paymentDate else { return false }
            return date >= bounds.start && date < bounds.end
        }.sorted { (basis == .shift ? $0.date : $0.paymentDate!) < (basis == .shift ? $1.date : $1.paymentDate!) }
    }
}

struct DeductionPlan {
    var inssEnabled = false
    var inssText = "0,00"
    var irEnabled = false
    var irText = "0,00"
    private var inssRate: Int? { inssEnabled ? Money.parse(inssText) : 0 }
    private var irRate: Int? { irEnabled ? Money.parse(irText) : 0 }
    var valid: Bool {
        guard let a = inssRate, let b = irRate else { return false }
        return a <= 10_000 && b <= 10_000 && a + b <= 10_000
    }
    func totals(gross: Int) -> FinancialTotals {
        guard valid, let a = inssRate, let b = irRate else { return FinancialTotals(gross: gross, inss: 0, incomeTax: 0) }
        let inss = (gross * a + 5_000) / 10_000
        let tax = min(max(0, gross - inss), (gross * b + 5_000) / 10_000)
        return FinancialTotals(gross: gross, inss: inss, incomeTax: tax)
    }
}
struct FinancialTotals {
    var gross: Int
    var inss: Int
    var incomeTax: Int
    var net: Int { gross - inss - incomeTax }
    var summary: [String] {
        ["Previsto bruto: \(Money.format(gross))", "INSS estimado: \(Money.format(inss))", "Imposto de renda estimado: \(Money.format(incomeTax))", "Previsto líquido: \(Money.format(net))", "Percentuais manuais sobre o bruto; estimativa sem tabela oficial."]
    }
}
struct MonthlySummary: Identifiable {
    let date: Date
    let shifts: [Shift]
    var id: Date { date }
    var minutes: Int { shifts.reduce(0) { $0 + $1.minutes } }
    var gross: Int { shifts.reduce(0) { $0 + $1.amountCents } }
    static func build(_ shifts: [Shift], now: Date = Date()) -> [MonthlySummary] {
        let c = Calendar.current
        let grouped = Dictionary(grouping: shifts) { c.dateInterval(of: .month, for: $0.date)!.start }
        let current = c.dateInterval(of: .month, for: now)!.start
        let first = min(grouped.keys.min() ?? current, current)
        let last = max(grouped.keys.max() ?? current, current)
        var date = first; var result: [MonthlySummary] = []
        while date <= last {
            result.append(MonthlySummary(date: date, shifts: grouped[date] ?? []))
            guard let next = c.date(byAdding: .month, value: 1, to: date), next > date else { break }
            date = next
        }
        return result
    }
}

extension Date {
    var clock24: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "HH:mm"
        return f.string(from: self)
    }
}
