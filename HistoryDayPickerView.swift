import SwiftUI

struct HistoryDayPickerView: View {
    let summaries: [DayHistorySummary]
    let selectedDay: Date
    let onSelectToday: () -> Void
    let onSelectDay: (Date) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let todaySummary {
                    Section("Today") {
                        dayRow(todaySummary)
                    }
                }

                if let yesterdaySummary {
                    Section("Yesterday") {
                        dayRow(yesterdaySummary)
                    }
                }

                if !earlierSummaries.isEmpty {
                    Section("Earlier") {
                        ForEach(earlierSummaries) { summary in
                            dayRow(summary)
                        }
                    }
                }

                if !hasPreviousDays {
                    previousDaysEmptyState
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        MonthlyHeatmapView(
                            summaries: summaries,
                            selectedDay: selectedDay,
                            onSelectToday: onSelectToday,
                            onSelectDay: onSelectDay
                        )
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
        }
    }

    private var todaySummary: DayHistorySummary? {
        summaries.first { Calendar.current.isDateInToday($0.day) }
    }

    private var yesterdaySummary: DayHistorySummary? {
        summaries.first { Calendar.current.isDateInYesterday($0.day) }
    }

    private var earlierSummaries: [DayHistorySummary] {
        summaries.filter { summary in
            !Calendar.current.isDateInToday(summary.day)
                && !Calendar.current.isDateInYesterday(summary.day)
        }
    }

    private var hasPreviousDays: Bool {
        yesterdaySummary != nil || !earlierSummaries.isEmpty
    }

    private var previousDaysEmptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("No previous days yet")
                .foregroundStyle(.primary)

            Text("Complete a session and your history will appear here.")
                .foregroundStyle(.secondary)
        }
    }

    private func dayRow(_ summary: DayHistorySummary) -> some View {
        Button {
            select(summary)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title(for: summary.day))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    if shouldShowFullDate(for: summary.day) {
                        Text(fullDate(for: summary.day))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(summary.formattedDuration)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    taskDots(for: summary)
                }

                if isSelected(summary.day) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(isSelected: isSelected(summary.day)))
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(isSelected ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
            .padding(.vertical, 2)
    }

    private func taskDots(for summary: DayHistorySummary) -> some View {
        HStack(spacing: -2) {
            ForEach(Array(summary.taskColors.prefix(4).enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color.color)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
            }
        }
    }

    private func title(for day: Date) -> String {
        if Calendar.current.isDateInToday(day) {
            return "Today"
        }

        if Calendar.current.isDateInYesterday(day) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: day)
    }

    private func fullDate(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: day)
    }

    private func shouldShowFullDate(for day: Date) -> Bool {
        Calendar.current.isDateInToday(day) || Calendar.current.isDateInYesterday(day)
    }

    private func isSelected(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDay)
    }

    private func select(_ summary: DayHistorySummary) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if Calendar.current.isDateInToday(summary.day) {
                onSelectToday()
            } else {
                onSelectDay(summary.day)
            }
        }
    }
}
