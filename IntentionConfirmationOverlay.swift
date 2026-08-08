import SwiftUI

/// The "Are you sure?" checkpoint shown before saving a brand-new expense or debt — asks for a
/// short reason and offers a "do not show again" choice for that specific title. Never used for
/// editing an existing item, and never shown for an automatic debt created alongside an expense.
struct IntentionConfirmationOverlay: View {
    let prompt: String
    @Binding var intention: String
    @Binding var doNotShowAgain: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .light ? Color.white : Color(white: 0.16)
    }

    private var fieldBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.12)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                Text("Are you sure?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text(prompt)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("e.g. Needed for groceries", text: $intention, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(2...5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(fieldBackground)
                        )
                }

                Button {
                    doNotShowAgain.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: doNotShowAgain ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(doNotShowAgain ? Color.accentColor : .secondary)

                        Text("Do not show again")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(fieldBackground)
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onConfirm) {
                        Text("Confirm")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
            )
            .padding(.horizontal, 32)
        }
    }
}
