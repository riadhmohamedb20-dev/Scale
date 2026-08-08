import SwiftUI

/// Step 2 of "Continue Without Selecting an Activity" — picks just the activity type
/// (Pain/Pleasure/Other) for a session with no linked activity. Visually mirrors
/// `ChooseActivityTypeView`'s type cards, but selecting one resolves the type directly
/// instead of navigating to a list of specific activities.
struct ChooseUnlinkedActivityTypeView: View {
    var onCancel: () -> Void
    var onSelect: (ActivityType) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        isDark ? Color(red: 0.93, green: 0.93, blue: 0.95) : .primary
    }

    private var secondaryTextColor: Color {
        isDark ? Color(red: 0.68, green: 0.68, blue: 0.71) : .secondary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cancelButton
                    .padding(.top, 20)

                Text("Choose Type")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
                    .padding(.top, 28)

                Text("Track without a specific activity — just pick what kind it is.")
                    .font(.system(size: 17))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    ForEach(ActivityType.allCases) { type in
                        typeCard(for: type)
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(primaryTextColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(activityPickerSystemBackground)))
    }

    private func typeCard(for type: ActivityType) -> some View {
        Button {
            onSelect(type)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isDark ? type.pickerAccentColor.opacity(0.28) : type.pickerIconBackground)
                        .frame(width: 52, height: 52)

                    Image(systemName: type.pickerIconName)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(isDark ? type.pickerAccentColor : Color.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(isDark ? type.pickerAccentColor : Color.primary)

                    Text(type.pickerDescription)
                        .font(.system(size: 15))
                        .foregroundStyle(secondaryTextColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryTextColor.opacity(0.6))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isDark ? type.pickerAccentColor.opacity(0.12) : Color(activityPickerSystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

/// Step 3 (Pain/Pleasure only) — picks the priority/level, reusing the same `PrioritySelector`
/// component used when creating a real activity, then starts tracking on confirmation.
struct ChooseUnlinkedActivityPriorityView: View {
    let type: ActivityType
    var onCancel: () -> Void
    var onConfirm: (ActivityPriority) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var selection: ActivityPriority? = .medium

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var primaryTextColor: Color {
        isDark ? Color(red: 0.93, green: 0.93, blue: 0.95) : .primary
    }

    private var secondaryTextColor: Color {
        isDark ? Color(red: 0.68, green: 0.68, blue: 0.71) : .secondary
    }

    private var levelLabel: String {
        type == .pleasure ? "Level" : "Priority"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cancelButton
                    .padding(.top, 20)

                Text("\(type.title) \(levelLabel)")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(primaryTextColor)
                    .padding(.top, 28)

                Text("Choose the \(levelLabel.lowercased()) for this session.")
                    .font(.system(size: 17))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, 12)

                PrioritySelector(selection: $selection)
                    .padding(.top, 24)

                Button {
                    guard let selection else { return }
                    onConfirm(selection)
                } label: {
                    Text("Start Tracking")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(type.pickerAccentColor))
                }
                .buttonStyle(.plain)
                .disabled(selection == nil)
                .opacity(selection == nil ? 0.4 : 1)
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(primaryTextColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(activityPickerSystemBackground)))
    }
}
