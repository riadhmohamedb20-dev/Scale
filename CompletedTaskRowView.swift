import SwiftUI

/// The read-only completed-task row visual, matching the completed state of the To-Do
/// page's task row (green checkmark + strikethrough title) exactly — but without any of
/// that row's interactive editing/reveal/subtask machinery, since a `CompletedTaskSnapshot`
/// is an immutable historical record, not a live, editable `ToDoItem`.
struct CompletedTaskRowView: View {
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.green)

            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .strikethrough(true)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
    }
}
