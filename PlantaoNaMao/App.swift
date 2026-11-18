import SwiftUI
import GoogleSignIn

@main
struct PlantaoNaMaoApp: App {
    @UIApplicationDelegateAdaptor(NotificationAppDelegate.self) private var appDelegate
    @StateObject private var reminders = ShiftNotifications()
    @StateObject private var store = AppLaunch.makeStore()
    @StateObject private var cloud = GoogleSyncController()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @AppStorage("plantao-na-mao.appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).environmentObject(cloud).environmentObject(reminders)
                .tint((ShiftColor(rawValue: theme) ?? .mint).value)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .onOpenURL { url in
                    if url.scheme == "plantaonamao" { UserDefaults.standard.set(url.absoluteString, forKey: "widget.pendingURL"); NotificationCenter.default.post(name: .widgetDateSelected, object: url) }
                    else { GIDSignIn.sharedInstance.handle(url) }
                }
                .task { reminders.start(store: store); await cloud.start(store: store) }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in reminders.refresh() }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in reminders.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { reminders.refresh(); WidgetBridge.publish(store.shifts); Task { await cloud.resume() } }
                    else { cloud.pause(); WidgetBridge.publish(store.shifts) }
                }
        }
    }
}

struct ContentView: View {
    @State private var tab = 0
    @EnvironmentObject private var store: ShiftStore
    var body: some View {
        VStack(spacing: 0) {
            if let error = store.storageError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).padding().background(Color.orange.opacity(0.15))
            }
            TabView(selection: $tab) {
                ScheduleView().tabItem { Label("Plantões", systemImage: "calendar") }.tag(0)
                FinanceView().tabItem { Label("Financeiro", systemImage: "chart.bar.xaxis") }.tag(1)
                DashboardView().tabItem { Label("Painel", systemImage: "chart.bar.fill") }.tag(2)
                LocationsView().tabItem { Label("Locais", systemImage: "building.2") }.tag(3)
                SettingsView().tabItem { Label("Ajustes", systemImage: "slider.horizontal.3") }.tag(4)
            }
        }.onReceive(NotificationCenter.default.publisher(for: .widgetDateSelected)) { _ in tab = 0 }
    }
}

private struct NewShiftRequest: Identifiable {
    let id = UUID()
    let date: Date
}

struct ScheduleView: View {
    @EnvironmentObject private var store: ShiftStore
    @AppStorage("plantao-na-mao.theme") private var theme = ShiftColor.mint.rawValue
    @State private var selectedDate = AppLaunch.initialDate
    @State private var newShift: NewShiftRequest?
    @State private var editing: Shift?
    @State private var showingReports = false
    @State private var pendingDeletion: Shift?
    private var accent: Color { (ShiftColor(rawValue: theme) ?? .mint).value }
    private var monthly: [Shift] { Reports.select(store.shifts, kind: .schedule, month: selectedDate) }
    private var daysAhead: [Date] {
        let c = Calendar.current
        let first = c.dateInterval(of: .month, for: selectedDate)!.start
        let count = c.range(of: .day, in: .month, for: selectedDate)!.count
        return (0..<count).compactMap { c.date(byAdding: .day, value: $0, to: first) }
    }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let compact = geometry.size.height < 450
                // Only the agenda scrolls. The month and calendar remain fixed.
                VStack(spacing: compact ? 6 : 12) {
                    monthHeader(compact: compact)
                    MonthCalendar(selectedDate: $selectedDate, accent: accent, compact: compact)
                        .padding(.horizontal, 10).padding(.vertical, compact ? 4 : 8)
                        .background(Color(.secondarySystemGroupedBackground).opacity(0.8), in: RoundedRectangle(cornerRadius: 24))
                        .padding(.horizontal, 12)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("fixed-calendar")
                    agenda
                }
            }
            .background { AppBackdrop() }
            .navigationTitle("Plantão na Mão").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Hoje") { selectedDate = .now } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingReports = true } label: { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Exportar PDF")
                    Button { newShift = NewShiftRequest(date: selectedDate) } label: { Image(systemName: "plus") }.accessibilityLabel("Adicionar plantão").disabled(!store.canWrite)
                }
            }
            .alert("Excluir este plantão?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
                Button("Cancelar", role: .cancel) { pendingDeletion = nil }
                Button("Excluir", role: .destructive) { if let item = pendingDeletion { store.remove(item) }; pendingDeletion = nil }
            } message: { Text("O plantão e sua previsão de pagamento serão removidos. Esta alteração também será sincronizada.") }
            .sheet(item: $newShift) { request in ShiftEditor(date: request.date) }
            .sheet(item: $editing) { ShiftEditor(date: $0.date, shift: $0) }
            .sheet(isPresented: $showingReports) { ReportView(month: selectedDate) }
            .onAppear { applyWidgetURL() }
            .onReceive(NotificationCenter.default.publisher(for: .widgetDateSelected)) { event in
                guard let url = event.object as? URL, let date = WidgetData.date(from: url) else { return }
                selectedDate = date
                openNotificationShift(url)
                UserDefaults.standard.removeObject(forKey: "widget.pendingURL")
            }
        }
    }
    private func monthHeader(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(selectedDate.formatted(.dateTime.month(.wide)).capitalized)
                        .font(.system(size: compact ? 26 : 38, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityIdentifier("large-current-month")
                    if !compact { Text(selectedDate.formatted(.dateTime.year())).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Button { moveMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel("Mês anterior")
                    Button { moveMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel("Próximo mês")
                }.font(.headline).glassSurface(radius: 24, interactive: true)
            }
            if !compact {
                HStack(spacing: 14) {
                    Label("\(monthly.count) plantões", systemImage: "calendar")
                    Label("\(monthly.reduce(0) { $0 + $1.minutes } / 60)h", systemImage: "clock")
                    Spacer(minLength: 0)
                    Text(Money.format(monthly.reduce(0) { $0 + $1.amountCents })).fontWeight(.semibold)
                }.font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
        }.padding(.horizontal, 22).padding(.top, 8)
    }
    private var agenda: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(daysAhead, id: \.self) { day in
                    Section {
                        let items = store.on(day)
                        if items.isEmpty {
                            Label("Sem plantão", systemImage: "minus").font(.subheadline).foregroundStyle(.secondary)
                                .listRowBackground(Color.clear)
                        }
                        ForEach(items) { shift in
                            Button { editing = shift } label: { ShiftRow(shift: shift) }.buttonStyle(.plain).accessibilityIdentifier("shift-row-\(Calendar.current.component(.day, from: shift.date))")
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button { pendingDeletion = shift } label: { Label("Excluir", systemImage: "trash") }.tint(.red).disabled(!store.canWrite)
                                    Button { editing = shift } label: { Label("Editar", systemImage: "pencil") }.tint(.orange).disabled(!store.canWrite)
                                }
                        }
                    } header: {
                        Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDate(day, inSameDayAs: selectedDate) ? accent : Color.secondary)
                    }.id(day)
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
                .accessibilityIdentifier("scrolling-agenda")
                .task(id: Calendar.current.startOfDay(for: selectedDate)) { @MainActor in
                    // List must finish its first layout before scrolling to an off-screen section.
                    // All earlier days stay in the List and remain reachable by scrolling back.
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    proxy.scrollTo(Calendar.current.startOfDay(for: selectedDate), anchor: .top)
                }
        }
    }
    private func applyWidgetURL() {
        guard let string = UserDefaults.standard.string(forKey: "widget.pendingURL"), let url = URL(string: string) else { return }
        if let date = WidgetData.date(from: url) { selectedDate = date; openNotificationShift(url) }
        UserDefaults.standard.removeObject(forKey: "widget.pendingURL")
    }

    private func openNotificationShift(_ url: URL) {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "shift" })?.value,
              let id = UUID(uuidString: value) else { return }
        if let shift = store.shifts.first(where: { $0.id == id }) { selectedDate = shift.date; editing = shift }
    }

    private func moveMonth(_ delta: Int) {
        selectedDate = Calendar.current.date(byAdding: .month, value: delta, to: selectedDate) ?? selectedDate
    }
}

