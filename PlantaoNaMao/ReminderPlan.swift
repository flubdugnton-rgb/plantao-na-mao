import Foundation

enum ReminderLead: Int, CaseIterable, Identifiable {
    case day = 1440, halfDay = 720, sixHours = 360, halfHour = 30
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .day: return "24 horas antes"
        case .halfDay: return "12 horas antes"
        case .sixHours: return "6 horas antes"
        case .halfHour: return "30 minutos antes"
        }
    }
}

struct ShiftReminder: Equatable {
    static let prefix = "plantao.reminder."
    let shiftID: UUID
    let fireDate: Date
    let title: String
    let subtitle: String
    let body: String
    let url: URL
    var identifier: String { Self.prefix + shiftID.uuidString }

    static func upcoming(_ shifts: [Shift], lead: ReminderLead, now: Date = Date(),
                         calendar: Calendar = .current, limit: Int = 64) -> [ShiftReminder] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return shifts.compactMap { shift -> ShiftReminder? in
            let interval = ShiftRules.interval(day: shift.date, start: shift.start, end: shift.end, calendar: calendar)
            let fireDate = interval.start.addingTimeInterval(-Double(lead.rawValue * 60))
            guard fireDate > now else { return nil }
            var parts = URLComponents()
            parts.scheme = "plantaonamao"; parts.host = "calendar"
            let routeDate = DateFormatter()
            routeDate.locale = Locale(identifier: "en_US_POSIX")
            routeDate.calendar = Calendar(identifier: .gregorian)
            routeDate.timeZone = calendar.timeZone
            routeDate.dateFormat = "yyyy-MM-dd"
            parts.queryItems = [URLQueryItem(name: "date", value: routeDate.string(from: shift.date)),
                                URLQueryItem(name: "shift", value: shift.id.uuidString)]
            guard let url = parts.url else { return nil }
            var details = ["Início: \(formatter.string(from: interval.start))",
                           "Fim: \(formatter.string(from: interval.end))"]
            if !shift.location.isEmpty { details.insert("Local: \(shift.location)", at: 0) }
            if shift.amountCents > 0 { details.append("Valor: \(shift.amount)") }
            if !shift.notes.isEmpty { details.append("Observações: \(shift.notes)") }
            return ShiftReminder(shiftID: shift.id, fireDate: fireDate, title: "Plantão: \(shift.title)",
                                 subtitle: lead.label, body: details.joined(separator: "\n"), url: url)
        }.sorted {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }.prefix(max(0, limit)).map { $0 }
    }
}
