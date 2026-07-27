import SwiftUI

struct AddToDoItemView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var expandedTypes: Set<ActivityType> = []

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var filteredTasks: [TaskItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.tasks }
        return viewModel.tasks.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }

    private var selectedActivity: TaskItem? {
        viewModel.tasks.first { $0.id == viewModel.newToDoItemActivityTaskID }
    }

    private var isTitleEmpty: Bool {
        viewModel.newToDoItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 20)

                Text(viewModel.editingToDoItemID == nil ? "Add New Task" : "Edit Task")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text(viewModel.editingToDoItemID == nil ? "Create a new task and assign it to an activity." : "Update your task details.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                sectionLabel("TASK TITLE")
                    .padding(.top, 24)

                TextField("Enter task title...", text: $viewModel.newToDoItemTitle)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("WHICH ACTIVITY?")
                    .padding(.top, 24)

                if let selectedActivity {
                    activitiesCard([selectedActivity])
                        .padding(.top, 8)
                } else if let selectedType = viewModel.newToDoItemActivityType {
                    selectedTypeRow(selectedType)
                        .padding(.top, 8)

                    if selectedType.usesDailyTarget {
                        sectionLabel("PRIORITY")
                            .padding(.top, 24)

                        priorityPicker
                            .padding(.top, 8)
                    }
                } else {
                    searchField
                        .padding(.top, 8)

                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if !filteredTasks.isEmpty {
                            activitiesCard(filteredTasks)
                                .padding(.top, 14)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(ActivityType.allCases) { type in
                                typeSection(type)
                            }
                        }
                        .padding(.top, 14)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            if let editingToDoItemID = viewModel.editingToDoItemID {
                Button {
                    viewModel.deleteToDoItem(id: editingToDoItemID)
                } label: {
                    Text("Delete Task")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(cardBackground))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.closeAddToDoItemSheet()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                viewModel.saveToDoItemForm()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .disabled(isTitleEmpty)
            .opacity(isTitleEmpty ? 0.4 : 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
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

    private func activitiesCard(_ items: [TaskItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, task in
                if index > 0 {
                    Divider()
                        .padding(.leading, 46)
                }
                activityRow(task)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func typeSection(_ type: ActivityType) -> some View {
        VStack(spacing: 8) {
            typeHeaderRow(type)

            if expandedTypes.contains(type) {
                let tasksForType = viewModel.tasks.filter { $0.activityType == type }
                if !tasksForType.isEmpty {
                    activitiesCard(tasksForType)
                }
            }
        }
    }

    private func typeHeaderRow(_ type: ActivityType) -> some View {
        let isExpanded = expandedTypes.contains(type)

        return HStack(spacing: 14) {
            Button {
                viewModel.newToDoItemActivityType = type
                viewModel.newToDoItemActivityTaskID = nil
                if type.usesDailyTarget {
                    viewModel.newToDoItemPriority = viewModel.newToDoItemPriority ?? .medium
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(type.pickerIconBackground)
                            .frame(width: 36, height: 36)

                        Image(systemName: type.pickerIconName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    Text(type.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedTypes.remove(type)
                    } else {
                        expandedTypes.insert(type)
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func selectedTypeRow(_ type: ActivityType) -> some View {
        Button {
            viewModel.newToDoItemActivityType = nil
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(type.pickerIconBackground)
                        .frame(width: 36, height: 36)

                    Image(systemName: type.pickerIconName)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                }

                Text(type.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private var priorityPicker: some View {
        HStack(spacing: 10) {
            ForEach(ActivityPriority.allCases) { priority in
                priorityOption(priority)
            }
        }
    }

    private func priorityOption(_ priority: ActivityPriority) -> some View {
        let isSelected = viewModel.newToDoItemPriority == priority

        return Button {
            viewModel.newToDoItemPriority = priority
        } label: {
            VStack(spacing: 6) {
                Image(systemName: priority.pickerIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : priority.pickerAccentColor)

                Text(priority.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? priority.pickerAccentColor : cardBackground)
            )
        }
        .buttonStyle(.plain)
    }

    private func activityRow(_ task: TaskItem) -> some View {
        let isSelected = viewModel.newToDoItemActivityTaskID == task.id

        return Button {
            if isSelected {
                viewModel.newToDoItemActivityTaskID = nil
            } else {
                viewModel.newToDoItemActivityTaskID = task.id
                viewModel.newToDoItemActivityType = nil
            }
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(task.color.color)
                    .frame(width: 12, height: 12)

                Text(task.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isSelected ? 20 : 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}
