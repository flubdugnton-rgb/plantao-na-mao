import SwiftUI
import Charts
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var store: ShiftStore
    @AppStorage("finance.inss.enabled") private var inssEnabled = false
    @AppStorage("finance.inss.rate") private var inssRate = "0,00"
    @AppStorage("finance.ir.enabled") private var irEnabled = false
    @AppStorage("finance.ir.rate") private var irRate = "0,00"
    @State private var selected: Date?
    @State private var referenceDate = Date()
    private var months: [MonthlySummary] { MonthlySummary.build(store.shifts, now: referenceDate) }
    private var current: MonthlySummary { months.first { Calendar.current.isDate($0.date, equalTo: selected ?? referenceDate, toGranularity: .month) } ?? MonthlySummary(date: Calendar.current.dateInterval(of: .month, for: selected ?? referenceDate)!.start, shifts: []) }
    private var plan: DeductionPlan { DeductionPlan(inssEnabled: inssEnabled, inssText: inssRate, irEnabled: irEnabled, irText: irRate) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    MonthChoice(title: "Competência do painel", date: Binding(get: { selected ?? referenceDate }, set: { selected = $0 }))
                    LabeledContent("Plantões", value: "\(current.shifts.count)")
                    LabeledContent("Horas trabalhadas", value: "\(current.minutes / 60)h \(current.minutes % 60)min")
                    FinanceTotalsRows(totals: plan.totals(gross: current.gross), valid: plan.valid)
                }
                Section("Evolução · últimos 12 meses registrados") {
                    Chart(Array(months.suffix(12))) { month in
                        BarMark(x: .value("Mês", month.date, unit: .month), y: .value("Bruto", Double(month.gross) / 100)).foregroundStyle(ShiftColor.mint.value)
                        if plan.valid { LineMark(x: .value("Mês", month.date, unit: .month), y: .value("Líquido", Double(plan.totals(gross: month.gross).net) / 100)).foregroundStyle(.blue) }
                    }.frame(height: 190)
                    Text(plan.valid ? "Barras: bruto. Linha azul: líquido estimado com os descontos escolhidos no Financeiro." : "Barras: bruto. Corrija os percentuais no Financeiro para visualizar o líquido.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Histórico mensal completo") {
                    ForEach(months.reversed()) { month in
                        Button { selected = month.date } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(month.date.formatted(.dateTime.month(.wide).year()).capitalized).font(.headline)
                                    Text("\(month.shifts.count) plantões · \(month.minutes / 60)h \(month.minutes % 60)min").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(Money.format(month.gross)).fontWeight(.semibold)
                                    if plan.valid { Text("Líquido: \(Money.format(plan.totals(gross: month.gross).net))").font(.caption).foregroundStyle(.secondary) }
                                }
                            }.foregroundStyle(.primary)
                        }.buttonStyle(.plain)
                    }
                }
                Section("Acumulado cadastrado") {
                    LabeledContent("Plantões", value: "\(store.shifts.count)")
                    LabeledContent("Bruto", value: Money.format(store.shifts.reduce(0) { $0 + $1.amountCents }))
                }
            }.navigationTitle("Painel mensal")
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in referenceDate = Date() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in referenceDate = Date() }
        }
    }
}
