import SwiftUI
import Combine

/// One contiguous, colored slice of time within a budget progress bar — the same idea as a
/// session's colored arc on the TimeCircle ring, just laid out linearly instead.
struct BudgetContribution: Identifiable {
    let id = UUID()
    let color: Color
    let duration: TimeInterval
}

/// What the "Select a Task" screen (and the "No Tasks Yet"/"No Remaining Tasks" prompts) are
/// currently sourcing their To-Do items from: either a specific activity's own tasks, or the
/// "General" tasks for a bare type/priority — the latter used by "Continue Without Selecting
/// an Activity", where there's no specific activity to attach tasks to.
enum ToDoSelectionSource: Equatable {
    case activity(UUID)
    case general(type: ActivityType, priority: ActivityPriority?)
}

final class TimeCircleViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var sessions: [SessionItem] = []
    @Published var toDoItems: [ToDoItem] = []
    @Published var selectedTaskID: UUID?
    @Published var selectedReviewTaskName: String?
    @Published var highlightedReviewSessionIDs: Set<UUID> = []
    @Published var selectedSessionID: UUID?
    @Published var editingTaskID: UUID?
    @Published var editingSessionID: UUID?
    @Published var isAddingTask = false
    @Published var isShowingTaskPicker = false
    @Published var isShowingManualSessionTaskPicker = false
    @Published var isAddingManualSession = false
    @Published var newTaskName = ""
    @Published var newTaskColor: Color = StoredColor.blue.color
    @Published var newTaskDescription = ""
    @Published var newTaskType: ActivityType?
    @Published var newTaskPriority: ActivityPriority?
    @Published var newTaskEmoji = ""
    @Published var editingSessionTaskName = ""
    @Published var editingSessionTaskColor: Color = StoredColor.blue.color
    @Published var editingSessionActivityType: ActivityType = .pain
    @Published var editingSessionPriority: ActivityPriority?
    @Published var editingSessionStartTime = Date()
    @Published var editingSessionEndTime = Date()
    @Published var editingSessionDescription = ""
    @Published var editingSessionSubActivityIDs: [UUID] = []
    @Published var selectedDay = Calendar.current.startOfDay(for: Date())
    @Published var isShowingHistoryPicker = false
    @Published var isShowingAddToDoItem = false
    @Published var editingToDoItemID: UUID?
    @Published var newToDoItemTitle = ""
    @Published var newToDoItemActivityTaskID: UUID?
    @Published var newToDoItemActivityType: ActivityType?
    @Published var newToDoItemPriority: ActivityPriority?
    @Published var newToDoItemSubtasks: [SubtaskItem] = []
    @Published var newToDoItemRecurringWeekdays: Set<Int> = []
    @Published var newToDoItemDescription = ""
    @Published var newToDoItemNotes = ""
    @Published var state: TrackingState = .stopped
    @Published var now = Date()
    @Published var isShowingNoFuelAlert = false
    @Published var noFuelAlertMessage = ""
    @Published var isShowingPainReminder = false
    @Published var expenses: [ExpenseItem] = []
    @Published var totalBudget: Double = TimeCircleStorage.defaultTotalBudget
    @Published var isShowingAddExpense = false
    @Published var isShowingEditBudget = false
    @Published var editingExpenseID: UUID?
    @Published var newExpenseTitle = ""
    @Published var newExpenseMerchant = ""
    @Published var newExpenseAmountText = ""
    @Published var newExpenseEmoji: String = ExpenseItem.defaultEmoji
    @Published var newExpenseDate = Date()
    @Published var newExpenseNotes = ""
    @Published var newExpenseIntention = ""
    @Published var newExpenseIntentionDoNotShowAgain = false
    @Published var expenseIntentionPreferences: [String: IntentionPreference] = [:]
    @Published var debts: [DebtItem] = []
    @Published var isShowingAddDebt = false
    @Published var editingDebtID: UUID?
    @Published var newDebtTitle = ""
    @Published var newDebtAmountText = ""
    @Published var newDebtDate = Date()
    @Published var newDebtNotes = ""
    @Published var newDebtIntention = ""
    @Published var newDebtIntentionDoNotShowAgain = false
    @Published var debtIntentionPreferences: [String: IntentionPreference] = [:]
    @Published var newDebtIsDateReminderEnabled = false
    @Published var newDebtScheduledDate = Date()
    @Published var newDebtIsTimeReminderEnabled = false
    @Published var newDebtScheduledTime = Date()
    @Published var isNotificationPermissionDenied = false
    @Published var isShowingAddMoney = false
    @Published var newMoneyAmountText = ""
    @Published var newMoneyDate = Date()
    @Published var moneyTopUps: [MoneyTopUp] = []
    @Published var budgetBaselineChanges: [BudgetBaselineChange] = []
    @Published var currentSessionToDoItemID: UUID?
    /// Tasks completed while the current tracking session (start-to-stop, across any
    /// pause/resume gaps) has been active, in completion order. Snapshotted onto the
    /// saved `SessionItem`(s) when the session ends, then cleared for the next session.
    private var currentSessionCompletedTasks: [CompletedTaskSnapshot] = []
    @Published var isSelectingToDoItemForTracking = false
    @Published var toDoItemSelectionSource: ToDoSelectionSource?
    @Published var isShowingNoToDoTasksPrompt = false
    @Published var noToDoTasksPromptSource: ToDoSelectionSource?
    @Published var isCreatingToDoItemToStartTracking = false
    @Published var isShowingNoRemainingTasksPrompt = false
    @Published var noRemainingTasksPromptSource: ToDoSelectionSource?

    // MARK: - Global Reminder
    @Published var isShowingSettings = false
    @Published var reminderMessages: [ReminderMessage] = []
    @Published var remindersEnabledGlobally = true
    @Published var reminderIntervalMinutes = ReminderInterval.thirtyMinutes.minutes
    @Published var isShowingGlobalReminder = false
    @Published var currentReminderMessage: ReminderMessage?
    @Published var remindLaterMinutes = ReminderInterval.thirtyMinutes.minutes
    @Published var isDontRemindAgainSelected = false
    @Published var isAddingReminderMessage = false
    @Published var editingReminderMessageID: UUID?
    @Published var newReminderMessageText = ""

    private var nextReminderDate: Date?
    private var lastShownReminderID: UUID?

    private var startTime: Date?
    private var runningStartTime: Date?
    private var elapsedBeforePause: TimeInterval = 0
    private var completedActiveIntervals: [ActiveTrackingInterval] = []
    private var recentTaskInteractionDates: [UUID: Date] = [:]
    private var wasPainReminderDue = false
    private var lastRecurringToDoGenerationDay: Date?
    private var dismissedNoToDoTasksPromptTaskIDs: Set<UUID> = []

    var selectedIndex: Int? {
        guard let selectedTaskID else { return nil }
        return tasks.indices.first { tasks[$0].id == selectedTaskID }
    }

    /// When tracking with "Continue Without Selecting an Activity", this holds an ephemeral
    /// `TaskItem` (type + optional priority, no name shown in any activity list) that stands
    /// in for `selectedTask` — it's never added to `tasks`, so it never appears as a pickable
    /// activity anywhere. `selectedTask` resolves it first so every existing piece of the
    /// tracking pipeline (budgets, the Live Activity, the ring, chips, session saving) keeps
    /// working unchanged, exactly as it does for a normal task.
    @Published var unlinkedTrackingTask: TaskItem?

    var selectedTask: TaskItem? {
        if let unlinkedTrackingTask { return unlinkedTrackingTask }
        guard let selectedIndex else { return nil }
        return tasks[selectedIndex]
    }

    var selectedSession: SessionItem? {
        sessions.first { $0.id == selectedSessionID }
    }

    /// The To-Do task the user picked for the activity currently being tracked, shown in the
    /// tracking activity card's "Task" row. Cleared whenever tracking resets (see
    /// `resetCurrentTracking`) so each new session starts without a stale selection.
    var currentSessionToDoItem: ToDoItem? {
        guard let currentSessionToDoItemID else { return nil }
        return toDoItems.first { $0.id == currentSessionToDoItemID }
    }

    var noToDoTasksPromptDisplayName: String {
        displayName(for: noToDoTasksPromptSource)
    }

    /// The toggle only makes sense when there's a specific activity to remember the opt-out
    /// for — "Continue Without Selecting an Activity" sessions have none.
    var noToDoTasksPromptShowsDontShowAgainToggle: Bool {
        if case .activity? = noToDoTasksPromptSource { return true }
        return false
    }

    var noRemainingTasksPromptDisplayName: String {
        displayName(for: noRemainingTasksPromptSource)
    }

    func displayName(for source: ToDoSelectionSource?) -> String {
        switch source {
        case .activity(let taskID):
            return tasks.first { $0.id == taskID }?.name ?? "This activity"
        case .general(let type, let priority):
            guard type.hasPriorityTiers, let priority else { return type.title }
            let label = type == .pleasure ? "Level" : "Priority"
            return "\(type.title) (\(priority.title) \(label))"
        case nil:
            return "This activity"
        }
    }

    /// Incomplete To-Do tasks assigned specifically to this activity (not just its bare type).
    func toDoItemsAvailableForTracking(_ task: TaskItem) -> [ToDoItem] {
        toDoItems.filter { $0.activityTaskID == task.id && !$0.isCompleted }
    }

    /// Incomplete "General" To-Do tasks for a bare type/priority — i.e. tasks created without
    /// picking a specific activity. This is what "Continue Without Selecting an Activity"
    /// sources its Select-a-Task screen from, instead of a specific activity's own tasks.
    func toDoItemsAvailableForTracking(generalType type: ActivityType, priority: ActivityPriority?) -> [ToDoItem] {
        toDoItems.filter {
            $0.activityTaskID == nil
                && $0.activityType == type
                && (!type.hasPriorityTiers || ($0.manualPriority ?? .medium) == (priority ?? .medium))
                && !$0.isCompleted
        }
    }

    func toDoItems(for source: ToDoSelectionSource) -> [ToDoItem] {
        switch source {
        case .activity(let taskID):
            guard let task = tasks.first(where: { $0.id == taskID }) else { return [] }
            return toDoItemsAvailableForTracking(task)
        case .general(let type, let priority):
            return toDoItemsAvailableForTracking(generalType: type, priority: priority)
        }
    }

    /// True once the user has opted out ("Don't show this again") of the no-tasks-yet prompt
    /// for this activity — task tracking is effectively disabled for it until it gets a task
    /// again, at which point `toDoItemsAvailableForTracking` becomes non-empty and this no
    /// longer matters for display purposes.
    func hasOptedOutOfTaskTracking(_ task: TaskItem) -> Bool {
        dismissedNoToDoTasksPromptTaskIDs.contains(task.id)
    }

    private var lastPainSessionEnd: Date? {
        sessions
            .filter { $0.activityType == .pain }
            .map { $0.startTime.addingTimeInterval($0.duration) }
            .max()
    }

    /// Quiet hours during which the Pain reminder never fires, regardless of how overdue it
    /// is — 11:30 PM through 9:30 AM.
    private var isWithinPainReminderQuietHours: Bool {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        guard let hour = components.hour, let minute = components.minute else { return false }

        let minutesSinceMidnight = hour * 60 + minute
        let quietStart = 23 * 60 + 30
        let quietEnd = 9 * 60 + 30

        return minutesSinceMidnight >= quietStart || minutesSinceMidnight < quietEnd
    }

    /// True once 60 minutes have passed since the last Pain session ended (or since the
    /// start of today, if none has happened yet today), unless a Pain activity is being
    /// tracked right now or it's currently quiet hours (11:30 PM–9:30 AM). Only checked while
    /// the app is open — there's no background notification system, so this piggybacks on the
    /// per-second `now` tick.
    ///
    /// Shares `remindersEnabledGlobally` with the global reminder popup (see Reminders
    /// Settings) — that's the single enable/disable switch for every reminder entry point in
    /// the app, so turning it off here also stops this Pain-specific reminder from appearing.
    var isPainReminderDue: Bool {
        guard remindersEnabledGlobally else { return false }

        if state != .stopped, let selectedTask, selectedTask.activityType == .pain {
            return false
        }

        if isWithinPainReminderQuietHours {
            return false
        }

        let startOfToday = Calendar.current.startOfDay(for: now)
        let baseline: Date
        if let lastPainSessionEnd, lastPainSessionEnd > startOfToday {
            baseline = lastPainSessionEnd
        } else {
            baseline = startOfToday
        }

        return now.timeIntervalSince(baseline) >= 3600
    }

    var editingTask: TaskItem? {
        guard let editingTaskID else { return nil }
        return tasks.first { $0.id == editingTaskID }
    }

    var editingSession: SessionItem? {
        guard let editingSessionID else { return nil }
        return sessions.first { $0.id == editingSessionID }
    }

    /// The immutable snapshot of tasks completed during this saved session, in completion
    /// order. Read directly off the stored `SessionItem` — never recomputed from live
    /// `ToDoItem` state, so edits/deletions to those tasks afterward have no effect here.
    var editingSessionCompletedTasks: [CompletedTaskSnapshot] {
        editingSession?.completedTasks ?? []
    }

    var editingTaskName: String {
        editingTask?.name ?? ""
    }

    var editingTaskColor: Color {
        editingTask?.color.color ?? .gray
    }

    var editingTaskDescription: String {
        editingTask?.description ?? ""
    }

    var editingTaskType: ActivityType {
        editingTask?.activityType ?? .pain
    }

    var editingTaskPriority: ActivityPriority? {
        editingTask?.priority
    }

    var editingTaskEmoji: String {
        editingTask?.emoji ?? ""
    }

    var isEditingTask: Bool {
        editingTask != nil
    }

    var isEditingSession: Bool {
        editingSession != nil || isAddingManualSession
    }

    var editingSessionTitle: String {
        isAddingManualSession ? "Add Session" : "Edit Session"
    }

    var shouldShowEditingSessionDeleteButton: Bool {
        !isAddingManualSession
    }

    var editingSessionDateRange: ClosedRange<Date>? {
        guard isAddingManualSession,
              let dayInterval = Calendar.current.dateInterval(of: .day, for: selectedDay),
              let latestDate = Calendar.current.date(byAdding: .minute, value: -1, to: dayInterval.end)
        else { return nil }

        return dayInterval.start...latestDate
    }

    var currentStartTime: Date? {
        startTime
    }

    var currentActiveIntervals: [DateInterval] {
        guard state != .stopped else { return [] }

        var intervals = completedActiveIntervals.compactMap { interval -> DateInterval? in
            guard interval.end > interval.start else { return nil }
            return DateInterval(start: interval.start, end: interval.end)
        }

        if state == .running, let runningStartTime {
            let intervalEnd = max(now, runningStartTime)
            if intervalEnd > runningStartTime {
                intervals.append(DateInterval(start: runningStartTime, end: intervalEnd))
            }
        }

        return intervals
    }

    var isViewingToday: Bool {
        Calendar.current.isDate(selectedDay, inSameDayAs: now)
    }

    var selectedDayTitle: String {
        TimeCircleFormat.weekdayMonthDay(selectedDay)
    }

    var selectedDayCurrentTime: Date {
        isViewingToday ? now : selectedDay
    }

    var selectedDaySessions: [SessionItem] {
        clippedSessions(overlapping: selectedDayInterval)
            .sorted { $0.startTime < $1.startTime }
    }

    /// Tasks due on `selectedDay`, plus any still-incomplete tasks carried forward from
    /// earlier days — an incomplete task keeps reappearing on every later day until it's
    /// completed, at which point it drops out here and remains visible only on its
    /// original day (via `completedToDoItemsForSelectedDay`'s exact-day match).
    var toDoItemsForSelectedDay: [ToDoItem] {
        toDoItems
            .filter { item in
                if Calendar.current.isDate(item.day, inSameDayAs: selectedDay) {
                    return true
                }
                return item.day < selectedDay && !item.isCompleted
            }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Today shows pending items normally; past days never show pending items, since
    /// there's no such thing as "pending" in the past — only what was completed that day.
    var pendingToDoItemsForSelectedDay: [ToDoItem] {
        guard isViewingToday else { return [] }
        return toDoItemsForSelectedDay.filter { !$0.isCompleted }
    }

    var completedToDoItemsForSelectedDay: [ToDoItem] {
        toDoItemsForSelectedDay.filter(\.isCompleted)
    }

    /// Top level is always Pain / Pleasure / Other (in that order) — every task belongs to
    /// one of the three, so there's no separate trailing bucket for unassigned tasks. (Any
    /// legacy item saved before that was required, with neither `activityTaskID` nor
    /// `activityType` set, simply folds into Other rather than getting its own section.)
    /// Past days only ever include what was completed that day, so a group with nothing
    /// completed simply doesn't appear.
    ///
    /// Pain/Pleasure additionally nest a priority layer (High/Medium/Low) between the
    /// type and its activities — only priority buckets that actually contain a task are
    /// shown. A bare-type item (no specific activity) still lands in the right bucket via
    /// its own `manualPriority`. Other has no priority concept, so it nests activities
    /// directly under the type, same as before.
    var toDoGroupsForSelectedDay: [ToDoGroup] {
        let relevantItems = isViewingToday ? toDoItemsForSelectedDay : completedToDoItemsForSelectedDay

        var itemsByActivityID: [UUID: [ToDoItem]] = [:]
        var itemsByActivityType: [ActivityType: [ToDoItem]] = [:]

        for item in relevantItems {
            if let activityTaskID = item.activityTaskID {
                itemsByActivityID[activityTaskID, default: []].append(item)
            } else {
                itemsByActivityType[item.activityType ?? .none, default: []].append(item)
            }
        }

        var groups: [ToDoGroup] = []

        for type in ActivityType.allCases {
            let directItems = itemsByActivityType[type] ?? []
            let activitiesForType = tasks.filter { $0.activityType == type }

            if type.hasPriorityTiers {
                let priorityGroups = ActivityPriority.allCases.compactMap { priority -> ToDoGroup? in
                    let directForPriority = directItems.filter { ($0.manualPriority ?? .medium) == priority }

                    let activitySubGroups = activitiesForType
                        .filter { ($0.priority ?? .medium) == priority }
                        .compactMap { task -> ToDoGroup? in
                            guard let items = itemsByActivityID[task.id], !items.isEmpty else { return nil }
                            return ToDoGroup(
                                id: task.id.uuidString,
                                type: type,
                                priority: priority,
                                activity: task,
                                items: sortedByCompletion(items),
                                subGroups: []
                            )
                        }

                    guard !directForPriority.isEmpty || !activitySubGroups.isEmpty else { return nil }

                    return ToDoGroup(
                        id: "type-\(type.rawValue)-priority-\(priority.rawValue)",
                        type: type,
                        priority: priority,
                        activity: nil,
                        items: sortedByCompletion(directForPriority),
                        subGroups: activitySubGroups
                    )
                }

                groups.append(ToDoGroup(
                    id: "type-\(type.rawValue)",
                    type: type,
                    priority: nil,
                    activity: nil,
                    items: [],
                    subGroups: priorityGroups
                ))
            } else {
                let activitySubGroups = activitiesForType.compactMap { task -> ToDoGroup? in
                    guard let items = itemsByActivityID[task.id], !items.isEmpty else { return nil }
                    return ToDoGroup(
                        id: task.id.uuidString,
                        type: type,
                        priority: nil,
                        activity: task,
                        items: sortedByCompletion(items),
                        subGroups: []
                    )
                }

                groups.append(ToDoGroup(
                    id: "type-\(type.rawValue)",
                    type: type,
                    priority: nil,
                    activity: nil,
                    items: sortedByCompletion(directItems),
                    subGroups: activitySubGroups
                ))
            }
        }

        return groups
    }

    /// Stable sort that pushes completed items below pending ones, preserving each
    /// bucket's existing (sortOrder-based) relative order.
    private func sortedByCompletion(_ items: [ToDoItem]) -> [ToDoItem] {
        items.sorted { !$0.isCompleted && $1.isCompleted }
    }

    var orderedTasksForSelectedDay: [TaskItem] {
        let latestUseByTaskName = latestSelectedDayUseByTaskName()

        return tasks.enumerated()
            .sorted { first, second in
                if isViewingToday {
                    let firstInteraction = recentTaskInteractionDates[first.element.id] ?? latestUseByTaskName[first.element.name]
                    let secondInteraction = recentTaskInteractionDates[second.element.id] ?? latestUseByTaskName[second.element.name]

                    switch (firstInteraction, secondInteraction) {
                    case let (firstInteraction?, secondInteraction?):
                        if firstInteraction != secondInteraction {
                            return firstInteraction > secondInteraction
                        }
                    case (_?, nil):
                        return true
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        break
                    }
                }

                let firstUse = latestUseByTaskName[first.element.name]
                let secondUse = latestUseByTaskName[second.element.name]

                switch (firstUse, secondUse) {
                case let (firstUse?, secondUse?):
                    if firstUse == secondUse {
                        return first.offset < second.offset
                    }

                    return firstUse > secondUse
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return first.offset < second.offset
                }
            }
            .map(\.element)
    }

    var recentlyTrackedTasks: [TaskItem] {
        let calendar = Calendar.current
        var latestUseByTaskName: [String: Date] = [:]

        for session in sessions where calendar.isDateInToday(session.endTime) {
            latestUseByTaskName[session.taskName] = max(
                latestUseByTaskName[session.taskName] ?? session.startTime,
                session.endTime
            )
        }

        for (taskID, date) in recentTaskInteractionDates where calendar.isDateInToday(date) {
            guard let task = tasks.first(where: { $0.id == taskID }) else { continue }
            latestUseByTaskName[task.name] = max(latestUseByTaskName[task.name] ?? date, date)
        }

        return tasks
            .filter { latestUseByTaskName[$0.name] != nil }
            .sorted { (latestUseByTaskName[$0.name] ?? .distantPast) > (latestUseByTaskName[$1.name] ?? .distantPast) }
    }

    var taskChipsForSelectedDay: [TaskChipItem] {
        if isViewingToday {
            return orderedTasksForSelectedDay.map { task in
                TaskChipItem(
                    id: task.id.uuidString,
                    taskID: task.id,
                    name: task.name,
                    color: task.color
                )
            }
        }

        let groupedSessions = Dictionary(grouping: selectedDaySessions, by: \.taskName)

        return groupedSessions.map { taskName, sessions in
            return (
                chip: TaskChipItem(
                    id: taskName,
                    taskID: nil,
                    name: taskName,
                    color: sessions.max(by: { $0.endTime < $1.endTime })?.color ?? .blue
                ),
                latestEnd: latestSessionEndTime(in: sessions)
            )
        }
        .sorted {
            if $0.latestEnd == $1.latestEnd {
                return $0.chip.name < $1.chip.name
            }

            return $0.latestEnd > $1.latestEnd
        }
        .map(\.chip)
    }

    private func latestSessionEndTime(in sessions: [SessionItem]) -> Date {
        sessions.map(\.endTime).max() ?? selectedDay
    }

    var selectedTaskTrackedTimeForSelectedDay: TimeInterval {
        guard let selectedTask else { return 0 }

        return selectedDaySessions
            .filter { $0.taskName == selectedTask.name }
            .reduce(0) { $0 + $1.duration }
    }

    var selectedTaskHasAccumulatedTimeForSelectedDay: Bool {
        selectedTaskTrackedTimeForSelectedDay > 0
    }

    var selectedTaskDisplayElapsed: TimeInterval {
        guard selectedTask != nil else { return 0 }
        guard isViewingToday, state != .stopped else {
            return selectedTaskTrackedTimeForSelectedDay
        }

        return selectedTaskTrackedTimeForSelectedDay + elapsed
    }

    var timelineDisplayTask: TaskItem? {
        if isViewingToday {
            return state == .stopped ? nil : selectedTask
        }

        guard let selectedReviewTaskName,
              let latestSession = selectedDaySessions
                .filter({ $0.taskName == selectedReviewTaskName })
                .sorted(by: { $0.startTime < $1.startTime })
                .last
        else { return nil }

        return TaskItem(name: selectedReviewTaskName, color: latestSession.color, activityType: latestSession.activityType)
    }

    var timelineDisplayElapsed: TimeInterval {
        guard !isViewingToday, let selectedReviewTaskName else {
            return selectedTaskDisplayElapsed
        }

        return selectedDaySessions
            .filter { $0.taskName == selectedReviewTaskName }
            .reduce(0) { $0 + $1.duration }
    }

    /// The TimeCircle center's live "hour" scope display: plain elapsed time counting up like
    /// a stopwatch, for all three types. Budget draining/overage still exists underneath (via
    /// `targetBalanceToday`, used for the Live Activity and for enforcement) — this is purely
    /// what's shown on-screen while actively tracking. Pain shows elapsed for just the priority
    /// being tracked (its own independent 2h pool, matching that priority's own segment in the
    /// activity panel below) rather than the combined total across all three priorities.
    var timelineCountdownDisplay: TimeInterval {
        guard isViewingToday, state != .stopped, let selectedTask else { return 0 }

        if selectedTask.activityType == .pain {
            let priority = selectedTask.priority ?? .medium
            return trackedTime(for: .pain, priority: priority, in: elapsedTodayInterval) + elapsed
        }

        // Neutral doesn't carry prior sessions into the live timer — each new session starts
        // counting from 00:00:00, even though its cumulative daily total (used for budgets and
        // the activity panel stat) keeps accumulating underneath.
        if selectedTask.activityType == .none {
            return elapsed
        }

        return trackedTime(for: selectedTask.activityType, in: elapsedTodayInterval) + elapsed
    }

    /// Display-only value for the activity information panel's "X / Total" stat and progress
    /// bar: plain elapsed time counting up like a stopwatch, for all three types. This is
    /// separate from the TimeCircle center's `timelineCountdownDisplay`, which still shows a
    /// draining countdown (with "+" overage) for Pain specifically, since that's the one type
    /// with real per-priority budget pressure. Start/resume/auto-stop enforcement is
    /// untouched — it still uses the per-priority Pain timer or the shared pool via
    /// `remainingFuelToday`/`targetBalanceToday`.
    var dailyBudgetRemainingToday: TimeInterval {
        guard isViewingToday, state != .stopped, let selectedTask else { return 0 }

        return trackedTime(for: selectedTask.activityType, in: elapsedTodayInterval) + elapsed
    }

    private func currentColor(for session: SessionItem) -> Color {
        (tasks.first { $0.name == session.taskName }?.color ?? session.color).color
    }

    /// Ordered, contiguous colored time contributions toward `priority`'s own 2h Pain budget
    /// today — one entry per session, each in that session's own task color, plus the live
    /// elapsed time if `priority` is the one currently being tracked. Drives the Pain activity
    /// panel's three-segment progress bar, where each segment fills with whichever tasks
    /// actually contributed to it (matching how the TimeCircle ring already colors each
    /// session by its own task), rather than one uniform tint for the whole segment.
    func painPriorityContributions(_ priority: ActivityPriority) -> [BudgetContribution] {
        guard let interval = elapsedTodayInterval else { return [] }

        var contributions = clippedSessions(overlapping: interval)
            .filter { currentActivityType(for: $0) == .pain && currentPriority(for: $0) == priority }
            .sorted { $0.startTime < $1.startTime }
            .map { BudgetContribution(color: currentColor(for: $0), duration: $0.duration) }

        if isViewingToday, state != .stopped, let selectedTask, selectedTask.activityType == .pain,
           (selectedTask.priority ?? .medium) == priority {
            contributions.append(BudgetContribution(color: selectedTask.color.color, duration: elapsed))
        }

        return contributions
    }

    /// Same idea as `painPriorityContributions`, for Pleasure/Neutral's single combined bar
    /// (no priority split).
    func budgetContributions(for activityType: ActivityType) -> [BudgetContribution] {
        guard let interval = elapsedTodayInterval else { return [] }

        var contributions = clippedSessions(overlapping: interval)
            .filter { currentActivityType(for: $0) == activityType }
            .sorted { $0.startTime < $1.startTime }
            .map { BudgetContribution(color: currentColor(for: $0), duration: $0.duration) }

        if isViewingToday, state != .stopped, let selectedTask, selectedTask.activityType == activityType {
            contributions.append(BudgetContribution(color: selectedTask.color.color, duration: elapsed))
        }

        return contributions
    }

    var historySummaries: [DayHistorySummary] {
        var groupedSessions: [Date: [SessionItem]] = [:]

        for session in sessions {
            for day in daysOverlapped(by: session) {
                guard let dayInterval = Calendar.current.dateInterval(of: .day, for: day),
                      let clippedSession = clippedSession(session, to: dayInterval)
                else { continue }

                groupedSessions[day, default: []].append(sessionWithCurrentActivityType(clippedSession))
            }
        }

        let today = Calendar.current.startOfDay(for: now)
        if groupedSessions[today] == nil {
            groupedSessions[today] = []
        }

        return groupedSessions.map { day, sessions in
            DayHistorySummary(day: day, sessions: sessions.sorted { $0.startTime < $1.startTime })
        }
        .sorted { $0.day > $1.day }
    }

    var elapsed: TimeInterval {
        switch state {
        case .stopped:
            return 0
        case .paused:
            return max(elapsedBeforePause, 0)
        case .running:
            guard let runningStartTime else { return elapsedBeforePause }
            return max(elapsedBeforePause + now.timeIntervalSince(runningStartTime), 0)
        }
    }

    var todayTrackedTime: TimeInterval {
        totalTrackedTime(in: Calendar.current.dateInterval(of: .day, for: now))
    }

    var weekTrackedTime: TimeInterval {
        totalTrackedTime(in: Calendar.current.dateInterval(of: .weekOfYear, for: now))
    }

    var monthTrackedTime: TimeInterval {
        totalTrackedTime(in: Calendar.current.dateInterval(of: .month, for: now))
    }

    var taskTimeSummaries: [TaskTimeSummary] {
        let groupedSessions = Dictionary(grouping: sessions, by: \.taskName)

        return groupedSessions.map { taskName, sessions in
            let duration = sessions.reduce(0) { $0 + $1.duration }
            let color = sessions.last?.color ?? .blue
            return TaskTimeSummary(taskName: taskName, color: color, duration: duration)
        }
        .sorted {
            if $0.duration == $1.duration {
                return $0.taskName < $1.taskName
            }

            return $0.duration > $1.duration
        }
    }

    var activityTypeTimeSummaries: [ActivityTypeTimeSummary] {
        let interval = elapsedTodayInterval
        let durationsByActivityType = Dictionary(
            uniqueKeysWithValues: ActivityType.allCases.map { activityType in
                (activityType, trackedTime(for: activityType, in: interval))
            }
        )
        let totalDuration = durationsByActivityType.values.reduce(0, +)

        return ActivityType.allCases.map { activityType in
            return ActivityTypeTimeSummary(
                activityType: activityType,
                duration: durationsByActivityType[activityType] ?? 0,
                totalDuration: totalDuration,
                targetDuration: activityType.totalDailyBudgetDuration
            )
        }
    }

    func loadData() {
        if let decodedTasks = TimeCircleStorage.loadTasks() {
            tasks = decodedTasks
        } else {
            tasks = TimeCircleStorage.defaultTasks
            saveData()
        }

        if let decodedSessions = TimeCircleStorage.loadSessions() {
            sessions = decodedSessions
        }

        if let decodedToDoItems = TimeCircleStorage.loadToDoItems() {
            toDoItems = decodedToDoItems
        }

        if let decodedDismissedIDs = TimeCircleStorage.loadDismissedNoToDoTasksPromptTaskIDs() {
            dismissedNoToDoTasksPromptTaskIDs = decodedDismissedIDs
        }

        if let decodedInteractionDates = TimeCircleStorage.loadRecentTaskInteractionDates() {
            recentTaskInteractionDates = decodedInteractionDates
        }

        if let decodedExpenses = TimeCircleStorage.loadExpenses() {
            expenses = decodedExpenses
        } else {
            expenses = TimeCircleStorage.defaultExpenses
            saveExpenses()
        }

        if let decodedTotalBudget = TimeCircleStorage.loadTotalBudget() {
            totalBudget = decodedTotalBudget
        } else {
            totalBudget = TimeCircleStorage.defaultTotalBudget
            saveTotalBudget()
        }

        if let decodedDebts = TimeCircleStorage.loadDebts() {
            debts = decodedDebts
        }

        if let decodedMoneyTopUps = TimeCircleStorage.loadMoneyTopUps() {
            moneyTopUps = decodedMoneyTopUps
        }

        if let decodedBudgetBaselineChanges = TimeCircleStorage.loadBudgetBaselineChanges() {
            budgetBaselineChanges = decodedBudgetBaselineChanges
        }

        if let decodedExpenseIntentionPreferences = TimeCircleStorage.loadExpenseIntentionPreferences() {
            expenseIntentionPreferences = decodedExpenseIntentionPreferences
        }

        if let decodedDebtIntentionPreferences = TimeCircleStorage.loadDebtIntentionPreferences() {
            debtIntentionPreferences = decodedDebtIntentionPreferences
        }

        if let decodedReminderMessages = TimeCircleStorage.loadReminderMessages() {
            reminderMessages = decodedReminderMessages
        } else {
            reminderMessages = TimeCircleStorage.defaultReminderMessages
            saveReminderMessages()
        }

        remindersEnabledGlobally = TimeCircleStorage.loadRemindersEnabled() ?? true
        reminderIntervalMinutes = TimeCircleStorage.loadReminderIntervalMinutes() ?? ReminderInterval.thirtyMinutes.minutes
        remindLaterMinutes = reminderIntervalMinutes
        nextReminderDate = TimeCircleStorage.loadNextReminderDate()
        lastShownReminderID = TimeCircleStorage.loadLastShownReminderID()

        if remindersEnabledGlobally, nextReminderDate == nil {
            scheduleNextReminder(minutesFromNow: reminderIntervalMinutes)
        }

        restoreActiveTrackingState()
        ensureValidSelectedTask()
        generateDueRecurringToDoOccurrences()
    }

    func replaceData(with backup: ScaleBackup) {
        resetCurrentTracking()
        tasks = backup.tasks
        sessions = backup.sessions
        toDoItems = backup.toDoItems
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        editingTaskID = nil
        editingSessionID = nil
        isAddingTask = false
        isShowingTaskPicker = false
        isShowingManualSessionTaskPicker = false
        isAddingManualSession = false
        isShowingHistoryPicker = false
        selectedDay = Calendar.current.startOfDay(for: now)
        saveData()
        saveToDoItems()
    }

    func updateCurrentTime(_ date: Date) {
        now = date
        if isViewingToday {
            selectedDay = Calendar.current.startOfDay(for: date)
        }

        ensureValidActiveTrackingState()
        enforceFuelLimitIfNeeded()
        updatePainReminderState()
        checkGlobalReminderSchedule()
        generateDueRecurringToDoOccurrences()
    }

    /// Surfaces the reminder the moment the due condition freshly becomes true, and
    /// auto-dismisses it the moment it stops being due (e.g. a Pain session starts).
    /// Dismissing it manually doesn't reappear until the condition clears and re-triggers
    /// (track a Pain activity, then let another hour pass) rather than nagging every tick.
    private func updatePainReminderState() {
        let due = isPainReminderDue

        if due && !wasPainReminderDue {
            isShowingPainReminder = true
        } else if !due {
            isShowingPainReminder = false
        }

        wasPainReminderDue = due
    }

    /// Checks whether the app-wide reminder is due, entirely independent of what page is
    /// currently on screen or whether an activity is being tracked — the popup is presented
    /// via a separate always-on-top window (see `GlobalReminderPresenter`), so this never needs
    /// to know about navigation state to be able to fire.
    private func checkGlobalReminderSchedule() {
        guard remindersEnabledGlobally, !isShowingGlobalReminder else { return }
        guard let nextReminderDate, now >= nextReminderDate else { return }
        guard let message = randomEnabledReminderMessage() else { return }

        currentReminderMessage = message
        remindLaterMinutes = reminderIntervalMinutes
        isDontRemindAgainSelected = false
        isShowingGlobalReminder = true

        lastShownReminderID = message.id
        TimeCircleStorage.save(lastShownReminderID: message.id)
    }

    /// Picks a random enabled message, avoiding an immediate repeat of the last one shown
    /// whenever more than one enabled message exists.
    private func randomEnabledReminderMessage() -> ReminderMessage? {
        let enabled = reminderMessages.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }

        if enabled.count > 1, let lastShownReminderID {
            let candidates = enabled.filter { $0.id != lastShownReminderID }
            if let choice = candidates.randomElement() {
                return choice
            }
        }

        return enabled.randomElement()
    }

    private func scheduleNextReminder(minutesFromNow minutes: Int) {
        let date = now.addingTimeInterval(TimeInterval(minutes * 60))
        nextReminderDate = date
        TimeCircleStorage.save(nextReminderDate: date)
    }

    /// Resolves the popup for any of its three outcomes. "Don't remind again" takes priority if
    /// selected; otherwise the next reminder is scheduled using `remindLaterMinutes`, which is
    /// reset to the standing default interval every time a reminder appears — so leaving it
    /// untouched and tapping "Got it" reproduces the existing schedule exactly, while changing
    /// it first postpones by that chosen amount instead.
    func resolveGlobalReminder() {
        if isDontRemindAgainSelected {
            remindersEnabledGlobally = false
            TimeCircleStorage.save(remindersEnabled: false)
            nextReminderDate = nil
            TimeCircleStorage.save(nextReminderDate: nil)
        } else {
            scheduleNextReminder(minutesFromNow: remindLaterMinutes)
        }

        isShowingGlobalReminder = false
        currentReminderMessage = nil
        isDontRemindAgainSelected = false
    }

    func setRemindersEnabledGlobally(_ isEnabled: Bool) {
        remindersEnabledGlobally = isEnabled
        TimeCircleStorage.save(remindersEnabled: isEnabled)

        if isEnabled, nextReminderDate == nil {
            scheduleNextReminder(minutesFromNow: reminderIntervalMinutes)
        }
    }

    func setReminderIntervalMinutes(_ minutes: Int) {
        reminderIntervalMinutes = minutes
        TimeCircleStorage.save(reminderIntervalMinutes: minutes)
    }

    private func saveReminderMessages() {
        TimeCircleStorage.save(reminderMessages: reminderMessages)
    }

    func openAddReminderMessageSheet() {
        editingReminderMessageID = nil
        newReminderMessageText = ""
        isAddingReminderMessage = true
    }

    func openEditReminderMessageSheet(_ message: ReminderMessage) {
        editingReminderMessageID = message.id
        newReminderMessageText = message.text
        isAddingReminderMessage = true
    }

    func closeAddReminderMessageSheet() {
        isAddingReminderMessage = false
        editingReminderMessageID = nil
    }

    func saveReminderMessageForm() {
        let trimmed = newReminderMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let editingReminderMessageID, let index = reminderMessages.firstIndex(where: { $0.id == editingReminderMessageID }) {
            reminderMessages[index].text = trimmed
        } else {
            reminderMessages.append(ReminderMessage(text: trimmed))
        }

        saveReminderMessages()
        isAddingReminderMessage = false
        editingReminderMessageID = nil
    }

    func deleteReminderMessage(_ message: ReminderMessage) {
        reminderMessages.removeAll { $0.id == message.id }
        saveReminderMessages()
    }

    func setReminderMessageEnabled(_ message: ReminderMessage, isEnabled: Bool) {
        guard let index = reminderMessages.firstIndex(where: { $0.id == message.id }) else { return }
        reminderMessages[index].isEnabled = isEnabled
        saveReminderMessages()
    }

    func appWillResignActive() {
        persistActiveTrackingState()
    }

    func appDidBecomeActive() {
        now = Date()
        if state == .stopped {
            restoreActiveTrackingState()
        } else {
            ensureValidActiveTrackingState()
            persistActiveTrackingState()
            syncLiveActivityIfNeeded()
        }
        generateDueRecurringToDoOccurrences()
    }

    func selectTask(_ task: TaskItem) {
        selectedTaskID = task.id
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        resetCurrentTracking()
    }

    func startTaskFromChip(_ task: TaskItem) -> Bool {
        guard state == .stopped, isViewingToday else { return false }
        guard hasFuelAvailableToStart(task) else {
            showNoFuelAlert(for: task.activityType, priority: task.priority)
            return false
        }

        moveTaskToFront(task.id)
        selectedTaskID = task.id
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        guard start() else {
            selectedTaskID = nil
            return false
        }

        return true
    }

    func handleTaskChipTap(_ chip: TaskChipItem) -> Bool {
        if isViewingToday {
            guard let taskID = chip.taskID,
                  let task = tasks.first(where: { $0.id == taskID })
            else { return false }

            return startTaskFromChip(task)
        }

        selectReviewTask(named: chip.name)
        return false
    }

    func isTaskChipActive(_ chip: TaskChipItem) -> Bool {
        if isViewingToday {
            return selectedTaskID?.uuidString == chip.id && state != .stopped
        }

        return selectedReviewTaskName == chip.name
    }

    func isSessionHighlightedForReview(_ session: SessionItem) -> Bool {
        highlightedReviewSessionIDs.contains(session.id)
    }

    func activityForEditing(from chip: TaskChipItem) -> TaskItem? {
        if let taskID = chip.taskID {
            return tasks.first { $0.id == taskID }
        }

        return tasks.first { $0.name == chip.name }
    }

    func clearSelectedTaskFromBackgroundTap() {
        guard state == .stopped else { return }

        clearSelectedTask()
    }

    func clearPastDayActivitySelectionFromBackgroundTap() {
        guard !isViewingToday else { return }

        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
    }

    func clearSelectedTask() {
        guard state == .stopped else { return }

        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
    }

    func selectReviewTask(named taskName: String) {
        guard !isViewingToday else { return }

        selectedReviewTaskName = taskName
        highlightedReviewSessionIDs = Set(
            selectedDaySessions
                .filter { $0.taskName == taskName }
                .map(\.id)
        )
        selectedTaskID = nil
        selectedSessionID = nil
    }

    func editTask(_ task: TaskItem) {
        editingTaskID = task.id
    }

    func closeTaskEditor() {
        let editedTaskID = editingTaskID
        editingTaskID = nil

        if isViewingToday, let editedTaskID {
            markTaskInteraction(editedTaskID)
            moveTaskToFront(editedTaskID)
        }
    }

    func openSessionEditor(_ session: SessionItem) {
        guard let originalSession = sessions.first(where: { $0.id == session.id }) else { return }

        selectedSessionID = session.id
        if isViewingToday {
            selectedReviewTaskName = nil
            highlightedReviewSessionIDs = []
        }
        editingSessionID = session.id
        editingSessionTaskName = originalSession.taskName
        editingSessionTaskColor = originalSession.color.color
        editingSessionActivityType = originalSession.activityType
        editingSessionPriority = originalSession.priority
        editingSessionStartTime = originalSession.startTime
        editingSessionEndTime = originalSession.endTime
        editingSessionDescription = originalSession.sessionDescription
        editingSessionSubActivityIDs = originalSession.subActivityIDs
    }

    func closeSessionEditor() {
        let closedSessionID = editingSessionID
        editingSessionID = nil
        isAddingManualSession = false
        editingSessionDescription = ""
        editingSessionSubActivityIDs = []
        selectedSessionID = nil

        if isViewingToday {
            selectedReviewTaskName = nil
            highlightedReviewSessionIDs = []
            guard state == .stopped else { return }

            selectedTaskID = nil
            return
        }

        removeClosedSessionFromReviewHighlights(closedSessionID)

        guard state == .stopped else { return }

        selectedTaskID = nil
    }

    func saveEditingSession() {
        if isAddingManualSession {
            saveManualSession()
            return
        }

        guard let editingSessionIndex else {
            closeSessionEditor()
            return
        }

        let trimmedName = editingSessionTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard editingSessionEndTime >= editingSessionStartTime else { return }

        sessions[editingSessionIndex].taskName = trimmedName
        sessions[editingSessionIndex].color = StoredColor(from: editingSessionTaskColor)
        sessions[editingSessionIndex].activityType = editingSessionActivityType
        sessions[editingSessionIndex].priority = editingSessionPriority
        sessions[editingSessionIndex].startTime = editingSessionStartTime
        sessions[editingSessionIndex].duration = editingSessionEndTime.timeIntervalSince(editingSessionStartTime)
        sessions[editingSessionIndex].sessionDescription = editingSessionDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        sessions[editingSessionIndex].subActivityIDs = validSubActivityIDs(for: editingSessionActivityType)
        saveData()
        closeSessionEditor()
    }

    private func saveManualSession() {
        let trimmedName = editingSessionTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard editingSessionEndTime >= editingSessionStartTime else { return }

        sessions.append(
            SessionItem(
                taskName: trimmedName,
                color: StoredColor(from: editingSessionTaskColor),
                startTime: editingSessionStartTime,
                duration: editingSessionEndTime.timeIntervalSince(editingSessionStartTime),
                activityType: editingSessionActivityType,
                sessionDescription: editingSessionDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                subActivityIDs: validSubActivityIDs(for: editingSessionActivityType),
                priority: editingSessionPriority
            )
        )

        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        saveData()
        editingSessionID = nil
        isAddingManualSession = false
        editingSessionDescription = ""
        editingSessionSubActivityIDs = []
    }

    func openAddTaskSheet() {
        newTaskName = ""
        newTaskColor = randomTaskColor().color
        newTaskDescription = ""
        newTaskType = nil
        newTaskPriority = nil
        newTaskEmoji = ""
        isAddingTask = true
    }

    func closeAddTaskSheet() {
        isAddingTask = false
    }

    func openTaskPicker() {
        guard isViewingToday, state == .stopped else { return }

        isShowingTaskPicker = true
    }

    func closeTaskPicker() {
        isShowingTaskPicker = false
    }

    func openManualSessionTaskPicker() {
        isShowingManualSessionTaskPicker = true
    }

    func closeManualSessionTaskPicker() {
        isShowingManualSessionTaskPicker = false
    }

    func openManualSessionEditor(for task: TaskItem) {
        let dayStart = Calendar.current.startOfDay(for: selectedDay)
        let defaultEnd = Calendar.current.date(byAdding: .hour, value: 1, to: dayStart) ?? dayStart

        editingSessionID = nil
        selectedSessionID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        editingSessionTaskName = task.name
        editingSessionTaskColor = task.color.color
        editingSessionActivityType = task.activityType
        editingSessionPriority = task.priority
        editingSessionStartTime = dayStart
        editingSessionEndTime = defaultEnd
        editingSessionDescription = ""
        editingSessionSubActivityIDs = []
        isAddingManualSession = true
        closeManualSessionTaskPicker()
    }

    func prepareToStart() -> Bool {
        guard state == .stopped else { return false }
        guard isViewingToday else { return false }
        guard selectedTask != nil else {
            openTaskPicker()
            return false
        }

        return start()
    }

    /// "Continue Without Selecting an Activity" — marks an ephemeral, unlisted `TaskItem`
    /// carrying just the chosen type (and priority, for Pain/Pleasure) as selected, without
    /// starting the timer yet. This mirrors `selectTask(_:)` exactly: pair with
    /// `evaluateGeneralPostSelectionToDoGate` and eventually `beginTrackingSelectedTask()`,
    /// same as a specific activity goes through `evaluatePostSelectionToDoGate`. Once tracking
    /// does begin, the saved session ends up identical in shape to any other (see
    /// `stopAndSave`/`sessionItems`), just tagged with a name that never matches a real
    /// activity — e.g. "Pain (No Activity)" — so history, Statistics, and the Life Chart can
    /// tell it apart from a linked activity's sessions at a glance.
    @discardableResult
    func prepareUnlinkedActivitySelection(type: ActivityType, priority: ActivityPriority?) -> Bool {
        guard state == .stopped, isViewingToday else { return false }

        let resolvedPriority = type.hasPriorityTiers ? (priority ?? .medium) : nil
        let task = TaskItem(
            name: "\(type.title) (No Activity)",
            color: StoredColor(from: type.pickerAccentColor),
            activityType: type,
            priority: resolvedPriority
        )

        guard hasFuelAvailableToStart(task) else {
            showNoFuelAlert(for: task.activityType, priority: task.priority)
            return false
        }

        resetCurrentTracking()
        unlinkedTrackingTask = task
        selectedTaskID = task.id
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil

        return true
    }

    /// Marks `task` as selected without starting the timer — used when further user input
    /// (a To-Do task pick, or the "no tasks yet" decision) must happen before tracking begins.
    /// Pair with `beginTrackingSelectedTask()` once that input is resolved.
    @discardableResult
    func selectTask(_ task: TaskItem) -> Bool {
        guard state == .stopped, isViewingToday else { return false }
        guard hasFuelAvailableToStart(task) else {
            closeTaskPicker()
            showNoFuelAlert(for: task.activityType, priority: task.priority)
            return false
        }

        moveTaskToFront(task.id)
        selectedTaskID = task.id
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        resetCurrentTracking()
        closeTaskPicker()
        return true
    }

    @discardableResult
    func beginTrackingSelectedTask() -> Bool {
        guard selectedTaskID != nil else { return false }
        // Already tracking (e.g. the user is just re-assigning the current session's To-Do
        // task mid-session) — nothing to start, and starting again would reset the timer.
        guard state == .stopped else { return true }
        guard start() else {
            selectedTaskID = nil
            return false
        }

        return true
    }

    @discardableResult
    func selectTaskAndStart(_ task: TaskItem) -> Bool {
        guard selectTask(task) else { return false }
        return beginTrackingSelectedTask()
    }

    func selectSession(_ session: SessionItem) {
        selectedSessionID = session.id
    }

    func clearSessionSelection() {
        selectedSessionID = nil
        if !isViewingToday {
            selectedReviewTaskName = nil
            highlightedReviewSessionIDs = []
        }
    }

    func openHistoryPicker() {
        isShowingHistoryPicker = true
    }

    func closeHistoryPicker() {
        isShowingHistoryPicker = false
    }

    func selectHistoryDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
        selectedSessionID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        closeHistoryPicker()
    }

    func selectToday() {
        selectedDay = Calendar.current.startOfDay(for: now)
        selectedSessionID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        closeHistoryPicker()
    }

    func moveSelectedDay(by dayOffset: Int) {
        guard let proposedDay = Calendar.current.date(byAdding: .day, value: dayOffset, to: selectedDay) else {
            return
        }

        let today = Calendar.current.startOfDay(for: now)
        let clampedDay = min(Calendar.current.startOfDay(for: proposedDay), today)
        selectedDay = clampedDay
        selectedSessionID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
    }

    func updateEditingTaskName(_ name: String) {
        guard let editingIndex else { return }

        tasks[editingIndex].name = name
        saveData()
        syncLiveActivityIfNeeded()
    }

    func updateEditingTaskColor(_ color: Color) {
        guard let editingIndex else { return }

        tasks[editingIndex].color = StoredColor(from: color)
        saveData()
        syncLiveActivityIfNeeded()
    }

    func updateEditingTaskDescription(_ description: String) {
        guard let editingIndex else { return }

        tasks[editingIndex].description = description
        saveData()
    }

    func updateEditingTaskType(_ activityType: ActivityType) {
        guard let editingIndex else { return }

        tasks[editingIndex].activityType = activityType
        if activityType.hasPriorityTiers {
            if tasks[editingIndex].priority == nil {
                tasks[editingIndex].priority = .medium
            }
        } else {
            tasks[editingIndex].priority = nil
        }
        saveData()
        syncLiveActivityIfNeeded()
    }

    func updateEditingTaskPriority(_ priority: ActivityPriority?) {
        guard let editingIndex else { return }

        tasks[editingIndex].priority = priority
        saveData()
        syncLiveActivityIfNeeded()
    }

    func updateEditingTaskEmoji(_ emoji: String) {
        guard let editingIndex else { return }

        tasks[editingIndex].emoji = emoji
        saveData()
        syncLiveActivityIfNeeded()
    }

    @discardableResult
    func start() -> Bool {
        guard let selectedTaskID, let selectedTask else { return false }
        guard hasFuelAvailableToStart(selectedTask) else {
            showNoFuelAlert(for: selectedTask.activityType, priority: selectedTask.priority)
            return false
        }

        selectedSessionID = nil
        markTaskInteraction(selectedTaskID)

        let date = Date()
        startTime = date
        runningStartTime = date
        elapsedBeforePause = 0
        completedActiveIntervals = []
        state = .running
        persistActiveTrackingState()
        syncLiveActivityIfNeeded()
        return true
    }

    func pause() {
        guard state == .running else { return }

        let pauseDate = Date()
        if let runningStartTime {
            elapsedBeforePause += pauseDate.timeIntervalSince(runningStartTime)
            if pauseDate > runningStartTime {
                completedActiveIntervals.append(
                    ActiveTrackingInterval(start: runningStartTime, end: pauseDate)
                )
            }
        }

        runningStartTime = nil
        state = .paused
        persistActiveTrackingState()
        syncLiveActivityIfNeeded()
    }

    @discardableResult
    func resume() -> Bool {
        guard state == .paused else { return false }
        guard let selectedTask else { return false }
        guard hasFuelAvailableToResume(selectedTask) else {
            finishCurrentSessionAtFuelLimit(for: selectedTask)
            return false
        }

        runningStartTime = Date()
        state = .running
        persistActiveTrackingState()
        syncLiveActivityIfNeeded()
        return true
    }

    @discardableResult
    func togglePauseResume() -> Bool {
        if state == .running {
            pause()
            return true
        }

        return resume()
    }

    func stopAndSave() {
        guard let selectedTask, let startTime else {
            resetCurrentTracking()
            return
        }

        let intervals = activeIntervalsForSaving(endingAt: Date())
        let allowedDuration = remainingFuelToday(for: selectedTask.activityType, priority: selectedTask.priority ?? .medium)
        let clippedIntervals = clippedActiveIntervals(intervals, maxDuration: allowedDuration)
        let savedSessions = sessionItems(
            from: clippedIntervals,
            task: selectedTask,
            completedTasks: currentSessionCompletedTasks
        )

        if savedSessions.isEmpty, intervals.isEmpty, elapsed > 0 {
            sessions.append(
                SessionItem(
                    taskName: selectedTask.name,
                    color: selectedTask.color,
                    startTime: startTime,
                    duration: max(elapsed, 1),
                    activityType: selectedTask.activityType,
                    priority: selectedTask.priority,
                    completedTasks: currentSessionCompletedTasks
                )
            )
        } else {
            sessions.append(contentsOf: savedSessions)
        }

        saveData()
        resetCurrentTracking()
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
    }

    func addTask() {
        let trimmed = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let trimmedDescription = newTaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = TaskItem(
            name: trimmed,
            color: StoredColor(from: newTaskColor),
            description: trimmedDescription,
            activityType: newTaskType ?? .none,
            priority: newTaskPriority,
            emoji: newTaskEmoji
        )

        tasks.insert(task, at: 0)
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        newTaskName = ""
        newTaskColor = randomTaskColor().color
        newTaskDescription = ""
        newTaskType = nil
        newTaskPriority = nil
        newTaskEmoji = ""
        resetCurrentTracking()
        saveData()
        closeAddTaskSheet()
    }

    func deleteTask(_ task: TaskItem) {
        tasks.removeAll { $0.id == task.id }

        if editingTaskID == task.id {
            editingTaskID = nil
        }

        if selectedTaskID == task.id {
            selectedTaskID = nil
            resetCurrentTracking()
        } else {
            ensureValidSelectedTask()
        }

        saveData()
    }

    func deleteEditingTask() {
        guard let editingTask else {
            closeTaskEditor()
            return
        }

        deleteTask(editingTask)
    }

    func deleteSelectedSession() {
        guard let selectedSessionID else { return }

        sessions.removeAll { $0.id == selectedSessionID }
        self.selectedSessionID = nil
        if editingSessionID == selectedSessionID {
            editingSessionID = nil
        }
        saveData()
    }

    func deleteEditingSession() {
        guard let editingSessionID else {
            closeSessionEditor()
            return
        }

        sessions.removeAll { $0.id == editingSessionID }
        saveData()
        closeSessionEditor()
    }

    private func resetCurrentTracking() {
        state = .stopped
        startTime = nil
        runningStartTime = nil
        elapsedBeforePause = 0
        completedActiveIntervals = []
        currentSessionToDoItemID = nil
        currentSessionCompletedTasks = []
        unlinkedTrackingTask = nil
        TimeCircleStorage.clearActiveTrackingState()
        endLiveActivity()
    }

    private func randomTaskColor() -> StoredColor {
        let colors: [StoredColor] = [.red, .blue, .green, .orange, .purple, .pink]
        return colors.randomElement() ?? .blue
    }

    private var editingIndex: Int? {
        guard let editingTaskID else { return nil }
        return tasks.indices.first { tasks[$0].id == editingTaskID }
    }

    private var editingSessionIndex: Int? {
        guard let editingSessionID else { return nil }
        return sessions.indices.first { sessions[$0].id == editingSessionID }
    }

    private func removeClosedSessionFromReviewHighlights(_ sessionID: UUID?) {
        guard let sessionID else {
            if highlightedReviewSessionIDs.isEmpty {
                selectedReviewTaskName = nil
            }
            return
        }

        var remainingSessionIDs = highlightedReviewSessionIDs
        remainingSessionIDs.remove(sessionID)
        highlightedReviewSessionIDs = remainingSessionIDs

        if remainingSessionIDs.isEmpty {
            selectedReviewTaskName = nil
        }
    }

    private var selectedDayInterval: DateInterval {
        Calendar.current.dateInterval(of: .day, for: selectedDay)
            ?? DateInterval(start: selectedDay, duration: 86_400)
    }

    private func totalTrackedTime(in interval: DateInterval?) -> TimeInterval {
        guard let interval else { return 0 }

        return clippedSessions(overlapping: interval)
            .reduce(0) { $0 + $1.duration }
    }

    private func trackedTime(for activityType: ActivityType, in interval: DateInterval?) -> TimeInterval {
        guard let interval else { return 0 }

        return clippedSessions(overlapping: interval)
            .filter { currentActivityType(for: $0) == activityType }
            .reduce(0) { $0 + $1.duration }
    }

    /// Sessions never own timers — the priority owns the timer, shared across every activity
    /// of that (type, priority) combination regardless of which activity/session recorded it.
    private func trackedTime(for activityType: ActivityType, priority: ActivityPriority, in interval: DateInterval?) -> TimeInterval {
        guard let interval else { return 0 }

        return clippedSessions(overlapping: interval)
            .filter { currentActivityType(for: $0) == activityType && currentPriority(for: $0) == priority }
            .reduce(0) { $0 + $1.duration }
    }

    /// One chunk of Pain tracking time today, tagged with the priority it was tracked under,
    /// used to walk today's Pain activity in chronological order for the borrowing cascade below.
    private struct PainTimeChunk {
        let priority: ActivityPriority
        let start: Date
        let duration: TimeInterval
    }

    private func painChunksToday() -> [PainTimeChunk] {
        guard let interval = elapsedTodayInterval else { return [] }

        var chunks = clippedSessions(overlapping: interval).compactMap { session -> PainTimeChunk? in
            guard currentActivityType(for: session) == .pain, let priority = currentPriority(for: session) else { return nil }

            return PainTimeChunk(priority: priority, start: session.startTime, duration: session.duration)
        }

        if state == .running, let selectedTask, selectedTask.activityType == .pain {
            let priority = selectedTask.priority ?? .medium

            for activeInterval in activeIntervalsForSaving(endingAt: now) {
                let clippedStart = max(activeInterval.start, interval.start)
                let clippedEnd = min(activeInterval.end, interval.end)
                guard clippedEnd > clippedStart else { continue }

                chunks.append(PainTimeChunk(priority: priority, start: clippedStart, duration: clippedEnd.timeIntervalSince(clippedStart)))
            }
        }

        return chunks.sorted { $0.start < $1.start }
    }

    /// Simulates today's Pain tracking, in chronological order, against the borrowing cascade:
    /// High spends its own 2h, then draws from Low, then from Medium, then spills to Pleasure.
    /// Medium spends its own 2h, then draws from Low, then spills straight to Pleasure (never
    /// from High). Low spends its own 2h, then spills straight to Pleasure. Because Low/Medium
    /// are shared reservoirs, whichever priority's overage happens first in real time claims
    /// whatever headroom is left in them — hence the chronological walk rather than a flat sum.
    private func painCascadeSpilloverToPleasureToday() -> TimeInterval {
        var remainingLow = ActivityPriority.low.dailyBudgetDuration
        var remainingMedium = ActivityPriority.medium.dailyBudgetDuration
        var remainingHigh = ActivityPriority.high.dailyBudgetDuration
        var spillover: TimeInterval = 0

        for chunk in painChunksToday() {
            var leftover = chunk.duration

            switch chunk.priority {
            case .high:
                let ownTake = min(leftover, remainingHigh); remainingHigh -= ownTake; leftover -= ownTake
                let lowTake = min(leftover, remainingLow); remainingLow -= lowTake; leftover -= lowTake
                let mediumTake = min(leftover, remainingMedium); remainingMedium -= mediumTake; leftover -= mediumTake
            case .medium:
                let ownTake = min(leftover, remainingMedium); remainingMedium -= ownTake; leftover -= ownTake
                let lowTake = min(leftover, remainingLow); remainingLow -= lowTake; leftover -= lowTake
            case .low:
                let ownTake = min(leftover, remainingLow); remainingLow -= ownTake; leftover -= ownTake
            }

            spillover += leftover
        }

        return spillover
    }

    /// Neutral never blocks (see `hasFuelAvailableToStart`); once it runs past its own 12h it
    /// spills the excess into Pleasure's pool, the same way Pain's overage does.
    private func neutralSpilloverToPleasureToday() -> TimeInterval {
        let trackedDuration = trackedTime(for: .none, in: elapsedTodayInterval)
        return max(trackedDuration - ActivityType.none.totalDailyBudgetDuration, 0)
    }

    private func totalOverageBorrowedFromPleasureToday() -> TimeInterval {
        painCascadeSpilloverToPleasureToday() + neutralSpilloverToPleasureToday()
    }

    /// Pain and Neutral: never blocked — Pain's priorities cascade through Low → Medium →
    /// Pleasure (see `painCascadeSpilloverToPleasureToday`), and Neutral spills straight to
    /// Pleasure once its own 12h is spent. Both go negative to represent overage rather than
    /// clamping at zero. Pleasure is the one pool that still clamps at zero and stays blocked
    /// once exhausted — it's the final sink everything else borrows against.
    private func remainingFuelToday(for activityType: ActivityType, priority: ActivityPriority) -> TimeInterval {
        switch activityType {
        case .pain:
            let trackedDuration = trackedTime(for: activityType, priority: priority, in: elapsedTodayInterval)
            return priority.dailyBudgetDuration - trackedDuration
        case .none:
            let trackedDuration = trackedTime(for: activityType, in: elapsedTodayInterval)
            return activityType.totalDailyBudgetDuration - trackedDuration
        case .pleasure:
            let trackedDuration = trackedTime(for: activityType, in: elapsedTodayInterval)
            let effectiveBudget = activityType.totalDailyBudgetDuration - totalOverageBorrowedFromPleasureToday()
            return max(effectiveBudget - trackedDuration, 0)
        }
    }

    private func hasFuelAvailableToStart(_ task: TaskItem) -> Bool {
        guard task.activityType != .pain, task.activityType != .none else { return true }

        return remainingFuelToday(for: task.activityType, priority: task.priority ?? .medium) > 0
    }

    private func hasFuelAvailableToResume(_ task: TaskItem) -> Bool {
        guard task.activityType != .pain, task.activityType != .none else { return true }

        return elapsed < remainingFuelToday(for: task.activityType, priority: task.priority ?? .medium)
    }

    private func enforceFuelLimitIfNeeded() {
        guard state == .running,
              let selectedTask,
              selectedTask.activityType != .pain,
              selectedTask.activityType != .none,
              elapsed >= remainingFuelToday(for: selectedTask.activityType, priority: selectedTask.priority ?? .medium)
        else { return }

        finishCurrentSessionAtFuelLimit(for: selectedTask)
    }

    private func finishCurrentSessionAtFuelLimit(for task: TaskItem) {
        let allowedDuration = remainingFuelToday(for: task.activityType, priority: task.priority ?? .medium)
        let clippedIntervals = clippedActiveIntervals(
            activeIntervalsForSaving(endingAt: now),
            maxDuration: allowedDuration
        )
        let savedSessions = sessionItems(from: clippedIntervals, task: task, completedTasks: currentSessionCompletedTasks)

        if !savedSessions.isEmpty {
            sessions.append(contentsOf: savedSessions)
            saveData()
        }

        resetCurrentTracking()
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        showNoFuelAlert(for: task.activityType, priority: task.priority)
    }

    private func showNoFuelAlert(for activityType: ActivityType, priority: ActivityPriority?) {
        let priorityLabel = (activityType == .pain) ? priority.map { " (\($0.title))" } ?? "" : ""
        noFuelAlertMessage = "You’ve used all your \(activityType.title)\(priorityLabel) time for today."
        isShowingNoFuelAlert = true
    }

    private func activeIntervalsForSaving(endingAt endDate: Date) -> [ActiveTrackingInterval] {
        var intervals = completedActiveIntervals.filter { $0.end > $0.start }

        if state == .running, let runningStartTime {
            let intervalEnd = max(endDate, runningStartTime)
            if intervalEnd > runningStartTime {
                intervals.append(ActiveTrackingInterval(start: runningStartTime, end: intervalEnd))
            }
        }

        return intervals.sorted { $0.start < $1.start }
    }

    private func clippedActiveIntervals(
        _ intervals: [ActiveTrackingInterval],
        maxDuration: TimeInterval
    ) -> [ActiveTrackingInterval] {
        guard maxDuration > 0 else { return [] }

        var remainingDuration = maxDuration
        var clippedIntervals: [ActiveTrackingInterval] = []

        for interval in intervals where remainingDuration > 0 {
            let intervalDuration = interval.end.timeIntervalSince(interval.start)
            guard intervalDuration > 0 else { continue }

            let clippedDuration = min(intervalDuration, remainingDuration)
            let clippedEnd = interval.start.addingTimeInterval(clippedDuration)
            if clippedEnd > interval.start {
                clippedIntervals.append(ActiveTrackingInterval(start: interval.start, end: clippedEnd))
            }
            remainingDuration -= clippedDuration
        }

        return clippedIntervals
    }

    private func sessionItems(
        from intervals: [ActiveTrackingInterval],
        task: TaskItem,
        completedTasks: [CompletedTaskSnapshot] = []
    ) -> [SessionItem] {
        intervals.compactMap { interval in
            let duration = interval.end.timeIntervalSince(interval.start)
            guard duration > 0 else { return nil }

            return SessionItem(
                taskName: task.name,
                color: task.color,
                startTime: interval.start,
                duration: max(duration, 1),
                activityType: task.activityType,
                priority: task.priority,
                completedTasks: completedTasks
            )
        }
    }

    /// Negative return values represent overage — Pain is allowed to run past its budget, and
    /// the caller (the ring's center countdown) formats a negative value with a "+" prefix.
    /// Pleasure still clamps at zero (see `remainingFuelToday`).
    private func targetBalanceToday(for activityType: ActivityType, priority: ActivityPriority, runningElapsed: TimeInterval) -> TimeInterval {
        switch activityType {
        case .pain:
            let totalTrackedTime = trackedTime(for: activityType, priority: priority, in: elapsedTodayInterval) + runningElapsed
            return priority.dailyBudgetDuration - totalTrackedTime
        case .none:
            let totalTrackedTime = trackedTime(for: activityType, in: elapsedTodayInterval) + runningElapsed
            return activityType.totalDailyBudgetDuration - totalTrackedTime
        case .pleasure:
            let totalTrackedTime = trackedTime(for: activityType, in: elapsedTodayInterval) + runningElapsed
            let effectiveBudget = activityType.totalDailyBudgetDuration - totalOverageBorrowedFromPleasureToday()
            return max(effectiveBudget - totalTrackedTime, 0)
        }
    }

    private var elapsedTodayInterval: DateInterval? {
        guard let dayInterval = Calendar.current.dateInterval(of: .day, for: now) else { return nil }

        return DateInterval(start: dayInterval.start, end: min(now, dayInterval.end))
    }

    private func clippedSessions(overlapping interval: DateInterval) -> [SessionItem] {
        sessions.compactMap { clippedSession($0, to: interval) }
    }

    private func clippedSession(_ session: SessionItem, to interval: DateInterval) -> SessionItem? {
        let clippedStart = max(session.startTime, interval.start)
        let clippedEnd = min(session.endTime, interval.end)
        guard clippedEnd > clippedStart else { return nil }

        return SessionItem(
            id: session.id,
            taskName: session.taskName,
            color: session.color,
            startTime: clippedStart,
            duration: clippedEnd.timeIntervalSince(clippedStart),
            activityType: session.activityType,
            sessionDescription: session.sessionDescription,
            subActivityIDs: session.subActivityIDs,
            priority: session.priority
        )
    }

    private func currentActivityType(for session: SessionItem) -> ActivityType {
        tasks.first { $0.name == session.taskName }?.activityType ?? session.activityType
    }

    private func currentPriority(for session: SessionItem) -> ActivityPriority? {
        tasks.first { $0.name == session.taskName }?.priority ?? session.priority
    }

    private func sessionWithCurrentActivityType(_ session: SessionItem) -> SessionItem {
        SessionItem(
            id: session.id,
            taskName: session.taskName,
            color: session.color,
            startTime: session.startTime,
            duration: session.duration,
            activityType: currentActivityType(for: session),
            sessionDescription: session.sessionDescription,
            subActivityIDs: session.subActivityIDs,
            priority: currentPriority(for: session)
        )
    }

    private func daysOverlapped(by session: SessionItem) -> [Date] {
        guard session.endTime > session.startTime else { return [] }

        var days: [Date] = []
        var day = Calendar.current.startOfDay(for: session.startTime)

        while day < session.endTime {
            if let dayInterval = Calendar.current.dateInterval(of: .day, for: day),
               clippedSession(session, to: dayInterval) != nil {
                days.append(day)
            }

            guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return days
    }

    private func latestSelectedDayUseByTaskName() -> [String: Date] {
        var latestUseByTaskName: [String: Date] = [:]

        for session in selectedDaySessions {
            let sessionEndTime = session.endTime
            latestUseByTaskName[session.taskName] = max(
                latestUseByTaskName[session.taskName] ?? session.startTime,
                sessionEndTime
            )
        }

        if let selectedTask, let startTime, isViewingToday, state != .stopped {
            latestUseByTaskName[selectedTask.name] = max(
                latestUseByTaskName[selectedTask.name] ?? startTime,
                now
            )
        }

        return latestUseByTaskName
    }

    private func ensureValidSelectedTask() {
        // An unlinked ("Continue Without Selecting an Activity") session's task is deliberately
        // never added to `tasks` — that's what keeps it out of every activity picker — so it
        // must never be treated as "missing" just because it can't be found there.
        guard unlinkedTrackingTask == nil else { return }
        guard let selectedTaskID else { return }

        if !tasks.contains(where: { $0.id == selectedTaskID }) {
            self.selectedTaskID = nil
            resetCurrentTracking()
        }
    }

    private func ensureValidActiveTrackingState() {
        guard state != .stopped else { return }
        guard unlinkedTrackingTask == nil else { return }
        guard let selectedTaskID,
              tasks.contains(where: { $0.id == selectedTaskID })
        else {
            self.selectedTaskID = nil
            resetCurrentTracking()
            return
        }
    }

    private func moveTaskToFront(_ taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }), index != 0 else { return }

        let task = tasks.remove(at: index)
        tasks.insert(task, at: 0)
        saveData()
    }

    private func validSubActivityIDs(for mainActivityType: ActivityType) -> [UUID] {
        let allowedIDs = Set(
            tasks
                .filter { isSubActivity($0, allowedFor: mainActivityType) }
                .map(\.id)
        )

        return editingSessionSubActivityIDs.filter { allowedIDs.contains($0) }
    }

    private func isSubActivity(_ task: TaskItem, allowedFor mainActivityType: ActivityType) -> Bool {
        switch mainActivityType {
        case .pain:
            return task.activityType == .pain
        case .pleasure:
            return task.activityType == .pleasure
        case .none:
            return task.activityType == .pain || task.activityType == .pleasure
        }
    }

    private func markTaskInteraction(_ taskID: UUID) {
        guard isViewingToday else { return }

        recentTaskInteractionDates[taskID] = Date()
        TimeCircleStorage.save(recentTaskInteractionDates: recentTaskInteractionDates)
    }

    private func saveData() {
        TimeCircleStorage.save(tasks: tasks, sessions: sessions)
    }

    private func saveToDoItems() {
        TimeCircleStorage.save(toDoItems: toDoItems)
    }

    /// Backfills any missing occurrences for recurring tasks, from the day after each
    /// series' latest known occurrence up through today. Runs at most once per calendar
    /// day (cheap no-op otherwise), from `loadData`, `appDidBecomeActive`, and each
    /// `updateCurrentTime` tick, so a recurring task's next occurrence appears the moment
    /// its weekday arrives — even if the app was closed over one or more of them.
    ///
    /// Only the series' latest occurrence (by `day`) is read for its `recurringWeekdays` —
    /// so editing an older occurrence's schedule never rewrites or affects history, and a
    /// series stops generating the moment its latest occurrence's schedule is cleared.
    private func generateDueRecurringToDoOccurrences() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        guard lastRecurringToDoGenerationDay != today else { return }
        lastRecurringToDoGenerationDay = today

        let seriesGroups = Dictionary(grouping: toDoItems.compactMap { item in
            item.recurrenceGroupID.map { (groupID: $0, item: item) }
        }, by: \.groupID)

        var didGenerate = false

        for (groupID, entries) in seriesGroups {
            guard let latest = entries.map(\.item).max(by: { $0.day < $1.day }) else { continue }
            guard !latest.recurringWeekdays.isEmpty else { continue }

            var cursorDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: latest.day)) ?? today
            while cursorDay <= today {
                defer { cursorDay = calendar.date(byAdding: .day, value: 1, to: cursorDay) ?? today.addingTimeInterval(86_400) }

                let weekday = calendar.component(.weekday, from: cursorDay)
                guard latest.recurringWeekdays.contains(weekday) else { continue }

                let alreadyExists = toDoItems.contains {
                    $0.recurrenceGroupID == groupID && calendar.isDate($0.day, inSameDayAs: cursorDay)
                }
                guard !alreadyExists else { continue }

                let nextSortOrder = (toDoItems
                    .filter { calendar.isDate($0.day, inSameDayAs: cursorDay) }
                    .map(\.sortOrder)
                    .max() ?? -1) + 1

                let occurrence = ToDoItem(
                    title: latest.title,
                    activityTaskID: latest.activityTaskID,
                    activityType: latest.activityType,
                    manualPriority: latest.manualPriority,
                    day: cursorDay,
                    sortOrder: nextSortOrder,
                    subtasks: latest.subtasks.map { SubtaskItem(title: $0.title, sortOrder: $0.sortOrder) },
                    recurringWeekdays: latest.recurringWeekdays,
                    recurrenceGroupID: groupID,
                    // The description is task-level and carries forward; notes are
                    // day-specific, so each new occurrence starts with none.
                    taskDescription: latest.taskDescription
                )
                toDoItems.append(occurrence)
                didGenerate = true
            }
        }

        if didGenerate {
            saveToDoItems()
        }
    }

    private func saveDismissedNoToDoTasksPromptTaskIDs() {
        TimeCircleStorage.save(dismissedNoToDoTasksPromptTaskIDs: dismissedNoToDoTasksPromptTaskIDs)
    }

    private func saveExpenses() {
        TimeCircleStorage.save(expenses: expenses)
    }

    private func saveExpenseIntentionPreferences() {
        TimeCircleStorage.save(expenseIntentionPreferences: expenseIntentionPreferences)
    }

    private func saveTotalBudget() {
        TimeCircleStorage.save(totalBudget: totalBudget)
    }

    var expensesByDateDescending: [ExpenseItem] {
        expenses.sorted { $0.date > $1.date }
    }

    var expensesForSelectedDay: [ExpenseItem] {
        expenses
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    var totalSpentForSelectedDay: Double {
        expensesForSelectedDay.reduce(0) { $0 + $1.amount }
    }

    /// Recent expenses offered for Quick Fill, newest first and de-duplicated by title (keeping
    /// each title's most recent occurrence) — this is meant to surface recurring expenses like
    /// "Coffee" or "Taxi" once each, not repeat the same title many times over.
    var recentExpensesForQuickFill: [ExpenseItem] {
        var seenTitles = Set<String>()
        var result: [ExpenseItem] = []

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let key = expense.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty, !seenTitles.contains(key) else { continue }
            seenTitles.insert(key)
            result.append(expense)
            if result.count >= 8 { break }
        }

        return result
    }

    /// With nothing left in the available budget, any new expense would be entirely uncovered —
    /// straight to Add Debt instead, so the user never fills out the same details twice only to
    /// have `saveExpenseForm` redirect them there anyway after the fact.
    func openAddExpenseSheet() {
        guard budgetForSelectedDay > 0 else {
            openAddDebtSheet()
            return
        }

        editingExpenseID = nil
        newExpenseTitle = ""
        newExpenseMerchant = ""
        newExpenseAmountText = ""
        newExpenseEmoji = ExpenseItem.defaultEmoji
        newExpenseDate = isViewingToday ? Date() : selectedDay
        newExpenseNotes = ""
        newExpenseIntention = ""
        newExpenseIntentionDoNotShowAgain = false
        isShowingAddExpense = true
    }

    func openEditExpenseSheet(_ expense: ExpenseItem) {
        editingExpenseID = expense.id
        newExpenseTitle = expense.title
        newExpenseMerchant = expense.merchant
        newExpenseAmountText = String(format: "%.2f", expense.amount)
        newExpenseEmoji = expense.emoji
        newExpenseDate = expense.date
        newExpenseNotes = expense.notes
        newExpenseIntention = expense.intention
        newExpenseIntentionDoNotShowAgain = expenseIntentionPreference(forTitle: expense.title)?.doNotShowAgain ?? false
        isShowingAddExpense = true
    }

    private func normalizedIntentionKey(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The remembered "do not show again" choice for a given expense title, if any — used to
    /// decide whether the new-expense confirmation step should appear at all for this specific
    /// title, keyed the same way Recent Expenses already dedupes by title.
    func expenseIntentionPreference(forTitle title: String) -> IntentionPreference? {
        expenseIntentionPreferences[normalizedIntentionKey(title)]
    }

    func debtIntentionPreference(forTitle title: String) -> IntentionPreference? {
        debtIntentionPreferences[normalizedIntentionKey(title)]
    }

    func closeAddExpenseSheet() {
        isShowingAddExpense = false
        editingExpenseID = nil
    }

    /// Fills the emoji, title, amount, and merchant from a recent expense — but never the date,
    /// which always stays whatever the form's currently selected date already is.
    func quickFillExpenseForm(from expense: ExpenseItem) {
        newExpenseEmoji = expense.emoji
        newExpenseTitle = expense.title
        newExpenseMerchant = expense.merchant
        newExpenseAmountText = String(format: "%.2f", expense.amount)
    }

    /// An expense can never push the available budget negative. The portion the budget can
    /// actually cover is what gets stored as the expense; anything beyond that becomes a linked
    /// automatic debt (see `DebtItem.linkedExpenseID`) for the uncovered remainder, left unpaid
    /// and folded into the existing debt carry-forward/budget system unchanged from there on.
    ///
    /// Editing re-derives both numbers from scratch: the old expense and its old linked debt (if
    /// any) are removed first, so `availableBudget(asOf:)` reflects what's available as if this
    /// expense didn't exist yet — exactly what "how much of the new amount is covered" needs to
    /// be measured against. This is what keeps the expense and its automatic debt synchronized
    /// on every edit rather than drifting apart.
    func saveExpenseForm() {
        let trimmedTitle = newExpenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let amount = Double(newExpenseAmountText), amount > 0 else { return }

        let trimmedMerchant = newExpenseMerchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmoji = newExpenseEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = trimmedEmoji.isEmpty ? ExpenseItem.defaultEmoji : trimmedEmoji
        let trimmedNotes = newExpenseNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        let isNewExpense = editingExpenseID == nil
        let expenseID = editingExpenseID ?? UUID()

        if let editingExpenseID {
            expenses.removeAll { $0.id == editingExpenseID }
            debts.removeAll { $0.linkedExpenseID == editingExpenseID }
        }

        let budgetBeforeThisExpense = max(availableBudget(asOf: newExpenseDate), 0)

        // A brand-new expense when there's nothing left to cover isn't a partial-coverage case —
        // there's no expense to record at all. Redirect the whole entry over to Add Debt instead.
        if isNewExpense && budgetBeforeThisExpense <= 0 {
            redirectExpenseFormToDebt(title: trimmedTitle, amountText: newExpenseAmountText, date: newExpenseDate, notes: trimmedNotes)
            return
        }

        let coveredAmount = min(amount, budgetBeforeThisExpense)
        let uncoveredAmount = amount - coveredAmount

        // The Edit Expense screen exposes the same intention/"do not show again" fields the new-
        // expense confirmation step writes, so both paths read from (and update) the exact same
        // published fields and the same preference dictionary — editing these here changes what
        // the confirmation step does the next time this title comes up, with no separate storage.
        let trimmedIntention = newExpenseIntention.trimmingCharacters(in: .whitespacesAndNewlines)
        expenseIntentionPreferences[normalizedIntentionKey(trimmedTitle)] = IntentionPreference(
            intention: trimmedIntention,
            doNotShowAgain: newExpenseIntentionDoNotShowAgain
        )
        saveExpenseIntentionPreferences()

        expenses.append(
            ExpenseItem(
                id: expenseID,
                title: trimmedTitle,
                merchant: trimmedMerchant,
                amount: coveredAmount,
                emoji: emoji,
                date: newExpenseDate,
                notes: trimmedNotes,
                intention: trimmedIntention
            )
        )

        if uncoveredAmount > 0 {
            debts.append(
                DebtItem(
                    title: trimmedTitle,
                    amount: uncoveredAmount,
                    debtDate: newExpenseDate,
                    recordedDate: Date(),
                    notes: trimmedNotes,
                    emoji: emoji,
                    merchant: trimmedMerchant,
                    linkedExpenseID: expenseID
                )
            )
        }

        saveExpenses()
        saveDebts()
        isShowingAddExpense = false
        editingExpenseID = nil
    }

    /// Closes Add Expense and opens Add Debt pre-filled with what was just typed, for the "budget
    /// is already 0" case where no expense can be recorded at all.
    private func redirectExpenseFormToDebt(title: String, amountText: String, date: Date, notes: String) {
        isShowingAddExpense = false
        editingExpenseID = nil

        editingDebtID = nil
        newDebtTitle = title
        newDebtAmountText = amountText
        newDebtDate = date
        newDebtNotes = notes
        newDebtIntention = ""
        newDebtIntentionDoNotShowAgain = false
        newDebtIsDateReminderEnabled = false
        newDebtScheduledDate = Date()
        newDebtIsTimeReminderEnabled = false
        newDebtScheduledTime = Date()
        refreshNotificationPermissionStatus()
        isShowingAddDebt = true
    }

    /// Removing the expense record is what restores its covered amount to the budget —
    /// `availableBudget(asOf:)` reads `expenses` live, so there's no separate reversal step. The
    /// linked automatic debt (if any) is removed alongside it via `linkedExpenseID`, which can
    /// only ever match a debt this same expense created — never an unrelated manual one.
    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
        debts.removeAll { $0.linkedExpenseID == id }
        saveExpenses()
        saveDebts()
        isShowingAddExpense = false
        editingExpenseID = nil
    }

    func openEditBudgetSheet() {
        isShowingEditBudget = true
    }

    enum BudgetEditScope {
        /// Updates the selected day's budget; it naturally carries forward to every later day
        /// exactly as any budget change already does. Days before the selected day keep
        /// whichever budget they already had.
        case today
        /// Updates the selected day *and* every day before it, by resetting the root baseline
        /// itself. Later days are unaffected beyond what "today" already changes for them — they
        /// keep carrying forward from the new value the same way they already do.
        case pastAndToday
    }

    /// `newValue` is the intended *available* budget for the day being viewed — the same figure
    /// the Money screen shows and Edit Budget was prefilled with — not the internal baseline.
    ///
    /// - `.today` solves backward for a new baseline value (prevents previously-recorded
    ///   expenses/paid debts from compounding into an unexpectedly low or negative result) and
    ///   records it as a `BudgetBaselineChange` effective from `selectedDay` onward — days before
    ///   it keep using whichever baseline already applied to them.
    /// - `.pastAndToday` does the same backward-solve, but instead clears every baseline change
    ///   on or before `selectedDay` and resets the root `totalBudget` itself. Since the root
    ///   baseline is what every day falls back to in the absence of a more specific change, this
    ///   cascades the same adjustment through every earlier day too — each still computed with
    ///   its own day's expenses/top-ups/paid debts, not flattened to one identical number. Any
    ///   baseline change already scheduled for *after* `selectedDay` is left untouched, so later
    ///   days keep carrying forward exactly as they already do.
    func updateTotalBudget(_ newValue: Double, scope: BudgetEditScope) {
        guard newValue >= 0 else { return }

        let newBaselineValue = newValue - derivedBudgetDelta(asOf: selectedDay)

        switch scope {
        case .today:
            budgetBaselineChanges.removeAll { Calendar.current.isDate($0.effectiveDate, inSameDayAs: selectedDay) }
            budgetBaselineChanges.append(BudgetBaselineChange(effectiveDate: selectedDay, value: newBaselineValue))
        case .pastAndToday:
            let dayStart = Calendar.current.startOfDay(for: selectedDay)
            budgetBaselineChanges.removeAll { Calendar.current.startOfDay(for: $0.effectiveDate) <= dayStart }
            totalBudget = newBaselineValue
            saveTotalBudget()
        }

        saveBudgetBaselineChanges()
    }

    private func saveBudgetBaselineChanges() {
        TimeCircleStorage.save(budgetBaselineChanges: budgetBaselineChanges)
    }

    private func saveDebts() {
        TimeCircleStorage.save(debts: debts)
    }

    private func saveDebtIntentionPreferences() {
        TimeCircleStorage.save(debtIntentionPreferences: debtIntentionPreferences)
    }

    /// A debt's visibility on a given day depends on where that day falls relative to its
    /// `debtDate` and (once paid) its `paidDate` — see `DebtItem`'s own doc comment for the
    /// exact rule. `recordedDate` plays no part here; it's informational only.
    private enum DebtDayStatus {
        case notYetCreated
        case pending
        case paid
        case hidden
    }

    /// An unpaid debt belongs to its `debtDate` and carries forward to every day after — still
    /// owed, still pending. Once marked paid, it stays visible as paid for every day from
    /// `debtDate` through `paidDate` inclusive (a fixed historical window), then disappears on
    /// every later day. Unpaying it again drops that window and resumes carry-forward from
    /// `debtDate` exactly as if it had never been paid.
    private func debtStatus(_ debt: DebtItem, on day: Date) -> DebtDayStatus {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let debtStart = calendar.startOfDay(for: debt.debtDate)

        guard dayStart >= debtStart else { return .notYetCreated }

        guard let paidDate = debt.paidDate else { return .pending }

        let paidStart = calendar.startOfDay(for: paidDate)
        return dayStart <= paidStart ? .paid : .hidden
    }

    var pendingDebtsForSelectedDay: [DebtItem] {
        debts
            .filter { debtStatus($0, on: selectedDay) == .pending }
            .sorted { $0.debtDate < $1.debtDate }
    }

    var paidDebtsForSelectedDay: [DebtItem] {
        debts
            .filter { debtStatus($0, on: selectedDay) == .paid }
            .sorted { $0.debtDate < $1.debtDate }
    }

    /// Not simply the pending list's total: a debt already shown as paid in history can still
    /// have been "still owed" as of `selectedDay` if that day falls before its `paidDate` — the
    /// header needs the amount that was actually outstanding on that day, independent of whether
    /// the row currently renders as pending or paid.
    private func isStillOwed(_ debt: DebtItem, asOf day: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let debtStart = calendar.startOfDay(for: debt.debtDate)

        guard dayStart >= debtStart else { return false }
        guard let paidDate = debt.paidDate else { return true }

        return calendar.startOfDay(for: paidDate) > dayStart
    }

    var totalOwedForSelectedDay: Double {
        debts
            .filter { isStillOwed($0, asOf: selectedDay) }
            .reduce(0) { $0 + $1.amount }
    }

    private func isDateOnOrBefore(_ date: Date, _ day: Date) -> Bool {
        Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: day)
    }

    /// Net effect of every Add Money top-up, expense, and paid debt that had happened by the end
    /// of `day`, relative to `totalBudget`. Pulled out of `availableBudget(asOf:)` so
    /// `updateTotalBudget(_:)` can solve for the baseline that makes a given day's available
    /// budget come out to an exact target value, instead of the two ever disagreeing.
    private func derivedBudgetDelta(asOf day: Date) -> Double {
        let topUpsTotal = moneyTopUps
            .filter { isDateOnOrBefore($0.date, day) }
            .reduce(0) { $0 + $1.amount }

        let expensesTotal = expenses
            .filter { isDateOnOrBefore($0.date, day) }
            .reduce(0) { $0 + $1.amount }

        // Reading straight off the live `debts` array (not a separately-tracked deduction) means
        // a paid debt that's later deleted or unpaid stops counting immediately and automatically
        // — there's no separate "restore the budget" step to forget to run.
        let paidDebtsTotal = debts.reduce(0.0) { partial, debt in
            guard debt.isPaid, let paidDate = debt.paidDate, isDateOnOrBefore(paidDate, day) else {
                return partial
            }
            return partial + debt.amount
        }

        return topUpsTotal - expensesTotal - paidDebtsTotal
    }

    /// The Money system's own start date — there's no budget history before this day, since
    /// nothing was being tracked yet. This is a display-only floor: it affects nothing about how
    /// expenses, debts, or top-ups are stored, only what `availableBudget(asOf:)` reports for a
    /// day that falls before it.
    ///
    /// Derived from the data itself — the earliest date among every top-up, expense, and debt —
    /// rather than a fixed date, since the Money feature's actual start is whenever its first
    /// real record was dated, not a date baked into the code. If there's no dated record at all
    /// yet (a completely fresh install), there's no history to speak of, so today is the floor.
    private var firstMoneyDay: Date {
        let calendar = Calendar.current
        var earliest: Date?

        for date in moneyTopUps.map(\.date) + expenses.map(\.date) + debts.map(\.debtDate) {
            if earliest == nil || date < earliest! {
                earliest = date
            }
        }

        return calendar.startOfDay(for: earliest ?? now)
    }

    /// The baseline in effect for `day`: whichever `BudgetBaselineChange` has the latest
    /// `effectiveDate` on or before `day`, or the original default `totalBudget` if none applies
    /// yet. This is what makes "Apply to Today and All Future Days" shift the budget forward
    /// from that day on without touching how earlier days are computed.
    private func baseline(asOf day: Date) -> Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        let applicable = budgetBaselineChanges
            .filter { calendar.startOfDay(for: $0.effectiveDate) <= dayStart }
            .max { $0.effectiveDate < $1.effectiveDate }

        return applicable?.value ?? totalBudget
    }

    /// The single source of truth for "available budget as of `day`". Every place that shows or
    /// edits the budget (the Money screen's figure and the Edit Budget screen alike) must go
    /// through this same calculation, so they can never disagree. It's recomputed fresh from
    /// source records each time rather than kept as a single mutated running total, so a past
    /// day's value is a stable historical fact that today's activity can't retroactively change.
    ///
    /// Days before `firstMoneyDay` always report 0 — budget history simply doesn't exist yet
    /// that far back, so nothing is reconstructed or carried backwards for them.
    func availableBudget(asOf day: Date) -> Double {
        guard Calendar.current.startOfDay(for: day) >= firstMoneyDay else {
            return 0
        }

        return baseline(asOf: day) + derivedBudgetDelta(asOf: day)
    }

    var budgetForSelectedDay: Double {
        availableBudget(asOf: selectedDay)
    }

    /// Marking a debt paid is only actionable while viewing today — same convention as pending
    /// To-Do items: past and future days show what was/would be true, but you only ever act on
    /// "now". Unchecking a paid debt, though, can't use that same guard: a paid debt is only
    /// ever displayed on its creation date (it doesn't carry forward once paid), so if creation
    /// date isn't today, requiring `isViewingToday` would make the row impossible to interact
    /// with wherever it's actually shown. Uncheck is gated on viewing that creation date instead
    /// — the one day the row exists to be tapped.
    /// Actionable from any day the debt is actually shown for `selectedDay` — pending debts are
    /// visible from creation date onward for as long as they're unpaid, and a paid debt only on
    /// its creation date, so gating on `debtStatus` (rather than a fixed "today" or "creation
    /// date" check) covers both without requiring navigation back to a specific day first.
    func toggleDebtPaid(_ id: UUID) {
        guard let index = debts.firstIndex(where: { $0.id == id }) else { return }

        switch debtStatus(debts[index], on: selectedDay) {
        case .pending:
            debts[index].isPaid = true
            debts[index].paidDate = isViewingToday ? Date() : selectedDay
            DebtReminderManager.cancelReminder(for: debts[index].id)
        case .paid:
            debts[index].isPaid = false
            debts[index].paidDate = nil
            // Re-schedules only if a reminder date/time is actually set and still in the
            // future — `scheduleReminder` itself is a no-op otherwise.
            DebtReminderManager.scheduleReminder(for: debts[index])
        case .notYetCreated, .hidden:
            return
        }

        saveDebts()
    }

    func openAddDebtSheet() {
        editingDebtID = nil
        newDebtTitle = ""
        newDebtAmountText = ""
        newDebtDate = isViewingToday ? Date() : selectedDay
        newDebtNotes = ""
        newDebtIntention = ""
        newDebtIntentionDoNotShowAgain = false
        newDebtIsDateReminderEnabled = false
        newDebtScheduledDate = Date()
        newDebtIsTimeReminderEnabled = false
        newDebtScheduledTime = Date()
        refreshNotificationPermissionStatus()
        isShowingAddDebt = true
    }

    func openEditDebtSheet(_ debt: DebtItem) {
        editingDebtID = debt.id
        newDebtTitle = debt.title
        newDebtAmountText = String(format: "%.2f", debt.amount)
        newDebtDate = debt.debtDate
        newDebtNotes = debt.notes
        newDebtIntention = debt.intention
        newDebtIntentionDoNotShowAgain = debtIntentionPreference(forTitle: debt.title)?.doNotShowAgain ?? false
        newDebtIsDateReminderEnabled = debt.scheduledPaymentDate != nil
        newDebtScheduledDate = debt.scheduledPaymentDate ?? debt.debtDate
        newDebtIsTimeReminderEnabled = debt.scheduledPaymentTime != nil
        newDebtScheduledTime = debt.scheduledPaymentTime ?? Date()
        refreshNotificationPermissionStatus()
        isShowingAddDebt = true
    }

    /// Called when the Date toggle changes. Turning it on seeds the reminder date from the
    /// debt date currently in the form and requests notification permission if not yet asked;
    /// turning it off also turns Time off, since Time can't be enabled without Date.
    func handleDateReminderToggle(_ isOn: Bool) {
        if isOn {
            newDebtScheduledDate = newDebtDate
            requestNotificationPermissionIfNeeded()
        } else {
            newDebtIsTimeReminderEnabled = false
        }
    }

    /// Called when the Time toggle changes. A no-op if Date isn't enabled — the UI disables
    /// this control in that case, but this guards the model too.
    func handleTimeReminderToggle(_ isOn: Bool) {
        guard newDebtIsDateReminderEnabled else {
            newDebtIsTimeReminderEnabled = false
            return
        }

        if isOn {
            newDebtScheduledTime = Date()
            requestNotificationPermissionIfNeeded()
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        DebtReminderManager.requestAuthorizationIfNeeded { [weak self] granted in
            self?.isNotificationPermissionDenied = !granted
        }
    }

    private func refreshNotificationPermissionStatus() {
        DebtReminderManager.isAuthorizationDenied { [weak self] isDenied in
            self?.isNotificationPermissionDenied = isDenied
        }
    }

    /// Read live off `debts` (rather than copied into a separate form field like the other
    /// editable fields) so the Add/Edit Debt screen reflects the paid date immediately after a
    /// paid/unpaid toggle, since that's set automatically and never directly editable here.
    var editingDebtPaidDate: Date? {
        guard let editingDebtID, let debt = debts.first(where: { $0.id == editingDebtID }) else {
            return nil
        }
        return debt.paidDate
    }

    /// `recordedDate` is fixed at creation and never editable, so — like `editingDebtPaidDate` —
    /// this is read live off `debts` rather than copied into a form field.
    var editingDebtRecordedDate: Date? {
        guard let editingDebtID, let debt = debts.first(where: { $0.id == editingDebtID }) else {
            return nil
        }
        return debt.recordedDate
    }

    func closeAddDebtSheet() {
        isShowingAddDebt = false
        editingDebtID = nil
    }

    func saveDebtForm() {
        let trimmedTitle = newDebtTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, let amount = Double(newDebtAmountText), amount > 0 else { return }

        let trimmedNotes = newDebtNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduledDate: Date? = newDebtIsDateReminderEnabled ? newDebtScheduledDate : nil
        let scheduledTime: Date? = (newDebtIsDateReminderEnabled && newDebtIsTimeReminderEnabled) ? newDebtScheduledTime : nil

        // The Add/Edit Debt screen exposes the same intention/"do not show again" fields the
        // new-debt confirmation step writes, so both paths read from (and update) the exact same
        // published fields and the same preference dictionary — editing these here changes what
        // the confirmation step does the next time this title comes up, with no separate storage.
        let trimmedIntention = newDebtIntention.trimmingCharacters(in: .whitespacesAndNewlines)
        debtIntentionPreferences[normalizedIntentionKey(trimmedTitle)] = IntentionPreference(
            intention: trimmedIntention,
            doNotShowAgain: newDebtIntentionDoNotShowAgain
        )
        saveDebtIntentionPreferences()

        let savedDebt: DebtItem
        if let editingDebtID, let index = debts.firstIndex(where: { $0.id == editingDebtID }) {
            debts[index].title = trimmedTitle
            debts[index].amount = amount
            debts[index].debtDate = newDebtDate
            debts[index].notes = trimmedNotes
            debts[index].scheduledPaymentDate = scheduledDate
            debts[index].scheduledPaymentTime = scheduledTime
            debts[index].intention = trimmedIntention
            savedDebt = debts[index]
        } else {
            let newDebt = DebtItem(
                title: trimmedTitle,
                amount: amount,
                debtDate: newDebtDate,
                recordedDate: Date(),
                notes: trimmedNotes,
                scheduledPaymentDate: scheduledDate,
                scheduledPaymentTime: scheduledTime,
                intention: trimmedIntention
            )
            debts.append(newDebt)
            savedDebt = newDebt
        }

        saveDebts()
        // Cancels whatever was previously scheduled and schedules fresh — covers both a new
        // reminder and any date/time change on an existing one.
        DebtReminderManager.scheduleReminder(for: savedDebt)
        isShowingAddDebt = false
        editingDebtID = nil
    }

    func deleteDebt(id: UUID) {
        DebtReminderManager.cancelReminder(for: id)
        debts.removeAll { $0.id == id }
        saveDebts()
        isShowingAddDebt = false
        editingDebtID = nil
    }

    func openAddMoneySheet() {
        newMoneyAmountText = ""
        newMoneyDate = isViewingToday ? Date() : selectedDay
        isShowingAddMoney = true
    }

    func closeAddMoneySheet() {
        isShowingAddMoney = false
    }

    private func saveMoneyTopUps() {
        TimeCircleStorage.save(moneyTopUps: moneyTopUps)
    }

    func saveMoneyForm() {
        guard let amount = Double(newMoneyAmountText), amount > 0 else { return }

        // The top-up belongs to whatever date is selected here — `availableBudget(asOf:)`
        // already filters top-ups to those on or before the day being viewed, so a top-up
        // dated in the future never affects earlier days, and moving its date (or removing it
        // entirely) is picked up automatically since nothing is precomputed per day.
        moneyTopUps.append(MoneyTopUp(amount: amount, date: newMoneyDate))
        saveMoneyTopUps()
        isShowingAddMoney = false
    }

    /// Only the top-ups dated on the day currently selected on the Money page — the History
    /// section on the Add Money screen shows what happened for that specific day, not every
    /// top-up ever recorded.
    var moneyTopUpsForSelectedDay: [MoneyTopUp] {
        moneyTopUps
            .filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDay) }
            .sorted { $0.date > $1.date }
    }

    /// Removing the record itself is what removes its effect — `availableBudget(asOf:)` reads
    /// `moneyTopUps` live, so there's nothing else to reverse or recompute.
    func deleteMoneyTopUp(id: UUID) {
        moneyTopUps.removeAll { $0.id == id }
        saveMoneyTopUps()
    }

    func openAddToDoItemSheet(
        presetActivityTaskID: UUID? = nil,
        presetActivityType: ActivityType? = nil,
        presetPriority: ActivityPriority? = nil
    ) {
        editingToDoItemID = nil
        newToDoItemTitle = ""
        newToDoItemActivityTaskID = presetActivityTaskID
        newToDoItemActivityType = presetActivityType
        newToDoItemPriority = presetPriority
        newToDoItemSubtasks = []
        newToDoItemRecurringWeekdays = []
        newToDoItemDescription = ""
        newToDoItemNotes = ""
        isShowingAddToDoItem = true
    }

    enum PostSelectionToDoGate {
        /// The source has its own To-Do tasks — tracking must wait for `selectToDoItemForTracking`
        /// or `cancelToDoItemSelection` to resolve the pick.
        case needsToDoSelection
        /// The source has no To-Do tasks yet — tracking must wait for the "no tasks yet"
        /// dialog to resolve via `dismissNoToDoTasksPrompt` (Not Now) or a task getting created.
        case needsNoTasksDecision
        /// No further input required — the caller should call `beginTrackingSelectedTask()` now.
        case readyToStart
    }

    /// Shared by `evaluatePostSelectionToDoGate` (a specific activity) and
    /// `evaluateGeneralPostSelectionToDoGate` ("Continue Without Selecting an Activity") — both
    /// just resolve to a `ToDoSelectionSource` and share every bit of this decision logic.
    /// The "already opted out, start immediately" shortcut only ever applies to a specific
    /// activity — there's nothing to remember an opt-out against for a bare type/priority.
    private func evaluateToDoGate(for source: ToDoSelectionSource) -> PostSelectionToDoGate {
        currentSessionToDoItemID = nil

        guard !toDoItems(for: source).isEmpty else {
            if case .activity(let taskID) = source, dismissedNoToDoTasksPromptTaskIDs.contains(taskID) {
                return .readyToStart
            }

            noToDoTasksPromptSource = source
            isShowingNoToDoTasksPrompt = true
            return .needsNoTasksDecision
        }

        toDoItemSelectionSource = source
        isSelectingToDoItemForTracking = true
        return .needsToDoSelection
    }

    /// Called right after a task has been selected (via `selectTask`), before tracking begins.
    /// Determines whether the user still needs to make a decision — pick one of the activity's
    /// own To-Do tasks, or respond to the "no tasks yet" prompt — or whether tracking can start
    /// immediately (already opted out of that prompt for this activity).
    func evaluatePostSelectionToDoGate(for task: TaskItem) -> PostSelectionToDoGate {
        evaluateToDoGate(for: .activity(task.id))
    }

    /// The "Continue Without Selecting an Activity" equivalent — sources the same gate/screen
    /// from the "General" tasks for a bare type/priority instead of a specific activity's tasks.
    func evaluateGeneralPostSelectionToDoGate(type: ActivityType, priority: ActivityPriority?) -> PostSelectionToDoGate {
        evaluateToDoGate(for: .general(type: type, priority: priority))
    }

    @discardableResult
    func selectToDoItemForTracking(_ item: ToDoItem) -> Bool {
        currentSessionToDoItemID = item.id
        isSelectingToDoItemForTracking = false
        toDoItemSelectionSource = nil
        return beginTrackingSelectedTask()
    }

    @discardableResult
    func cancelToDoItemSelection() -> Bool {
        currentSessionToDoItemID = nil
        isSelectingToDoItemForTracking = false
        toDoItemSelectionSource = nil
        return beginTrackingSelectedTask()
    }

    /// Lets the user revisit the To-Do task for an activity that's already being tracked —
    /// tapping the Task row mid-session. Reuses the same selection screen as the pre-tracking
    /// flow; `selectToDoItemForTracking`/`cancelToDoItemSelection` both no-op on the timer via
    /// `beginTrackingSelectedTask()`'s `state == .stopped` guard, so the running session is
    /// left untouched either way.
    func beginManagingCurrentSessionToDoItem() {
        guard let selectedTask, state != .stopped else { return }

        if unlinkedTrackingTask != nil {
            toDoItemSelectionSource = .general(type: selectedTask.activityType, priority: selectedTask.priority)
        } else {
            toDoItemSelectionSource = .activity(selectedTask.id)
        }
        isSelectingToDoItemForTracking = true
    }

    /// Resolves the "no tasks yet" dialog. Does not itself start tracking — the caller decides
    /// when (immediately for "Not Now", or after a newly created task is saved for "Create a
    /// Task", via `isCreatingToDoItemToStartTracking`).
    @discardableResult
    func dismissNoToDoTasksPrompt(dontShowAgain: Bool) -> ToDoSelectionSource? {
        if dontShowAgain, case .activity(let taskID) = noToDoTasksPromptSource {
            dismissedNoToDoTasksPromptTaskIDs.insert(taskID)
            saveDismissedNoToDoTasksPromptTaskIDs()
        }

        let source = noToDoTasksPromptSource
        isShowingNoToDoTasksPrompt = false
        noToDoTasksPromptSource = nil
        return source
    }

    /// Called after completing a To-Do task from the mid-session "manage current task" picker
    /// (`toDoItemSelectionContent`). If that was the source's last remaining task, exits the
    /// picker immediately (rather than leaving the user on an empty list) and surfaces the
    /// "no remaining tasks" prompt in its place.
    func handleToDoItemCompletedDuringTracking(for source: ToDoSelectionSource) {
        guard isSelectingToDoItemForTracking, toDoItemSelectionSource == source else { return }
        guard toDoItems(for: source).isEmpty else { return }

        currentSessionToDoItemID = nil
        isSelectingToDoItemForTracking = false
        toDoItemSelectionSource = nil
        noRemainingTasksPromptSource = source
        isShowingNoRemainingTasksPrompt = true
    }

    /// Resolves the "no remaining tasks" dialog. Like `dismissNoToDoTasksPrompt`, doesn't itself
    /// start tracking — `beginTrackingSelectedTask()`'s `state == .stopped` guard makes it a
    /// no-op when a session is already running, so this is safe to call from both contexts.
    @discardableResult
    func dismissNoRemainingTasksPrompt() -> ToDoSelectionSource? {
        let source = noRemainingTasksPromptSource
        isShowingNoRemainingTasksPrompt = false
        noRemainingTasksPromptSource = nil
        return source
    }

    func openEditToDoItemSheet(_ item: ToDoItem) {
        editingToDoItemID = item.id
        newToDoItemTitle = item.title
        newToDoItemActivityTaskID = item.activityTaskID
        newToDoItemActivityType = item.activityType
        newToDoItemPriority = item.manualPriority
        newToDoItemSubtasks = item.subtasks
        newToDoItemRecurringWeekdays = item.recurringWeekdays
        newToDoItemDescription = item.taskDescription
        newToDoItemNotes = item.notes
        isShowingAddToDoItem = true
    }

    func toggleNewToDoRecurringWeekday(_ weekday: Int) {
        if newToDoItemRecurringWeekdays.contains(weekday) {
            newToDoItemRecurringWeekdays.remove(weekday)
        } else {
            newToDoItemRecurringWeekdays.insert(weekday)
        }
    }

    func toggleNewToDoRecurringAllWeekdays() {
        newToDoItemRecurringWeekdays = newToDoItemRecurringWeekdays.count == 7 ? [] : Set(1...7)
    }

    func addNewToDoSubtask() {
        newToDoItemSubtasks.append(SubtaskItem(title: ""))
    }

    func removeNewToDoSubtask(id: UUID) {
        newToDoItemSubtasks.removeAll { $0.id == id }
    }

    func moveNewToDoSubtask(id: UUID, offset: Int) {
        guard let index = newToDoItemSubtasks.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = index + offset
        guard newToDoItemSubtasks.indices.contains(newIndex) else { return }
        newToDoItemSubtasks.swapAt(index, newIndex)
    }

    func closeAddToDoItemSheet() {
        isShowingAddToDoItem = false
        editingToDoItemID = nil
        isCreatingToDoItemToStartTracking = false
    }

    func saveToDoItemForm() {
        let trimmedTitle = newToDoItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        // Every task must belong to Pain/Pleasure/Other — either a specific activity or a
        // bare type — so there's no longer a way to save one unassigned into its own section.
        guard newToDoItemActivityTaskID != nil || newToDoItemActivityType != nil else { return }

        let resolvedPriority = newToDoItemActivityType?.hasPriorityTiers == true ? (newToDoItemPriority ?? .medium) : nil

        let resolvedSubtasks: [SubtaskItem] = newToDoItemSubtasks.enumerated().compactMap { index, subtask in
            let trimmed = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var resolved = subtask
            resolved.title = trimmed
            resolved.sortOrder = index
            return resolved
        }

        let resolvedDescription = newToDoItemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNotes = newToDoItemNotes.trimmingCharacters(in: .whitespacesAndNewlines)

        var createdItemID: UUID?

        if let editingToDoItemID, let index = toDoItems.firstIndex(where: { $0.id == editingToDoItemID }) {
            toDoItems[index].title = trimmedTitle
            toDoItems[index].activityTaskID = newToDoItemActivityTaskID
            toDoItems[index].activityType = newToDoItemActivityType
            toDoItems[index].manualPriority = newToDoItemActivityTaskID == nil ? resolvedPriority : nil
            toDoItems[index].subtasks = resolvedSubtasks
            // Only this occurrence's own schedule changes — history is untouched, and since
            // `generateDueRecurringToDoOccurrences` only reads a series' latest occurrence,
            // this takes effect for future occurrences without rewriting past ones.
            toDoItems[index].recurringWeekdays = newToDoItemRecurringWeekdays
            if !newToDoItemRecurringWeekdays.isEmpty && toDoItems[index].recurrenceGroupID == nil {
                toDoItems[index].recurrenceGroupID = UUID()
            }
            // Notes are day-specific — only this occurrence's own record changes.
            toDoItems[index].notes = resolvedNotes
            // The description is task-level, so it's mirrored onto every other occurrence
            // sharing this recurrence series (if any).
            toDoItems[index].taskDescription = resolvedDescription
            if let groupID = toDoItems[index].recurrenceGroupID {
                for otherIndex in toDoItems.indices where toDoItems[otherIndex].recurrenceGroupID == groupID {
                    toDoItems[otherIndex].taskDescription = resolvedDescription
                }
            }
        } else {
            let nextSortOrder = (toDoItems
                .filter { Calendar.current.isDate($0.day, inSameDayAs: selectedDay) }
                .map(\.sortOrder)
                .max() ?? -1) + 1

            let item = ToDoItem(
                title: trimmedTitle,
                activityTaskID: newToDoItemActivityTaskID,
                activityType: newToDoItemActivityType,
                manualPriority: newToDoItemActivityTaskID == nil ? resolvedPriority : nil,
                day: selectedDay,
                sortOrder: nextSortOrder,
                subtasks: resolvedSubtasks,
                recurringWeekdays: newToDoItemRecurringWeekdays,
                recurrenceGroupID: newToDoItemRecurringWeekdays.isEmpty ? nil : UUID(),
                taskDescription: resolvedDescription,
                notes: resolvedNotes
            )
            toDoItems.append(item)
            createdItemID = item.id
        }

        saveToDoItems()
        isShowingAddToDoItem = false
        editingToDoItemID = nil

        // If this task was created from the Tracking screen's "no tasks yet" prompt, the
        // tracking session was deliberately held back until now — begin it with the task just
        // created, so the user never had to make an extra selection.
        if isCreatingToDoItemToStartTracking {
            isCreatingToDoItemToStartTracking = false
            if let createdItemID {
                currentSessionToDoItemID = createdItemID
            }
            beginTrackingSelectedTask()
        }
    }

    func deleteToDoItem(id: UUID) {
        toDoItems.removeAll { $0.id == id }
        saveToDoItems()
        isShowingAddToDoItem = false
        editingToDoItemID = nil
    }

    func completeToDoItem(_ item: ToDoItem) {
        guard let index = toDoItems.firstIndex(where: { $0.id == item.id }) else { return }
        guard !toDoItems[index].isCompleted else { return }

        toDoItems[index].isCompleted = true
        if state != .stopped {
            currentSessionCompletedTasks.append(CompletedTaskSnapshot(title: toDoItems[index].title))
        }
        saveToDoItems()
    }

    func uncompleteToDoItem(_ item: ToDoItem) {
        guard let index = toDoItems.firstIndex(where: { $0.id == item.id }) else { return }
        toDoItems[index].isCompleted = false
        saveToDoItems()
    }

    func completeSubtask(_ subtaskID: UUID, in itemID: UUID) {
        guard let itemIndex = toDoItems.firstIndex(where: { $0.id == itemID }),
              let subtaskIndex = toDoItems[itemIndex].subtasks.firstIndex(where: { $0.id == subtaskID })
        else { return }
        toDoItems[itemIndex].subtasks[subtaskIndex].isCompleted = true
        resortSubtasksByCompletion(itemIndex: itemIndex)
        saveToDoItems()
    }

    func uncompleteSubtask(_ subtaskID: UUID, in itemID: UUID) {
        guard let itemIndex = toDoItems.firstIndex(where: { $0.id == itemID }),
              let subtaskIndex = toDoItems[itemIndex].subtasks.firstIndex(where: { $0.id == subtaskID })
        else { return }
        toDoItems[itemIndex].subtasks[subtaskIndex].isCompleted = false
        resortSubtasksByCompletion(itemIndex: itemIndex)
        saveToDoItems()
    }

    /// Pushes completed subtasks below incomplete ones within a single parent task,
    /// ordering each bucket by `sortOrder` (the original, completion-independent
    /// position) rather than current array order — so unchecking a subtask returns it
    /// to exactly where it started instead of just appending it to the incomplete group.
    private func resortSubtasksByCompletion(itemIndex: Int) {
        toDoItems[itemIndex].subtasks.sort { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    func moveToDoItems(from source: IndexSet, to destination: Int) {
        var dayItems = pendingToDoItemsForSelectedDay
        dayItems.move(fromOffsets: source, toOffset: destination)

        for (index, item) in dayItems.enumerated() {
            if let itemIndex = toDoItems.firstIndex(where: { $0.id == item.id }) {
                toDoItems[itemIndex].sortOrder = index
            }
        }
        saveToDoItems()
    }

    func persistActiveTrackingState() {
        guard state != .stopped,
              let selectedTaskID,
              let startTime,
              tasks.contains(where: { $0.id == selectedTaskID })
        else {
            TimeCircleStorage.clearActiveTrackingState()
            return
        }

        TimeCircleStorage.save(
            activeTrackingState: ActiveTrackingState(
                taskID: selectedTaskID,
                startTime: startTime,
                runningStartTime: runningStartTime,
                elapsedBeforePause: elapsedBeforePause,
                isPaused: state == .paused,
                activeIntervals: completedActiveIntervals
            )
        )
    }

    private func restoreActiveTrackingState() {
        guard let storedState = TimeCircleStorage.loadActiveTrackingState() else { return }
        guard tasks.contains(where: { $0.id == storedState.taskID }) else {
            TimeCircleStorage.clearActiveTrackingState()
            resetCurrentTracking()
            selectedTaskID = nil
            return
        }

        now = Date()
        selectedDay = Calendar.current.startOfDay(for: now)
        selectedTaskID = storedState.taskID
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        startTime = storedState.startTime
        elapsedBeforePause = max(storedState.elapsedBeforePause, 0)
        completedActiveIntervals = restoredActiveIntervals(from: storedState)

        if storedState.isPaused {
            state = .paused
            runningStartTime = nil
        } else {
            state = .running
            runningStartTime = storedState.runningStartTime ?? storedState.startTime
        }

        persistActiveTrackingState()
        syncLiveActivityIfNeeded()
    }

    private func restoredActiveIntervals(from storedState: ActiveTrackingState) -> [ActiveTrackingInterval] {
        if !storedState.activeIntervals.isEmpty {
            return storedState.activeIntervals.filter { $0.end > $0.start }
        }

        guard storedState.elapsedBeforePause > 0 else { return [] }

        return [
            ActiveTrackingInterval(
                start: storedState.startTime,
                end: storedState.startTime.addingTimeInterval(storedState.elapsedBeforePause)
            )
        ]
    }

    private func syncLiveActivityIfNeeded() {
        guard state != .stopped,
              let selectedTask,
              startTime != nil
        else {
            endLiveActivity()
            return
        }

        // Elapsed tracked earlier today for this activity's (type, priority) pool, excluding the
        // live run in progress — mirrors timelineCountdownDisplay's own logic exactly, so the
        // widget's count-up reads as the same elapsed the in-app ring shows. Neutral resets to
        // 00:00:00 for each new session, so it never carries prior sessions into the widget.
        let priorTodayElapsed: TimeInterval
        if selectedTask.activityType == .pain {
            priorTodayElapsed = trackedTime(for: .pain, priority: selectedTask.priority ?? .medium, in: elapsedTodayInterval)
        } else if selectedTask.activityType == .none {
            priorTodayElapsed = 0
        } else {
            priorTodayElapsed = trackedTime(for: selectedTask.activityType, in: elapsedTodayInterval)
        }

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.startOrUpdate(
                task: selectedTask,
                runningStartTime: runningStartTime,
                elapsedBeforePause: elapsedBeforePause,
                isPaused: state == .paused,
                priorTodayElapsed: priorTodayElapsed
            )
        }
        #endif
    }

    private func endLiveActivity() {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.end()
        }
        #endif
    }
}
