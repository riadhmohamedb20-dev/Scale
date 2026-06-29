import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @StateObject private var viewModel = TimeCircleViewModel()
    @State private var selectedTimelinePage = 0
    @State private var isShowingSaveConfirmation = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

    private var activePageDotColor: Color {
        colorScheme == .light ? .black : .white
    }

    private var inactivePageDotColor: Color {
        colorScheme == .light ? Color.gray.opacity(0.5) : Color.gray.opacity(0.68)
    }

    private var pageIndicatorBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.08)
    }

    var body: some View {
        TabView {
            trackingView
                .tabItem {
                    Label("Tracking", systemImage: "clock")
                }

            StatisticsView(viewModel: viewModel)
                .tabItem {
                    Label("Statistics", systemImage: "chart.pie.fill")
                }
        }
        .onAppear {
            viewModel.loadData()
        }
        .onReceive(timer) { value in
            viewModel.updateCurrentTime(value)
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
                onDone: viewModel.closeTaskEditor,
                onDelete: viewModel.deleteEditingTask
            )
        }
        .sheet(isPresented: $viewModel.isAddingTask) {
            AddTaskView(
                taskName: $viewModel.newTaskName,
                taskColor: $viewModel.newTaskColor,
                onDone: viewModel.addTask
            )
        }
        .sheet(isPresented: $viewModel.isShowingTaskPicker) {
            TaskPickerView(
                tasks: viewModel.orderedTasksForSelectedDay,
                onSelect: { task in
                    if viewModel.selectTaskAndStart(task) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimelinePage = 1
                        }
                    }
                },
                onCancel: viewModel.closeTaskPicker
            )
        }
        .sheet(isPresented: $viewModel.isShowingHistoryPicker) {
            HistoryDayPickerView(
                summaries: viewModel.historySummaries,
                selectedDay: viewModel.selectedDay,
                onSelectToday: viewModel.selectToday,
                onSelectDay: viewModel.selectHistoryDay
            )
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
                onSave: viewModel.saveEditingSession,
                onDelete: viewModel.deleteEditingSession
            )
        }
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

    private var trackingView: some View {
        ZStack {
            Color(platformSystemBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.clearSelectedTaskFromBackgroundTap()
                }

            VStack(spacing: 14) {
                topBar
                    .padding(.top, 12)

                timelinePager

                taskChips

                Spacer()

                if viewModel.isViewingToday {
                    controls
                        .padding(.bottom, 24)
                } else {
                    pastDayControls
                        .padding(.bottom, 24)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.selectedDay)
    }

    private var topBar: some View {
        ZStack {
            HStack {
                appearanceMenu

                Spacer()
            }

            dateSelector
        }
        .padding(.horizontal, 16)
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
                .background(Color.primary.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var dateSelector: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                viewModel.openHistoryPicker()
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedDayTitle)
                    .font(.subheadline.weight(.semibold))

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.06))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var timelinePager: some View {
        GeometryReader { proxy in
            let pageWidth = proxy.size.width
            let circleSize = min(370, max(280, pageWidth - 32))

            VStack(spacing: 8) {
                TabView(selection: $selectedTimelinePage) {
                    timelinePage(scope: .day, circleSize: circleSize)
                        .frame(width: pageWidth, height: 370)
                        .tag(0)

                    timelinePage(scope: .hour, circleSize: circleSize)
                        .frame(width: pageWidth, height: 370)
                        .tag(1)
                }
                .timelinePagerStyle()
                .frame(width: pageWidth, height: 370)
                .clipped()

                HStack(spacing: 8) {
                    Circle()
                        .fill(selectedTimelinePage == 0 ? activePageDotColor : inactivePageDotColor)
                        .frame(width: 7, height: 7)

                    Circle()
                        .fill(selectedTimelinePage == 1 ? activePageDotColor : inactivePageDotColor)
                        .frame(width: 7, height: 7)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(pageIndicatorBackground)
                .clipShape(Capsule())
            }
            .frame(width: pageWidth, height: 390)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 390)
    }

    private func timelinePage(scope: TimelineScope, circleSize: CGFloat) -> some View {
        TimelineView(
            scope: scope,
            task: viewModel.selectedTask,
            sessions: viewModel.selectedDaySessions,
            selectedSessionID: viewModel.selectedSessionID,
            state: viewModel.isViewingToday ? viewModel.state : .stopped,
            startTime: viewModel.isViewingToday ? viewModel.currentStartTime : nil,
            elapsed: viewModel.isViewingToday ? viewModel.elapsed : 0,
            displayElapsed: viewModel.selectedTaskDisplayElapsed,
            currentTime: viewModel.selectedDayCurrentTime,
            showsCurrentTimeWhenEmpty: viewModel.isViewingToday,
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
                if viewModel.selectedTaskHasAccumulatedTimeForSelectedDay {
                    HStack(spacing: 34) {
                        startTrackingButton

                        Button {
                            viewModel.clearSelectedTask()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 86, height: 86)
                                .background(darkCircularControlBackground)
                                .clipShape(Circle())
                        }
                    }
                } else {
                    HStack(spacing: 24) {
                        startTrackingButton

                        Button {
                            viewModel.openAddTaskSheet()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(secondaryControlIconColor)
                                .frame(width: 64, height: 64)
                                .background(secondaryControlBackground)
                                .clipShape(Circle())
                        }

                        saveImageButton
                    }
                }
            } else {
                HStack(spacing: 34) {
                    Button {
                        viewModel.togglePauseResume()
                    } label: {
                        Image(systemName: viewModel.state == .running ? "pause.fill" : "play.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 86, height: 86)
                            .background(.orange)
                            .clipShape(Circle())
                    }

                    Button {
                        viewModel.stopAndSave()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 86, height: 86)
                            .background(darkCircularControlBackground)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var pastDayControls: some View {
        HStack {
            saveImageButton
        }
    }

    private var startTrackingButton: some View {
        Button {
            if viewModel.prepareToStart() {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTimelinePage = 1
                }
            }
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(viewModel.selectedTask?.color.color ?? .gray)
                .clipShape(Circle())
        }
    }

    private var saveImageButton: some View {
        Button {
            saveCurrentCircleImage()
        } label: {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(secondaryControlIconColor)
                .frame(width: 64, height: 64)
                .background(secondaryControlBackground)
                .clipShape(Circle())
        }
    }

    private var taskChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.orderedTasksForSelectedDay) { task in
                        Text(task.name)
                            .font(.system(size: viewModel.selectedTaskID == task.id ? 18 : 16, weight: .bold))
                            .lineLimit(1)
                        .padding(.horizontal, viewModel.selectedTaskID == task.id ? 16 : 13)
                        .padding(.vertical, viewModel.selectedTaskID == task.id ? 10 : 8)
                        .background(task.color.color.opacity(viewModel.selectedTaskID == task.id ? 1 : 0.25))
                        .foregroundStyle(viewModel.selectedTaskID == task.id ? .white : .primary)
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                        .id(task.id)
                        .onTapGesture {
                            viewModel.selectTask(task)
                            scrollToSelectedTask(with: proxy)
                        }
                        .onLongPressGesture {
                            viewModel.editTask(task)
                            scrollToSelectedTask(with: proxy)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: viewModel.selectedTaskID) { _, _ in
                scrollToSelectedTask(with: proxy)
            }
            .onChange(of: viewModel.orderedTasksForSelectedDay.map(\.id)) { _, _ in
                scrollToSelectedTask(with: proxy)
            }
        }
    }

    private func scrollToSelectedTask(with proxy: ScrollViewProxy) {
        guard let selectedTaskID = viewModel.selectedTaskID else { return }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(selectedTaskID, anchor: .center)
            }
        }
    }

    @MainActor
    private func saveCurrentCircleImage() {
        let scope: TimelineScope = selectedTimelinePage == 0 ? .day : .hour
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
            elapsed: viewModel.isViewingToday ? viewModel.elapsed : 0,
            displayElapsed: viewModel.selectedTaskDisplayElapsed,
            currentTime: viewModel.selectedDayCurrentTime,
            showsCurrentTimeWhenEmpty: viewModel.isViewingToday,
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
}

private struct TaskPickerView: View {
    let tasks: [TaskItem]
    let onSelect: (TaskItem) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    Text("No tasks yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Choose a task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
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
