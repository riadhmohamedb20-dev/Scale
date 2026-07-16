import SwiftUI

struct EditTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var taskDescription: String
    @Binding var taskType: ActivityType
    @Binding var taskPriority: ActivityPriority?

    var onDone: () -> Void
    var onDelete: () -> Void

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Activity title", text: $taskName)
                    ColorPicker("Activity color", selection: $taskColor)
                }

                Section {
                    ActivityTypeSelector(selection: Binding(
                        get: { taskType },
                        set: { taskType = $0 ?? .none }
                    ))
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Activity type")
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

                Section {
                    Button(role: .destructive) {
                        isShowingDeleteConfirmation = true
                    } label: {
                        Text("Delete Activity")
                    }
                }
            }
            .navigationTitle("Edit Activity")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
            .alert("Delete this activity?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete Activity", role: .destructive) {
                    onDelete()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the activity, but existing completed sessions should remain.")
            }
        }
    }
}
