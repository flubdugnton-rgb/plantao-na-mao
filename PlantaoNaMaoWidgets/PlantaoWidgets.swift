import SwiftUI
import WidgetKit

struct CalendarEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}
struct CalendarProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalendarEntry {
        let date = Date()
        let shift = Shift(date: date, title: "Plantão", location: "Hospital", start: date, end: date, color: .red)
        return CalendarEntry(date: date, snapshot: WidgetSnapshot(shifts: [shift], appearance: "system", updatedAt: date))
    }
    func getSnapshot(in context: Context, completion: @escaping (CalendarEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : CalendarEntry(date: Date(), snapshot: WidgetData.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarEntry>) -> Void) {
        let now = Date(), snapshot = WidgetData.load()
        let calendar = Calendar.current
        // Precompute day/month changes even when the app stays closed for several days.
        let entries = [CalendarEntry(date: now, snapshot: snapshot)] + (1...7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)).map { CalendarEntry(date: $0, snapshot: snapshot) }
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}
struct CalendarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var systemScheme
    let entry: CalendarEntry
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var appearance: ColorScheme? { entry.snapshot.appearance == "dark" ? .dark : entry.snapshot.appearance == "light" ? .light : nil }
    private var calendar: Calendar { var c = Calendar.current; c.firstWeekday = 1; return c }
    private var first: Date { calendar.dateInterval(of: .month, for: entry.date)!.start }
    private var offset: Int { calendar.component(.weekday, from: first) - 1 }
    private var rows: Int { (offset + calendar.range(of: .day, in: .month, for: entry.date)!.count + 6) / 7 }
    var body: some View {
        GeometryReader { geometry in
            let titleHeight: CGFloat = large ? 32 : 19
            let weekdayHeight: CGFloat = large ? 24 : 15
            let rowHeight = max(1, (geometry.size.height - titleHeight - weekdayHeight) / CGFloat(rows))
            let cellWidth = geometry.size.width / 7
            let ring = min(cellWidth - 5, rowHeight - (large ? 8 : 2))
            let font: CGFloat = large ? min(18, ring * 0.61) : min(small ? 11 : 13, ring * 0.66)
            VStack(spacing: 0) {
                Text(entry.date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "pt_BR"))).uppercased())
                    .font(.system(size: large ? 17 : 12, weight: .bold))
                    .foregroundStyle(Color.orange).frame(height: titleHeight)
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        Text(["D", "S", "T", "Q", "Q", "S", "S"][column])
                            .font(.system(size: large ? 13 : 9)).foregroundStyle(.secondary)
                            .frame(width: cellWidth, height: weekdayHeight)
                    }
                }
                // Eager stacks render all aros in WidgetKit's snapshot, with square circles.
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { column in
                            let day = calendar.date(byAdding: .day, value: row * 7 + column - offset, to: first)!
                            Link(destination: WidgetData.url(for: day)) {
                                dayCell(day, font: font, ring: max(5, ring))
                                    .frame(width: cellWidth, height: rowHeight)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(.horizontal, small ? 9 : 14).padding(.vertical, large ? 12 : 8)
        .environment(\.locale, Locale(identifier: "pt_BR"))
        .preferredColorScheme(appearance)
        .widgetURL(WidgetData.url(for: entry.date))
        .containerBackground(.background, for: .widget)
        .environment(\.colorScheme, appearance ?? systemScheme)
    }
    private func dayCell(_ day: Date, font: CGFloat, ring: CGFloat) -> some View {
        let inMonth = calendar.isDate(day, equalTo: entry.date, toGranularity: .month)
        let today = calendar.isDate(day, inSameDayAs: entry.date)
        let shifts = entry.snapshot.shifts.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let colors = shifts.reduce(into: [ShiftColor]()) { if !$0.contains($1.color) { $0.append($1.color) } }
        return ZStack {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                Circle().trim(from: Double(index) / Double(colors.count) + (colors.count > 1 ? 0.015 : 0), to: Double(index + 1) / Double(colors.count) - (colors.count > 1 ? 0.015 : 0))
                    .stroke(color.value.opacity(inMonth ? 1 : 0.28), style: StrokeStyle(lineWidth: large ? 1.9 : 1.3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: font, weight: today ? .bold : .regular))
                .foregroundStyle(today ? Color.orange : inMonth ? Color.primary : Color.secondary.opacity(0.4))
        }.frame(width: ring, height: ring)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(date: .abbreviated, time: .omitted)), \(shifts.count) plantões")
    }
}
@main
struct PlantaoCalendarWidget: Widget {
    let kind = "PlantaoNaMaoCalendar"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalendarProvider()) { CalendarWidgetView(entry: $0) }
            .configurationDisplayName("Plantão na Mão")
            .description("Seu mês inteiro com aros nas cores dos plantões.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
            .contentMarginsDisabled()
    }
}
