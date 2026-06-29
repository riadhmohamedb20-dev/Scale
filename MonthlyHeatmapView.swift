import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct MonthlyHeatmapView: View {
    let summaries: [DayHistorySummary]
    let selectedDay: Date
    let onSelectToday: () -> Void
    let onSelectDay: (Date) -> Void

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var heatmapContentHeight: CGFloat = 320

    private let squareSpacing: CGFloat = 6
    private let weekLabelWidth: CGFloat = 42
    private let weekdaySymbols = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        ZStack {
            Color(platformSystemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    monthHeader
                    heatmap
                    legendCard
                }
                .padding()
            }
        }
        .navigationTitle("")
        #if os(iOS) || os(tvOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthTitle)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
    }

    private var heatmap: some View {
        GeometryReader { proxy in
            let squareSize = min(64, max(28, (proxy.size.width - weekLabelWidth - (squareSpacing * 7)) / 7))
            let contentHeight = heatmapHeight(for: squareSize)

            VStack(alignment: .leading, spacing: squareSpacing) {
                HStack(spacing: squareSpacing) {
                    Color.clear
                        .frame(width: weekLabelWidth, height: 18)

                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: squareSize, height: 18)
                    }
                }

                ForEach(weekRows) { row in
                    HStack(spacing: squareSpacing) {
                        Text(row.weekLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: weekLabelWidth, height: squareSize, alignment: .leading)

                        ForEach(row.days) { day in
                            dayCell(for: day)
                                .frame(width: squareSize, height: squareSize)
                        }
                    }
                }
            }
            .frame(height: contentHeight, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(monthSwipeGesture)
            .onAppear {
                heatmapContentHeight = contentHeight
            }
            .onChange(of: contentHeight) { _, newValue in
                heatmapContentHeight = newValue
            }
        }
        .frame(height: heatmapContentHeight)
    }

    private func dayCell(for day: HeatmapDay) -> some View {
        Group {
            if day.kind != .currentMonth {
                Color.clear
            } else {
                dayButton(for: day.date, kind: day.kind)
            }
        }
    }

    private func dayButton(for day: Date, kind: HeatmapDay.Kind) -> some View {
        Button {
            if kind == .currentMonth {
                select(day)
            }
        } label: {
            RoundedRectangle(cornerRadius: 5)
                .fill(color(for: day, kind: kind))
                .overlay(
                    Text(kind == .currentMonth ? dayNumber(for: day) : "")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(textColor(for: day, kind: kind))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(shouldShowSelectionStroke(for: day, kind: kind) ? Color.primary.opacity(0.45) : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .disabled(kind != .currentMonth)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About this heatmap")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text("Each square represents the total time tracked for that day.")
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                legendRow(color: inactiveColor, title: "No activity")
                legendRow(color: lowActivityColor, title: "1 - 29 min")
                legendRow(color: mediumLowActivityColor, title: "30 min - 1 h 59 min")
                legendRow(color: mediumActivityColor, title: "2 h - 4 h 59 min")
                legendRow(color: highActivityColor, title: "5 h or more")
                legendRow(color: todayColor, title: "Today")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(platformSecondarySystemBackground))
        )
    }

    private func legendRow(color: Color, title: String) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 60

                guard abs(horizontalDistance) > horizontalThreshold,
                      abs(horizontalDistance) > abs(verticalDistance)
                else { return }

                if horizontalDistance < 0 {
                    moveMonth(by: 1)
                } else {
                    moveMonth(by: -1)
                }
            }
    }

    private func heatmapHeight(for squareSize: CGFloat) -> CGFloat {
        18 + squareSpacing + (CGFloat(weekRows.count) * squareSize) + (CGFloat(max(weekRows.count - 1, 0)) * squareSpacing)
    }

    private var weekRows: [HeatmapWeekRow] {
        guard let monthInterval = Calendar.current.dateInterval(of: .month, for: displayedMonth),
              let lastMonthDay = Calendar.current.date(byAdding: .day, value: -1, to: monthInterval.end)
        else { return [] }

        var rows: [HeatmapWeekRow] = []
        var weekStart = isoCalendar.startOfWeek(for: monthInterval.start)
        let finalWeekStart = isoCalendar.startOfWeek(for: lastMonthDay)

        while weekStart <= finalWeekStart {
            let days = (0..<7).compactMap { offset -> HeatmapDay? in
                guard let date = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) else {
                    return nil
                }
                let kind = heatmapDayKind(for: date, in: monthInterval)

                return HeatmapDay(
                    id: "\(weekStart.timeIntervalSince1970)-\(offset)",
                    date: date,
                    kind: kind
                )
            }

            rows.append(
                HeatmapWeekRow(
                    id: weekStart,
                    weekLabel: "W\(isoCalendar.component(.weekOfYear, from: weekStart))",
                    days: days
                )
            )

            guard let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
                break
            }
            weekStart = nextWeek
        }

        return rows
    }

    private var totalsByDay: [Date: TimeInterval] {
        Dictionary(uniqueKeysWithValues: summaries.map { summary in
            (Calendar.current.startOfDay(for: summary.day), summary.totalDuration)
        })
    }

    private var isoCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    private func totalDuration(on day: Date) -> TimeInterval {
        totalsByDay[Calendar.current.startOfDay(for: day)] ?? 0
    }

    private func heatmapDayKind(for day: Date, in monthInterval: DateInterval) -> HeatmapDay.Kind {
        if Calendar.current.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            return .currentMonth
        }

        return day < monthInterval.start ? .leading : .trailing
    }

    private func color(for day: Date, kind: HeatmapDay.Kind) -> Color {
        guard kind == .currentMonth else {
            return inactiveColor
        }

        if Calendar.current.isDateInToday(day) {
            return todayColor
        }

        switch totalDuration(on: day) {
        case 0:
            return inactiveColor
        case ..<1_800:
            return lowActivityColor
        case ..<7_200:
            return mediumLowActivityColor
        case ..<18_000:
            return mediumActivityColor
        default:
            return highActivityColor
        }
    }

    private func textColor(for day: Date, kind: HeatmapDay.Kind) -> Color {
        guard kind == .currentMonth else {
            return .clear
        }

        if Calendar.current.isDateInToday(day) {
            return .white
        }

        return totalDuration(on: day) >= 18_000 ? .white : .white.opacity(0.86)
    }

    private var inactiveColor: Color {
        Color.gray.opacity(0.55)
    }

    private var lowActivityColor: Color {
        Color(red: 0.75, green: 0.93, blue: 0.38)
    }

    private var mediumLowActivityColor: Color {
        Color(red: 0.55, green: 0.82, blue: 0.25)
    }

    private var mediumActivityColor: Color {
        Color(red: 0.28, green: 0.70, blue: 0.25)
    }

    private var highActivityColor: Color {
        Color(red: 0.00, green: 0.35, blue: 0.11)
    }

    private var todayColor: Color {
        Color.blue
    }

    private func dayNumber(for day: Date) -> String {
        String(Calendar.current.component(.day, from: day))
    }

    private func isSelected(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDay)
    }

    private func shouldShowSelectionStroke(for day: Date, kind: HeatmapDay.Kind) -> Bool {
        kind == .currentMonth && isSelected(day) && !Calendar.current.isDateInToday(day)
    }

    private func moveMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        }
    }

    private func select(_ day: Date) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if Calendar.current.isDateInToday(day) {
                onSelectToday()
            } else {
                onSelectDay(day)
            }
        }
    }
}

private struct HeatmapWeekRow: Identifiable {
    let id: Date
    let weekLabel: String
    let days: [HeatmapDay]
}

private struct HeatmapDay: Identifiable {
    enum Kind {
        case leading
        case currentMonth
        case trailing
    }

    let id: String
    let date: Date
    let kind: Kind
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }

    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

private var platformSystemBackground: HeatmapPlatformColor {
    #if canImport(UIKit)
    UIColor.systemBackground
    #else
    NSColor.windowBackgroundColor
    #endif
}

private var platformSecondarySystemBackground: HeatmapPlatformColor {
    #if canImport(UIKit)
    UIColor.secondarySystemBackground
    #else
    NSColor.controlBackgroundColor
    #endif
}

#if canImport(UIKit)
private typealias HeatmapPlatformColor = UIColor
#else
private typealias HeatmapPlatformColor = NSColor
#endif
