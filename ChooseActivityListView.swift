import SwiftUI

struct ChooseActivityListView: View {
    let type: ActivityType
    let tasks: [TaskItem]
    var onBack: () -> Void
    var onSelect: (TaskItem) -> Void
    var onCreateNew: () -> Void
    var onLongPress: (TaskItem) -> Void = { _ in }
    @Environment(\.colorScheme) private var colorScheme

    private func tasks(for priority: ActivityPriority) -> [TaskItem] {
        tasks.filter { $0.priority == priority }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                backButton
                    .padding(.top, 20)

                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? type.pickerAccentColor : type.pickerIconBackground)
                            .frame(width: 44, height: 44)

                        Image(systemName: type.pickerIconName)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    Text(type.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(type.pickerAccentColor)
                }
                .padding(.top, 24)

                Text("Choose Activity")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 16)

                Text(type.pickerDescription)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                if type.hasPriorityTiers {
                    VStack(spacing: 14) {
                        ForEach(ActivityPriority.allCases) { priority in
                            priorityCard(priority)
                        }
                    }
                    .padding(.top, 24)
                } else if !tasks.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                            activityRow(task)

                            if index < tasks.count - 1 {
                                Divider()
                                    .padding(.leading, 34)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(activityPickerSystemBackground))
                    )
                    .padding(.top, 24)
                }

                addNewActivityCard
                    .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))

                Text("Back")
                    .font(.system(size: 17, weight: .regular))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color(activityPickerSystemBackground)))
    }

    private func priorityCard(_ priority: ActivityPriority) -> some View {
        let matchingTasks = tasks(for: priority)

        return VStack(spacing: 0) {
            priorityHeader(priority)

            if matchingTasks.isEmpty {
                priorityEmptyState(priority)
            } else {
                ForEach(Array(matchingTasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 34)
                    }
                    activityRow(task)
                }
            }
        }
        .padding(.bottom, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(activityPickerSystemBackground))
        )
    }

    private func priorityHeader(_ priority: ActivityPriority) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(priority.pickerAccentColor)
                        .frame(width: 20, height: 20)

                    Image(systemName: priority.pickerIconName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("\(priority.title) \(type == .pleasure ? "Level" : "Priority")")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(priority.pickerAccentColor)
            }

            Text(priority.pickerDescription(for: type))
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private func priorityEmptyState(_ priority: ActivityPriority) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 44, height: 44)

                Image(systemName: "tray")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("No activities yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text("Add your first \(priority.title.lowercased()) \(type.title.lowercased()) activity.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private func activityRow(_ task: TaskItem) -> some View {
        ActivityRow(task: task, onTap: { onSelect(task) }, onLongPress: { onLongPress(task) })
    }

    private var addNewActivityCard: some View {
        Button(action: onCreateNew) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add New Activity")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Create a custom activity")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(activityPickerSystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityRow: View {
    let task: TaskItem
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isLongPressing = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(task.color.color)
                .frame(width: 12, height: 12)

            Text(task.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .opacity(isLongPressing ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.12), value: isLongPressing)
        .contentShape(Rectangle())
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
