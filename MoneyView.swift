import SwiftUI

struct MoneyView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    var onSwipeToToDo: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var editBudgetText = ""
    @State private var isDatePillPressed = false

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private let accentGreen = Color(red: 0.20, green: 0.78, blue: 0.35)

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 20)

                    Text("Money")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.primary)
                        .padding(.top, 24)

                    Text("Track your spending")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    budgetCard
                        .padding(.top, 20)

                    if viewModel.expensesForSelectedDay.isEmpty {
                        emptyState
                            .padding(.top, 28)
                    } else {
                        spendingHeader
                            .padding(.top, 28)

                        spendingListCard
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .background(Color(activityPickerSystemBackground).ignoresSafeArea())
            .gesture(swipeGesture)

            floatingAddExpenseButton
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $viewModel.isShowingAddExpense) {
            AddExpenseView(viewModel: viewModel)
        }
        .alert("Edit Budget", isPresented: $viewModel.isShowingEditBudget) {
            TextField("Total budget", text: $editBudgetText)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
            Button("Save") {
                if let value = Double(editBudgetText) {
                    viewModel.updateTotalBudget(value)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter your new budget.")
        }
    }

    private var header: some View {
        ZStack(alignment: .center) {
            HStack {
                appearanceMenu

                Spacer()
            }
            .frame(height: 36, alignment: .center)

            dateSelector
                .overlay(alignment: .trailing) {
                    if !viewModel.isViewingToday {
                        returnToTodayButton
                            .offset(x: 46)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36, alignment: .center)
    }

    private var dateSelector: some View {
        HStack(spacing: 6) {
            Text(viewModel.selectedDayTitle)
                .font(.subheadline.weight(.semibold))

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(isDatePillPressed ? 0.12 : 0.06))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .scaleEffect(isDatePillPressed ? 0.98 : 1)
        .animation(.easeInOut(duration: 0.12), value: isDatePillPressed)
        .gesture(datePillGesture)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 60
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                guard isSwipe, horizontalDistance > 0 else { return }

                onSwipeToToDo()
            }
    }

    private var datePillGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 45
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                isDatePillPressed = !isSwipe
            }
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 45
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                isDatePillPressed = false

                if isSwipe {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if horizontalDistance > 0 {
                            viewModel.moveSelectedDay(by: -1)
                        } else {
                            viewModel.moveSelectedDay(by: 1)
                        }
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.openHistoryPicker()
                    }
                }
            }
    }

    private var returnToTodayButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.selectToday()
            }
        } label: {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(colorScheme == .light ? Color.black.opacity(0.82) : .white)
                .frame(width: 34, height: 34)
                .background(colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var appearanceMenu: some View {
        Menu {
            ForEach(AppAppearanceMode.allCases) { mode in
                Button {
                    appearanceModeRaw = mode.rawValue
                } label: {
                    Label(mode.title, systemImage: appearanceMode == mode ? "checkmark" : mode.iconName)
                }
            }
        } label: {
            Image(systemName: appearanceMode.iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Text("Budget")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    editBudgetText = String(format: "%.2f", viewModel.totalBudget)
                    viewModel.openEditBudgetSheet()
                } label: {
                    Text("Edit Budget")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentGreen)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .stroke(accentGreen.opacity(0.6), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            Text(MoneyFormat.currency(viewModel.totalSpent))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 10)

            Text("of \(MoneyFormat.currency(viewModel.totalBudget)) budget")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            MoneyProgressBar(progress: viewModel.budgetProgress, tint: accentGreen)
                .frame(height: 8)
                .padding(.top, 14)

            Text("\(MoneyFormat.currency(max(viewModel.remainingBudget, 0))) left")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accentGreen)
                .padding(.top, 12)

            Text("\(MoneyFormat.percent(viewModel.percentOfBudgetUsed)) of budget used")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var spendingHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Spending")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if !viewModel.expensesForSelectedDay.isEmpty {
                Text(MoneyFormat.currency(viewModel.totalSpentForSelectedDay))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var spendingListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.expensesForSelectedDay.enumerated()), id: \.element.id) { index, expense in
                if index > 0 {
                    Divider()
                        .padding(.leading, 70)
                }

                expenseRow(expense)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func expenseRow(_ expense: ExpenseItem) -> some View {
        Button {
            viewModel.openEditExpenseSheet(expense)
        } label: {
            expenseRowContent(expense)
        }
        .buttonStyle(.plain)
    }

    private func expenseRowContent(_ expense: ExpenseItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(expense.category.iconBackground)
                    .frame(width: 40, height: 40)

                Image(systemName: expense.category.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !expense.merchant.isEmpty {
                    Text(expense.merchant)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(MoneyFormat.currency(expense.amount))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(MoneyFormat.transactionDate(expense.date))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 44, height: 44)

                Image(systemName: "tray")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text(viewModel.isViewingToday ? "No spending yet" : "No spending on this day")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text(viewModel.isViewingToday ? "Add your first expense to get started." : "Nothing was logged for this day.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var floatingAddExpenseButton: some View {
        Button {
            viewModel.openAddExpenseSheet()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(cardBackground))

                Text("Add Expense")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MoneyProgressBar: View {
    var progress: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))

                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(progress))
            }
        }
    }
}
