import SwiftUI

struct EditSessionView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var startTime: Date
    @Binding var endTime: Date

    var title = "Edit Session"
    var showsDeleteButton = true
    var dateRange: ClosedRange<Date>?
    var onSave: () -> Void
    var onDelete: () -> Void

    @State private var isShowingDeleteConfirmation = false

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
        }
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
