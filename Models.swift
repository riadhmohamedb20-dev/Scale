import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct StoredColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    init(from color: Color) {
        #if canImport(UIKit)
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        red = Double(r)
        green = Double(g)
        blue = Double(b)
        opacity = Double(a)
        #elseif canImport(AppKit)
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? .black

        red = Double(nsColor.redComponent)
        green = Double(nsColor.greenComponent)
        blue = Double(nsColor.blueComponent)
        opacity = Double(nsColor.alphaComponent)
        #endif
    }

    static let red = StoredColor(red: 1, green: 0.25, blue: 0.28)
    static let blue = StoredColor(red: 0.1, green: 0.55, blue: 1)
    static let green = StoredColor(red: 0.1, green: 0.7, blue: 0.3)
    static let orange = StoredColor(red: 1, green: 0.55, blue: 0.15)
    static let purple = StoredColor(red: 0.6, green: 0.35, blue: 0.9)
    static let pink = StoredColor(red: 1, green: 0.2, blue: 0.6)
}

struct TaskItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var color: StoredColor
    var description: String
    var activityType: ActivityType
    var priority: ActivityPriority?

    init(
        id: UUID = UUID(),
        name: String,
        color: StoredColor,
        description: String = "",
        activityType: ActivityType = .pain,
        priority: ActivityPriority? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.description = description
        self.activityType = activityType
        self.priority = activityType.usesDailyTarget ? (priority ?? .medium) : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case description
        case activityType
        case priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(StoredColor.self, forKey: .color)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) ?? .pain
        let decodedPriority = try container.decodeIfPresent(ActivityPriority.self, forKey: .priority)
        priority = activityType.usesDailyTarget ? (decodedPriority ?? .medium) : nil
    }
}

enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case none
    case pain
    case pleasure

    static let allCases: [ActivityType] = [.pain, .pleasure, .none]

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none:
            return "Neutral"
        case .pain:
            return "Pain"
        case .pleasure:
            return "Pleasure"
        }
    }

    var usesDailyTarget: Bool {
        self == .pain || self == .pleasure
    }

    /// Aggregate of all three priority budgets combined, for display-only rollups (statistics, heatmap).
    /// Actual budget enforcement happens per-priority via `ActivityPriority.dailyBudgetDuration`.
    var totalDailyBudgetDuration: TimeInterval {
        guard usesDailyTarget else { return 0 }
        return ActivityPriority.allCases.reduce(0) { $0 + $1.dailyBudgetDuration }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case Self.none.rawValue, "neutral", "rest":
            self = .none
        case Self.pain.rawValue:
            self = .pain
        case Self.pleasure.rawValue:
            self = .pleasure
        default:
            self = .pain
        }
    }
}

enum ActivityPriority: String, CaseIterable, Identifiable, Codable {
    case high
    case medium
    case low

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }

    /// Each priority owns its own independent 2-hour daily timer, shared by every
    /// activity of that (type, priority) combination — the timer belongs to the
    /// priority, not to any individual activity or session.
    var dailyBudgetDuration: TimeInterval {
        7_200
    }
}

