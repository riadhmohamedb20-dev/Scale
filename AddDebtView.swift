import SwiftUI

struct AddDebtView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingSaveConfirmation = false

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var isFormValid: Bool {
        let trimmedTitle = viewModel.newDebtTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let amount = Double(viewModel.newDebtAmountText) else { return false }
        return amount > 0
    }

    private var paidDateText: String {
        guard let paidDate = viewModel.editingDebtPaidDate else { return "Not paid yet" }
        return MoneyFormat.transactionDate(paidDate)
    }

    private var recordedDateText: String {
        MoneyFormat.transactionDate(viewModel.editingDebtRecordedDate ?? Date())
    }

    var body: some View {
        ZStack {
            debtForm

            if isShowingSaveConfirmation {
                IntentionConfirmationOverlay(
                    prompt: "Why are you making this debt?",
                    intention: $viewModel.newDebtIntention,
                    doNotShowAgain: $viewModel.newDebtIntentionDoNotShowAgain,
                    onCancel: {
                        isShowingSaveConfirmation = false
                        viewModel.closeAddDebtSheet()
                    },
                    onConfirm: {
                        isShowingSaveConfirmation = false
                        viewModel.saveDebtForm()
                    }
                )
            }
        }
    }

    private var debtForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 20)

                Text(viewModel.editingDebtID == nil ? "Add Debt" : "Edit Debt")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text(viewModel.editingDebtID == nil ? "Track money you owe until it's paid." : "Update your debt details.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                sectionLabel("TITLE")
                    .padding(.top, 24)

                TextField("e.g. Rent", text: $viewModel.newDebtTitle)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("AMOUNT")
                    .padding(.top, 24)

                HStack(spacing: 4) {
                    TextField("0.00", text: $viewModel.newDebtAmountText)
                        .font(.system(size: 17))
                        #if canImport(UIKit)
                        .keyboardType(.decimalPad)
                        #endif

                    Text("DA")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(cardBackground)
                )
                .padding(.top, 8)

                sectionLabel("NOTES (OPTIONAL)")
                    .padding(.top, 24)

                TextField("Add a note", text: $viewModel.newDebtNotes, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(3...8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("INTENTION (OPTIONAL)")
                    .padding(.top, 24)

                TextField("Why are you making this debt?", text: $viewModel.newDebtIntention, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(3...8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("CONFIRMATION")
                    .padding(.top, 24)

                HStack {
                    Text("Do not show again")
                        .font(.system(size: 17))
                        .foregroundStyle(.primary)

                    Spacer()

                    Toggle("", isOn: $viewModel.newDebtIntentionDoNotShowAgain)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(cardBackground)
                )
                .padding(.top, 8)

                sectionLabel("SCHEDULED PAYMENT")
                    .padding(.top, 24)

                scheduledPaymentCard
                    .padding(.top, 8)

                sectionLabel("DEBT DATE")
                    .padding(.top, 24)

                DatePicker("", selection: $viewModel.newDebtDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("RECORDED DATE")
                    .padding(.top, 24)

                Text(recordedDateText)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                sectionLabel("PAID DATE")
                    .padding(.top, 24)

                Text(paidDateText)
                    .font(.system(size: 17))
                    .foregroundStyle(viewModel.editingDebtPaidDate == nil ? .secondary : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            if let editingDebtID = viewModel.editingDebtID {
                Button {
                    viewModel.deleteDebt(id: editingDebtID)
                } label: {
                    Text("Delete Debt")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(cardBackground))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.closeAddDebtSheet()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                if viewModel.editingDebtID == nil {
                    if let preference = viewModel.debtIntentionPreference(forTitle: viewModel.newDebtTitle), preference.doNotShowAgain {
                        viewModel.newDebtIntention = preference.intention
                        viewModel.newDebtIntentionDoNotShowAgain = true
                        viewModel.saveDebtForm()
                    } else {
                        // Leave newDebtIntention/newDebtIntentionDoNotShowAgain as they are —
                        // the form already exposes these same fields, so whatever the user typed
                        // there carries straight into the confirmation step instead of getting
                        // wiped and asked for a second time.
                        isShowingSaveConfirmation = true
                    }
                } else {
                    viewModel.saveDebtForm()
                }
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(cardBackground))
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
            .opacity(isFormValid ? 1 : 0.4)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.5)
    }

    private var scheduledPaymentCard: some View {
        VStack(spacing: 0) {
            scheduledPaymentRow(icon: "calendar", title: "Date", isOn: $viewModel.newDebtIsDateReminderEnabled)
                .onChange(of: viewModel.newDebtIsDateReminderEnabled) { _, isOn in
                    viewModel.handleDateReminderToggle(isOn)
                }

            if viewModel.newDebtIsDateReminderEnabled {
                DatePicker("", selection: $viewModel.newDebtScheduledDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }

            Divider()
                .padding(.leading, 54)

            scheduledPaymentRow(icon: "clock", title: "Time", isOn: $viewModel.newDebtIsTimeReminderEnabled)
                .disabled(!viewModel.newDebtIsDateReminderEnabled)
                .opacity(viewModel.newDebtIsDateReminderEnabled ? 1 : 0.4)
                .onChange(of: viewModel.newDebtIsTimeReminderEnabled) { _, isOn in
                    viewModel.handleTimeReminderToggle(isOn)
                }

            if viewModel.newDebtIsDateReminderEnabled && viewModel.newDebtIsTimeReminderEnabled {
                DatePicker("", selection: $viewModel.newDebtScheduledTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }

            if viewModel.isNotificationPermissionDenied {
                Text("Notifications are disabled. Enable them in Settings to receive this reminder.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func scheduledPaymentRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
