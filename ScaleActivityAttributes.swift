import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct ScaleActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var activityTitle: String
        var activityTypeTitle: String
        var displayStartDate: Date
        var isPaused: Bool
        var colorRed: Double
        var colorGreen: Double
        var colorBlue: Double
        /// The moment the activity's budget countdown reaches zero — set for Pain and Pleasure
        /// (both have a daily budget), nil for None (no budget, counts up instead). Always a
        /// fresh "now + remaining" snapshot as of the last sync, so it can drive a native
        /// Text(timerInterval:) that ticks live without any further app-side updates.
        var countdownEndDate: Date?
        /// Non-nil exactly when paused — freezes the native timer text (countdown or count-up)
        /// at its value as of this moment via Text(timerInterval:pauseTime:).
        var pauseDate: Date?
    }

    var activityID: UUID
}
#endif
