import SwiftUI

struct ChooseActivityTypeView: View {
    var recentTasks: [TaskItem] = []
    var onCancel: () -> Void
    var onSelect: (ActivityType) -> Void
    var onSelectTask: (TaskItem) -> Void = { _ in }
    var onLongPressTask: (TaskItem) -> Void = { _ in }
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

                Text("What kind of activity you want to track?")
                    .font(.system(size: 17))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, 12)

                if !recentTasks.isEmpty {
                    Text("RECENTLY TRACKED")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                        .padding(.top, 24)

                    recentlyTrackedRow
                        .padding(.top, 12)

                    Divider()
                        .padding(.top, 20)
                }

                Text("ALL ACTIVITY TYPES")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, recentTasks.isEmpty ? 24 : 20)

                VStack(spacing: 14) {
                    ForEach(ActivityType.allCases) { type in
                        typeCard(for: type)
                    }
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var recentlyTrackedRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(recentTasks) { task in
                    recentTaskPill(task)
                }
            }
        }
    }

    private func recentTaskPill(_ task: TaskItem) -> some View {
        RecentTaskPill(
            task: task,
            textColor: primaryTextColor,
            backgroundOpacity: isDark ? 0.35 : 0.25,
            onTap: { onSelectTask(task) },
            onLongPress: { onLongPressTask(task) }
        )
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

private struct RecentTaskPill: View {
    let task: TaskItem
    let textColor: Color
    let backgroundOpacity: Double
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isLongPressing = false

    var body: some View {
        Text(task.name)
            .font(.system(size: 16, weight: .bold))
            .lineLimit(1)
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(task.color.color.opacity(backgroundOpacity)))
            .opacity(isLongPressing ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.12), value: isLongPressing)
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(
                minimumDuration: 0.4,
                maximumDistance: 16,
                pressing: { pressing in
                    isLongPressing = pressing
                },
                perform: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isLongPressing = false
                    }
                    onLongPress()
                }
            )
    }
}
