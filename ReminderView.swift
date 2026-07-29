import SwiftUI

struct ReminderView: View {
    var onClose: () -> Void
    var onTakeAction: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private let quote = "Pressing on the pain side of the balance can lead to its opposite—pleasure. Unlike pressing on the pleasure side, the dopamine that comes from pain is indirect and potentially more enduring."

    private var isDark: Bool {
        colorScheme == .dark
    }

    private var cardBackground: Color {
        isDark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var vividGlyphColor: Color {
        Color.black.opacity(0.75)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 20)

                Text("A gentle reminder to keep you on track.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                quoteCard
                    .padding(.top, 24)

                actionCard
                    .padding(.top, 24)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("Reminder")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDark ? vividGlyphColor : Color.primary)
                    .frame(width: 44, height: 44)
                    .background(isDark ? ActivityType.pain.pickerAccentColor : ActivityType.pain.pickerIconBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var quoteCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(isDark ? ActivityType.pain.pickerAccentColor.opacity(0.28) : ActivityType.pain.pickerIconBackground)
                    .frame(width: 72, height: 72)

                Image(systemName: "lightbulb")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(isDark ? ActivityType.pain.pickerAccentColor : Color.primary)
            }

            Text("Anna Lembke says,")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ActivityType.pain.pickerAccentColor)

            Text("\u{201C}\(quote)\u{201D}")
                .font(.system(size: 22, design: .serif))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                Rectangle()
                    .fill(ActivityType.pain.pickerAccentColor.opacity(0.35))
                    .frame(height: 1)

                Image(systemName: "sparkle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ActivityType.pain.pickerAccentColor)

                Rectangle()
                    .fill(ActivityType.pain.pickerAccentColor.opacity(0.35))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(isDark ? cardBackground : ActivityType.pain.pickerIconBackground.opacity(0.45))
        )
    }

    private var actionCard: some View {
        Button(action: onTakeAction) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isDark ? ActivityType.pain.pickerAccentColor.opacity(0.28) : ActivityType.pain.pickerIconBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: ActivityType.pain.pickerIconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isDark ? ActivityType.pain.pickerAccentColor : Color.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Take meaningful action")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Choose a pain activity to move closer to your goals.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                ZStack {
                    Circle()
                        .fill(isDark ? ActivityType.pain.pickerAccentColor : ActivityType.pain.pickerIconBackground)
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isDark ? vividGlyphColor : Color.primary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(isDark ? cardBackground : ActivityType.pain.pickerIconBackground.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }
}
