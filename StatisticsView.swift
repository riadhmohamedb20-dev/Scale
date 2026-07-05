import SwiftUI
import Charts

struct StatisticsView: View {
    @ObservedObject var viewModel: TimeCircleViewModel

    private var summaries: [TaskTimeSummary] {
        viewModel.taskTimeSummaries
    }

    private var typeSummaries: [ActivityTypeTimeSummary] {
        viewModel.activityTypeTimeSummaries
    }

    private var totalTrackedTime: TimeInterval {
        summaries.reduce(0) { $0 + $1.duration }
    }

    private var hasEnoughChartData: Bool {
        totalTrackedTime >= 60
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Statistics")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 22)

                summaryCards
                activityBalanceCard

                if summaries.isEmpty {
                    emptyState
                } else if !hasEnoughChartData {
                    lowDataState
                    taskTotalsCard
                } else {
                    chartsGrid
                    taskTotalsCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(platformSystemBackground).ignoresSafeArea())
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
            SummaryCard(title: "Today", duration: viewModel.todayTrackedTime)
            SummaryCard(title: "This Week", duration: viewModel.weekTrackedTime)
            SummaryCard(title: "This Month", duration: viewModel.monthTrackedTime)
        }
    }

    private var activityBalanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Balance")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(typeSummaries) { summary in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(color(for: summary.activityType))
                            .frame(width: 12, height: 12)

                        Text(summary.activityType.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(balanceDuration(Int(summary.duration))) / \(balanceDuration(Int(summary.targetDuration)))")
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.primary)

                            Text("\(balanceDuration(Int(summary.remainingDuration))) remaining")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Text("\(summary.percentage)%")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var chartsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
            chartCard(title: "Time by activity") {
                Chart(summaries) { summary in
                    SectorMark(
                        angle: .value("Time", summary.duration),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.2
                    )
                    .foregroundStyle(summary.color.color)
                }
                .frame(height: 150)
            }

            chartCard(title: "Activity totals") {
                Chart(summaries) { summary in
                    BarMark(
                        x: .value("Time", summary.duration),
                        y: .value("Activity", summary.taskName)
                    )
                    .foregroundStyle(summary.color.color)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom) { value in
                        AxisGridLine()
                            .foregroundStyle(.secondary.opacity(0.35))
                        AxisTick()
                            .foregroundStyle(.secondary)
                        AxisValueLabel {
                            if let seconds = value.as(Double.self) {
                                Text(TimeCircleFormat.readable(Int(seconds)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisValueLabel()
                            .foregroundStyle(.primary)
                    }
                }
                .frame(height: min(max(CGFloat(summaries.count) * 34, 120), 190))
            }
        }
    }

    private var taskTotalsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed sessions by activity")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            VStack(spacing: 12) {
                ForEach(summaries) { summary in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(summary.color.color)
                            .frame(width: 12, height: 12)

                        Text(summary.taskName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        Text(TimeCircleFormat.readable(Int(summary.duration)))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No completed sessions yet")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("Complete a session to see your time totals and charts here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .cardStyle()
    }

    private var lowDataState: some View {
        VStack(spacing: 8) {
            Text("Keep tracking")
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text("A little more tracked time will make the charts useful. Your totals are shown below.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardStyle()
    }

    private func chartCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            content()
        }
        .cardStyle()
    }

    private func color(for activityType: ActivityType) -> Color {
        switch activityType {
        case .none:
            return Color.secondary
        case .pleasure:
            return Color(red: 0.76, green: 0.24, blue: 0.86)
        case .neutral:
            return Color(red: 0.56, green: 0.56, blue: 0.58)
        case .pain:
            return Color(red: 1.0, green: 0.23, blue: 0.19)
        }
    }

    private func balanceDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return String(format: "00:%02d", max(seconds, 0))
        }

        let h = seconds / 3600
        let m = (seconds % 3600) / 60

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        } else {
            return "\(m)m"
        }
    }
}

private struct SummaryCard: View {
    var title: String
    var duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            Text(TimeCircleFormat.readable(Int(duration)))
                .font(.system(size: 24, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(16)
            .background(Color(platformSystemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private var platformSystemGray6: PlatformColor {
    #if canImport(UIKit)
    UIColor.systemGray6
    #else
    NSColor.controlBackgroundColor
    #endif
}

private var platformSystemBackground: PlatformColor {
    #if canImport(UIKit)
    UIColor.systemBackground
    #else
    NSColor.windowBackgroundColor
    #endif
}

#if canImport(UIKit)
private typealias PlatformColor = UIColor
#else
private typealias PlatformColor = NSColor
#endif
