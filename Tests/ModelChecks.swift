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
        check(FinancePeriod(start: date(2026, 11, 30), end: date(2026, 11, 1), mode: .competence, basis: .shift).select([paymentShift]).count == 1, "Competência inclui o mês inteiro")
        let monthly = MonthlySummary.build([paymentShift], now: date(2026, 12, 1))
        check(monthly.count == 2 && monthly[0].shifts.count == 1 && monthly[1].gross == 0, "Painel preserva histórico e meses sem movimento")
        var hourly = paymentShift; hourly.pricingMode = .hour; hourly.rateCents = 2636; hourly.createdAt = date(2026, 11, 17)
        let hourlyRoundTrip = try JSONDecoder().decode(Shift.self, from: JSONEncoder().encode(hourly))
        check(hourlyRoundTrip == hourly, "Persistência de preço por hora e data de criação")
        var oldSchema = SyncSnapshot(); oldSchema.schemaVersion = 1
        let upgraded = try oldSchema.validated()
        check(upgraded.schemaVersion == 2, "Migra sincronização 1.1 sem perder campos da versão 1.2")
        print("\(checks) verificações aprovadas · \(TimeZone.current.identifier)")
    }
}
