import Foundation

struct ScaleBackup: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var tasks: [TaskItem]
    var sessions: [SessionItem]
    var toDoItems: [ToDoItem]
    var appearanceModeRawValue: String?

    init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        tasks: [TaskItem],
        sessions: [SessionItem],
        toDoItems: [ToDoItem] = [],
        appearanceModeRawValue: String?
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.sessions = sessions
        self.toDoItems = toDoItems
        self.appearanceModeRawValue = appearanceModeRawValue
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case exportedAt
        case tasks
        case sessions
        case toDoItems
        case appearanceModeRawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        tasks = try container.decode([TaskItem].self, forKey: .tasks)
        sessions = try container.decode([SessionItem].self, forKey: .sessions)
        toDoItems = try container.decodeIfPresent([ToDoItem].self, forKey: .toDoItems) ?? []
        appearanceModeRawValue = try container.decodeIfPresent(String.self, forKey: .appearanceModeRawValue)
    }

    func validate() throws {
        guard schemaVersion >= 1 else {
            throw ScaleBackupError.unsupportedVersion
        }

        guard Set(tasks.map(\.id)).count == tasks.count,
              Set(sessions.map(\.id)).count == sessions.count
        else {
            throw ScaleBackupError.duplicateData
        }
    }
}

enum ScaleBackupError: Error {
    case unsupportedVersion
    case duplicateData
}

enum TimeCircleStorage {
    private static let tasksKey = "timeCircleTasks"
    private static let sessionsKey = "timeCircleSessions"
    private static let toDoItemsKey = "timeCircleToDoItems"
    private static let activeTrackingStateKey = "timeCircleActiveTrackingState"
    private static let recentTaskInteractionDatesKey = "timeCircleRecentTaskInteractionDates"
    private static let expensesKey = "timeCircleExpenses"
    private static let totalBudgetKey = "timeCircleTotalBudget"
    private static let debtsKey = "timeCircleDebts"
    private static let moneyTopUpsKey = "timeCircleMoneyTopUps"
    private static let budgetBaselineChangesKey = "timeCircleBudgetBaselineChanges"
    private static let expenseIntentionPreferencesKey = "timeCircleExpenseIntentionPreferences"
    private static let debtIntentionPreferencesKey = "timeCircleDebtIntentionPreferences"
    private static let dismissedNoToDoTasksPromptTaskIDsKey = "timeCircleDismissedNoToDoTasksPromptTaskIDs"
    private static let reminderMessagesKey = "timeCircleReminderMessages"
    private static let remindersEnabledKey = "timeCircleRemindersEnabled"
    private static let reminderIntervalMinutesKey = "timeCircleReminderIntervalMinutes"
    private static let nextReminderDateKey = "timeCircleNextReminderDate"
    private static let lastShownReminderIDKey = "timeCircleLastShownReminderID"

    static let defaultReminderMessages: [ReminderMessage] = [
        ReminderMessage(text: "Take a moment to reflect and track your day."),
        ReminderMessage(text: "How are you feeling right now? Log an activity if something stands out."),
        ReminderMessage(text: "A quick check-in now makes your day easier to look back on later.")
    ]

    static let defaultTasks = [
        TaskItem(name: "Learning French", color: .red),
        TaskItem(name: "Gym", color: .blue)
    ]

