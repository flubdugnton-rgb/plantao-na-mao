import Foundation

enum AppLaunch {
    static var isUITest: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--ui-testing")
        #else
        return false
        #endif
    }
    static var initialDate: Date {
        isUITest ? Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 17))! : Date()
    }
    static func makeStore() -> ShiftStore {
        UserDefaults.standard.set(ShiftColor.mint.rawValue, forKey: "plantao-na-mao.theme")
        guard isUITest else { return ShiftStore() }
        let suite = "PlantaoNaMao.ui-testing"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = ShiftStore(defaults: defaults)
        for (index, day) in [3, 6, 12, 17, 18, 21, 23, 24, 26, 27, 30].enumerated() {
            let date = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day))!
            let start = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date)!
            let end = Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: date)!
            store.save(Shift(date: date, title: "MT UCE", location: index.isMultiple(of: 3) ? "HRC (trocas)" : "HRC",
                             start: start, end: end, color: index.isMultiple(of: 3) ? .emerald : .red,
                             notes: "Plantão de demonstração", amountCents: 31632,
                             paymentDate: ShiftRules.paymentDate(for: date, day: 10, nextMonth: true)))
        }
        let date = initialDate
        store.save(Shift(date: date, title: "Clínica", location: "Clínica Central", start: date, end: date, color: .blue))
        return store
    }
}
