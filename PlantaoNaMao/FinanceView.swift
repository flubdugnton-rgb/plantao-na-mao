import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var start = Calendar.current.dateInterval(of: .month, for: Date())!.start
    @State private var end = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.dateInterval(of: .month, for: Date())!.end)!
    @State private var mode: PeriodMode = .dates
    @State private var basis: DateBasis = .payment
    @State private var editing: Shift?
    @State private var showingPDF = false
    @AppStorage("finance.inss.enabled") private var inssEnabled = false
    @AppStorage("finance.inss.rate") private var inssRate = "0,00"
    @AppStorage("finance.ir.enabled") private var irEnabled = false
    @AppStorage("finance.ir.rate") private var irRate = "0,00"
    private var period: FinancePeriod { FinancePeriod(start: start, end: end, mode: mode, basis: basis) }
    private var items: [Shift] { period.select(store.shifts) }
    private var plan: DeductionPlan { DeductionPlan(inssEnabled: inssEnabled, inssText: inssRate, irEnabled: irEnabled, irText: irRate) }
    private var totals: FinancialTotals { plan.totals(gross: items.reduce(0) { $0 + $1.amountCents }) }
    private var periodLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "pt_BR"); f.dateFormat = "dd/MM/yyyy"
        return "\(basis.rawValue): \(f.string(from: start)) a \(f.string(from: end))"
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Selecione o período") {
                    Picker("Selecionar por", selection: $mode) { ForEach(PeriodMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                        .onChange(of: mode) { _, value in basis = value == .competence ? .shift : .payment }
                    Picker("Referência", selection: $basis) { ForEach(DateBasis.allCases) { Text($0.rawValue).tag($0) } }
                    DatePicker(mode == .dates ? "Data inicial" : "Competência inicial", selection: $start, displayedComponents: .date)
                        .accessibilityIdentifier("finance-start")
                    DatePicker(mode == .dates ? "Data final" : "Competência final", selection: $end, displayedComponents: .date)
                        .accessibilityIdentifier("finance-end")
                    if period.bounds == nil { Text("O início precisa ser anterior ou igual ao fim.").foregroundStyle(.red) }
                }
                DeductionControls()
                Section("Previsão do período") {
                    LabeledContent("Plantões", value: "\(items.count)")
                    LabeledContent("Horas", value: "\(items.reduce(0) { $0 + $1.minutes } / 60)h \(items.reduce(0) { $0 + $1.minutes } % 60)min")
                    FinanceTotalsRows(totals: totals, valid: plan.valid)
                }
                Section {
                    if items.isEmpty { ContentUnavailableView("Sem plantões neste período", systemImage: "calendar", description: Text("Confira as datas e se a referência é pagamento ou plantão.")) }
                    ForEach(items) { shift in
                        Button { editing = shift } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack { Text(shift.title).font(.headline); Spacer(); Text(shift.amount).fontWeight(.semibold) }
                                Text(shift.location).font(.subheadline).foregroundStyle(.secondary)
                                Text((basis == .shift ? shift.date : shift.paymentDate ?? shift.date).formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            }.foregroundStyle(.primary).padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                } header: { Text("Plantões considerados") } footer: {
                    Text(basis == .payment ? "Plantões sem previsão de pagamento não entram neste filtro. Selecione a referência Plantão para incluí-los pela data trabalhada." : "O filtro considera a data de início de cada plantão. Escolha dia, mês e ano; as duas datas selecionadas são incluídas.")
                }
            }.navigationTitle("Financeiro")
                .toolbar { Button { showingPDF = true } label: { Image(systemName: "square.and.arrow.up") }.disabled(items.isEmpty || !plan.valid || period.bounds == nil).accessibilityLabel("Exportar previsão em PDF") }
                .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
                .sheet(isPresented: $showingPDF) { ReportView(month: start, initialKind: .payments, customShifts: items, customPeriod: periodLabel, financialSummary: totals.summary) }
        }
    }
}

struct DeductionControls: View {
    @AppStorage("finance.inss.enabled") private var inssEnabled = false
    @AppStorage("finance.inss.rate") private var inssRate = "0,00"
    @AppStorage("finance.ir.enabled") private var irEnabled = false
    @AppStorage("finance.ir.rate") private var irRate = "0,00"
    private var valid: Bool { DeductionPlan(inssEnabled: inssEnabled, inssText: inssRate, irEnabled: irEnabled, irText: irRate).valid }
    var body: some View {
        Section {
            Toggle("Descontar INSS", isOn: $inssEnabled)
            if inssEnabled { MoneyEntry(title: "INSS (%)", text: $inssRate) }
            Toggle("Descontar imposto de renda", isOn: $irEnabled)
            if irEnabled { MoneyEntry(title: "Imposto de renda (%)", text: $irRate) }
            if !valid { Text("Informe percentuais entre 0 e 100. A soma não pode ultrapassar 100%.").foregroundStyle(.red).font(.caption) }
        } header: { Text("Descontos opcionais") } footer: {
            Text("Cada percentual é aplicado diretamente sobre o valor bruto. Valores estimados, definidos por você; não usamos tabelas oficiais de INSS ou imposto de renda.")
        }
    }
}
struct FinanceTotalsRows: View {
    let totals: FinancialTotals
    let valid: Bool
    var body: some View {
        LabeledContent("Previsto bruto", value: Money.format(totals.gross)).fontWeight(.semibold)
        if valid {
            LabeledContent("INSS estimado", value: Money.format(totals.inss))
            LabeledContent("Imposto de renda estimado", value: Money.format(totals.incomeTax))
            LabeledContent("Previsto líquido", value: Money.format(totals.net)).font(.headline).foregroundStyle(.tint)
        }
    }
}
