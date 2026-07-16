import SwiftUI

struct PrioritySelector: View {
    @Binding var selection: ActivityPriority?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ActivityPriority.allCases) { priorityOption in
                let isSelected = selection == priorityOption

                Button {
                    selection = priorityOption
                } label: {
                    Text(priorityOption.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemFill))
        )
    }
}
