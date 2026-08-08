import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.2, *)
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<ScaleActivityAttributes>?

    private init() {}

    func startOrUpdate(
        task: TaskItem,
        runningStartTime: Date?,
        elapsedBeforePause: TimeInterval,
        isPaused: Bool,
        priorTodayElapsed: TimeInterval
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = contentState(
            for: task,
            runningStartTime: runningStartTime,
            elapsedBeforePause: elapsedBeforePause,
            isPaused: isPaused,
            priorTodayElapsed: priorTodayElapsed
        )

        Task {
            if currentActivity == nil {
                currentActivity = Activity<ScaleActivityAttributes>.activities.first
            }

            if let currentActivity {
                await currentActivity.update(ActivityContent(state: contentState, staleDate: nil))
            } else {
                do {
                    let attributes = ScaleActivityAttributes(activityID: task.id)
                    currentActivity = try Activity.request(
                        attributes: attributes,
                        content: ActivityContent(state: contentState, staleDate: nil),
                        pushType: nil
                    )
                } catch {
                    currentActivity = nil
                }
            }
        }
    }

    func end() {
        Task {
            for activity in Activity<ScaleActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            currentActivity = nil
        }
    }

    private func contentState(
        for task: TaskItem,
        runningStartTime: Date?,
        elapsedBeforePause: TimeInterval,
        isPaused: Bool,
        priorTodayElapsed: TimeInterval
    ) -> ScaleActivityAttributes.ContentState {
        let now = Date()

        // While running, elapsed = now - displayStartDate must hold, anchored to the fresh
        // runningStartTime. While paused there's no running anchor, so anchor to "now" itself —
        // paired with pauseDate (also "now" below), that freezes the count-up display at exactly
        // elapsedBeforePause. Using the original session startTime here instead would corrupt
        // the count-up freeze value after more than one pause/resume. Shifting further back by
        // priorTodayElapsed makes the displayed count-up read as cumulative elapsed for today
        // (matching the in-app ring/panel), not just elapsed in this particular run.
        let displayStartDate = (runningStartTime ?? now)
            .addingTimeInterval(-elapsedBeforePause)
            .addingTimeInterval(-priorTodayElapsed)

        let pauseDate = isPaused ? now : nil

        return ScaleActivityAttributes.ContentState(
            activityTitle: task.name,
            activityTypeTitle: task.activityType.title,
            displayStartDate: displayStartDate,
            isPaused: isPaused,
            colorRed: task.color.red,
            colorGreen: task.color.green,
            colorBlue: task.color.blue,
            pauseDate: pauseDate
        )
    }
}
#endif
