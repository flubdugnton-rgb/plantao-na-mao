import SwiftUI

@main
struct PlantaoNaMaoApp: App {
    @StateObject private var store = ShiftStore()
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @AppStorage("plantao-na-mao.appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                .tint((ShiftColor(rawValue: theme) ?? .mint).value)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .environment(\.locale, Locale(identifier: "pt_BR"))
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: ShiftStore
    var body: some View {
        VStack(spacing: 0) {
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).padding().background(Color.orange.opacity(0.15))
            }
            TabView {
                ScheduleView().tabItem { Label("Escala", systemImage: "calendar") }
                FinanceView().tabItem { Label("Financeiro", systemImage: "banknote") }
                LocationsView().tabItem { Label("Locais", systemImage: "building.2") }
                SettingsView().tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }
            }
        }
    }
}

struct ScheduleView: View {
    @EnvironmentObject private var store: ShiftStore
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @State private var selectedDate = Date()
    @State private var showingEditor = false
    @State private var editing: Shift?
    @State private var showingReports = false
    private var accent: Color { (ShiftColor(rawValue: theme) ?? .mint).value }
    private var monthly: [Shift] { Reports.select(store.shifts, kind: .schedule, month: selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    overview
                    calendarCard
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Seus plantões").font(.title3.bold())
                            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { showingEditor = true } label: { Image(systemName: "plus.circle.fill").font(.title) }
                            .accessibilityLabel("Adicionar plantão").disabled(!store.canWrite)
                    }
                    let items = store.on(selectedDate)
                    if items.isEmpty {
                        ContentUnavailableView {
                            Label("Seu dia está livre", systemImage: "calendar.badge.plus")
                        } description: { Text("Cadastre um plantão e deixe sua escala organizada.") }
                        actions: { Button("Adicionar plantão") { showingEditor = true }.disabled(!store.canWrite) }
                    }
                    ForEach(items) { shift in
                        Button { editing = shift } label: { ShiftRow(shift: shift) }.buttonStyle(.plain)
                    }
                }.padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plantão na Mão")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Hoje") { selectedDate = .now } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingReports = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Exportar relatórios em PDF")
                }
            }
            .sheet(isPresented: $showingEditor) { ShiftEditor(date: selectedDate) }
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
            .sheet(isPresented: $showingReports) { ReportView(month: selectedDate) }
        }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("SUA ROTINA, MAIS LEVE", systemImage: "sun.max")
                    .font(.caption.weight(.semibold)).tracking(1)
                Spacer(); Image(systemName: "cross.case.fill").font(.title2)
            }
            Text("Tudo sob controle.\nUm plantão por vez.").font(.title2.bold())
            HStack(alignment: .top, spacing: 12) {
                metric("Plantões no mês", "\(monthly.count)")
                Spacer()
                metric("Horas na escala", "\(monthly.reduce(0) { $0 + $1.minutes } / 60)h")
                Spacer()
                metric("Valor no mês", Money.format(monthly.reduce(0) { $0 + $1.amountCents }))
            }
        }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [accent, accent.opacity(0.80), accent.opacity(0.70)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value).font(.headline).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.85))
        }
    }
    private var calendarCard: some View {
        let calendar = Calendar.current
        let days = calendar.range(of: .day, in: .month, for: selectedDate).map(Array.init) ?? []
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let symbols = ["D", "S", "T", "Q", "Q", "S", "S"]
        return VStack(spacing: 16) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").padding(8) }.accessibilityLabel("Mês anterior")
                Spacer()
                Text(selectedDate.formatted(.dateTime.month(.wide).year()).capitalized).font(.headline)
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right").padding(8) }.accessibilityLabel("Próximo mês")
            }
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text(symbols[(calendar.firstWeekday - 1 + i) % 7]).font(.caption.bold())
                        .frame(maxWidth: .infinity).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 6) {
                ForEach(0..<(offset + days.count), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: 46) }
                    else {
                        let day = days[index - offset]
                        let date = calendar.date(byAdding: .day, value: day - 1, to: first) ?? first
                        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let items = store.on(date)
                        Button { selectedDate = date } label: {
                            VStack(spacing: 5) {
                                Text("\(day)").font(.subheadline.weight(selected ? .bold : .regular))
                                HStack(spacing: 2) {
                                    ForEach(Array(items.prefix(3))) { shift in
                                        Circle().fill(selected ? Color.white : shift.color.value).frame(width: 4, height: 4)
                                    }
                                }.frame(height: 4)
                            }
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background(selected ? accent : calendar.isDateInToday(date) ? accent.opacity(0.1) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(items.count) plantões")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }.padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 22))
    }
    private func moveMonth(_ amount: Int) {
        selectedDate = Calendar.current.date(byAdding: .month, value: amount, to: selectedDate) ?? selectedDate
    }
}

struct ShiftRow: View {
    let shift: Shift
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(shift.color.value).frame(width: 5)
            VStack(alignment: .leading, spacing: 6) {
                Text(shift.title).font(.headline)
                Label(shift.location, systemImage: "mappin").font(.subheadline).foregroundStyle(.secondary)
                Text("\(shift.start.formatted(date: .omitted, time: .shortened)) – \(shift.end.formatted(date: .omitted, time: .shortened)) · \(shift.duration)")
                    .font(.caption).foregroundStyle(.secondary)
                if shift.amountCents > 0 {
                    Text("\(shift.amount) · \(shift.isPaid ? "Recebido" : "A receber")").font(.caption.weight(.semibold))
                    if let due = shift.paymentDate {
                        Text("Pagamento: \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2).foregroundStyle(shift.overdue() ? Color.red : Color.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(16).background(Color(.secondarySystemGroupedBackground)).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
