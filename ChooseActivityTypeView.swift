import SwiftUI

struct ChooseActivityTypeView: View {
    var onCancel: () -> Void
    var onSelect: (ActivityType) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                cancelButton
                    .padding(.top, 20)

                Text("Choose Type")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 28)

                Text("What kind of activity you want to track?")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    ForEach(ActivityType.allCases) { type in
                        typeCard(for: type)
                    }
                }
                .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSecondarySystemBackground).ignoresSafeArea())
    }

    private var cancelButton: some View {
        Button("Cancel", action: onCancel)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color(activityPickerSystemBackground)))
    }

    private func typeCard(for type: ActivityType) -> some View {
        Button {
            onSelect(type)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(type.pickerIconBackground)
                        .frame(width: 52, height: 52)

                    Image(systemName: type.pickerIconName)
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(type.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(type.pickerDescription)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.6))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(activityPickerSystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}
