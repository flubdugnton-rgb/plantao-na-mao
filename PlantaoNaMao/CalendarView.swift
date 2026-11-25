import SwiftUI

struct MonthCalendar: View {
    @EnvironmentObject private var store: ShiftStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedDate: Date
    let accent: Color
    let compact: Bool
    let onMonthChange: (Int) -> Void
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.18))) private var dragOffset: CGFloat = 0
    @State private var transitionOffset: CGFloat = 0
    @State private var isPaging = false
    private var calendar: Calendar { Calendar.current }
    var body: some View {
        // Keep the current grid's intrinsic height while adjacent months follow the finger.
        monthGrid(for: selectedDate, isCurrentPage: false).hidden().accessibilityHidden(true)
            .overlay {
                GeometryReader { geometry in
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(-1...1, id: \.self) { page in
                            let date = calendar.date(byAdding: .month, value: page, to: selectedDate) ?? selectedDate
                            monthGrid(for: date, isCurrentPage: page == 0)
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                .accessibilityHidden(page != 0)
                                .allowsHitTesting(page == 0)
                        }
                    }
                    .offset(x: -geometry.size.width + (isPaging ? transitionOffset : dragOffset))
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
                    .contentShape(Rectangle())
                    .highPriorityGesture(monthSwipe(width: geometry.size.width))
                }
            }
            .clipped()
            .allowsHitTesting(!isPaging)
    }

    private func monthSwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, offset, _ in
                guard !isPaging, abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                offset = min(width, max(-width, value.translation.width))
            }
            .onEnded { value in
                let horizontal = value.translation.width
                guard !isPaging, abs(horizontal) >= 20,
                      abs(horizontal) > abs(value.translation.height) * 1.2 else { return }
                let threshold = min(56, width * 0.18)
                let projected = value.predictedEndTranslation.width
                guard abs(horizontal) >= threshold || (abs(projected) >= threshold && horizontal * projected > 0) else { return }
                let delta = horizontal < 0 ? 1 : -1
                let originalDate = selectedDate
                transitionOffset = min(width, max(-width, horizontal))
                isPaging = true
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2), completionCriteria: .logicallyComplete) {
                    transitionOffset = delta > 0 ? -width : width
                } completion: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if selectedDate == originalDate { onMonthChange(delta) }
                        transitionOffset = 0
                        isPaging = false
                    }
                }
            }
    }

    private func monthGrid(for date: Date, isCurrentPage: Bool = true) -> some View {
        let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let offset = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        // Weekday labels and dates share one grid, including column widths and spacing.
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: compact ? 1 : 4) {
            ForEach(0..<(7 + offset + count), id: \.self) { index in
                if index < 7 {
                    Text(["D", "S", "T", "Q", "Q", "S", "S"][(calendar.firstWeekday - 1 + index) % 7])
                        .font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, compact ? 1 : 3)
                        .accessibilityIdentifier(isCurrentPage ? "weekday-column-\(index)" : "")
                        .accessibilityHidden(!isCurrentPage)
                } else if index < 7 + offset {
                    Color.clear.frame(height: compact ? 27 : 39)
                } else {
                    let day = calendar.date(byAdding: .day, value: index - 7 - offset, to: first) ?? first
                    CalendarDay(date: day, selected: calendar.isDate(day, inSameDayAs: date),
                                shifts: store.on(day), accent: accent, size: compact ? 27 : 39,
                                isInteractive: isCurrentPage) { selectedDate = day }
                        .accessibilityHidden(!isCurrentPage)
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
    let isInteractive: Bool
    let action: () -> Void
    private var colors: [ShiftColor] {
        shifts.reduce(into: [ShiftColor]()) { if !$0.contains($1.color) { $0.append($1.color) } }
    }
    var body: some View {
        if isInteractive {
            Button(action: action) { dayContent }
                .buttonStyle(.plain)
                .accessibilityIdentifier("calendar-day-\(Calendar.current.component(.day, from: date))")
                .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(shifts.count) plantões\(colors.isEmpty ? "" : ", " + colors.map(\.name).joined(separator: ", "))")
                .accessibilityAddTraits(selected ? .isSelected : [])
        } else {
            dayContent.accessibilityElement(children: .ignore).accessibilityHidden(true)
        }
    }
    private var dayContent: some View {
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

