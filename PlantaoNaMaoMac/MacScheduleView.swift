import SwiftUI

private struct MacNewShift: Identifiable { let id = UUID(); let date: Date }

struct MacScheduleView: View {
    @EnvironmentObject private var store: ShiftStore
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @Binding var selectedDate: Date
    @State private var newShift: MacNewShift?
    @State private var editing: Shift?
    @State private var deleting: Shift?
    @State private var report = false
    private var accent: Color { (ShiftColor(rawValue: theme) ?? .mint).value }
    private var monthly: [Shift] { Reports.select(store.shifts, kind: .schedule, month: selectedDate) }
    var body: some View {
        NavigationStack {
            HSplitView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedDate.formatted(.dateTime.month(.wide)).capitalized).font(.system(size: 36, weight: .bold, design: .rounded))
                                .accessibilityIdentifier("large-current-month")
                            Text(selectedDate.formatted(.dateTime.year())).foregroundStyle(.secondary)
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 34, height: 34) }.accessibilityLabel("Mês anterior")
                            Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 34, height: 34) }.accessibilityLabel("Próximo mês")
                        }.buttonStyle(.plain).glassSurface(radius: 20, interactive: true)
                    }
                    HStack(spacing: 20) {
                        Label("\(monthly.count) plantões", systemImage: "calendar")
                        Label("\(monthly.reduce(0) { $0 + $1.minutes } / 60)h", systemImage: "clock")
                        Spacer()
                        Text(Money.format(monthly.reduce(0) { $0 + $1.amountCents })).fontWeight(.semibold)
                    }.font(.callout).foregroundStyle(.secondary)
                    MonthCalendar(selectedDate: $selectedDate, accent: accent, compact: false, onMonthChange: moveMonth)
                        .padding(16).background(.background.opacity(0.85), in: RoundedRectangle(cornerRadius: 24))
                        .accessibilityElement(children: .contain).accessibilityIdentifier("fixed-calendar")
                    Button { newShift = MacNewShift(date: selectedDate) } label: { Label("Adicionar plantão", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!store.canWrite)
                    Spacer(minLength: 0)
                }.padding(28).frame(minWidth: 440, idealWidth: 530)
                dayAgenda.frame(minWidth: 300, idealWidth: 400)
            }
            .navigationTitle("Plantões")
            .toolbar {
                Button("Hoje") { selectedDate = Date() }
                Button { report = true } label: { Label("Exportar PDF", systemImage: "square.and.arrow.up") }
                Button { newShift = MacNewShift(date: selectedDate) } label: { Label("Novo plantão", systemImage: "plus") }.disabled(!store.canWrite)
            }
            .sheet(item: $newShift) { ShiftEditor(date: $0.date) }
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
            .sheet(isPresented: $report) { ReportView(month: selectedDate) }
            .confirmationDialog("Excluir este plantão?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Excluir", role: .destructive) { if let deleting { store.remove(deleting) }; deleting = nil }
            } message: { Text("A exclusão também será sincronizada com o iPhone.") }
        }
    }
    private var dayAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.title3.bold()).foregroundStyle(accent).padding(.horizontal, 20).padding(.top, 24)
            if store.on(selectedDate).isEmpty {
                ContentUnavailableView("Dia livre", systemImage: "calendar.badge.plus", description: Text("Adicione um plantão ou escolha outro dia no calendário."))
            }
            List {
                ForEach(store.on(selectedDate)) { shift in
                    Button { editing = shift } label: { ShiftRow(shift: shift) }.buttonStyle(.plain)
                        .listRowSeparator(.hidden).listRowBackground(Color.clear)
                        .contextMenu {
                            Button("Editar plantão") { editing = shift }
                            Button(shift.isPaid ? "Marcar como previsto" : "Marcar como pago") { store.togglePaid(shift) }.disabled(!store.canWrite)
                            Button("Excluir plantão", role: .destructive) { deleting = shift }.disabled(!store.canWrite)
                        }
                }
                if !monthly.isEmpty {
                    Section("Neste mês") {
                        ForEach(monthly.sorted { $0.interval.start < $1.interval.start }) { shift in
                            Button { selectedDate = shift.date; editing = shift } label: {
                                HStack(spacing: 10) {
                                    Circle().fill(shift.color.value).frame(width: 9, height: 9)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(shift.title).fontWeight(.medium)
                                        Text("\(shift.date.formatted(.dateTime.day().month())) · \(shift.location)").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(); Text(shift.amount).font(.caption)
                                }.padding(.vertical, 5)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.scrollContentBackground(.hidden)
        }
    }
    private func moveMonth(_ delta: Int) {
        selectedDate = Calendar.current.date(byAdding: .month, value: delta, to: selectedDate) ?? selectedDate
    }
}