    static let defaultExpenses: [ExpenseItem] = {
        let calendar = Calendar.current
        let today = Date()

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: today) ?? today
        }

        return [
            ExpenseItem(title: "Groceries", merchant: "Walmart", amount: 48.50, emoji: "🛒", date: daysAgo(0)),
            ExpenseItem(title: "Lunch", merchant: "Chipotle", amount: 11.25, emoji: "🍔", date: daysAgo(1)),
            ExpenseItem(title: "Bills", merchant: "Netflix", amount: 15.99, emoji: "📄", date: daysAgo(2)),
            ExpenseItem(title: "Other", merchant: "Various", amount: 23.10, emoji: "🧾", date: daysAgo(2))
        ]
    }()

    static let defaultTotalBudget = 5000.0

    static func save(expenses: [ExpenseItem]) {
        saveCodable(expenses, forKey: expensesKey)
    }

    static func loadExpenses() -> [ExpenseItem]? {
        loadCodable([ExpenseItem].self, forKey: expensesKey)
    }

    static func save(debts: [DebtItem]) {
        saveCodable(debts, forKey: debtsKey)
    }

    static func loadDebts() -> [DebtItem]? {
        loadCodable([DebtItem].self, forKey: debtsKey)
    }

    static func save(moneyTopUps: [MoneyTopUp]) {
        saveCodable(moneyTopUps, forKey: moneyTopUpsKey)
    }

    static func loadMoneyTopUps() -> [MoneyTopUp]? {
        loadCodable([MoneyTopUp].self, forKey: moneyTopUpsKey)
    }

    static func save(budgetBaselineChanges: [BudgetBaselineChange]) {
        saveCodable(budgetBaselineChanges, forKey: budgetBaselineChangesKey)
    }

    static func loadBudgetBaselineChanges() -> [BudgetBaselineChange]? {
        loadCodable([BudgetBaselineChange].self, forKey: budgetBaselineChangesKey)
    }

    static func save(expenseIntentionPreferences: [String: IntentionPreference]) {
        saveCodable(expenseIntentionPreferences, forKey: expenseIntentionPreferencesKey)
    }

    static func loadExpenseIntentionPreferences() -> [String: IntentionPreference]? {
        loadCodable([String: IntentionPreference].self, forKey: expenseIntentionPreferencesKey)
    }

    static func save(debtIntentionPreferences: [String: IntentionPreference]) {
        saveCodable(debtIntentionPreferences, forKey: debtIntentionPreferencesKey)
    }

    static func loadDebtIntentionPreferences() -> [String: IntentionPreference]? {
        loadCodable([String: IntentionPreference].self, forKey: debtIntentionPreferencesKey)
    }

    static func save(totalBudget: Double) {
        UserDefaults.standard.set(totalBudget, forKey: totalBudgetKey)
    }

    static func loadTotalBudget() -> Double? {
        guard UserDefaults.standard.object(forKey: totalBudgetKey) != nil else { return nil }
        return UserDefaults.standard.double(forKey: totalBudgetKey)
    }

    static func save(tasks: [TaskItem], sessions: [SessionItem]) {
        saveCodable(tasks, forKey: tasksKey)
        saveCodable(sessions, forKey: sessionsKey)
    }

    static func loadTasks() -> [TaskItem]? {
        loadCodable([TaskItem].self, forKey: tasksKey)
    }

    static func loadSessions() -> [SessionItem]? {
        loadCodable([SessionItem].self, forKey: sessionsKey)
    }

    static func save(recentTaskInteractionDates: [UUID: Date]) {
        saveCodable(recentTaskInteractionDates, forKey: recentTaskInteractionDatesKey)
    }

    static func loadRecentTaskInteractionDates() -> [UUID: Date]? {
        loadCodable([UUID: Date].self, forKey: recentTaskInteractionDatesKey)
    }

    static func save(toDoItems: [ToDoItem]) {
        saveCodable(toDoItems, forKey: toDoItemsKey)
    }

    static func loadToDoItems() -> [ToDoItem]? {
        loadCodable([ToDoItem].self, forKey: toDoItemsKey)
    }

    static func save(dismissedNoToDoTasksPromptTaskIDs: Set<UUID>) {
        saveCodable(dismissedNoToDoTasksPromptTaskIDs, forKey: dismissedNoToDoTasksPromptTaskIDsKey)
    }

    static func loadDismissedNoToDoTasksPromptTaskIDs() -> Set<UUID>? {
        loadCodable(Set<UUID>.self, forKey: dismissedNoToDoTasksPromptTaskIDsKey)
    }

    static func save(reminderMessages: [ReminderMessage]) {
        saveCodable(reminderMessages, forKey: reminderMessagesKey)
    }

    static func loadReminderMessages() -> [ReminderMessage]? {
        loadCodable([ReminderMessage].self, forKey: reminderMessagesKey)
    }

    static func save(remindersEnabled: Bool) {
        UserDefaults.standard.set(remindersEnabled, forKey: remindersEnabledKey)
    }

    static func loadRemindersEnabled() -> Bool? {
        guard UserDefaults.standard.object(forKey: remindersEnabledKey) != nil else { return nil }
        return UserDefaults.standard.bool(forKey: remindersEnabledKey)
    }

    static func save(reminderIntervalMinutes: Int) {
        UserDefaults.standard.set(reminderIntervalMinutes, forKey: reminderIntervalMinutesKey)
    }

    static func loadReminderIntervalMinutes() -> Int? {
        guard UserDefaults.standard.object(forKey: reminderIntervalMinutesKey) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: reminderIntervalMinutesKey)
    }

    static func save(nextReminderDate: Date?) {
        guard let nextReminderDate else {
            UserDefaults.standard.removeObject(forKey: nextReminderDateKey)
            return
        }
        UserDefaults.standard.set(nextReminderDate, forKey: nextReminderDateKey)
    }

    static func loadNextReminderDate() -> Date? {
        UserDefaults.standard.object(forKey: nextReminderDateKey) as? Date
    }

    static func save(lastShownReminderID: UUID?) {
        guard let lastShownReminderID else {
            UserDefaults.standard.removeObject(forKey: lastShownReminderIDKey)
            return
        }
        UserDefaults.standard.set(lastShownReminderID.uuidString, forKey: lastShownReminderIDKey)
    }

    static func loadLastShownReminderID() -> UUID? {
        guard let string = UserDefaults.standard.string(forKey: lastShownReminderIDKey) else { return nil }
        return UUID(uuidString: string)
    }

    static func save(activeTrackingState: ActiveTrackingState?) {
        guard let activeTrackingState else {
            UserDefaults.standard.removeObject(forKey: activeTrackingStateKey)
            return
        }

        saveCodable(activeTrackingState, forKey: activeTrackingStateKey)
    }

    static func loadActiveTrackingState() -> ActiveTrackingState? {
        loadCodable(ActiveTrackingState.self, forKey: activeTrackingStateKey)
    }

    static func clearActiveTrackingState() {
        UserDefaults.standard.removeObject(forKey: activeTrackingStateKey)
    }

    static func backupData(
        tasks: [TaskItem],
        sessions: [SessionItem],
        toDoItems: [ToDoItem],
        appearanceModeRawValue: String?
    ) throws -> Data {
        let backup = ScaleBackup(
            tasks: tasks,
            sessions: sessions,
            toDoItems: toDoItems,
            appearanceModeRawValue: appearanceModeRawValue
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func decodeBackup(from data: Data) throws -> ScaleBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(ScaleBackup.self, from: data)
        try backup.validate()
        return backup
    }

    private static func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        if let encodedValue = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encodedValue, forKey: key)
        }
    }

    private static func loadCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
