import SwiftUI

private enum PaymentMode: String, CaseIterable, Identifiable {
    case none = "Sem previsão", standard = "Dia padrão", custom = "Data personalizada"
    var id: String { rawValue }
}

struct MoneyEntry: View {
    let title: String
    @Binding var text: String
    @FocusState private var focused: Bool
    var body: some View {
        HStack {
            Text(title)
            TextField("0,00", text: $text).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).focused($focused)
                .onChange(of: focused) { _, active in if !active { normalize() } }
                .onSubmit { normalize() }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { if focused { Spacer(); Button("Concluir") { normalize(); focused = false } } } }
    }
    private func normalize() { if let cents = Money.parse(text) { text = Money.input(cents) } }
}

struct ShiftEditor: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("plantao-na-mao.paymentDay") private var defaultDay = 5
    @AppStorage("plantao-na-mao.nextMonth") private var nextMonth = true
    private let existing: Shift?
    @State private var newID = UUID()
    @State private var createdAt = Date()
    @State private var title: String
    @State private var location: String
    @State private var date: Date
    @State private var start: Date
    @State private var end: Date
    @State private var color: ShiftColor
    @State private var notes: String
    @State private var amount: String
    @State private var pricing: PricingMode
    @State private var mode: PaymentMode
    @State private var customDate: Date
    @State private var confirmingDelete = false
    @State private var showingPDF = false
    @State private var validationError: String?

    init(date: Date, shift: Shift? = nil) {
        existing = shift
        _title = State(initialValue: shift?.title ?? "")
        _location = State(initialValue: shift?.location ?? "")
        _date = State(initialValue: shift?.date ?? date)
        _start = State(initialValue: shift?.start ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date)
        _end = State(initialValue: shift?.end ?? Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: date) ?? date)
        _color = State(initialValue: shift?.color ?? .mint)
        _notes = State(initialValue: shift?.notes ?? "")
        _amount = State(initialValue: shift.map { Money.input($0.pricingMode == .hour ? $0.rateCents : $0.amountCents) } ?? "")
        _pricing = State(initialValue: shift?.pricingMode ?? .shift)
        _mode = State(initialValue: shift == nil ? .standard : shift?.paymentDate == nil ? .none : .custom)
        _customDate = State(initialValue: shift?.paymentDate ?? date)
    }
    private var predictedDate: Date? {
        switch mode {
        case .none: return nil
        case .standard: return ShiftRules.paymentDate(for: date, day: defaultDay, nextMonth: nextMonth)
        case .custom: return Calendar.current.startOfDay(for: customDate)
        }
    }
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Money.parse(amount) != nil && store.canWrite
    }
    private var draft: Shift {
        let interval = ShiftRules.interval(day: date, start: start, end: end)
        let rate = Money.parse(amount) ?? 0
        return Shift(id: existing?.id ?? newID, date: Calendar.current.startOfDay(for: date),
                     title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                     location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sem local" : location.trimmingCharacters(in: .whitespacesAndNewlines),
                     start: interval.start, end: interval.end, color: color, notes: notes,
                     amountCents: pricing.total(rateCents: rate, minutes: Int(interval.duration / 60)), paymentDate: predictedDate,
                     isPaid: existing?.isPaid ?? false, pricingMode: pricing, rateCents: rate,
                     createdAt: existing == nil ? createdAt : existing?.createdAt)
    }
    var body: some View {
        NavigationStack {
            Form {
                if existing == nil && !store.recent.isEmpty { recentSection }
                Section("Seu plantão") {
                    TextField("Nome do plantão", text: $title).textInputAutocapitalization(.sentences).accessibilityIdentifier("shift-title")
                    TextField("Hospital, clínica ou local", text: $location).textInputAutocapitalization(.words)
                    if !store.locations.isEmpty {
                        Menu("Usar local já cadastrado") { ForEach(store.locations, id: \.self) { name in Button(name) { location = name } } }
                    }
                    DatePicker("Data do plantão", selection: $date, displayedComponents: .date)
                    Text(date.formatted(.dateTime.day().month(.wide).year())).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("shift-selected-date")
                }
                Section {
                    DatePicker("Entrada", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Saída", selection: $end, displayedComponents: .hourAndMinute)
                    LabeledContent("Duração", value: draft.duration)
                } header: { Text("Horários") } footer: {
                    Text("Saída antes da entrada termina no dia seguinte. Horários iguais representam 24 horas.")
                }
                Section {
                    Picker("Forma de cálculo", selection: $pricing) { ForEach(PricingMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                    MoneyEntry(title: pricing == .hour ? "Valor da hora (R$)" : "Valor do plantão (R$)", text: $amount)
                    if Money.parse(amount) == nil { Text("Informe um valor como 330,00 ou 26,36.").font(.caption).foregroundStyle(.red) }
                    LabeledContent("Total previsto", value: draft.amount).fontWeight(.semibold)
                    if pricing == .hour {
                        Text("\(Money.format(Money.parse(amount) ?? 0))/h × \(draft.duration). O total acompanha os horários, incluindo minutos.").font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Previsão de pagamento", selection: $mode) { ForEach(PaymentMode.allCases) { Text($0.rawValue).tag($0) } }
                    if mode == .custom { DatePicker("Receber em", selection: $customDate, displayedComponents: .date) }
                    if mode == .standard, let due = predictedDate {
                        LabeledContent("Previsão", value: due.formatted(date: .abbreviated, time: .omitted))
                    }
                } header: { Text("Pagamento previsto") } footer: {
                    Text("Ao salvar, o valor já entra automaticamente no financeiro como previsão. Digite 330 ou 330,00; completamos as casas decimais ao sair do campo.")
                }
                Section("Cor do aro no calendário") { ColorChoices(selection: $color) }
                Section("Observações") { TextField("Informações importantes", text: $notes, axis: .vertical).lineLimit(3...6) }
                Section { Button { showingPDF = true } label: { Label("Exportar este plantão em PDF", systemImage: "doc.richtext") }.disabled(!valid) }
                if existing != nil { Section { Button("Excluir plantão", role: .destructive) { confirmingDelete = true }.disabled(!store.canWrite) } }
            }
            .navigationTitle(existing == nil ? "Novo plantão" : "Editar plantão").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { if store.save(draft) { dismiss() } else { validationError = store.storageError ?? "Confira os campos e tente novamente." } }.bold().disabled(!valid).accessibilityIdentifier("save-shift") }
            }
            .confirmationDialog("Excluir este plantão?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Excluir plantão", role: .destructive) { if let existing { store.remove(existing); dismiss() } }
            } message: { Text("Esta ação remove o plantão e sua previsão de pagamento.") }
            .sheet(isPresented: $showingPDF) { ReportView(month: date, singleShift: draft) }
            .alert("Não foi possível salvar", isPresented: Binding(get: { validationError != nil }, set: { if !$0 { validationError = nil } })) { Button("OK", role: .cancel) { validationError = nil } } message: { Text(validationError ?? "") }
        }
    }
    private var recentSection: some View {
        Section {
            ForEach(store.recent) { shift in
                Button { use(shift) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(shift.color.value).frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shift.title).font(.headline)
                            Text("\(shift.location) · \(shift.start.clock24)–\(shift.end.clock24)").font(.caption).foregroundStyle(.secondary)
                            Text("\(shift.date.formatted(date: .abbreviated, time: .omitted)) · \(shift.amount)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "arrow.down.doc")
                    }
                }.buttonStyle(.borderless).accessibilityLabel("Reaproveitar \(shift.title)").accessibilityIdentifier("reuse-\(shift.id.uuidString)")
            }
        } header: { Text("Reaproveitar um dos últimos 3 plantões") } footer: {
            Text("Toque para preencher nome, local, horários, cor e valor. A data escolhida é mantida e a previsão de pagamento é recalculada pelo seu padrão. Depois toque em Salvar.")
        }
    }
    private func use(_ shift: Shift) {
        let preset = shift.reused(on: date, paymentDay: defaultDay, nextMonth: nextMonth)
        title = preset.title; location = preset.location
        start = preset.start; end = preset.end; color = preset.color; notes = preset.notes
        pricing = preset.pricingMode
        amount = Money.input(preset.pricingMode == .hour ? preset.rateCents : preset.amountCents)
        mode = preset.paymentDate == nil ? .none : .standard
        customDate = preset.paymentDate ?? date
        validationError = nil
    }
}
