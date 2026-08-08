import SwiftUI

struct MoneyView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    var onSwipeToToDo: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var editBudgetText = ""
    @State private var isDatePillPressed = false
    @State private var datePillLongPressTimer: DispatchWorkItem?
    @State private var datePillDidTriggerLongPress = false
    @State private var isShowingAddOptions = false
    @State private var isSpendingExpanded = true
    @State private var isDebtsExpanded = true

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

                    Text("Schedule your spending")
                        .font(.system(size: 17))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    budgetCard
                        .padding(.top, 20)

                    spendingHeader
                        .padding(.top, 28)

                    if isSpendingExpanded && !viewModel.expensesForSelectedDay.isEmpty {
                        spendingListCard
                            .padding(.top, 12)
                            .transition(.opacity)
                    }

                    debtsHeader
                        .padding(.top, 28)

                    if isDebtsExpanded && !(viewModel.pendingDebtsForSelectedDay.isEmpty && viewModel.paidDebtsForSelectedDay.isEmpty) {
                        debtsListCard
                            .padding(.top, 12)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
            }
            .background(Color(activityPickerSystemBackground).ignoresSafeArea())
            .gesture(swipeGesture)

            floatingAddButton
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $viewModel.isShowingAddExpense) {
            AddExpenseView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingAddDebt) {
            AddDebtView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isShowingAddMoney) {
            AddMoneyView(viewModel: viewModel)
        }
        .alert("Edit Budget", isPresented: $viewModel.isShowingEditBudget) {
            TextField("Total budget", text: $editBudgetText)
                #if canImport(UIKit)
                .keyboardType(.decimalPad)
                #endif
            Button("Update Today's Budget") {
                if let value = Double(editBudgetText) {
                    viewModel.updateTotalBudget(value, scope: .today)
                }
            }
            Button("Update Past & Today's Budget") {
                if let value = Double(editBudgetText) {
                    viewModel.updateTotalBudget(value, scope: .pastAndToday)
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

                settingsButton
            }
            .frame(height: 36, alignment: .center)

            dateSelector
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36, alignment: .center)
    }

    private var settingsButton: some View {
        Button {
            viewModel.isShowingSettings = true
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
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
        .highPriorityGesture(datePillGesture)
        .onChange(of: viewModel.isShowingHistoryPicker) { oldValue, newValue in
            // See ToDoView's dateSelector for why this reset is needed: the sheet presentation
            // triggered by a long press cancels the in-flight touch before the DragGesture's
            // `onEnded` runs, so `datePillDidTriggerLongPress` never gets reset by its `defer`
            // and silently swallows the next tap unless we reset it here on dismissal.
            if oldValue, !newValue {
                datePillLongPressTimer?.cancel()
                datePillLongPressTimer = nil
                datePillDidTriggerLongPress = false
                isDatePillPressed = false
            }
        }
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

    /// Tap vs. swipe vs. long-press all share this one `DragGesture(minimumDistance: 0)` so a
    /// press can start out ambiguous and resolve as any of the three. Swipe still moves the
    /// selected day by one. A tap opens the Heatmap while viewing today, or returns to today
    /// while viewing a past day. A long press (past day only — today does nothing extra beyond
    /// its own tap behavior) opens the Heatmap without first needing to return to today.
    private var datePillGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 45
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                isDatePillPressed = !isSwipe

                if datePillLongPressTimer == nil, !datePillDidTriggerLongPress, !isSwipe, !viewModel.isViewingToday {
                    let timer = DispatchWorkItem {
                        datePillDidTriggerLongPress = true
                        isDatePillPressed = false
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.openHistoryPicker()
                        }
                    }
                    datePillLongPressTimer = timer
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: timer)
                }

                if isSwipe {
                    datePillLongPressTimer?.cancel()
                    datePillLongPressTimer = nil
                }
            }
            .onEnded { value in
                datePillLongPressTimer?.cancel()
                datePillLongPressTimer = nil
                defer { datePillDidTriggerLongPress = false }

                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 45
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                isDatePillPressed = false

                guard !datePillDidTriggerLongPress else { return }

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
                        if viewModel.isViewingToday {
                            viewModel.openHistoryPicker()
                        } else {
                            viewModel.selectToday()
                        }
                    }
                }
            }
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
                    editBudgetText = String(format: "%.2f", viewModel.budgetForSelectedDay)
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

            Text(MoneyFormat.currency(viewModel.budgetForSelectedDay))
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 10)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var debtsHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Debts")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(MoneyFormat.currency(viewModel.totalOwedForSelectedDay))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            collapseChevronButton(isExpanded: $isDebtsExpanded)
        }
    }

    private var debtsListCard: some View {
        let pending = viewModel.pendingDebtsForSelectedDay.map { (debt: $0, isCheckedForDay: false) }
        let paid = viewModel.paidDebtsForSelectedDay.map { (debt: $0, isCheckedForDay: true) }
        let rows = pending + paid

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.debt.id) { index, row in
                if index > 0 {
                    Divider()
                        .padding(.leading, 70)
                }

                debtRow(row.debt, isCheckedForDay: row.isCheckedForDay)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    /// `isCheckedForDay` reflects whether this debt is paid *as of the day being viewed*, not
    /// `debt.isPaid` directly — that flag is permanent once set, but a debt paid on a later day
    /// must still render as pending on days before that, to match what was actually true then.
    private func debtRow(_ debt: DebtItem, isCheckedForDay: Bool) -> some View {
        HStack(spacing: 14) {
            Button {
                viewModel.toggleDebtPaid(debt.id)
            } label: {
                Image(systemName: isCheckedForDay ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isCheckedForDay ? accentGreen : Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.openEditDebtSheet(debt)
            } label: {
                HStack(spacing: 8) {
                    Text(debt.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isCheckedForDay ? .secondary : .primary)
                        .strikethrough(isCheckedForDay)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(MoneyFormat.currency(debt.amount))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isCheckedForDay ? .secondary : .primary)
                        .strikethrough(isCheckedForDay)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var spendingHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Spending")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(MoneyFormat.currency(viewModel.totalSpentForSelectedDay))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            collapseChevronButton(isExpanded: $isSpendingExpanded)
        }
    }

    private func collapseChevronButton(isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.wrappedValue.toggle()
            }
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    .fill(cardBackground)
                    .frame(width: 40, height: 40)

                Text(expense.emoji)
                    .font(.system(size: 20))
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

    private var floatingAddButton: some View {
        Button {
            isShowingAddOptions = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(cardBackground))

                Text("Add")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("Add", isPresented: $isShowingAddOptions, titleVisibility: .visible) {
            Button("Add Money") {
                viewModel.openAddMoneySheet()
            }

            Button("Add Expense") {
                viewModel.openAddExpenseSheet()
            }

            Button("Add Debt") {
                viewModel.openAddDebtSheet()
            }

            Button("Cancel", role: .cancel) { }
        }
    }
}
