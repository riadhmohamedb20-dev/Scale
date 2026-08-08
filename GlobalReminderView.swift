import SwiftUI

/// The app-wide Reminder popup — recreates the reference design (bell glyph, bold title,
/// user-authored message, a "Remind me later" row with an inline duration picker, a "Don't
/// remind again" checkbox row, and a light "Got it" button) over a dimmed backdrop.
struct GlobalReminderView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme
    let message: ReminderMessage
    /// When true, this renders a visual-only preview (from the Reminder Messages list's long
    /// press): its own local state stands in for `viewModel.remindLaterMinutes` /
    /// `isDontRemindAgainSelected`, and "Got it" just calls `onDismissPreview` instead of
    /// `viewModel.resolveGlobalReminder()` — so nothing here ever touches the real schedule,
    /// settings, or persisted state.
    var isPreview = false
    var onDismissPreview: (() -> Void)?

    @State private var previewRemindLaterMinutes: Int
    @State private var previewIsDontRemindAgainSelected = false

    init(
        viewModel: TimeCircleViewModel,
        message: ReminderMessage,
        isPreview: Bool = false,
        onDismissPreview: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.message = message
        self.isPreview = isPreview
        self.onDismissPreview = onDismissPreview
        _previewRemindLaterMinutes = State(initialValue: isPreview ? viewModel.reminderIntervalMinutes : viewModel.remindLaterMinutes)
    }

    private var remindLaterMinutes: Int {
        isPreview ? previewRemindLaterMinutes : viewModel.remindLaterMinutes
    }

    private var isDontRemindAgainSelected: Bool {
        isPreview ? previewIsDontRemindAgainSelected : viewModel.isDontRemindAgainSelected
    }

    private func selectRemindLaterMinutes(_ minutes: Int) {
        if isPreview {
            previewRemindLaterMinutes = minutes
        } else {
            viewModel.remindLaterMinutes = minutes
        }
    }

    private func toggleDontRemindAgainSelected() {
        if isPreview {
            previewIsDontRemindAgainSelected.toggle()
        } else {
            viewModel.isDontRemindAgainSelected.toggle()
        }
    }

    private func resolve() {
        if isPreview {
            onDismissPreview?()
        } else {
            viewModel.resolveGlobalReminder()
        }
    }

    /// Dark mode keeps the original near-black card; light mode uses a plain white card —
    /// everything else (`.primary`/`.secondary` text, the accent-colored interval, the
    /// black-on-white "Got it" button) already adapts to color scheme on its own.
    private var cardBackground: Color {
        colorScheme == .dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
    }

    private var dividerColor: Color {
        Color(uiColor: .separator)
    }

    var body: some View {
        // The whole ZStack ignores the safe area (not just the dimmed background) so its
        // default center alignment centers the card against the full screen bounds — centering
        // it only within the safe area shifted it down, since the top safe-area inset is
        // larger than the bottom one.
        ZStack {
            Color.black.opacity(0.55)

            VStack(spacing: 0) {
                VStack(spacing: 14) {
                    Image(systemName: "bell")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(.secondary)
                        .padding(.top, 28)

                    Text("Reminder")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)

                Divider().overlay(dividerColor)

                remindLaterRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .allowsHitTesting(!isPreview)

                Divider().overlay(dividerColor)

                dontRemindAgainRow
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .allowsHitTesting(!isPreview)

                Button {
                    resolve()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: 380)
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private var remindLaterRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)

            Text("Remind me later")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            Menu {
                ForEach(ReminderInterval.allCases) { interval in
                    Button {
                        selectRemindLaterMinutes(interval.minutes)
                    } label: {
                        if remindLaterMinutes == interval.minutes {
                            Label(interval.title, systemImage: "checkmark")
                        } else {
                            Text(interval.title)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text("in \(ReminderInterval.closest(toMinutes: remindLaterMinutes).title)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.accentColor)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    private var dontRemindAgainRow: some View {
        Button {
            toggleDontRemindAgainSelected()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isDontRemindAgainSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isDontRemindAgainSelected ? Color.accentColor : .primary)
                    .frame(width: 32, height: 32)

                Text("Don't remind again")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}
