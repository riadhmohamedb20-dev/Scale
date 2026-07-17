import SwiftUI

struct AddTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var taskDescription: String
    @Binding var taskType: ActivityType?
    @Binding var taskPriority: ActivityPriority?

    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity title", text: $taskName)
                    ColorPicker("Activity color", selection: $taskColor)
                }

                Section {
                    ActivityTypeSelector(selection: $taskType)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Type")
                }

                if taskType == .pain || taskType == .pleasure {
                    Section {
                        PrioritySelector(selection: $taskPriority)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(taskType == .pleasure ? "Pleasure Level" : "Priority")
                    }
                }

                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        if taskDescription.isEmpty {
                            Text("What does this activity include?")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }

                        TextEditor(text: $taskDescription)
                            .frame(minHeight: 96)
                    }
                }
            }
            .navigationTitle("Add Activity")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                    .disabled(isMissingRequiredPriority)
                }
            }
        }
    }

    private var isMissingRequiredPriority: Bool {
        (taskType == .pain || taskType == .pleasure) && taskPriority == nil
    }
}
