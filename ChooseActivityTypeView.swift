import SwiftUI

struct ChooseActivityTypeView: View {
    var recentTasks: [TaskItem] = []
    var tasks: [TaskItem] = []
    var onCancel: () -> Void
    var onSelect: (ActivityType) -> Void
    var onSelectTask: (TaskItem) -> Void = { _ in }
    var onLongPressTask: (TaskItem) -> Void = { _ in }
    var onContinueWithoutActivity: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private func matchingTasks(for type: ActivityType) -> [TaskItem] {
        tasks.filter {
            $0.activityType == type && $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var filteredActivityTypes: [ActivityType] {
        guard isSearching else {
            return ActivityType.allCases
        }
        return ActivityType.allCases.filter { !matchingTasks(for: $0).isEmpty }
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

                searchField
                    .padding(.top, 16)

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
                    ForEach(filteredActivityTypes) { type in
                        if isSearching {
                            searchResultSection(for: type)
                        } else {
                            typeCard(for: type)
                        }
                    }
                }
                .padding(.top, 12)

                continueWithoutActivityButton
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var continueWithoutActivityButton: some View {
        Button(action: onContinueWithoutActivity) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                }

                Text("Continue Without Selecting an Activity")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryTextColor.opacity(0.6))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(activityPickerSystemBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search activities...", text: $searchText)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
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

    private func searchResultSection(for type: ActivityType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDark ? type.pickerAccentColor.opacity(0.28) : type.pickerIconBackground)
                        .frame(width: 36, height: 36)

                    Image(systemName: type.pickerIconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDark ? type.pickerAccentColor : Color.primary)
                }

                Text(type.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isDark ? type.pickerAccentColor : Color.primary)
            }

            VStack(spacing: 0) {
                ForEach(Array(matchingTasks(for: type).enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 46)
                    }
                    searchResultRow(task)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(activityPickerSystemBackground))
            )
        }
    }

    private func searchResultRow(_ task: TaskItem) -> some View {
        Button {
            onSelectTask(task)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(task.color.color)
                    .frame(width: 12, height: 12)

                Text(task.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(secondaryTextColor.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
