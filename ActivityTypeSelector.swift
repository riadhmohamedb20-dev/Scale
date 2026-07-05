import SwiftUI

struct ActivityTypeSelector: View {
    @Binding var selection: ActivityType

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ActivityType.allCases) { type in
                let isSelected = selection == type

                Button {
                    selection = isSelected ? .none : type
                } label: {
                    Text(type.title)
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
