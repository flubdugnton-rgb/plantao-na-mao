import SwiftUI

private enum PaymentMode: String, CaseIterable, Identifiable {
    case none = "Sem previsão", standard = "Dia padrão", custom = "Data personalizada"
    var id: String { rawValue }
}

struct ShiftEditor: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("plantao-na-mao.paymentDay") private var defaultDay = 5
    @AppStorage("plantao-na-mao.nextMonth") private var nextMonth = true
    private let existing: Shift?
    @State private var title: String
    @State private var location: String
    @State private var date: Date
    @State private var start: Date
    @State private var end: Date
    @State private var color: ShiftColor
    @State private var notes: String
    @State private var amount: String
    @State private var isPaid: Bool
    @State private var mode: PaymentMode
    @State private var customDate: Date
    @State private var confirmingDelete = false
    @State private var showingPDF = false
    @State private var validationError: String?

    init(date: Date, shift: Shift? = nil) {
        existing = shift
        _title = State(initialValue: shift?.title ?? "Plantão")
        _location = State(initialValue: shift?.location ?? "")
        _date = State(initialValue: shift?.date ?? date)
        _start = State(initialValue: shift?.start ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date)
        _end = State(initialValue: shift?.end ?? Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: date) ?? date)
        _color = State(initialValue: shift?.color ?? .mint)
        _notes = State(initialValue: shift?.notes ?? "")
        _amount = State(initialValue: shift.map { Money.input($0.amountCents) } ?? "")
        _isPaid = State(initialValue: shift?.isPaid ?? false)
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
        return Shift(id: existing?.id ?? UUID(), date: Calendar.current.startOfDay(for: date),
                     title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                     location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sem local" : location.trimmingCharacters(in: .whitespacesAndNewlines),
                     start: interval.start, end: interval.end, color: color, notes: notes,
                     amountCents: Money.parse(amount) ?? 0, paymentDate: predictedDate,
                     isPaid: (Money.parse(amount) ?? 0) > 0 && isPaid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Seu plantão") {
                    TextField("Nome do plantão", text: $title).textInputAutocapitalization(.sentences)
                    TextField("Hospital, clínica ou local", text: $location).textInputAutocapitalization(.words)
                    if !store.locations.isEmpty {
                        Menu("Usar local já cadastrado") {
                            ForEach(store.locations, id: \.self) { name in Button(name) { location = name } }
                        }
                    }
                    DatePicker("Data do plantão", selection: $date, displayedComponents: .date)
                }
                Section {
                    DatePicker("Entrada", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Saída", selection: $end, displayedComponents: .hourAndMinute)
                    LabeledContent("Duração", value: draft.duration)
                } header: { Text("Horários") } footer: {
                    Text("Se a saída for antes da entrada, o plantão termina no dia seguinte. Horários iguais representam 24 horas.")
                }
                Section {
                    HStack { Text("Valor (R$)"); TextField("0,00", text: $amount).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    if Money.parse(amount) == nil { Text("Use um valor como 1.250,50.").font(.caption).foregroundStyle(.red) }
                    Picker("Previsão de pagamento", selection: $mode) { ForEach(PaymentMode.allCases) { Text($0.rawValue).tag($0) } }
                    if mode == .custom { DatePicker("Receber em", selection: $customDate, displayedComponents: .date) }
                    if mode == .standard, let due = predictedDate {
                        LabeledContent("Previsão", value: due.formatted(date: .abbreviated, time: .omitted))
                        Text("Dia \(defaultDay) \(nextMonth ? "do mês seguinte" : "do mesmo mês"). Altere o padrão em Ajustes.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Pagamento recebido", isOn: $isPaid).disabled((Money.parse(amount) ?? 0) == 0)
                } header: { Text("Pagamento") } footer: {
                    Text("A data pode ser escolhida livremente para cada plantão. Alterar o dia padrão não muda as previsões já salvas.")
                }
                Section("Cor do plantão") { ColorChoices(selection: $color) }
                Section("Observações") {
                    TextField("Informações importantes", text: $notes, axis: .vertical).lineLimit(3...6)
                }
                Section {
                    Button { showingPDF = true } label: { Label("Exportar este plantão em PDF", systemImage: "doc.richtext") }.disabled(!valid)
                }
                if existing != nil {
                    Section { Button("Excluir plantão", role: .destructive) { confirmingDelete = true }.disabled(!store.canWrite) }
                }
            }
            .navigationTitle(existing == nil ? "Novo plantão" : "Editar plantão").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        guard valid else { return }
                        store.save(draft)
                        if store.canWrite { dismiss() } else { validationError = store.storageError }
                    }.bold().disabled(!valid)
                }
            }
            .confirmationDialog("Excluir este plantão?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Excluir plantão", role: .destructive) { if let existing { store.remove(existing); dismiss() } }
            } message: { Text("Esta ação remove o plantão e seu registro de pagamento.") }
            .sheet(isPresented: $showingPDF) { ReportView(month: date, singleShift: draft) }
            .alert("Não foi possível salvar", isPresented: Binding(get: { validationError != nil }, set: { if !$0 { validationError = nil } })) {
                Button("OK", role: .cancel) { validationError = nil }
            } message: { Text(validationError ?? "") }
        }
    }
}
