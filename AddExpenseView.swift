import SwiftUI

struct AddExpenseView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var isFormValid: Bool {
        let trimmedTitle = viewModel.newExpenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let amount = Double(viewModel.newExpenseAmountText) else { return false }
        return amount > 0
    }

    var body: some View {
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

                TextField("e.g. Groceries", text: $viewModel.newExpenseTitle)
                    .font(.system(size: 17))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(cardBackground)
                    )
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

                sectionLabel("CATEGORY")
                    .padding(.top, 24)

                categoryPicker
                    .padding(.top, 8)

                sectionLabel("DATE")
                    .padding(.top, 24)

                DatePicker("", selection: $viewModel.newExpenseDate, displayedComponents: .date)
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
                viewModel.saveExpenseForm()
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

    private var categoryPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 10)], spacing: 10) {
            ForEach(ExpenseCategory.allCases) { category in
                categoryOption(category)
            }
        }
    }

    private func categoryOption(_ category: ExpenseCategory) -> some View {
        let isSelected = viewModel.newExpenseCategory == category

        return Button {
            viewModel.newExpenseCategory = category
        } label: {
            VStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : category.iconBackground)

                Text(category.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? category.iconBackground : cardBackground)
            )
        }
        .buttonStyle(.plain)
    }
}
