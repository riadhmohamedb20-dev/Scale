import SwiftUI

struct EditTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var taskDescription: String

    var onDone: () -> Void
    var onDelete: () -> Void

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $taskName)
                    ColorPicker("Task color", selection: $taskColor)
                }

                Section("Description") {
                    ZStack(alignment: .topLeading) {
                        if taskDescription.isEmpty {
                            Text("What does this task include?")
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
                        Text("Delete Task")
                    }
                }
            }
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
            .alert("Delete this task?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete Task", role: .destructive) {
                    onDelete()
                }

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will remove the task, but existing completed sessions should remain.")
            }
        }
    }
}