struct MonthCalendar: View {
    @EnvironmentObject private var store: ShiftStore
    @Binding var selectedDate: Date
    let accent: Color
    let compact: Bool
    private var calendar: Calendar { Calendar.current }
    private var first: Date { calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) ?? selectedDate }
    private var offset: Int { (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7 }
    private var count: Int { calendar.range(of: .day, in: .month, for: selectedDate)?.count ?? 30 }
    var body: some View {
        VStack(spacing: compact ? 2 : 7) {
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    Text(["D", "S", "T", "Q", "Q", "S", "S"][(calendar.firstWeekday - 1 + i) % 7])
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: compact ? 1 : 4) {
                ForEach(0..<(offset + count), id: \.self) { index in
                    if index < offset { Color.clear.frame(height: compact ? 27 : 39) }
                    else {
                        let day = calendar.date(byAdding: .day, value: index - offset, to: first) ?? first
                        CalendarDay(date: day, selected: calendar.isDate(day, inSameDayAs: selectedDate),
                                    shifts: store.on(day), accent: accent, size: compact ? 27 : 39) { selectedDate = day }
                    }
                }
            }
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

struct CalendarDay: View {
    let date: Date
    let selected: Bool
    let shifts: [Shift]
    let accent: Color
    let size: CGFloat
    let action: () -> Void
    private var colors: [ShiftColor] {
        shifts.reduce(into: [ShiftColor]()) { if !$0.contains($1.color) { $0.append($1.color) } }
    }
    var body: some View {
        Button(action: action) {
            ZStack {
                if selected { Circle().fill(accent.opacity(0.17)).padding(3) }
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Circle().trim(from: Double(index) / Double(colors.count) + (colors.count > 1 ? 0.012 : 0),
                                  to: Double(index + 1) / Double(colors.count) - (colors.count > 1 ? 0.012 : 0))
                        .stroke(color.value, style: StrokeStyle(lineWidth: 2.3, lineCap: .round)).rotationEffect(.degrees(-90)).padding(2)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: size < 30 ? 12 : 17, weight: selected || Calendar.current.isDateInToday(date) ? .bold : .regular))
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? accent : Color.primary)
            }.frame(width: size, height: size).frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("calendar-day-\(Calendar.current.component(.day, from: date))")
            .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(shifts.count) plantões\(colors.isEmpty ? "" : ", " + colors.map(\.name).joined(separator: ", "))")
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ShiftRow: View {
    let shift: Shift
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(shift.color.value).frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(shift.title).font(.headline)
                Text(shift.location).font(.subheadline).foregroundStyle(.secondary)
                if shift.amountCents > 0 {
                    Text("\(shift.amount) · Previsto").font(.caption.weight(.semibold))
                    if let due = shift.paymentDate { Text("Pagamento: \(due.formatted(date: .abbreviated, time: .omitted))").font(.caption2).foregroundStyle(shift.overdue() ? Color.red : Color.secondary) }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(shift.start.clock24)–\(shift.end.clock24)").font(.subheadline.monospacedDigit())
                Text(shift.duration).font(.caption).foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }.padding(16).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

