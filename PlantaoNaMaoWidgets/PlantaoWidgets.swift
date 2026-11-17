import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}
struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        let date = Date()
        let shift = Shift(date: date, title: "Plantão", location: "Hospital", start: date, end: date, color: .mint)
        return CalendarEntry(date: date, snapshot: WidgetSnapshot(shifts: [shift], appearance: "system", updatedAt: date))
    }
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : CalendarEntry(date: Date(), snapshot: WidgetData.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let now = Date(), snapshot = WidgetData.load()
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        // Include midnight so the highlighted day and month change without opening the app.
        let entries = [CalendarEntry(date: now, snapshot: snapshot), CalendarEntry(date: tomorrow, snapshot: snapshot)]
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }
}
struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var systemScheme
    let entry: CalendarEntry
    private var small: Bool { family == .systemSmall }
    private var monthly: [Shift] { entry.snapshot.shifts.filter { ShiftRules.inMonth($0.date, month: entry.date) } }
    private var upcoming: [Shift] { entry.snapshot.shifts.filter { $0.interval.end >= entry.date }.sorted { $0.interval.start < $1.interval.start } }
    private var appearance: ColorScheme? { entry.snapshot.appearance == "dark" ? .dark : entry.snapshot.appearance == "light" ? .light : nil }
    var body: some View {
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    calendar(font: 10, ring: 16).frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plantão na Mão").font(.caption.bold()).foregroundStyle(ShiftColor.mint.value)
                        nextShifts(limit: 1)
                        Text("\(monthly.count) plantões · \(monthly.reduce(0) { $0 + $1.minutes } / 60)h no mês").font(.caption2).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: small ? 4 : 12) {
                    calendar(font: small ? 10 : 16, ring: small ? 18 : 27)
                    if !small {
                        Divider()
                        HStack { Text("\(monthly.count) plantões · \(monthly.reduce(0) { $0 + $1.minutes } / 60)h"); Spacer(); Text(Money.format(monthly.reduce(0) { $0 + $1.amountCents })) }.font(.caption).foregroundStyle(.secondary)
                        nextShifts(limit: 1)
                    }
                }
            }
        }
        .padding(small ? 10 : 14)
        .environment(\.locale, Locale(identifier: "pt_BR"))
        .preferredColorScheme(appearance)
        .widgetURL(WidgetData.url(for: entry.date))
        .containerBackground(.background, for: .widget)
        .environment(\.colorScheme, appearance ?? systemScheme)
    }
    private func calendar(font: CGFloat, ring: CGFloat) -> some View {
        let c = Calendar.current
        let first = c.dateInterval(of: .month, for: entry.date)!.start
        let count = c.range(of: .day, in: .month, for: first)!.count
        let offset = (c.component(.weekday, from: first) - c.firstWeekday + 7) % 7
        let slots = ((offset + count + 6) / 7) * 7
        return VStack(spacing: family == .systemLarge ? 3 : 1) {
            Text(entry.date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "pt_BR"))).uppercased())
                .font(.system(size: small ? 12 : 15, weight: .bold)).foregroundStyle(ShiftColor.mint.value).padding(.bottom, small ? 2 : 4)
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(["D","S","T","Q","Q","S","S"][(c.firstWeekday - 1 + i) % 7]).font(.system(size: font - 1)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: family == .systemLarge ? 3 : 1) {
                ForEach(0..<slots, id: \.self) { slot in
                    let day = c.date(byAdding: .day, value: slot - offset, to: first)!
                    let inMonth = c.isDate(day, equalTo: entry.date, toGranularity: .month)
                    let items = entry.snapshot.shifts.filter { c.isDate($0.date, inSameDayAs: day) }
                    let colors = items.reduce(into: [ShiftColor]()) { if !$0.contains($1.color) { $0.append($1.color) } }
                    Link(destination: WidgetData.url(for: day)) {
                        ZStack {
                            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                                Circle().trim(from: Double(index) / Double(colors.count) + (colors.count > 1 ? 0.015 : 0), to: Double(index + 1) / Double(colors.count) - (colors.count > 1 ? 0.015 : 0))
                                    .stroke(color.value.opacity(inMonth ? 1 : 0.3), lineWidth: small ? 1.2 : 1.8).rotationEffect(.degrees(-90)).padding(1)
                            }
                            Text("\(c.component(.day, from: day))").font(.system(size: font, weight: c.isDate(day, inSameDayAs: entry.date) ? .bold : .regular))
                                .foregroundStyle(c.isDate(day, inSameDayAs: entry.date) ? ShiftColor.mint.value : inMonth ? Color.primary : Color.secondary.opacity(0.4))
                        }.frame(height: ring)
                    }.buttonStyle(.plain).accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(items.count) plantões")
                }
            }
        }
    }
    @ViewBuilder private func nextShifts(limit: Int) -> some View {
        if upcoming.isEmpty { Text(entry.snapshot.updatedAt == .distantPast ? "Abra o app para carregar seus plantões." : "Sem próximos plantões").font(.caption).foregroundStyle(.secondary) }
        ForEach(Array(upcoming.prefix(limit))) { shift in
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(shift.color.value).frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(shift.title).font(.caption.bold()).lineLimit(1)
                    Text(shift.location).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Text("\(shift.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "pt_BR")))) · \(shift.start.clock24)–\(shift.end.clock24)").font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
@main
struct PlantaoCalendarWidget: Widget {
    let kind = "PlantaoNaMaoCalendar"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { CalendarWidgetView(entry: $0) }
            .configurationDisplayName("Plantão na Mão")
            .description("Calendário com aros e seus próximos plantões.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}
