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
        budgetCountdownRemaining: TimeInterval?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = contentState(
            for: task,
            runningStartTime: runningStartTime,
            elapsedBeforePause: elapsedBeforePause,
            isPaused: isPaused,
            budgetCountdownRemaining: budgetCountdownRemaining
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
        budgetCountdownRemaining: TimeInterval?
    ) -> ScaleActivityAttributes.ContentState {
        let now = Date()

        // While running, elapsed = now - displayStartDate must hold, anchored to the fresh
        // runningStartTime. While paused there's no running anchor, so anchor to "now" itself —
        // paired with pauseDate (also "now" below), that freezes a count-up display at exactly
        // elapsedBeforePause. Using the original session startTime here instead would corrupt
        // the count-up freeze value for None-type activities after more than one pause/resume.
        let displayStartDate = (runningStartTime ?? now).addingTimeInterval(-elapsedBeforePause)

        // Always a fresh "now + remaining" snapshot, so Text(timerInterval:) can tick live on its
        // own from here with no further app-side updates. When paused, pauseDate is set to this
        // same "now", so the native timer text freezes at exactly budgetCountdownRemaining.
        let countdownEndDate = budgetCountdownRemaining.map { now.addingTimeInterval($0) }
        let pauseDate = isPaused ? now : nil

        return ScaleActivityAttributes.ContentState(
            activityTitle: task.name,
            activityTypeTitle: task.activityType.title,
            displayStartDate: displayStartDate,
            isPaused: isPaused,
            colorRed: task.color.red,
            colorGreen: task.color.green,
            colorBlue: task.color.blue,
            countdownEndDate: countdownEndDate,
            pauseDate: pauseDate
        )
    }
}
#endif
