import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ScaleLiveActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScaleLiveActivityWidget()
    }
}

struct ScaleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScaleActivityAttributes.self) { context in
            LiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    activityColorDot(context.state)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.activityTitle)
                            .font(.headline)
                            .lineLimit(1)

                        Text(context.state.activityTypeTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timeText(for: context.state)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } compactLeading: {
                activityColorDot(context.state)
            } compactTrailing: {
                timeText(for: context.state)
                    .font(.caption2.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 50)
            } minimal: {
                activityColorDot(context.state)
            }
            .keylineTint(.black)
        }
    }
}

private struct LiveActivityLockScreenView: View {
    var state: ScaleActivityAttributes.ContentState

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: 16) {
                activityColorDot(state)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.activityTitle)
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Text(state.isPaused ? "Paused" : state.activityTypeTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                timeText(for: state)
                    .font(.system(size: 28, weight: .heavy).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(width: proxy.size.width, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black)
            )
            .frame(height: proxy.size.height, alignment: .center)
        }
    }
}

/// Plain elapsed time counting up like a stopwatch since `displayStartDate` — matches the in-app
/// ring and activity panel, which both show elapsed rather than a draining budget countdown.
/// `displayStartDate` is already shifted back by however much was tracked earlier today for this
/// activity's (type, priority) pool, so this reads as cumulative elapsed for today, not just the
/// current run. Uses the system's native timer text so it ticks live on-device every second with
/// no app-side polling — a TimelineView-driven timer is NOT guaranteed that treatment inside a
/// Live Activity, only Text(timerInterval:) is. `pauseTime` uses the same built-in mechanism to
/// freeze the display at its value as of that moment.
private func timeText(for state: ScaleActivityAttributes.ContentState) -> some View {
    Text(
        timerInterval: state.displayStartDate...Date.distantFuture,
        pauseTime: state.pauseDate,
        countsDown: false,
        showsHours: true
    )
}

private func activityColorDot(_ state: ScaleActivityAttributes.ContentState) -> some View {
    Circle()
        .fill(
            Color(
                red: state.colorRed,
                green: state.colorGreen,
                blue: state.colorBlue
            )
        )
}
