import SwiftUI

struct EditTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color

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
