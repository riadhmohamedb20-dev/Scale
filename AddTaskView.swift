import SwiftUI
import UIKit

struct AddTaskView: View {
    @Binding var taskName: String
    @Binding var taskColor: Color
    @Binding var taskDescription: String
    @Binding var taskType: ActivityType?
    @Binding var taskPriority: ActivityPriority?
    @Environment(\.colorScheme) private var colorScheme

    var onDone: () -> Void
    var onCancel: () -> Void

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)

            Text("Add Activity")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Form {
                Section {
                    TextField("Activity title", text: $taskName)
                    ColorPicker("Activity color", selection: $taskColor)
                } header: {
                    Text("Activity")
                        .padding(.leading, -20)
                }

                Section {
                    ActivityTypeSelector(selection: $taskType)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Type")
                        .padding(.leading, -20)
                }

                if taskType == .pain || taskType == .pleasure {
                    Section {
                        PrioritySelector(selection: $taskPriority)
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color.clear)
                    } header: {
                        Text(taskType == .pleasure ? "Pleasure Level" : "Priority")
                            .padding(.leading, -20)
                    }
                }

                Section {
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
                } header: {
                    Text("Description")
                        .padding(.leading, -20)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .disabled(isMissingRequiredPriority)
            .opacity(isMissingRequiredPriority ? 0.4 : 1)
        }
    }

    private var isMissingRequiredPriority: Bool {
        (taskType == .pain || taskType == .pleasure) && taskPriority == nil
    }
}
