import SwiftUI

struct EditSessionView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var startTime: Date
    @Binding var endTime: Date
    @Binding var sessionDescription: String
    @Binding var subActivityIDs: [UUID]

    var title = "Edit Session"
    var showsDeleteButton = true
    var dateRange: ClosedRange<Date>?
    var activities: [TaskItem] = []
    var onSave: () -> Void
    var onDelete: () -> Void

    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingSubActivityPicker = false

    private let timeLabelWidth: CGFloat = 54
    private let dateColumnWidth: CGFloat = 140
    private let timeColumnWidth: CGFloat = 92
    private let timeColumnSpacing: CGFloat = 12

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity title", text: $taskName)
                    ColorPicker("Activity color", selection: $taskColor)
                }

                Section {
                    if !selectedSubActivities.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedSubActivities) { activity in
                                    subActivityChip(activity)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    Button {
                        isShowingSubActivityPicker = true
                    } label: {
                        Label("Choose Sub-activity", systemImage: "checklist")
                    }
                } header: {
                    Text("Sub-activities")
                }

                Section("Time") {
                    timeEditorRow(label: "Start", selection: $startTime)
                    timeEditorRow(label: "End", selection: $endTime)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(formattedDuration)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    if hasInvalidTimeRange {
                        Text("End time must be after start time.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        if sessionDescription.isEmpty {
                            Text("What does this session include?")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $sessionDescription)
                            .frame(minHeight: 96)
                    }
                }

                if showsDeleteButton {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Text("Delete Session")
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(hasInvalidTimeRange)
                }
            }
            .alert("Delete this session?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete Session", role: .destructive) {
                    onDelete()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This completed session will be removed.")
            }
            .sheet(isPresented: $isShowingSubActivityPicker) {
                SubActivityPickerView(
                    activities: allowedSubActivities,
                    selectedIDs: $subActivityIDs
                )
            }
        }
    }

    private var selectedSubActivities: [TaskItem] {
        subActivityIDs.compactMap { id in
            allowedSubActivities.first { $0.id == id }
        }
    }

    private var allowedSubActivities: [TaskItem] {
        activities.filter { isSubActivityAllowed($0) }
    }

    private func isSubActivityAllowed(_ activity: TaskItem) -> Bool {
        switch mainActivityType {
        case .pain:
            return activity.activityType == .pain
        case .pleasure:
            return activity.activityType == .pleasure
        case .neutral:
            return activity.activityType == .pain || activity.activityType == .pleasure
        case .none:
            return activity.activityType != .none
        }
    }

    private var mainActivityType: ActivityType {
        activities.first { $0.name == taskName }?.activityType ?? .none
    }

    private func subActivityChip(_ activity: TaskItem) -> some View {
        Text(activity.name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(activity.color.color.opacity(0.26))
            )
    }

    private func timeEditorRow(label: String, selection: Binding<Date>) -> some View {
        HStack(spacing: timeColumnSpacing) {
            Text(label)
                .frame(width: timeLabelWidth, alignment: .leading)

            if let dateRange {
                DatePicker("", selection: selection, in: dateRange, displayedComponents: .date)
                    .labelsHidden()
                    .frame(width: dateColumnWidth, alignment: .leading)
            } else {
                DatePicker("", selection: selection, displayedComponents: .date)
                    .labelsHidden()
                    .frame(width: dateColumnWidth, alignment: .leading)
            }

            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .frame(width: timeColumnWidth, alignment: .leading)
        }
    }

    private var hasInvalidTimeRange: Bool {
        endTime < startTime
    }

    private var calculatedDuration: TimeInterval {
        max(endTime.timeIntervalSince(startTime), 0)
    }

    private var formattedDuration: String {
        let totalMinutes = Int(calculatedDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

private struct SubActivityPickerView: View {
    var activities: [TaskItem]
    @Binding var selectedIDs: [UUID]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(activities) { activity in
                    Button {
                        toggle(activity.id)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(activity.color.color)
                                .frame(width: 12, height: 12)

                            Text(activity.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedIDs.contains(activity.id) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose Sub-activity")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.removeAll { $0 == id }
        } else {
            selectedIDs.append(id)
        }
    }
}
