import SwiftUI

extension ActivityType {
    var pickerIconName: String {
        switch self {
        case .pain:
            return "calendar"
        case .pleasure:
            return "face.smiling"
        case .none:
            return "minus.circle"
        }
    }

    var pickerIconBackground: Color {
        switch self {
        case .pain:
            return Color(red: 0.965, green: 0.894, blue: 0.686)
        case .pleasure:
            return Color(red: 0.996, green: 0.827, blue: 0.859)
        case .none:
            return Color(red: 0.843, green: 0.804, blue: 0.992)
        }
    }

    var pickerAccentColor: Color {
        switch self {
        case .pain:
            return Color(red: 244 / 255, green: 182 / 255, blue: 41 / 255)
        case .pleasure:
            return Color(red: 236 / 255, green: 64 / 255, blue: 122 / 255)
        case .none:
            return Color(red: 124 / 255, green: 92 / 255, blue: 239 / 255)
        }
    }

    var pickerDescription: String {
        switch self {
        case .pain:
            return "Activities related to a future project, obligation, or something you have to do."
        case .pleasure:
            return "Activities that you enjoy and bring you satisfaction."
        case .none:
            return "Activities that are neutral or neither painful nor pleasurable."
        }
    }
}

extension ActivityPriority {
    var pickerAccentColor: Color {
        switch self {
        case .high:
            return Color(red: 233 / 255, green: 61 / 255, blue: 119 / 255)
        case .medium:
            return Color(red: 246 / 255, green: 152 / 255, blue: 48 / 255)
        case .low:
            return Color(red: 40 / 255, green: 143 / 255, blue: 181 / 255)
        }
    }

    var pickerIconName: String {
        switch self {
        case .high:
            return "star.fill"
        case .medium:
            return "heart.fill"
        case .low:
            return "arrow.down"
        }
    }

    func pickerDescription(for type: ActivityType) -> String {
        switch type {
        case .pleasure:
            switch self {
            case .high:
                return "Activities that you enjoy a lot"
            case .medium:
                return "Activities that you enjoy moderately"
            case .low:
                return "Activities that you enjoy a little"
            }
        case .pain:
            switch self {
            case .high:
                return "Activities that feel very difficult"
            case .medium:
                return "Activities that feel moderately difficult"
            case .low:
                return "Activities that feel slightly difficult"
            }
        case .none:
            return ""
        }
    }
}

var activityPickerSystemBackground: ActivityPickerPlatformColor {
    #if canImport(UIKit)
    UIColor.systemBackground
    #else
    NSColor.windowBackgroundColor
    #endif
}

var activityPickerSecondarySystemBackground: ActivityPickerPlatformColor {
    #if canImport(UIKit)
    UIColor.secondarySystemBackground
    #else
    NSColor.controlBackgroundColor
    #endif
}

#if canImport(UIKit)
typealias ActivityPickerPlatformColor = UIColor
#else
typealias ActivityPickerPlatformColor = NSColor
#endif
