import SwiftUI

/// A single-emoji picker row shared by `AddTaskView` and `EditTaskView`. Tapping the circle
/// focuses a hidden text field so the system emoji keyboard appears; typing any character
/// keeps only the most recently entered emoji grapheme cluster (non-emoji input is discarded).
struct EmojiField: View {
    @Binding var emoji: String
    @FocusState private var isFocused: Bool
    @State private var typingBuffer = ""

    var body: some View {
        HStack {
            Text("Emoji")

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 36, height: 36)

                if emoji.isEmpty {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text(emoji)
                        .font(.system(size: 20))
                }

                TextField("", text: Binding(
                    get: { typingBuffer },
                    set: { newValue in
                        if let lastEmoji = newValue.last(where: \.isEmoji) {
                            emoji = String(lastEmoji)
                        } else if newValue.isEmpty {
                            emoji = ""
                        }
                        typingBuffer = ""
                    }
                ))
                .focused($isFocused)
                .frame(width: 36, height: 36)
                .opacity(0.015)
            }
            .contentShape(Circle())
            .onTapGesture { isFocused = true }
        }
    }
}

private extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