struct TaskChipItem: Identifiable, Equatable {
    var id: String
    var taskID: UUID?
    var name: String
    var color: StoredColor
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "Automatic"
        }
    }

    var iconName: String {
        switch self {
        case .light:
            return "sun.max.circle"
        case .dark:
            return "moon.circle"
        case .system:
            return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}

struct SessionItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var taskName: String
    var color: StoredColor
    var startTime: Date
    var duration: TimeInterval
    var activityType: ActivityType
    var sessionDescription: String
    var subActivityIDs: [UUID]
    var priority: ActivityPriority?

    init(
        id: UUID = UUID(),
        taskName: String,
        color: StoredColor,
        startTime: Date,
        duration: TimeInterval,
        activityType: ActivityType = .pain,
        sessionDescription: String = "",
        subActivityIDs: [UUID] = [],
        priority: ActivityPriority? = nil
    ) {
        self.id = id
        self.taskName = taskName
        self.color = color
        self.startTime = startTime
        self.duration = duration
        self.activityType = activityType
        self.sessionDescription = sessionDescription
        self.subActivityIDs = subActivityIDs
        self.priority = activityType.usesDailyTarget ? (priority ?? .medium) : nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskName
        case color
        case startTime
        case duration
        case activityType
        case sessionDescription
        case subActivityIDs
        case priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        taskName = try container.decode(String.self, forKey: .taskName)
        color = try container.decode(StoredColor.self, forKey: .color)
        startTime = try container.decode(Date.self, forKey: .startTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) ?? .pain
        sessionDescription = try container.decodeIfPresent(String.self, forKey: .sessionDescription) ?? ""
        subActivityIDs = try container.decodeIfPresent([UUID].self, forKey: .subActivityIDs) ?? []
        let decodedPriority = try container.decodeIfPresent(ActivityPriority.self, forKey: .priority)
        priority = activityType.usesDailyTarget ? (decodedPriority ?? .medium) : nil
    }

    var endTime: Date {
        startTime.addingTimeInterval(duration)
    }

    var formattedStartTime: String {
        TimeCircleFormat.clock(startTime)
    }

    var formattedDuration: String {
        TimeCircleFormat.elapsed(Int(duration))
    }
}

struct ToDoItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    /// A specific existing activity this task belongs to. Mutually exclusive with
    /// `activityType` — at most one of the two is ever set at a time.
    var activityTaskID: UUID?
    /// A bare Pain/Pleasure/Neutral category, used when the task isn't tied to any
    /// specific activity yet (e.g. the activity doesn't exist in the app so far).
    var activityType: ActivityType?
    /// Only meaningful when `activityType` is set directly (no specific activity) and
    /// that type uses priority (Pain/Pleasure) — lets a bare-type task still land in the
    /// High/Medium/Low breakdown on the To-Do screen instead of only specific activities.
    var manualPriority: ActivityPriority?
    var day: Date
    var isCompleted: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        activityTaskID: UUID?,
        activityType: ActivityType? = nil,
        manualPriority: ActivityPriority? = nil,
        day: Date,
        isCompleted: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.activityTaskID = activityTaskID
        self.activityType = activityType
        self.manualPriority = activityType?.usesDailyTarget == true ? (manualPriority ?? .medium) : nil
        self.day = day
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }
}

/// A row in the To-Do "Activities" list. Top-level groups are Pain/Pleasure/Neutral
/// (`type` set, `activity` nil) or "Other" (`type` and `activity` nil).
///
/// For Pain/Pleasure, the type group's `subGroups` are priority groups (`priority` set,
/// `activity` nil) — one per High/Medium/Low that actually has a task in it — and each
/// priority group's own `subGroups` are the specific named activities at that priority.
/// For Neutral (no priority concept) and "Other", `subGroups` go straight to specific
/// named activities, skipping the priority layer entirely.
struct ToDoGroup: Identifiable {
    var id: String
    var type: ActivityType?
    var priority: ActivityPriority?
    var activity: TaskItem?
    var items: [ToDoItem]
    var subGroups: [ToDoGroup]
}

struct TaskTimeSummary: Identifiable, Equatable {
    var taskName: String
    var color: StoredColor
    var duration: TimeInterval

    var id: String {
        taskName
    }

    var formattedDuration: String {
        TimeCircleFormat.elapsed(Int(duration))
    }
}

struct ActivityTypeTimeSummary: Identifiable, Equatable {
    var activityType: ActivityType
    var duration: TimeInterval
    var totalDuration: TimeInterval
    var targetDuration: TimeInterval

    var id: ActivityType {
        activityType
    }

    var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int((duration / totalDuration * 100).rounded())
    }

    var remainingDuration: TimeInterval {
        max(targetDuration - duration, 0)
    }
}

struct DayHistorySummary: Identifiable, Equatable {
    var day: Date
    var sessions: [SessionItem]

    var id: Date {
        day
    }

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    var painDuration: TimeInterval {
        sessions
            .filter { $0.activityType == .pain }
            .reduce(0) { $0 + $1.duration }
    }

    var formattedDate: String {
        TimeCircleFormat.day(day)
    }

