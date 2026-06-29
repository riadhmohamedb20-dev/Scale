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

    init(
        id: UUID = UUID(),
        name: String,
        color: StoredColor,
        description: String = "",
        activityType: ActivityType = .pain
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.description = description
        self.activityType = activityType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
        case description
        case activityType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        color = try container.decode(StoredColor.self, forKey: .color)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) ?? .pain
    }
}

enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case pain
    case pleasure
    case rest

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .pain:
            return "Pain"
        case .pleasure:
            return "Pleasure"
        case .rest:
            return "Rest"
        }
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

    init(
        id: UUID = UUID(),
        taskName: String,
        color: StoredColor,
        startTime: Date,
        duration: TimeInterval,
        activityType: ActivityType = .pain
    ) {
        self.id = id
        self.taskName = taskName
        self.color = color
        self.startTime = startTime
        self.duration = duration
        self.activityType = activityType
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case taskName
        case color
        case startTime
        case duration
        case activityType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        taskName = try container.decode(String.self, forKey: .taskName)
        color = try container.decode(StoredColor.self, forKey: .color)
        startTime = try container.decode(Date.self, forKey: .startTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        activityType = try container.decodeIfPresent(ActivityType.self, forKey: .activityType) ?? .pain
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

    var id: ActivityType {
        activityType
    }

    var percentage: Int {
        guard totalDuration > 0 else { return 0 }
        return Int((duration / totalDuration * 100).rounded())
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
}
