import SwiftUI

struct FinanceView: View {
    @EnvironmentObject private var store: ShiftStore
    @State private var month = Date()
    @State private var filter: PaymentFilter = .all
    @State private var allDates = false
    @State private var editing: Shift?
    @State private var showingReports = false
    private var monthly: [Shift] { Reports.select(store.shifts, kind: .payments, month: allDates ? nil : month) }
    private var shown: [Shift] { monthly.filter { filter.includes($0) } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Todos os períodos", isOn: $allDates)
                    if !allDates { DatePicker("Mês de pagamento", selection: $month, displayedComponents: .date) }
                } footer: { Text("O financeiro considera o mês da previsão de pagamento, mesmo que o plantão aconteça em outro mês.") }
                Section("Visão dos pagamentos") {
                    summary("Previsto", monthly.reduce(0) { $0 + $1.amountCents }, icon: "banknote", color: .primary)
                    summary("Recebido", monthly.filter(\.isPaid).reduce(0) { $0 + $1.amountCents }, icon: "checkmark.circle", color: .green)
                    summary("A receber", monthly.filter { !$0.isPaid }.reduce(0) { $0 + $1.amountCents }, icon: "clock", color: .orange)
                    let overdue = monthly.filter { $0.overdue() }
                    if !overdue.isEmpty { summary("Em atraso", overdue.reduce(0) { $0 + $1.amountCents }, icon: "exclamationmark.circle", color: .red) }
                }
                Section {
                    Picker("Situação", selection: $filter) { ForEach(PaymentFilter.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    if shown.isEmpty { ContentUnavailableView("Sem pagamentos neste filtro", systemImage: "banknote", description: Text("Cadastre o valor e a previsão de pagamento nos seus plantões.")) }
                    ForEach(shown) { shift in
                        Button { editing = shift } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(shift.title).font(.headline); Spacer(); Text(shift.amount).font(.headline) }
                                Text(shift.location).font(.subheadline).foregroundStyle(.secondary)
                                HStack {
                                    Text(shift.paymentDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "Sem previsão")
                                    Spacer()
                                    Text(shift.isPaid ? "Recebido" : shift.overdue() ? "Em atraso" : "A receber")
                                        .foregroundStyle(shift.isPaid ? Color.green : shift.overdue() ? Color.red : Color.orange)
                                }.font(.caption)
                            }.foregroundStyle(.primary).padding(.vertical, 4)
                        }.buttonStyle(.plain)
                            .swipeActions(edge: .leading) {
                                Button(shift.isPaid ? "Marcar pendente" : "Marcar recebido") { store.togglePaid(shift) }.tint(.green).disabled(!store.canWrite)
                            }
                    }
                } header: { Text("Pagamentos") } footer: { Text("Deslize um registro para a direita para atualizar o recebimento.") }
                if !allDates {
                    let undated = store.shifts.filter { $0.amountCents > 0 && $0.paymentDate == nil }
                    if !undated.isEmpty {
                        Section("Sem data de pagamento · \(undated.count)") {
                            ForEach(undated) { shift in
                                Button { editing = shift } label: {
                                    HStack { Text(shift.title); Spacer(); Text(shift.amount) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Financeiro")
            .toolbar { Button { showingReports = true } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Exportar pagamentos em PDF") }
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
            .sheet(isPresented: $showingReports) { ReportView(month: month, initialKind: .payments, initialAllDates: allDates, initialFilter: filter) }
        }
    }
    private func summary(_ title: String, _ amount: Int, icon: String, color: Color) -> some View {
        HStack { Label(title, systemImage: icon).foregroundStyle(color); Spacer(); Text(Money.format(amount)).fontWeight(.semibold) }
    }
}

struct LocationsView: View {
    @EnvironmentObject private var store: ShiftStore
    var body: some View {
        NavigationStack {
            List {
                if store.locations.isEmpty {
                    ContentUnavailableView("Seus locais de trabalho", systemImage: "building.2", description: Text("Os locais aparecem aqui quando você cadastra seus plantões."))
                }
                ForEach(store.locations, id: \.self) { location in
                    NavigationLink {
                        LocationDetailView(location: location)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "building.2.crop.circle.fill").font(.title).foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location).font(.headline)
                                Text("\(store.shifts.filter { $0.location == location }.count) plantões cadastrados").font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 6)
                    }
                }
            }.navigationTitle("Locais de trabalho")
        }
    }
}

struct LocationDetailView: View {
    @EnvironmentObject private var store: ShiftStore
    let location: String
    @State private var editing: Shift?
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(store.shifts.filter { $0.location == location }.sorted { $0.interval.start > $1.interval.start }) { shift in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shift.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        Button { editing = shift } label: { ShiftRow(shift: shift) }.buttonStyle(.plain)
                    }
                }
            }.padding()
        }.background(Color(.systemGroupedBackground)).navigationTitle(location)
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
    }
}