    var formattedDuration: String {
        TimeCircleFormat.readable(Int(totalDuration))
    }

    var taskColors: [StoredColor] {
        var seenNames: Set<String> = []
        return sessions.compactMap { session in
            guard !seenNames.contains(session.taskName) else { return nil }
            seenNames.insert(session.taskName)
            return session.color
        }
    }
}

enum TrackingState {
    case stopped, running, paused
}

struct ActiveTrackingState: Codable, Equatable {
    var taskID: UUID
    var startTime: Date
    var runningStartTime: Date?
    var elapsedBeforePause: TimeInterval
    var isPaused: Bool
    var activeIntervals: [ActiveTrackingInterval]

    init(
        taskID: UUID,
        startTime: Date,
        runningStartTime: Date?,
        elapsedBeforePause: TimeInterval,
        isPaused: Bool,
        activeIntervals: [ActiveTrackingInterval] = []
    ) {
        self.taskID = taskID
        self.startTime = startTime
        self.runningStartTime = runningStartTime
        self.elapsedBeforePause = elapsedBeforePause
        self.isPaused = isPaused
        self.activeIntervals = activeIntervals
    }

    private enum CodingKeys: String, CodingKey {
        case taskID
        case startTime
        case runningStartTime
        case elapsedBeforePause
        case isPaused
        case activeIntervals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        taskID = try container.decode(UUID.self, forKey: .taskID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        runningStartTime = try container.decodeIfPresent(Date.self, forKey: .runningStartTime)
        elapsedBeforePause = try container.decode(TimeInterval.self, forKey: .elapsedBeforePause)
        isPaused = try container.decode(Bool.self, forKey: .isPaused)
        activeIntervals = try container.decodeIfPresent([ActiveTrackingInterval].self, forKey: .activeIntervals) ?? []
    }
}

struct ActiveTrackingInterval: Codable, Equatable {
    var start: Date
    var end: Date
}

enum TimeCircleFormat {
    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    static func twentyFourHourClock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func seconds(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "ss"
        return formatter.string(from: date)
    }

    static func hourNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH"
        return formatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    static func weekdayMonthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    static func elapsed(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    static func centerTimer(_ seconds: Int) -> String {
        let clampedSeconds = max(seconds, 0)
        let h = clampedSeconds / 3600
        let m = (clampedSeconds % 3600) / 60
        let s = clampedSeconds % 60

        if h > 0 {
            return String(format: "%d:%02d", h, m)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    static func elapsedHoursMinutes(_ seconds: Int) -> String {
        let clampedSeconds = max(seconds, 0)
        let h = clampedSeconds / 3600
        let m = (clampedSeconds % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    static func elapsedSeconds(_ seconds: Int) -> String {
        let clampedSeconds = max(seconds, 0)
        let s = clampedSeconds % 60
        return String(format: "%02d", s)
    }

    static func countdownHoursMinutes(_ seconds: Int) -> String {
        let absoluteSeconds = abs(seconds)
        let h = absoluteSeconds / 3600
        let m = (absoluteSeconds % 3600) / 60
        let prefix = seconds < 0 ? "+" : ""
        return String(format: "\(prefix)%02d:%02d", h, m)
    }

    static func countdownSeconds(_ seconds: Int) -> String {
        let s = abs(seconds) % 60
        return String(format: "%02d", s)
    }

    static func readable(_ seconds: Int) -> String {
        if seconds < 60 {
            return String(format: "00:%02d", max(seconds, 0))
        }

        let h = seconds / 3600
        let m = (seconds % 3600) / 60

        if h > 0, m > 0 {
            return "\(h)h \(m)m"
        } else if h > 0 {
            return "\(h)h"
        } else {
            return "\(m)m"
        }
    }

    static func budgetRemaining(_ seconds: TimeInterval) -> String {
        let clampedSeconds = max(Int(seconds), 0)
        let h = clampedSeconds / 3600
        let m = (clampedSeconds % 3600) / 60

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        } else {
            return String(format: "%dm", m)
        }
    }

    static func budgetTotal(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 3600))h"
    }
}
