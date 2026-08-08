import Foundation
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
        /// Non-nil exactly when paused — freezes the native count-up timer text at its value as
        /// of this moment via Text(timerInterval:pauseTime:).
        var pauseDate: Date?
    }

    var activityID: UUID
}
