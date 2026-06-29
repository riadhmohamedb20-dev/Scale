import SwiftUI

struct AddTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color

    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $taskName)
                    ColorPicker("Task color", selection: $taskColor)
                }
            }
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                    }
                }
            }
        }
    }
}
