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
        startTime: Date,
        runningStartTime: Date?,
        elapsedBeforePause: TimeInterval,
        isPaused: Bool,
        painCountdownRemaining: TimeInterval?
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let contentState = contentState(
            for: task,
            startTime: startTime,
            runningStartTime: runningStartTime,
            elapsedBeforePause: elapsedBeforePause,
            isPaused: isPaused,
            painCountdownRemaining: painCountdownRemaining
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
        startTime: Date,
        runningStartTime: Date?,
        elapsedBeforePause: TimeInterval,
        isPaused: Bool,
        painCountdownRemaining: TimeInterval?
    ) -> ScaleActivityAttributes.ContentState {
        let now = Date()
        let displayStartDate = (runningStartTime ?? startTime).addingTimeInterval(-elapsedBeforePause)
        let pausedElapsed = max(elapsedBeforePause, 0)

        // Always a fresh "now + remaining" snapshot, so Text(timerInterval:) can tick live on its
        // own from here with no further app-side updates. When paused, countdownPauseDate is set to
        // this same "now", so the native timer text freezes at exactly painCountdownRemaining.
        let countdownEndDate = painCountdownRemaining.map { now.addingTimeInterval($0) }
        let countdownPauseDate = (countdownEndDate != nil && isPaused) ? now : nil

        return ScaleActivityAttributes.ContentState(
            activityTitle: task.name,
            activityTypeTitle: task.activityType.title,
            displayStartDate: displayStartDate,
            pausedElapsed: pausedElapsed,
            isPaused: isPaused,
            colorRed: task.color.red,
            colorGreen: task.color.green,
            colorBlue: task.color.blue,
            countdownEndDate: countdownEndDate,
            countdownPauseDate: countdownPauseDate
        )
    }
}
#endif
