import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    settingsCategoriesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(activityPickerSystemBackground).ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                }
            }
            .navigationDestination(for: SettingsCategory.self) { category in
                switch category {
                case .reminders:
                    RemindersSettingsView(viewModel: viewModel)
                }
            }
        }
    }

    /// The list of settings categories — currently just Reminders, but each new section only
    /// needs a new `SettingsCategory` case and a row here, keeping the destinations decoupled
    /// from this list.
    private var settingsCategoriesSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(SettingsCategory.allCases.enumerated()), id: \.element) { index, category in
                if index > 0 {
                    Divider().padding(.leading, 16)
                }

                NavigationLink(value: category) {
                    HStack(spacing: 14) {
                        Text(category.title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }
}

private enum SettingsCategory: Hashable, CaseIterable {
    case reminders

    var title: String {
        switch self {
        case .reminders: return "Reminders"
        }
    }
}

private struct RemindersSettingsView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var previewingReminderMessage: ReminderMessage?

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                reminderSettingsSection
                reminderMessagesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.isAddingReminderMessage) {
            ReminderMessageEditorView(viewModel: viewModel)
        }
        .overlay {
            // An `.overlay` rather than a `.fullScreenCover`/`.sheet` so the Reminders page
            // itself stays visible, dimmed, behind the popup — exactly like the real
            // reminder appearing over whatever screen the user was already on.
            if let message = previewingReminderMessage {
                GlobalReminderView(
                    viewModel: viewModel,
                    message: message,
                    isPreview: true,
                    onDismissPreview: { previewingReminderMessage = nil }
                )
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    /// Reminder configuration only — enable/disable and the default interval. Reminder messages
    /// live in their own section below so this one never needs to repeat itself.
    private var reminderSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("REMINDER SETTINGS")

            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { viewModel.remindersEnabledGlobally },
                    set: { viewModel.setRemindersEnabledGlobally($0) }
                )) {
                    Text("Enable Reminders")
                        .font(.system(size: 17, weight: .semibold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if !viewModel.remindersEnabledGlobally {
                    Text("Reminders were turned off from \u{201c}Don\u{2019}t remind again\u{201d}, or from here. Re-enable them to resume the schedule.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                }

                Divider().padding(.leading, 16)

                HStack {
                    Text("Default Interval")
                        .font(.system(size: 17, weight: .semibold))

                    Spacer()

                    Menu {
                        ForEach(ReminderInterval.allCases) { interval in
                            Button {
                                viewModel.setReminderIntervalMinutes(interval.minutes)
                            } label: {
                                if viewModel.reminderIntervalMinutes == interval.minutes {
                                    Label(interval.title, systemImage: "checkmark")
                                } else {
                                    Text(interval.title)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(ReminderInterval.closest(toMinutes: viewModel.reminderIntervalMinutes).title)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.accentColor)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardBackground)
            )
            .padding(.top, 8)
        }
    }

    /// Just the message list — adding, enabling/disabling, and deleting individual reminders.
    private var reminderMessagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel("REMINDER MESSAGES")

                Spacer()

                Button {
                    viewModel.openAddReminderMessageSheet()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.reminderMessages.isEmpty {
                Text("No reminder messages yet. Add one to start showing reminders.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.reminderMessages.enumerated()), id: \.element.id) { index, message in
                        if index > 0 {
                            Divider().padding(.leading, 16)
                        }

                        reminderMessageRow(message)
                    }
                }
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardBackground)
                )
                .padding(.top, 4)
            }
        }
    }

    private func reminderMessageRow(_ message: ReminderMessage) -> some View {
        HStack(spacing: 14) {
            Toggle(isOn: Binding(
                get: { message.isEnabled },
                set: { viewModel.setReminderMessageEnabled(message, isEnabled: $0) }
            )) {
                EmptyView()
            }
            .labelsHidden()

            Text(message.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(message.isEnabled ? .primary : .secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.openEditReminderMessageSheet(message)
                }
                .onLongPressGesture {
                    previewingReminderMessage = message
                }

            Button {
                viewModel.deleteReminderMessage(message)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ReminderMessageEditorView: View {
    @ObservedObject var viewModel: TimeCircleViewModel

    private var isEditing: Bool {
        viewModel.editingReminderMessageID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message") {
                    TextField("Reminder text", text: $viewModel.newReminderMessageText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.closeAddReminderMessageSheet()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveReminderMessageForm()
                    }
                    .disabled(viewModel.newReminderMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
