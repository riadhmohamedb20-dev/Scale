import SwiftUI

struct AddExpenseView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingSaveConfirmation = false

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var isFormValid: Bool {
        let trimmedTitle = viewModel.newExpenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let amount = Double(viewModel.newExpenseAmountText) else { return false }
        return amount > 0
    }

    var body: some View {
        ZStack {
            expenseForm

            if isShowingSaveConfirmation {
                IntentionConfirmationOverlay(
                    prompt: "Why are you spending this?",
                    intention: $viewModel.newExpenseIntention,
                    doNotShowAgain: $viewModel.newExpenseIntentionDoNotShowAgain,
                    onCancel: {
                        isShowingSaveConfirmation = false
                        viewModel.closeAddExpenseSheet()
                    },
                    onConfirm: {
                        isShowingSaveConfirmation = false
                        viewModel.saveExpenseForm()
                    }
                )
            }
        }
    }

    private var expenseForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 20)

                Text(viewModel.editingExpenseID == nil ? "Add Expense" : "Edit Expense")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.primary)
                    .padding(.top, 24)

                Text(viewModel.editingExpenseID == nil ? "Log a new expense against your budget." : "Update your expense details.")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                sectionLabel("TITLE")
                    .padding(.top, 24)

                HStack(spacing: 10) {
                    emojiField

                    TextField("e.g. Groceries", text: $viewModel.newExpenseTitle)
                        .font(.system(size: 17))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(cardBackground)
                        )
                }
                .padding(.top, 8)

                sectionLabel("MERCHANT (OPTIONAL)")
                    .padding(.top, 24)

                TextField("e.g. Walmart", text: $viewModel.newExpenseMerchant)
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
                    TextField("0.00", text: $viewModel.newExpenseAmountText)
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

                TextField("Add a note", text: $viewModel.newExpenseNotes, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(3...8)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)

                if viewModel.editingExpenseID != nil {
                    sectionLabel("INTENTION (OPTIONAL)")
                        .padding(.top, 24)

                    TextField("Why did you spend this?", text: $viewModel.newExpenseIntention, axis: .vertical)
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

                        Toggle("", isOn: $viewModel.newExpenseIntentionDoNotShowAgain)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
                    .padding(.top, 8)
                }

                if viewModel.editingExpenseID == nil && !viewModel.recentExpensesForQuickFill.isEmpty {
                    sectionLabel("RECENT EXPENSES")
                        .padding(.top, 24)

                    recentExpensesList
                        .padding(.top, 8)
                }

                sectionLabel("DATE")
                    .padding(.top, 24)

                DatePicker("", selection: $viewModel.newExpenseDate, in: ...Date(), displayedComponents: .date)
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Color(activityPickerSystemBackground).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            if let editingExpenseID = viewModel.editingExpenseID {
                Button {
                    viewModel.deleteExpense(id: editingExpenseID)
                } label: {
                    Text("Delete Expense")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(cardBackground))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.closeAddExpenseSheet()
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
                if viewModel.editingExpenseID == nil {
                    if let preference = viewModel.expenseIntentionPreference(forTitle: viewModel.newExpenseTitle), preference.doNotShowAgain {
                        viewModel.newExpenseIntention = preference.intention
                        viewModel.newExpenseIntentionDoNotShowAgain = true
                        viewModel.saveExpenseForm()
                    } else {
                        viewModel.newExpenseIntention = ""
                        viewModel.newExpenseIntentionDoNotShowAgain = false
                        isShowingSaveConfirmation = true
                    }
                } else {
                    viewModel.saveExpenseForm()
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

    /// A single-character text field: tapping it brings up the system keyboard, and switching to
    /// the emoji keyboard lets the user pick literally any emoji rather than a fixed preset list.
    /// `onChange` trims the field down to just the most recently typed character so it can never
    /// hold more than one emoji.
    private var emojiField: some View {
        TextField("🙂", text: $viewModel.newExpenseEmoji)
            .font(.system(size: 28))
            .multilineTextAlignment(.center)
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(cardBackground)
            )
            .onChange(of: viewModel.newExpenseEmoji) { _, newValue in
                guard let last = newValue.last else { return }
                viewModel.newExpenseEmoji = String(last)
            }
    }

    private var recentExpensesList: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.recentExpensesForQuickFill.enumerated()), id: \.element.id) { index, expense in
                if index > 0 {
                    Divider()
                        .padding(.leading, 70)
                }

                recentExpenseRow(expense)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func recentExpenseRow(_ expense: ExpenseItem) -> some View {
        Button {
            viewModel.quickFillExpenseForm(from: expense)
        } label: {
            HStack(spacing: 14) {
                Text(expense.emoji)
                    .font(.system(size: 20))
                    .frame(width: 32)

                Text(expense.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(MoneyFormat.currency(expense.amount))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
