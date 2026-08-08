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

    private var isActivitySelectionMissing: Bool {
        viewModel.newToDoItemActivityTaskID == nil && viewModel.newToDoItemActivityType == nil
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

                sectionLabel("DESCRIPTION")
                    .padding(.top, 24)

                multilineField(
                    text: $viewModel.newToDoItemDescription,
                    placeholder: "Add a description shared by every occurrence of this task..."
                )
                .padding(.top, 8)

                sectionLabel("NOTES FOR THIS DAY")
                    .padding(.top, 24)

                multilineField(
                    text: $viewModel.newToDoItemNotes,
                    placeholder: "Add a note just for this day..."
                )
                .padding(.top, 8)

                HStack {
                    sectionLabel("REPEAT")

                    Spacer()

                    Button {
                        viewModel.toggleNewToDoRecurringAllWeekdays()
                    } label: {
                        Text(viewModel.newToDoItemRecurringWeekdays.count == 7 ? "Deselect All" : "Select All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 24)

                weekdayPicker
                    .padding(.top, 8)

                sectionLabel("WHICH ACTIVITY?")
                    .padding(.top, 24)

                if let selectedActivity {
                    activitiesCard([selectedActivity])
                        .padding(.top, 8)
                } else if let selectedType = viewModel.newToDoItemActivityType {
                    selectedTypeRow(selectedType)
                        .padding(.top, 8)

                    if selectedType.hasPriorityTiers {
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

                sectionLabel("SUBTASKS")
                    .padding(.top, 24)

                subtasksSection
                    .padding(.top, 8)
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
            .disabled(isTitleEmpty || isActivitySelectionMissing)
            .opacity((isTitleEmpty || isActivitySelectionMissing) ? 0.4 : 1)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private func multilineField(text: Binding<String>, placeholder: String) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
            }

            TextEditor(text: text)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
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
                if type.hasPriorityTiers {
                    viewModel.newToDoItemPriority = viewModel.newToDoItemPriority ?? .medium
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        if colorScheme == .dark {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(type.pickerAccentColor)
                                .frame(width: 36, height: 36)
                        } else {
                            Circle()
                                .fill(type.pickerIconBackground)
                                .frame(width: 36, height: 36)
                        }

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

    /// `Calendar`'s `.weekday` component values (1 = Sunday ... 7 = Saturday) paired with
    /// their single-letter labels, Sunday-first to match the app's date pill/history picker.
    private static let weekdaySymbols: [(weekday: Int, label: String)] = [
        (1, "S"), (2, "M"), (3, "T"), (4, "W"), (5, "T"), (6, "F"), (7, "S")
    ]

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(Self.weekdaySymbols, id: \.weekday) { symbol in
                weekdayOption(symbol.weekday, label: symbol.label)
            }
        }
    }

    private func weekdayOption(_ weekday: Int, label: String) -> some View {
        let isSelected = viewModel.newToDoItemRecurringWeekdays.contains(weekday)

        return Button {
            viewModel.toggleNewToDoRecurringWeekday(weekday)
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor : cardBackground)
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

    private var subtasksSection: some View {
        VStack(spacing: 8) {
            if !viewModel.newToDoItemSubtasks.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.newToDoItemSubtasks.enumerated()), id: \.element.id) { index, subtask in
                        if index > 0 {
                            Divider()
                                .padding(.leading, 16)
                        }
                        subtaskRow(subtask, index: index)
                    }
                }
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardBackground)
                )
            }

            addSubtaskButton
        }
    }

    private func subtaskRow(_ subtask: SubtaskItem, index: Int) -> some View {
        let isFirst = index == 0
        let isLast = index == viewModel.newToDoItemSubtasks.count - 1

        return HStack(spacing: 10) {
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 6, height: 6)

            TextField("Subtask title...", text: subtaskTitleBinding(for: subtask.id))
                .font(.system(size: 16, weight: .medium))

            Spacer(minLength: 4)

            VStack(spacing: 2) {
                Button {
                    viewModel.moveNewToDoSubtask(id: subtask.id, offset: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isFirst ? Color.secondary.opacity(0.25) : Color.secondary)
                        .frame(width: 20, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(isFirst)

                Button {
                    viewModel.moveNewToDoSubtask(id: subtask.id, offset: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isLast ? Color.secondary.opacity(0.25) : Color.secondary)
                        .frame(width: 20, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(isLast)
            }

            Button {
                viewModel.removeNewToDoSubtask(id: subtask.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func subtaskTitleBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.newToDoItemSubtasks.first(where: { $0.id == id })?.title ?? "" },
            set: { newValue in
                if let index = viewModel.newToDoItemSubtasks.firstIndex(where: { $0.id == id }) {
                    viewModel.newToDoItemSubtasks[index].title = newValue
                }
            }
        )
    }

    private var addSubtaskButton: some View {
        Button {
            viewModel.addNewToDoSubtask()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Add Subtask")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}
