import SwiftUI
import Combine

final class TimeCircleViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var sessions: [SessionItem] = []
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
    @Published var newTaskType: ActivityType = .none
    @Published var editingSessionTaskName = ""
    @Published var editingSessionTaskColor: Color = StoredColor.blue.color
    @Published var editingSessionActivityType: ActivityType = .pain
    @Published var editingSessionStartTime = Date()
    @Published var editingSessionEndTime = Date()
    @Published var editingSessionDescription = ""
    @Published var editingSessionSubActivityIDs: [UUID] = []
    @Published var selectedDay = Calendar.current.startOfDay(for: Date())
    @Published var isShowingHistoryPicker = false
    @Published var state: TrackingState = .stopped
    @Published var now = Date()
    @Published var isShowingNoFuelAlert = false
    @Published var noFuelAlertMessage = ""

    private var startTime: Date?
    private var runningStartTime: Date?
    private var elapsedBeforePause: TimeInterval = 0
    private var completedActiveIntervals: [ActiveTrackingInterval] = []
    private var recentTaskInteractionDates: [UUID: Date] = [:]

    var selectedIndex: Int? {
        guard let selectedTaskID else { return nil }
        return tasks.indices.first { tasks[$0].id == selectedTaskID }
    }

    var selectedTask: TaskItem? {
        guard let selectedIndex else { return nil }
        return tasks[selectedIndex]
    }

    var selectedSession: SessionItem? {
        sessions.first { $0.id == selectedSessionID }
    }

    var editingTask: TaskItem? {
        guard let editingTaskID else { return nil }
        return tasks.first { $0.id == editingTaskID }
    }

    var editingSession: SessionItem? {
        guard let editingSessionID else { return nil }
        return sessions.first { $0.id == editingSessionID }
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

    var timelineCountdownDisplay: TimeInterval {
        guard isViewingToday, state != .stopped, let selectedTask else { return 0 }

        if selectedTask.activityType == .neutral {
            return trackedTime(for: .neutral, in: elapsedTodayInterval) + elapsed
        }

        guard selectedTask.activityType.usesDailyTarget else {
            return elapsed
        }

        return targetBalanceToday(for: selectedTask.activityType, runningElapsed: elapsed)
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
                targetDuration: activityType.dailyTargetDuration
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

        restoreActiveTrackingState()
        ensureValidSelectedTask()
    }

    func replaceData(with backup: ScaleBackup) {
        resetCurrentTracking()
        tasks = backup.tasks
        sessions = backup.sessions
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
    }

    func updateCurrentTime(_ date: Date) {
        now = date
        if isViewingToday {
            selectedDay = Calendar.current.startOfDay(for: date)
        }

        ensureValidActiveTrackingState()
        enforceFuelLimitIfNeeded()
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
            showNoFuelAlert(for: task.activityType)
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
                subActivityIDs: validSubActivityIDs(for: editingSessionActivityType)
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
        newTaskType = .none
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

    func selectTaskAndStart(_ task: TaskItem) -> Bool {
        guard state == .stopped, isViewingToday else { return false }
        guard hasFuelAvailableToStart(task) else {
            closeTaskPicker()
            showNoFuelAlert(for: task.activityType)
            return false
        }

        moveTaskToFront(task.id)
        selectedTaskID = task.id
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        resetCurrentTracking()
        closeTaskPicker()
        guard start() else {
            selectedTaskID = nil
            return false
        }

        return true
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
        saveData()
        syncLiveActivityIfNeeded()
    }

    @discardableResult
    func start() -> Bool {
        guard let selectedTaskID, let selectedTask else { return false }
        guard hasFuelAvailableToStart(selectedTask) else {
            showNoFuelAlert(for: selectedTask.activityType)
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
        let allowedDuration = selectedTask.activityType.usesDailyTarget
            ? remainingFuelToday(for: selectedTask.activityType)
            : intervals.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let clippedIntervals = clippedActiveIntervals(intervals, maxDuration: allowedDuration)
        let savedSessions = sessionItems(
            from: clippedIntervals,
            task: selectedTask
        )

        if savedSessions.isEmpty, intervals.isEmpty, elapsed > 0 {
            sessions.append(
                SessionItem(
                    taskName: selectedTask.name,
                    color: selectedTask.color,
                    startTime: startTime,
                    duration: max(elapsed, 1),
                    activityType: selectedTask.activityType
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
            activityType: newTaskType
        )

        tasks.insert(task, at: 0)
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        newTaskName = ""
        newTaskColor = randomTaskColor().color
        newTaskDescription = ""
        newTaskType = .none
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

    private func totalFuelDuration(for activityType: ActivityType) -> TimeInterval {
        activityType.dailyTargetDuration + activityType.reserveDuration
    }

    private func remainingFuelToday(for activityType: ActivityType) -> TimeInterval {
        guard activityType.usesDailyTarget else { return .infinity }

        let trackedDuration = trackedTime(for: activityType, in: elapsedTodayInterval)
        return max(totalFuelDuration(for: activityType) - trackedDuration, 0)
    }

    private func hasFuelAvailableToStart(_ task: TaskItem) -> Bool {
        guard task.activityType.usesDailyTarget else { return true }

        return remainingFuelToday(for: task.activityType) > 0
    }

    private func hasFuelAvailableToResume(_ task: TaskItem) -> Bool {
        guard task.activityType.usesDailyTarget else { return true }

        return elapsed < remainingFuelToday(for: task.activityType)
    }

    private func enforceFuelLimitIfNeeded() {
        guard state == .running,
              let selectedTask,
              selectedTask.activityType.usesDailyTarget,
              elapsed >= remainingFuelToday(for: selectedTask.activityType)
        else { return }

        finishCurrentSessionAtFuelLimit(for: selectedTask)
    }

    private func finishCurrentSessionAtFuelLimit(for task: TaskItem) {
        let allowedDuration = remainingFuelToday(for: task.activityType)
        let clippedIntervals = clippedActiveIntervals(
            activeIntervalsForSaving(endingAt: now),
            maxDuration: allowedDuration
        )
        let savedSessions = sessionItems(from: clippedIntervals, task: task)

        if !savedSessions.isEmpty {
            sessions.append(contentsOf: savedSessions)
            saveData()
        }

        resetCurrentTracking()
        selectedTaskID = nil
        selectedReviewTaskName = nil
        highlightedReviewSessionIDs = []
        selectedSessionID = nil
        showNoFuelAlert(for: task.activityType)
    }

    private func showNoFuelAlert(for activityType: ActivityType) {
        guard activityType.usesDailyTarget else { return }

        noFuelAlertMessage = "You’ve used all your \(activityType.title) time for today."
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
        task: TaskItem
    ) -> [SessionItem] {
        intervals.compactMap { interval in
            let duration = interval.end.timeIntervalSince(interval.start)
            guard duration > 0 else { return nil }

            return SessionItem(
                taskName: task.name,
                color: task.color,
                startTime: interval.start,
                duration: max(duration, 1),
                activityType: task.activityType
            )
        }
    }

    private func targetBalanceToday(for activityType: ActivityType, runningElapsed: TimeInterval) -> TimeInterval {
        let totalTrackedTime = trackedTime(for: activityType, in: elapsedTodayInterval) + runningElapsed

        if totalTrackedTime < activityType.dailyTargetDuration {
            return activityType.dailyTargetDuration - totalTrackedTime
        }

        let reserveElapsed = totalTrackedTime - activityType.dailyTargetDuration
        if reserveElapsed < activityType.reserveDuration {
            return activityType.reserveDuration - reserveElapsed
        }

        return 0
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
            subActivityIDs: session.subActivityIDs
        )
    }

    private func currentActivityType(for session: SessionItem) -> ActivityType {
        tasks.first { $0.name == session.taskName }?.activityType ?? session.activityType
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
            subActivityIDs: session.subActivityIDs
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
        guard let selectedTaskID else { return }

        if !tasks.contains(where: { $0.id == selectedTaskID }) {
            self.selectedTaskID = nil
            resetCurrentTracking()
        }
    }

    private func ensureValidActiveTrackingState() {
        guard state != .stopped else { return }
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
        case .neutral:
            return task.activityType == .pain || task.activityType == .pleasure
        case .none:
            return task.activityType != .none
        }
    }

    private func markTaskInteraction(_ taskID: UUID) {
        guard isViewingToday else { return }

        recentTaskInteractionDates[taskID] = Date()
    }

    private func saveData() {
        TimeCircleStorage.save(tasks: tasks, sessions: sessions)
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
              let startTime
        else {
            endLiveActivity()
            return
        }

        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.startOrUpdate(
                task: selectedTask,
                startTime: startTime,
                runningStartTime: runningStartTime,
                elapsedBeforePause: elapsedBeforePause,
                isPaused: state == .paused
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
