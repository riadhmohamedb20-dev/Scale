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
    }

    var activityID: UUID
}
#endif
