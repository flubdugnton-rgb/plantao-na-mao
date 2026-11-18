import Foundation

@main
struct ModelChecks {
    static func main() throws {
        let calendar = Calendar.current
        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            precondition(condition(), "FALHOU: \(label)"); checks += 1
        }
        check(Money.parse("1.250,50") == 125050, "BRL com separador de milhar")
        check(Money.parse("200,5") == 20050, "Uma casa decimal")
        check(Money.parse("200.50") == 20050, "Teclado com ponto decimal")
        check(Money.parse("1.250") == 125000, "Milhar brasileiro")
        check(Money.parse("12.34.56") == nil, "Rejeitar separadores de milhar incorretos")
        check(Money.parse("") == 0, "Valor não informado")
        for invalid in ["-2", "abc", "1,000", "1,2,3", "99999999999999999999999"] {
            check(Money.parse(invalid) == nil, "Valor inválido: \(invalid)")
        }
        check(Money.parse(Money.input(123456)) == 123456, "Preservar centavos na edição")
        let night = ShiftRules.interval(day: date(2026, 11, 17), start: date(2020, 1, 1, 19), end: date(2020, 1, 1, 7))
        check(Int(night.duration) == 12 * 3600, "Plantão noturno de 12h")
        check(calendar.component(.day, from: night.end) == 18, "Saída no dia seguinte")
        let full = ShiftRules.interval(day: date(2026, 11, 17), start: date(2020, 1, 1, 7), end: date(2020, 1, 1, 7))
        check(Int(full.duration) == 24 * 3600, "Horários iguais representam 24h")
        check(ShiftRules.paymentDate(for: date(2026, 1, 15), day: 31, nextMonth: true) == date(2026, 2, 28), "Dia 31 em fevereiro")
        check(ShiftRules.paymentDate(for: date(2028, 1, 15), day: 31, nextMonth: true) == date(2028, 2, 29), "Ano bissexto")
        check(ShiftRules.paymentDate(for: date(2026, 12, 31), day: 5, nextMonth: true) == date(2027, 1, 5), "Virada do ano")
        check(ShiftRules.paymentDate(for: date(2026, 11, 17), day: 8, nextMonth: false) == date(2026, 11, 8), "Mesmo mês")
        var shift = Shift(date: date(2026, 11, 17), title: "Noturno", location: "Hospital", start: night.start, end: night.end,
                          color: .purple, notes: "Observação", amountCents: 125050, paymentDate: date(2026, 12, 5))
        let encoded = try JSONEncoder().encode(shift)
        let decoded = try JSONDecoder().decode(Shift.self, from: encoded)
        check(decoded == shift, "Persistência de todos os campos")
        // Build exactly the JSON shape used by the original app.
        var legacy = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        for key in ["amountCents", "paymentDate", "isPaid"] { legacy.removeValue(forKey: key) }
        legacy["color"] = "sage"
        let migrated = try JSONDecoder().decode(Shift.self, from: JSONSerialization.data(withJSONObject: legacy))
        check(migrated.id == shift.id && migrated.notes == shift.notes && migrated.color == .sage, "Migrar preservando os dados antigos")
        check(migrated.amountCents == 0 && migrated.paymentDate == nil && !migrated.isPaid, "Valores padrão na migração")
        check(Reports.select([shift], kind: .schedule, month: date(2026, 11, 1)).count == 1, "Escala usa a data do plantão")
        check(Reports.select([shift], kind: .payments, month: date(2026, 11, 1)).isEmpty, "Não contar pagamento futuro no mês do plantão")
        check(Reports.select([shift], kind: .payments, month: date(2026, 12, 1)).count == 1, "Financeiro usa a previsão")
        check(!shift.overdue(on: date(2026, 12, 5, 23)), "Vencimento hoje não está atrasado")
        check(shift.overdue(on: date(2026, 12, 6)), "Pagamento pendente vencido")
        shift.isPaid = true
        check(!shift.overdue(on: date(2026, 12, 6)), "Recebidos não estão atrasados")
        check(Reports.select([shift], kind: .payments, month: nil, filter: .pending).isEmpty, "Filtro pendente")
        check(Reports.select([shift], kind: .payments, month: nil, filter: .paid).count == 1, "Filtro recebido")
        shift.paymentDate = nil
        check(Reports.select([shift], kind: .payments, month: nil).count == 1, "Todo período inclui pagamentos sem data")
        check(Reports.select([shift], kind: .payments, month: date(2026, 11, 1)).isEmpty, "Sem data fica fora de um mês específico")
        check(ShiftColor.allCases.count == 24, "Vinte e quatro cores disponíveis")
        let early = SyncRecord(shift: shift, modifiedAt: date(2026, 11, 1), writerID: "iPhone")
        var newer = early; newer.modifiedAt = date(2026, 11, 2); newer.writerID = "Mac"; newer.shift.notes = "Editado no Mac"
        let a = SyncSnapshot(records: [early])
        let b = SyncSnapshot(records: [newer])
        let merged = SyncMerge.combine([a, b])
        check(merged.visibleShifts.first?.notes == "Editado no Mac", "Edição mais recente entre aparelhos")
        check(merged == SyncMerge.combine([b, a]), "Mesclagem independe da ordem")
        check(SyncMerge.combine([merged, merged]) == merged, "Sincronização repetida não duplica dados")
        let deletion = SyncSnapshot(deletions: [SyncDeletion(id: shift.id, modifiedAt: date(2026, 11, 3), writerID: "iPhone")])
        let deleted = SyncMerge.combine([merged, deletion])
        check(deleted.visibleShifts.isEmpty, "Exclusão remove registro em outro dispositivo")
        check(SyncMerge.combine([deleted, a]).visibleShifts.isEmpty, "Aparelho antigo não ressuscita exclusão")
        var tied = newer; tied.writerID = "Z"; tied.shift.notes = "Empate"
        check(SyncMerge.combine([SyncSnapshot(records: [tied]), b]) == SyncMerge.combine([b, SyncSnapshot(records: [tied])]), "Empate tem resultado determinístico")
        let equalDeletion = SyncSnapshot(deletions: [SyncDeletion(id: shift.id, modifiedAt: newer.modifiedAt, writerID: "A")])
        check(SyncMerge.combine([b, equalDeletion]).visibleShifts.isEmpty, "Exclusão prevalece em timestamp igual")
        let syncData = try JSONEncoder().encode(deleted)
        let syncRead = try JSONDecoder().decode(SyncSnapshot.self, from: syncData).validated()
        check(syncRead == deleted, "Formato compartilhado entre iOS e futuro macOS")
        check(PricingMode.hour.total(rateCents: 2636, minutes: 720) == 31632, "26,36 por hora durante 12h")
        check(PricingMode.hour.total(rateCents: 2636, minutes: 750) == 32950, "Hora fracionada inclui minutos")
        check(PricingMode.hour.total(rateCents: 100, minutes: 1) == 2, "Arredondamento ao centavo")
        check(PricingMode.shift.total(rateCents: 33000, minutes: 720) == 33000, "Preço por plantão não depende das horas")
        let noDiscount = DeductionPlan().totals(gross: 31632)
        check(noDiscount.net == 31632, "Descontos desligados por padrão")
        let discounts = DeductionPlan(inssEnabled: true, inssText: "11", irEnabled: true, irText: "7,5")
        let discounted = discounts.totals(gross: 100000)
        check(discounted.inss == 11000 && discounted.incomeTax == 7500 && discounted.net == 81500, "Descontos independentes sobre o bruto")
        check(!DeductionPlan(inssEnabled: true, inssText: "101").valid, "Não permitir percentual maior que 100")
        check(!DeductionPlan(inssEnabled: true, inssText: "60", irEnabled: true, irText: "50").valid, "Não permitir soma acima de 100")
        let cent = DeductionPlan(inssEnabled: true, inssText: "50", irEnabled: true, irText: "50").totals(gross: 1)
        check(cent.net == 0, "Arredondamento dos descontos nunca gera líquido negativo")
        var paymentShift = shift; paymentShift.date = date(2026, 11, 17); paymentShift.paymentDate = date(2026, 12, 5)
        let dayRange = FinancePeriod(start: date(2026, 12, 5), end: date(2026, 12, 5), mode: .dates, basis: .payment)
        check(dayRange.select([paymentShift]).count == 1, "Datas inicial e final inclusivas")
        check(FinancePeriod(start: date(2026, 12, 6), end: date(2026, 12, 5), mode: .dates, basis: .payment).bounds == nil, "Intervalo invertido inválido")
        check(FinancePeriod(start: date(2026, 11, 30), end: date(2026, 11, 1), mode: .competence, basis: .shift).bounds == nil, "Competência rejeita intervalo invertido")
        let competence = FinancePeriod(start: date(2026, 11, 17), end: date(2026, 11, 20), mode: .competence, basis: .shift)
        var outside = paymentShift; outside.id = UUID(); outside.date = date(2026, 11, 16)
        var finalDay = paymentShift; finalDay.id = UUID(); finalDay.date = date(2026, 11, 20, 23, 59)
        var after = paymentShift; after.id = UUID(); after.date = date(2026, 11, 21)
        check(competence.select([outside, paymentShift, finalDay, after]).map(\.id) == [paymentShift.id, finalDay.id], "Competência respeita dia inicial e inclui último dia até 23:59")
        check(FinancePeriod(start: date(2026, 11, 17), end: date(2026, 11, 17), mode: .competence, basis: .shift).select([paymentShift]).count == 1, "Competência de um único dia")
        let monthly = MonthlySummary.build([paymentShift], now: date(2026, 12, 1))
        check(monthly.count == 2 && monthly[0].shifts.count == 1 && monthly[1].gross == 0, "Painel preserva histórico e meses sem movimento")
        var hourly = paymentShift; hourly.pricingMode = .hour; hourly.rateCents = 2636; hourly.createdAt = date(2026, 11, 17)
        let hourlyRoundTrip = try JSONDecoder().decode(Shift.self, from: JSONEncoder().encode(hourly))
        check(hourlyRoundTrip == hourly, "Persistência de preço por hora e data de criação")
        var oldSchema = SyncSnapshot(); oldSchema.schemaVersion = 1
        let upgraded = try oldSchema.validated()
        check(upgraded.schemaVersion == 2, "Migra sincronização 1.1 sem perder campos da versão 1.2")
        let originalDay = date(2026, 11, 17)
        let chosenDay = date(2026, 11, 20)
        let original = Shift(date: originalDay, title: "MT UCE", location: "HRC", start: date(2026, 11, 17, 7), end: date(2026, 11, 17, 19), color: .red, notes: "Modelo", amountCents: 31632, paymentDate: date(2026, 12, 10), isPaid: true, pricingMode: .hour, rateCents: 2636)
        let preset = original.reused(on: chosenDay, paymentDay: 5, nextMonth: true)
        check(preset.date == chosenDay && preset.id != original.id, "Preset cria novo ID e mantém dia 20 escolhido")
        check(preset.start == date(2026, 11, 20, 7) && preset.end == date(2026, 11, 20, 19), "Horários do preset pertencem ao novo dia")
        check(preset.title == original.title && preset.location == original.location && preset.color == .red && preset.notes == original.notes, "Preset preserva informações e cor")
        check(preset.amountCents == 31632 && preset.rateCents == 2636 && preset.pricingMode == .hour, "Preset mantém tarifa e cálculo por hora")
        check(!preset.isPaid && preset.paymentDate == date(2026, 12, 5), "Nova previsão recalculada sem herdar recebido")
        check(Money.parse(Money.input(preset.rateCents)) == 2636, "Valor do preset continua válido ao preencher o formulário")
        let nightPreset = shift.reused(on: chosenDay, paymentDay: 5, nextMonth: true)
        check(nightPreset.start == date(2026, 11, 20, 19) && nightPreset.end == date(2026, 11, 21, 7), "Preset noturno mantém saída no próximo dia")
        let snapshotFile = WidgetSnapshotFile(url: FileManager.default.temporaryDirectory.appendingPathComponent("widget-check-\(UUID().uuidString).json"))
        defer { try? FileManager.default.removeItem(at: snapshotFile.url) }
        let widgetSnapshot = WidgetSnapshot(shifts: [original, preset], appearance: "dark", updatedAt: chosenDay)
        try snapshotFile.save(widgetSnapshot)
        check(snapshotFile.load() == widgetSnapshot, "Widget lê todos os dados após gravação atômica")
        let widgetEdited = WidgetSnapshot(shifts: [preset], appearance: "light", updatedAt: chosenDay)
        try snapshotFile.save(widgetEdited)
        check(snapshotFile.load() == widgetEdited, "Widget relê exclusões e aparência sem cache antigo")
        try Data("incomplete".utf8).write(to: snapshotFile.url)
        check(snapshotFile.load() == nil, "Widget rejeita arquivo ilegível")
        check(WidgetData.date(from: WidgetData.url(for: chosenDay)) == chosenDay, "Tocar no widget abre o dia correspondente")
        check(WidgetData.date(from: URL(string: "plantaonamao://invalid?date=2026-11-20")!) == nil, "Widget rejeita rota desconhecida")
        let calendarPayload = WidgetCalendarPayload(snapshot: widgetSnapshot)
        check(calendarPayload.days.count == 2, "Chaves carregam dias com aros do mês")
        let projection = calendarPayload.snapshot
        check(projection.shifts.map(\.date) == [originalDay, chosenDay] && projection.shifts.allSatisfy { $0.color == .red }, "Alternativa nas Chaves preserva datas e cores")
        check(projection.shifts.allSatisfy { $0.title.isEmpty && $0.location.isEmpty && $0.notes.isEmpty && $0.amountCents == 0 && $0.paymentDate == nil }, "Chaves não recebem nomes, locais, anotações nem valores")
        let payloadEncoded = try JSONEncoder().encode(calendarPayload)
        let payloadRead = try JSONDecoder().decode(WidgetCalendarPayload.self, from: payloadEncoded)
        check(payloadRead == calendarPayload && payloadRead.fingerprint == calendarPayload.fingerprint, "Calendário das Chaves mantém identificação após leitura")
        check(WidgetCalendarPayload(snapshot: projection).fingerprint == calendarPayload.fingerprint, "Leitura do widget produz a mesma confirmação do app")
        var named = original; named.title = "Nome privado"; named.location = "Local privado"; named.notes = "Anotação privada"; named.amountCents = 987654
        let renamed = WidgetCalendarPayload(snapshot: WidgetSnapshot(shifts: [named, preset], appearance: "dark", updatedAt: chosenDay))
        check(renamed.fingerprint == calendarPayload.fingerprint, "Identificação depende apenas das informações visíveis no widget")
        var recolored = preset; recolored.color = .blue
        let changedColor = WidgetCalendarPayload(snapshot: WidgetSnapshot(shifts: [original, recolored], appearance: "dark", updatedAt: chosenDay))
        check(changedColor.fingerprint != calendarPayload.fingerprint, "Mudar a cor exige nova confirmação do widget")
        var far = original; far.date = date(2027, 7, 1)
        let limited = WidgetCalendarPayload(snapshot: WidgetSnapshot(shifts: [original, far], appearance: "dark", updatedAt: chosenDay))
        check(limited.days.count == 1, "Chaves enviam apenas mês anterior, atual e seguinte")
        let receipt = WidgetReadReceipt(fingerprint: calendarPayload.fingerprint, readAt: chosenDay, days: 2, source: "Chaves")
        let readReceipt = try JSONDecoder().decode(WidgetReadReceipt.self, from: JSONEncoder().encode(receipt))
        check(readReceipt == receipt, "Confirmação identifica os dados realmente lidos")
        // Reminder dates use the shift's chosen day, including midnight and DST.
        let now = date(2026, 11, 15)
        for lead in ReminderLead.allCases {
            let reminder = ShiftReminder.upcoming([original], lead: lead, now: now, calendar: calendar).first!
            check(reminder.fireDate == original.interval.start.addingTimeInterval(-Double(lead.rawValue * 60)), "Antecedência exata: \(lead.label)")
            check(reminder.body.contains("HRC") && reminder.body.contains("07:00") && reminder.body.contains("19:00") && reminder.body.contains("Modelo") && reminder.body.contains("316,32"), "Aviso contém detalhes do plantão")
            check(WidgetData.date(from: reminder.url) == originalDay, "Toque no aviso abre o dia do plantão")
            check(reminder.url.absoluteString.contains(original.id.uuidString), "Aviso identifica o plantão exato")
        }
        let nightReminder = ShiftReminder.upcoming([shift], lead: .halfHour, now: now, calendar: calendar).first!
        check(nightReminder.body.contains("18/11/2026 às 07:00"), "Aviso noturno informa a data da saída")
        check(ShiftReminder.upcoming([original], lead: .day, now: original.interval.start, calendar: calendar).isEmpty, "Não enviar lembretes passados")
        check(ShiftReminder.upcoming([original], lead: .day, now: original.interval.start.addingTimeInterval(-86400), calendar: calendar).isEmpty, "Não disparar um aviso retroativo no instante atual")
        var moved = original; moved.date = chosenDay
        let oldReminder = ShiftReminder.upcoming([original], lead: .day, now: now).first!
        let newReminder = ShiftReminder.upcoming([moved], lead: .day, now: now).first!
        check(oldReminder.identifier == newReminder.identifier && oldReminder.fireDate != newReminder.fireDate, "Editar data substitui o mesmo aviso")
        let many = (0..<70).map { day -> Shift in
            var item = original; item.id = UUID(); item.date = calendar.date(byAdding: .day, value: day, to: originalDay)!; return item
        }
        let reminders = ShiftReminder.upcoming(many.reversed(), lead: .halfHour, now: now, calendar: calendar)
        check(reminders.count == 64 && reminders.first!.shiftID == many.first!.id && reminders.last!.shiftID == many[63].id, "Priorizar os 64 próximos avisos")
        var dst = Calendar(identifier: .gregorian); dst.timeZone = TimeZone(identifier: "America/New_York")!
        let dstDay = dst.date(from: DateComponents(year: 2027, month: 3, day: 14))!
        let dstShift = Shift(date: dstDay, title: "DST", location: "", start: date(2020, 1, 1, 7), end: date(2020, 1, 1, 19))
        let dstStart = ShiftRules.interval(day: dstDay, start: dstShift.start, end: dstShift.end, calendar: dst).start
        let dstReminder = ShiftReminder.upcoming([dstShift], lead: .day, now: dstDay.addingTimeInterval(-172800), calendar: dst).first!
        check(dstStart.timeIntervalSince(dstReminder.fireDate) == 86400, "24 horas reais mesmo na troca de horário de verão")
        let suite = "sync-checkpoint-check-" + UUID().uuidString
        let syncDefaults = UserDefaults(suiteName: suite)!
        defer { syncDefaults.removePersistentDomain(forName: suite) }
        let checkpoint = SyncCheckpoint(defaults: syncDefaults)
        let initialSync = SyncSnapshot(records: [SyncRecord(shift: original, modifiedAt: originalDay, writerID: "phone")])
        check(checkpoint.needsUpload(initialSync), "Primeira conexão ainda precisa conciliar o backup")
        try checkpoint.acknowledge(initialSync)
        check(!checkpoint.needsUpload(initialSync), "Sem alterações não existe sincronização automática")
        check(!SyncCheckpoint(defaults: syncDefaults).needsUpload(initialSync), "Reabrir app não consulta rede após sucesso")
        var editedSync = initialSync; editedSync.records[0].shift.notes = "Alterado offline"
        check(checkpoint.needsUpload(editedSync), "Edição offline fica pendente sem timer")
        check(SyncCheckpoint(defaults: syncDefaults).needsUpload(editedSync), "Pendência sobrevive ao fechamento do app")
        try checkpoint.acknowledge(initialSync)
        check(checkpoint.needsUpload(editedSync), "Resposta de upload antigo não confirma edição feita durante a requisição")
        try checkpoint.acknowledge(editedSync)
        check(!checkpoint.needsUpload(editedSync), "Só confirmar snapshot enviado com sucesso")
        let deletedSync = SyncSnapshot(deletions: [SyncDeletion(id: original.id, modifiedAt: chosenDay, writerID: "phone")])
        check(checkpoint.needsUpload(deletedSync), "Excluir também pede sincronização")
        print("\(checks) verificações aprovadas · \(TimeZone.current.identifier)")
    }
}

