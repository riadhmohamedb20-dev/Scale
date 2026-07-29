import SwiftUI
import Combine
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private enum MainTab {
    case today
    case todo
    case statistics
    case money
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @StateObject private var viewModel = TimeCircleViewModel()
    @State private var selectedMainTab: MainTab = .today
    @State private var selectedTimelinePage = 0
    @State private var isShowingSaveConfirmation = false
    @State private var isDatePillPressed = false
    @State private var isShowingAddOptions = false
    @State private var isChoosingActivityType = false
    @State private var browsingActivityType: ActivityType?
    @State private var isShowingMoreOptions = false
    @State private var isShowingDataOptions = false
    @State private var isShowingBackupShareSheet = false
    @State private var isShowingBackupImporter = false
    @State private var isShowingImportConfirmation = false
    @State private var isShowingImportError = false
    @State private var isShowingImportSuccess = false
    @State private var backupExportURL: URL?
    @State private var pendingBackup: ScaleBackup?
    @State private var importErrorMessage = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let activityChipLeadingSpacerID = "activityChipLeadingSpacer"
    private let activityHeadingToChipSpacing: CGFloat = 7.2
    private let activityChipRowTopPadding: CGFloat = 8
    private let previousDayActivityChipRowTopPadding: CGFloat = 8
    private let trackingTopBarTopPadding: CGFloat = 23
    private let idleControlsTopPadding: CGFloat = 23
    private let trackingTopBarHeight: CGFloat = 36
    private let trackingTopBarHorizontalPadding: CGFloat = 16
    private let returnToTodayButtonTrailingOffset: CGFloat = 46

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var secondaryControlBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    private var secondaryControlIconColor: Color {
        colorScheme == .light ? Color.black.opacity(0.82) : .white
    }

    private var darkCircularControlBackground: Color {
        colorScheme == .light ? .black : Color.white.opacity(0.14)
    }

    var body: some View {
        rootContent
        .onAppear {
            viewModel.loadData()
        }
        .onReceive(timer) { value in
            viewModel.updateCurrentTime(value)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                viewModel.appDidBecomeActive()
            case .inactive, .background:
                viewModel.appWillResignActive()
            @unknown default:
                viewModel.appWillResignActive()
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isEditingTask },
                set: { isPresented in
                    if !isPresented {
                        viewModel.closeTaskEditor()
                    }
                }
            )
        ) {
            EditTaskView(
                taskName: Binding(
                    get: { viewModel.editingTaskName },
                    set: viewModel.updateEditingTaskName
                ),
                taskColor: Binding(
                    get: { viewModel.editingTaskColor },
                    set: viewModel.updateEditingTaskColor
                ),
                taskDescription: Binding(
                    get: { viewModel.editingTaskDescription },
                    set: viewModel.updateEditingTaskDescription
                ),
                taskType: Binding(
                    get: { viewModel.editingTaskType },
                    set: viewModel.updateEditingTaskType
                ),
                taskPriority: Binding(
                    get: { viewModel.editingTaskPriority },
                    set: viewModel.updateEditingTaskPriority
                ),
                onDone: viewModel.closeTaskEditor,
                onDelete: viewModel.deleteEditingTask
            )
        }
        .sheet(isPresented: $viewModel.isAddingTask) {
            AddTaskView(
                taskName: $viewModel.newTaskName,
                taskColor: $viewModel.newTaskColor,
                taskDescription: $viewModel.newTaskDescription,
                taskType: $viewModel.newTaskType,
                taskPriority: $viewModel.newTaskPriority,
                onDone: viewModel.addTask,
                onCancel: viewModel.closeAddTaskSheet
            )
        }
        .fullScreenCover(isPresented: $viewModel.isShowingPainReminder) {
            ReminderView(
                onClose: {
                    viewModel.isShowingPainReminder = false
                },
                onTakeAction: {
                    viewModel.isShowingPainReminder = false
                    browsingActivityType = .pain
                    isChoosingActivityType = true
                }
            )
        }
        .sheet(isPresented: $isChoosingActivityType) {
            NavigationStack {
                ChooseActivityTypeView(
                    recentTasks: viewModel.recentlyTrackedTasks,
                    onCancel: { isChoosingActivityType = false },
                    onSelect: { type in browsingActivityType = type },
                    onSelectTask: { task in selectTaskFromActivityPicker(task) }
                )
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $browsingActivityType) { type in
                    ChooseActivityListView(
                        type: type,
                        tasks: viewModel.tasks.filter { $0.activityType == type },
                        onBack: { browsingActivityType = nil },
                        onSelect: { task in selectTaskFromActivityPicker(task) },
                        onCreateNew: {
                            isChoosingActivityType = false
                            browsingActivityType = nil
                            viewModel.openAddTaskSheet()
                            viewModel.newTaskType = type
                        }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .sheet(isPresented: $viewModel.isShowingTaskPicker) {
            NavigationStack {
                TaskPickerView(
                    tasks: viewModel.orderedTasksForSelectedDay,
                    groupsByType: true,
                    onSelect: { task in
                        if viewModel.selectTaskAndStart(task) {
                            switchToHourlyPage()
                        }
                    },
                    onCancel: viewModel.closeTaskPicker
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingManualSessionTaskPicker) {
            NavigationStack {
                TaskPickerView(
                    tasks: viewModel.orderedTasksForSelectedDay,
                    onSelect: viewModel.openManualSessionEditor,
                    onCancel: viewModel.closeManualSessionTaskPicker
                )
            }
        }
        .sheet(isPresented: $viewModel.isShowingHistoryPicker) {
            NavigationStack {
                MonthlyHeatmapView(
                    summaries: viewModel.historySummaries,
                    selectedDay: viewModel.selectedDay,
                    onSelectToday: {
                        viewModel.selectToday()
                        viewModel.closeHistoryPicker()
                    },
                    onSelectDay: viewModel.selectHistoryDay
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            viewModel.closeHistoryPicker()
                        }
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.isEditingSession },
                set: { isPresented in
                    if !isPresented {
                        viewModel.closeSessionEditor()
                    }
                }
            )
        ) {
            EditSessionView(
                taskName: $viewModel.editingSessionTaskName,
                taskColor: $viewModel.editingSessionTaskColor,
                startTime: $viewModel.editingSessionStartTime,
                endTime: $viewModel.editingSessionEndTime,
                sessionDescription: $viewModel.editingSessionDescription,
                subActivityIDs: $viewModel.editingSessionSubActivityIDs,
                title: viewModel.editingSessionTitle,
                showsDeleteButton: viewModel.shouldShowEditingSessionDeleteButton,
                dateRange: viewModel.editingSessionDateRange,
                activities: viewModel.tasks,
                onSave: viewModel.saveEditingSession,
                onDelete: viewModel.deleteEditingSession
            )
        }
        .confirmationDialog("Add", isPresented: $isShowingAddOptions, titleVisibility: .visible) {
            Button("Add New Activity") {
                viewModel.openAddTaskSheet()
            }

            Button("Add New Session") {
                viewModel.openManualSessionTaskPicker()
            }

            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("More", isPresented: $isShowingMoreOptions, titleVisibility: .visible) {
            Button("Share") {
                saveCurrentCircleImage()
            }

            Button("Data") {
                isShowingDataOptions = true
            }

            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog("Data", isPresented: $isShowingDataOptions, titleVisibility: .visible) {
            Button("Export Backup") {
                exportBackup()
            }

            Button("Import Backup") {
                isShowingBackupImporter = true
            }

            Button("Cancel", role: .cancel) { }
        }
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleBackupImportSelection
        )
        .alert("Import Backup?", isPresented: $isShowingImportConfirmation) {
            Button("Import", role: .destructive, action: importPendingBackup)
            Button("Cancel", role: .cancel) {
                pendingBackup = nil
            }
        } message: {
            Text("Importing this backup will replace your current activities and sessions.")
        }
        .alert("Import Failed", isPresented: $isShowingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importErrorMessage)
        }
        .alert("Backup Imported", isPresented: $isShowingImportSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your activities and sessions were restored.")
        }
        .alert("No fuel for today", isPresented: $viewModel.isShowingNoFuelAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.noFuelAlertMessage)
        }
        #if canImport(UIKit)
        .sheet(isPresented: $isShowingBackupShareSheet) {
            if let backupExportURL {
                BackupShareSheet(activityItems: [backupExportURL])
            }
        }
        #endif
        .overlay(alignment: .bottom) {
            if isShowingSaveConfirmation {
                Text("Saved to Photos")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.82))
                    .clipShape(Capsule())
                    .padding(.bottom, 88)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedMainTab {
                case .today:
                    trackingView
                case .todo:
                    ToDoView(viewModel: viewModel, onSwipeToChart: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedMainTab = .today
                        }
                    })
                case .statistics:
                    StatisticsView(viewModel: viewModel)
                case .money:
                    MoneyView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if shouldShowMainTabBar {
                mainTabBar
            }
        }
    }

    private var shouldShowMainTabBar: Bool {
        selectedMainTab != .today || (viewModel.isViewingToday && !isShowingActiveCard)
    }

    private var mainTabBar: some View {
        HStack(spacing: 0) {
            mainTabBarButton(title: "Life Chart", tab: .today)
            mainTabBarButton(title: "To-Do", tab: .todo)
            mainTabBarButton(title: "Money", tab: .money)
        }
        .padding(.top, 44.8)
        .padding(.bottom, 8)
    }

    private func mainTabBarIconName(for tab: MainTab) -> String {
        switch tab {
        case .today:
            return "chart.pie.fill"
        case .todo:
            return "checklist.checked"
        case .statistics:
            return "chart.bar.fill"
        case .money:
            return "cylinder.split.1x2"
        }
    }

    @ViewBuilder
    private func mainTabBarIcon(for tab: MainTab, isActive: Bool) -> some View {
        let iconSize: CGFloat = isActive ? 24 : 22
        let tint = isActive ? Color.primary : Color.secondary

        Image(systemName: mainTabBarIconName(for: tab))
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(tint)
    }

    private func mainTabBarButton(title: String, tab: MainTab) -> some View {
        let isActive = selectedMainTab == tab

        return Button {
            selectedMainTab = tab
        } label: {
            VStack(spacing: 8) {
                mainTabBarIcon(for: tab, isActive: isActive)
                    .frame(height: 24)

                Text(title)
                    .font(.system(size: isActive ? 19 : 17, weight: isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)

                Rectangle()
                    .fill(isActive ? Color.primary : Color.clear)
                    .frame(height: 4.2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var trackingView: some View {
        GeometryReader { proxy in
            let topBarTopPadding = trackingTopBarTopPadding
            let circleSize = min(390, max(280, proxy.size.width - 8))

            ZStack {
            Color(platformSystemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.clearSelectedTaskFromBackgroundTap()
                }
                .gesture(mainTabSwipeGesture)

            VStack(spacing: 14) {
                topBarPlaceholder(topPadding: topBarTopPadding)

                timelinePager(pageWidth: proxy.size.width, circleSize: circleSize)
                    .padding(.top, 22.3)

                if shouldShowActivityChipSection {
                    activityChipSection
                        .padding(.top, 8)
                }

                if isShowingActiveCard {
                    controls
                        .padding(.top, 22)

                    Spacer(minLength: 16)
                } else {
                    if viewModel.isViewingToday {
                        controls
                            .padding(.top, idleControlsTopPadding)
                    } else {
                        pastDayControls
                            .padding(.top, idleControlsTopPadding)
                    }

                    Spacer(minLength: 16)
                }
            }
            .background {
                if !viewModel.isViewingToday {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.clearPastDayActivitySelectionFromBackgroundTap()
                        }
                }
            }

            VStack {
                topBar
                    .padding(.top, topBarTopPadding)

                Spacer()
            }
        }
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedDay)
        }
    }

    private func topBarPlaceholder(topPadding: CGFloat) -> some View {
        Color.clear
            .frame(height: trackingTopBarHeight)
            .padding(.top, topPadding)
    }

    private var topBar: some View {
        ZStack(alignment: .center) {
            HStack {
                appearanceMenu

                Spacer()
            }
            .frame(height: trackingTopBarHeight, alignment: .center)

            dateSelector
                .overlay(alignment: .trailing) {
                    if !viewModel.isViewingToday {
                        returnToTodayButton
                            .offset(x: returnToTodayButtonTrailingOffset)
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: trackingTopBarHeight, alignment: .center)
        .padding(.horizontal, trackingTopBarHorizontalPadding)
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

    private var mainTabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 60
                let isSwipe = abs(horizontalDistance) > horizontalThreshold
                    && abs(horizontalDistance) > abs(verticalDistance)

                guard isSwipe else { return }

                withAnimation(.easeInOut(duration: 0.25)) {
                    if horizontalDistance < 0, selectedMainTab == .today {
                        selectedMainTab = .todo
                    } else if horizontalDistance > 0, selectedMainTab == .todo {
                        selectedMainTab = .today
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

    private func timelinePager(pageWidth: CGFloat, circleSize: CGFloat) -> some View {
        VStack(spacing: 8) {
            if viewModel.isViewingToday {
                TabView(selection: $selectedTimelinePage) {
                    timelinePage(scope: .day, circleSize: circleSize)
                        .frame(width: pageWidth, height: circleSize)
                        .tag(0)

                    timelinePage(scope: .hour, circleSize: circleSize)
                        .frame(width: pageWidth, height: circleSize)
                        .tag(1)
                }
                .timelinePagerStyle()
                .frame(width: pageWidth, height: circleSize)
                .clipped()
            } else {
                timelinePage(scope: .day, circleSize: circleSize)
                    .frame(width: pageWidth, height: circleSize)
            }
        }
        .frame(width: pageWidth, height: circleSize)
        .padding(.top, 4)
        .frame(maxWidth: .infinity)
    }

    private func timelinePage(scope: TimelineScope, circleSize: CGFloat) -> some View {
        TimelineView(
            scope: scope,
            task: viewModel.timelineDisplayTask,
            sessions: viewModel.selectedDaySessions,
            selectedSessionID: viewModel.selectedSessionID,
            state: viewModel.isViewingToday ? viewModel.state : .stopped,
            startTime: viewModel.isViewingToday ? viewModel.currentStartTime : nil,
            activeIntervals: viewModel.isViewingToday ? viewModel.currentActiveIntervals : [],
            elapsed: viewModel.isViewingToday ? viewModel.elapsed : 0,
            displayElapsed: scope == .hour ? viewModel.timelineCountdownDisplay : viewModel.timelineDisplayElapsed,
            currentTime: viewModel.selectedDayCurrentTime,
            showsCurrentTimeWhenEmpty: viewModel.isViewingToday,
            highlightedSessionIDs: viewModel.isViewingToday ? [] : viewModel.highlightedReviewSessionIDs,
            selectedSession: viewModel.selectedSession,
            onSelectSession: viewModel.openSessionEditor,
            onClearSelection: viewModel.clearSessionSelection
        )
        .frame(width: 370, height: 370)
        .scaleEffect(circleSize / 370)
        .frame(width: circleSize, height: circleSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        Group {
            if viewModel.state == .stopped {
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        moreButton

                        Text("More")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 8) {
                        startTrackingButton

                        Text("Start")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 8) {
                        Button {
                            isShowingAddOptions = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(secondaryControlIconColor)
                                .frame(width: 72, height: 72)
                                .background(secondaryControlBackground)
                                .clipShape(Circle())
                        }

                        Text("Add")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            } else {
                HStack(spacing: 30) {
                    Button {
                        let wasRunning = viewModel.state == .running
                        guard viewModel.togglePauseResume() else { return }
                        if wasRunning {
                            switchToDayPage()
                        } else {
                            switchToHourlyPage()
                        }
                    } label: {
                        Image(systemName: viewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(.orange)
                            .clipShape(Circle())
                    }

                    Button {
                        viewModel.stopAndSave()
                        switchToDayPage()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 96, height: 96)
                            .background(darkCircularControlBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var pastDayControls: some View {
        HStack {
            moreButton
        }
    }

    private var startTrackingButton: some View {
        Button {
            if viewModel.selectedTask != nil {
                if viewModel.prepareToStart() {
                    switchToHourlyPage()
                }
            } else {
                isChoosingActivityType = true
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 108, height: 108)
                .background(viewModel.selectedTask?.color.color ?? .gray)
                .clipShape(Circle())
        }
    }

    private var moreButton: some View {
        Button {
            isShowingMoreOptions = true
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(secondaryControlIconColor)
                .frame(width: 72, height: 72)
                .background(secondaryControlBackground)
                .clipShape(Circle())
        }
    }

    private var activityChipSection: some View {
        Group {
            if viewModel.isViewingToday, viewModel.state != .stopped,
               let activeChip = activeActivityChip, let activeTask = viewModel.selectedTask {
                activeActivityPanel(chip: activeChip, task: activeTask)
            } else {
                VStack(alignment: .leading, spacing: activityHeadingToChipSpacing) {
                    Text("Activities")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)

                    taskChips
                        .frame(height: 46)
                }
            }
        }
    }

    private var isShowingActiveCard: Bool {
        viewModel.isViewingToday
            && viewModel.state != .stopped
            && activeActivityChip != nil
    }

    private var shouldShowActivityChipSection: Bool {
        !(viewModel.state == .stopped && viewModel.isViewingToday)
    }

    private var activeActivityChip: TaskChipItem? {
        guard let task = viewModel.selectedTask else { return nil }

        return TaskChipItem(
            id: task.id.uuidString,
            taskID: task.id,
            name: task.name,
            color: task.color
        )
    }

    private func activeActivityPanel(chip: TaskChipItem, task: TaskItem) -> some View {
        activityBudgetCard(chip: chip, task: task)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 0)
    }

    private func activityBudgetCard(chip: TaskChipItem, task: TaskItem) -> some View {
        let accentColor = task.color.color

        let dailyRemaining = viewModel.dailyBudgetRemainingToday
        let dailyTotal = dailyBudgetTotal(for: task)
        let dailyProgress = dailyTotal > 0 ? min(max(dailyRemaining / dailyTotal, 0), 1) : 0

        return VStack(alignment: .leading, spacing: 0) {
            ActivityNameLabel(name: chip.name, color: accentColor) {
                guard let editingTask = viewModel.activityForEditing(from: chip) else { return }

                viewModel.editTask(editingTask)
            }

            HStack(alignment: .center, spacing: 10) {
                cardStat(label: "Type", value: task.activityType.title, color: accentColor)

                if task.activityType.hasPriorityTiers {
                    cardDivider

                    cardStat(
                        label: task.activityType == .pleasure ? "Level" : "Priority",
                        value: (task.priority ?? .medium).title,
                        color: accentColor
                    )
                }
            }
            .padding(.top, 10)

            Text("\(TimeCircleFormat.budgetRemaining(dailyRemaining)) / \(TimeCircleFormat.budgetTotal(dailyTotal))")
                .font(.system(size: 15, weight: .bold, design: .default).monospacedDigit())
                .foregroundStyle(accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)

            BudgetProgressBar(progress: dailyProgress, tint: accentColor)
                .frame(height: 8)
                .padding(.top, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(secondaryControlBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accentColor.opacity(0.5), lineWidth: 1.25)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var cardDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.12))
            .frame(width: 1)
            .padding(.vertical, 2)
    }

    private func dailyBudgetTotal(for task: TaskItem) -> TimeInterval {
        task.activityType.totalDailyBudgetDuration
    }

    private var taskChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: 16)
                        .id(activityChipLeadingSpacerID)

                    HStack(spacing: 10) {
                        if !viewModel.isViewingToday {
                            Button {
                                viewModel.openManualSessionTaskPicker()
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(secondaryControlIconColor)
                                    .frame(width: 36, height: 36)
                                    .background(secondaryControlBackground)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(viewModel.taskChipsForSelectedDay) { task in
                            let isActiveTask = viewModel.isTaskChipActive(task)

                            TaskChipView(
                                task: task,
                                isActive: isActiveTask,
                                allowsLongPress: true,
                                onTap: {
                                    if viewModel.handleTaskChipTap(task) {
                                        switchToHourlyPage()
                                        scrollToFirstTask(with: proxy)
                                    }
                                },
                                onLongPress: {
                                    guard let editingTask = viewModel.activityForEditing(from: task) else { return }

                                    viewModel.editTask(editingTask)
                                }
                            )
                            .id(task.id)
                        }
                    }

                    Color.clear
                        .frame(width: 16)
                }
                .padding(.top, viewModel.isViewingToday ? activityChipRowTopPadding : previousDayActivityChipRowTopPadding)
                .padding(.bottom, 6)
            }
            .onChange(of: viewModel.selectedTaskID) { _, _ in
                scrollToFirstTask(with: proxy)
            }
            .onChange(of: viewModel.taskChipsForSelectedDay.map(\.id)) { _, _ in
                scrollToFirstTask(with: proxy)
            }
            .onChange(of: viewModel.isEditingTask) { wasEditing, isEditing in
                if wasEditing && !isEditing {
                    scrollToFirstTask(with: proxy)
                }
            }
        }
    }

    private func scrollToFirstTask(with proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(activityChipLeadingSpacerID, anchor: .leading)
            }
        }
    }

    private func selectTaskFromActivityPicker(_ task: TaskItem) {
        isChoosingActivityType = false
        browsingActivityType = nil
        if viewModel.selectTaskAndStart(task) {
            switchToHourlyPage()
        }
    }

    private func switchToHourlyPage() {
        guard viewModel.isViewingToday else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTimelinePage = 1
        }
    }

    private func switchToDayPage() {
        guard viewModel.isViewingToday else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            selectedTimelinePage = 0
        }
    }

    @MainActor
    private func saveCurrentCircleImage() {
        let scope: TimelineScope = !viewModel.isViewingToday || selectedTimelinePage == 0 ? .day : .hour
        let summaries = selectedDayTaskSummaries()
        let imageWidth: CGFloat = 430
        let imageHeight = exportImageHeight(for: summaries.count)
        let renderer = ImageRenderer(
            content: exportDailySummary(scope: scope, summaries: summaries)
                .frame(width: imageWidth, height: imageHeight)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )

        #if canImport(UIKit)
        renderer.scale = 3.0

        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(opaqueWhiteImage(from: image), nil, nil, nil)
        #endif

        showSaveConfirmation()
    }

    #if canImport(UIKit)
    private func opaqueWhiteImage(from image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
    #endif

    private func exportDailySummary(scope: TimelineScope, summaries: [ExportTaskSummary]) -> some View {
        VStack(spacing: 18) {
            Text(fullDateString(for: viewModel.selectedDay))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            exportTimelinePage(scope: scope)
                .frame(width: 370, height: 370)

            exportLegend(summaries: summaries)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white)
    }

    private func exportTimelinePage(scope: TimelineScope) -> some View {
        TimelineView(
            scope: scope,
            task: viewModel.selectedTask,
            sessions: viewModel.selectedDaySessions,
            selectedSessionID: viewModel.selectedSessionID,
            state: viewModel.isViewingToday ? viewModel.state : .stopped,
            startTime: viewModel.isViewingToday ? viewModel.currentStartTime : nil,
            activeIntervals: viewModel.isViewingToday ? viewModel.currentActiveIntervals : [],
            elapsed: viewModel.isViewingToday ? viewModel.elapsed : 0,
            displayElapsed: viewModel.selectedTaskDisplayElapsed,
            currentTime: viewModel.selectedDayCurrentTime,
            showsCurrentTimeWhenEmpty: viewModel.isViewingToday,
            highlightedSessionIDs: [],
            selectedSession: viewModel.selectedSession,
            onSelectSession: { _ in },
            onClearSelection: { }
        )
    }

    private func exportLegend(summaries: [ExportTaskSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if summaries.isEmpty {
                Text("No completed sessions")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(summaries) { summary in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(summary.color.color)
                            .frame(width: 12, height: 12)

                        Text(summary.taskName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 16)

                        Text(TimeCircleFormat.readable(Int(summary.duration)))
                            .font(.system(size: 16, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectedDayTaskSummaries() -> [ExportTaskSummary] {
        let groupedSessions = Dictionary(grouping: viewModel.selectedDaySessions, by: \.taskName)

        return groupedSessions.map { taskName, sessions in
            let duration = sessions.reduce(0) { $0 + $1.duration }
            let color = sessions.sorted { $0.startTime < $1.startTime }.last?.color ?? .blue
            return ExportTaskSummary(taskName: taskName, color: color, duration: duration)
        }
        .sorted {
            if $0.duration == $1.duration {
                return $0.taskName < $1.taskName
            }

            return $0.duration > $1.duration
        }
    }

    private func fullDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func exportImageHeight(for summaryCount: Int) -> CGFloat {
        let legendRows = max(summaryCount, 1)
        return 30 + 54 + 370 + 18 + CGFloat(legendRows * 28) + 30
    }

    private func showSaveConfirmation() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isShowingSaveConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingSaveConfirmation = false
            }
        }
    }

    private func exportBackup() {
        do {
            let data = try TimeCircleStorage.backupData(
                tasks: viewModel.tasks,
                sessions: viewModel.sessions,
                toDoItems: viewModel.toDoItems,
                appearanceModeRawValue: appearanceModeRaw
            )
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(backupFileName())

            try data.write(to: url, options: [.atomic])
            backupExportURL = url

            #if canImport(UIKit)
            isShowingBackupShareSheet = true
            #endif
        } catch {
            importErrorMessage = "Scale could not create a backup file. Please try again."
            isShowingImportError = true
        }
    }

    private func handleBackupImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
            defer {
                if didAccessSecurityScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            pendingBackup = try TimeCircleStorage.decodeBackup(from: data)
            isShowingImportConfirmation = true
        } catch {
            importErrorMessage = "Scale could not read this backup file."
            isShowingImportError = true
        }
    }

    private func importPendingBackup() {
        guard let pendingBackup else { return }

        viewModel.replaceData(with: pendingBackup)

        if let rawValue = pendingBackup.appearanceModeRawValue,
           AppAppearanceMode(rawValue: rawValue) != nil {
            appearanceModeRaw = rawValue
        }

        self.pendingBackup = nil
        isShowingImportSuccess = true
    }

    private func backupFileName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HH-mm"
        return "Scale-Backup-\(formatter.string(from: Date())).json"
    }
}

#if canImport(UIKit)
private struct BackupShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

private struct BudgetProgressBar: View {
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

private struct ActivityNameLabel: View {
    let name: String
    let color: Color
    let onLongPress: () -> Void

    @State private var isLongPressing = false

    var body: some View {
        Text(name)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .opacity(isLongPressing ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.12), value: isLongPressing)
            .contentShape(Rectangle())
            .onLongPressGesture(
                minimumDuration: 0.4,
                maximumDistance: 16,
                pressing: { pressing in
                    isLongPressing = pressing
                },
                perform: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isLongPressing = false
                    }
                    onLongPress()
                }
            )
    }
}

private struct TaskChipView: View {
    let task: TaskChipItem
    let isActive: Bool
    let allowsLongPress: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var isLongPressing = false

    var body: some View {
        Text(task.name)
            .font(.system(size: isActive ? 18 : 16, weight: .bold))
            .lineLimit(1)
            .padding(.horizontal, isActive ? 16 : 13)
            .padding(.vertical, isActive ? 10 : 8)
            .background(task.color.color.opacity(backgroundOpacity))
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(Capsule())
            .contentShape(Capsule())
            .scaleEffect(isLongPressing ? 1.04 : 1)
            .animation(.easeInOut(duration: 0.12), value: isLongPressing)
            .onTapGesture(perform: onTap)
            .onLongPressGesture(
                minimumDuration: 0.4,
                maximumDistance: 16,
                pressing: { pressing in
                    guard allowsLongPress else { return }
                    isLongPressing = pressing
                },
                perform: {
                    guard allowsLongPress else { return }
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isLongPressing = false
                    }
                    onLongPress()
                }
            )
    }

    private var backgroundOpacity: Double {
        if isActive {
            return 1
        }

        return isLongPressing ? 0.45 : 0.25
    }
}

private struct TaskPickerView: View {
    let tasks: [TaskItem]
    var groupsByType = false
    let onSelect: (TaskItem) -> Void
    let onCancel: () -> Void
    var onCreateNew: (() -> Void)?

    var body: some View {
        List {
            if groupsByType {
                Text("An activity’s type depends on how it feels before and during it, and it can change over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 10, trailing: 20))
            }

            if tasks.isEmpty {
                Text("No activities yet")
                    .foregroundStyle(.secondary)
            } else if groupsByType {
                ForEach(groupedSections) { section in
                    Section {
                        ForEach(section.tasks) { task in
                            taskRow(task)
                        }
                    } header: {
                        Text(section.headerTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(tasks) { task in
                    taskRow(task)
                }
            }
        }
        .navigationTitle("Choose Activity")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }

            if let onCreateNew {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onCreateNew) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private var groupedSections: [TaskPickerSection] {
        TaskPickerSection.groupOrder.compactMap { activityType in
            let groupedTasks = tasks.filter { $0.activityType == activityType }
            guard !groupedTasks.isEmpty else { return nil }

            return TaskPickerSection(activityType: activityType, tasks: groupedTasks)
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        Button {
            onSelect(task)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(task.color.color)
                    .frame(width: 14, height: 14)

                Text(task.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskPickerSection: Identifiable {
    static let groupOrder: [ActivityType] = [.pain, .pleasure, .none]

    var activityType: ActivityType
    var tasks: [TaskItem]

    var id: String {
        activityType.rawValue
    }

    var title: String {
        switch activityType {
        case .none:
            return "Neutral"
        default:
            return activityType.title
        }
    }

    var headerTitle: String {
        switch activityType {
        case .pain:
            return "Pain: Activities related to a future project or path."
        default:
            return title
        }
    }
}

private struct ExportTaskSummary: Identifiable {
    var taskName: String
    var color: StoredColor
    var duration: TimeInterval

    var id: String {
        taskName
    }
}

private extension View {
    @ViewBuilder
    func timelinePagerStyle() -> some View {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self.tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        #else
        self
        #endif
    }
}

private var platformSystemBackground: PlatformBackgroundColor {
    #if canImport(UIKit)
    UIColor.systemBackground
    #else
    NSColor.windowBackgroundColor
    #endif
}

#if canImport(UIKit)
private typealias PlatformBackgroundColor = UIColor
#else
private typealias PlatformBackgroundColor = NSColor
#endif
