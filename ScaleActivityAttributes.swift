import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct ScaleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var activityTitle: String
        var activityTypeTitle: String
        var displayStartDate: Date
        var pausedElapsed: TimeInterval
        var isPaused: Bool
        var colorRed: Double
        var colorGreen: Double
        var colorBlue: Double
        /// The moment the activity's budget countdown reaches zero, when the activity type
        /// uses one (e.g. Pain's priority-scoped budget). Nil means there is no countdown
        /// for this activity and the time text should show elapsed time instead. Always a
        /// fresh "now + remaining" snapshot as of the last sync, so it can drive a native
        /// Text(timerInterval:) that ticks live without any further app-side updates.
        var countdownEndDate: Date?
        /// Non-nil exactly when paused and the activity has a countdown — freezes the native
        /// timer text at the remaining value as of this moment via Text(timerInterval:pauseTime:).
        var countdownPauseDate: Date?
    }

    var activityID: UUID
}
#endif
