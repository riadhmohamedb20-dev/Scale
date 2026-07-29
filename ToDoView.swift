import SwiftUI
import AudioToolbox
import UIKit

struct ToDoView: View {
    @ObservedObject var viewModel: TimeCircleViewModel
    var onSwipeToChart: () -> Void = {}
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appAppearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var isDatePillPressed = false
    @State private var expandedGroupIDs: Set<String> = []
    @State private var revealedToDoItemID: UUID?
    @State private var revealedToDoItemOffset: CGFloat = 0

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var cardBackground: Color {
        colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 20)

                    Text("To-Do")
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundStyle(.primary)
                        .padding(.top, 24)

                    if viewModel.toDoGroupsForSelectedDay.isEmpty {
                        emptyState
                            .padding(.top, 24)
                    } else {
                        Text("Activities")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .padding(.top, 24)

                        VStack(spacing: 10) {
                            ForEach(viewModel.toDoGroupsForSelectedDay) { group in
                                groupSection(group)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, viewModel.isViewingToday ? 110 : 24)
                .contentShape(Rectangle())
                .onTapGesture {
                    revealedToDoItemID = nil
                    revealedToDoItemOffset = 0
                }
            }
            .background(Color(activityPickerSystemBackground).ignoresSafeArea())
            .gesture(swipeToChartGesture)

            if viewModel.isViewingToday {
                floatingAddButton
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $viewModel.isShowingAddToDoItem) {
            AddToDoItemView(viewModel: viewModel)
        }
    }

    private func groupSection(_ group: ToDoGroup) -> some View {
        let isExpanded = expandedGroupIDs.contains(group.id)
        let tint = colorScheme == .dark
            ? (group.type?.pickerAccentColor.opacity(0.18) ?? Color.secondary.opacity(0.12))
            : (group.type?.pickerIconBackground.opacity(0.12) ?? Color.secondary.opacity(0.06))

        return VStack(alignment: .leading, spacing: 0) {
            groupHeader(group, isExpanded: isExpanded)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if group.subGroups.contains(where: { $0.priority != nil }) {
                        ForEach(Array(group.subGroups.enumerated()), id: \.element.id) { index, priorityGroup in
                            VStack(alignment: .leading, spacing: 8) {
                                if index > 0 {
                                    Divider()
                                }

                                priorityHeader(priorityGroup)

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(Array(subBlocks(for: priorityGroup).enumerated()), id: \.element.id) { subIndex, block in
                                        VStack(alignment: .leading, spacing: 8) {
                                            if let title = block.title {
                                                Text(title)
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(.secondary)
                                            }

                                            groupCard(block.items)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        ForEach(Array(subBlocks(for: group).enumerated()), id: \.element.id) { index, block in
                            VStack(alignment: .leading, spacing: 8) {
                                if index > 0 {
                                    Divider()
                                }

                                if let title = block.title {
                                    Text(title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }

                                groupCard(block.items)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 16)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint)
        )
    }

    private struct ToDoSubBlock: Identifiable {
        var id: String
        var title: String?
        var items: [ToDoItem]
    }

    private func subBlocks(for group: ToDoGroup) -> [ToDoSubBlock] {
        var blocks: [ToDoSubBlock] = []

        if !group.items.isEmpty {
            let hasNamedLabel = group.type != nil
            blocks.append(ToDoSubBlock(id: "\(group.id)-general", title: hasNamedLabel ? "General" : nil, items: group.items))
        }

        for subGroup in group.subGroups {
            blocks.append(ToDoSubBlock(id: subGroup.id, title: groupTitle(subGroup), items: subGroup.items))
        }

        return blocks
    }

    private func groupHeader(_ group: ToDoGroup, isExpanded: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isExpanded {
                    expandedGroupIDs.remove(group.id)
                } else {
                    expandedGroupIDs.insert(group.id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                groupIcon(group)

                Text(groupTitle(group))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                let count = groupItemCount(group)
                Text("\(count) \(count == 1 ? "Task" : "Tasks")")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.15))
                    )

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func groupItemCount(_ group: ToDoGroup) -> Int {
        group.items.count + group.subGroups.reduce(0) { $0 + groupItemCount($1) }
    }

    private func priorityHeader(_ group: ToDoGroup) -> some View {
        guard let priority = group.priority, let type = group.type else {
            return AnyView(EmptyView())
        }

        return AnyView(
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(priority.pickerAccentColor)
                        .frame(width: 18, height: 18)

                    Image(systemName: priority.pickerIconName)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("\(priority.title) \(type == .pleasure ? "Level" : "Priority")")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(priority.pickerAccentColor)

                Spacer(minLength: 8)
            }
        )
    }

    @ViewBuilder
    private func groupIcon(_ group: ToDoGroup) -> some View {
        if let type = group.type {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(colorScheme == .dark ? type.pickerAccentColor : type.pickerIconBackground)
                    .frame(width: 36, height: 36)

                Image(systemName: type.pickerIconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "circle.grid.2x2")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
    }

    private func groupTitle(_ group: ToDoGroup) -> String {
        if let activity = group.activity {
            return activity.name
        } else if let type = group.type {
            return type.title
        } else {
            return "Other"
        }
    }

    private func groupCard(_ items: [ToDoItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider()
                        .padding(.leading, 54)
                }
                ToDoRowView(
                    item: item,
                    revealedOffset: revealedToDoItemID == item.id ? revealedToDoItemOffset : 0,
                    onToggleComplete: {
                        if item.isCompleted {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.uncompleteToDoItem(item)
                            }
                        } else {
                            AudioServicesPlaySystemSound(1104)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                                viewModel.completeToDoItem(item)
                            }
                        }
                    },
                    onEdit: {
                        revealedToDoItemID = nil
                        revealedToDoItemOffset = 0
                        viewModel.openEditToDoItemSheet(item)
                    },
                    onRevealChange: { newOffset in
                        if newOffset == 0 {
                            revealedToDoItemID = nil
                            revealedToDoItemOffset = 0
                        } else {
                            revealedToDoItemID = item.id
                            revealedToDoItemOffset = newOffset
                        }
                    }
                )
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(activityPickerSystemBackground))
        )
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

            Text("No tasks yet")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text(viewModel.isViewingToday ? "Add your first task to get started." : "No tasks were completed this day.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var floatingAddButton: some View {
        Button {
            viewModel.openAddToDoItemSheet()
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

    private var swipeToChartGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height
                let horizontalThreshold: CGFloat = 60
                let isSwipe = horizontalDistance > horizontalThreshold
                    && horizontalDistance > abs(verticalDistance)

                if isSwipe {
                    onSwipeToChart()
                }
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
}

/// A to-do row whose title only becomes swipeable once it's actually truncated:
/// dragging left shifts the text to reveal the hidden tail and sticks exactly where
/// the finger lets go (no snapping), until dragged back right or the caller clears
/// the shared `revealedOffset` state (e.g. tapping elsewhere on the screen).
private struct ToDoRowView: View {
    let item: ToDoItem
    let revealedOffset: CGFloat
    let onToggleComplete: () -> Void
    let onEdit: () -> Void
    let onRevealChange: (CGFloat) -> Void

    @State private var rowWidth: CGFloat = 0
    @State private var checkboxWidth: CGFloat = 22
    @State private var dragHandleWidth: CGFloat = 15
    @State private var dragTranslation: CGFloat = 0
    @State private var longPressTimer: DispatchWorkItem?
    @State private var didTriggerLongPress = false

    /// Fixed-width neighbors within the row (checkbox + spacing, drag handle + spacing,
    /// horizontal padding) subtracted from the row's own measured width, rather than
    /// measuring the text's slot directly — nested GeometryReaders inside the text's own
    /// modifier chain proved unreliable (they kept reporting the row's un-constrained
    /// ideal width instead of the actual laid-out space). The checkbox and drag-handle
    /// widths are measured live rather than guessed, since SF Symbols don't render at
    /// exactly their font-size width (e.g. "line.3.horizontal" is wider than tall).
    private var availableWidth: CGFloat {
        max(0, rowWidth - checkboxWidth - dragHandleWidth - 28 - 24)
    }

    private var naturalWidth: CGFloat {
        (item.title as NSString).size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)]).width
    }

    private var rawOverflow: CGFloat {
        naturalWidth - availableWidth
    }

    private var isTruncated: Bool {
        rawOverflow > 1
    }

    /// Extra points beyond the measured overflow so (a) a full drag always clears the
    /// last character — small mismatches between UIKit's text metrics (used to measure
    /// `naturalWidth`) and SwiftUI's own rendering can leave the last letter or two
    /// unreachable otherwise — and (b) the fully-revealed tail still leaves a small gap
    /// before the drag handle instead of running flush against it, matching the resting
    /// (truncated) state's natural trailing space.
    private var overflow: CGFloat {
        isTruncated ? rawOverflow + 14 : 0
    }

    private var restingOffset: CGFloat {
        min(0, max(-overflow, revealedOffset))
    }

    private var liveOffset: CGFloat {
        guard isTruncated else { return 0 }
        return min(0, max(-overflow, restingOffset + dragTranslation))
    }

    /// A `Text` that's already been truncated by `.lineLimit` has discarded the
    /// clipped characters — shifting it reveals nothing. So the truncated ellipsis
    /// view and the full-width (revealed) view have to be two separate `Text`s,
    /// swapped based on whether we're currently showing more than the resting state.
    private var showsFullTitle: Bool {
        isTruncated && (restingOffset != 0 || dragTranslation != 0)
    }

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggleComplete) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(item.isCompleted ? Color.green : Color.secondary.opacity(0.5))
                    .symbolEffect(.bounce, value: item.isCompleted)
            }
            .buttonStyle(.plain)
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear { checkboxWidth = geo.size.width }
                }
            )

            // The base is a plain, non-fixedSize Text — its reported size is what the
            // HStack lays out around. The full-width (revealed) title is drawn via
            // `.overlay`, which never feeds its own (potentially much wider) natural
            // size back into the base's size, so revealing never blows out the row.
            Text(item.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .strikethrough(item.isCompleted)
                .lineLimit(1)
                .opacity(showsFullTitle ? 0 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if showsFullTitle {
                        Text(item.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.primary)
                            .strikethrough(item.isCompleted)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(x: liveOffset)
                    }
                }
            .clipped()
            .contentShape(Rectangle())
            // A single DragGesture (minimumDistance: 0) instead of a separate
            // onLongPressGesture + simultaneousGesture(DragGesture) pair — the two
            // separate gesture recognizers were fighting over priority, delaying the
            // drag's onChanged until the long-press gesture resolved and then applying
            // the accumulated translation all at once (felt like a jump instead of
            // tracking the finger). Long-press is now a manual timer that gets
            // cancelled the moment real movement is detected.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if longPressTimer == nil && !didTriggerLongPress {
                            let timer = DispatchWorkItem {
                                didTriggerLongPress = true
                                onEdit()
                            }
                            longPressTimer = timer
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: timer)
                        }
                        if abs(value.translation.width) > 10 || abs(value.translation.height) > 10 {
                            longPressTimer?.cancel()
                            longPressTimer = nil
                        }
                        guard isTruncated, !didTriggerLongPress else { return }
                        dragTranslation = value.translation.width
                    }
                    .onEnded { value in
                        longPressTimer?.cancel()
                        longPressTimer = nil
                        defer { didTriggerLongPress = false }
                        guard isTruncated, !didTriggerLongPress else { return }
                        // No snapping — the row sticks exactly where the finger let go.
                        let finalOffset = min(0, max(-overflow, restingOffset + value.translation.width))
                        dragTranslation = 0
                        onRevealChange(finalOffset)
                    }
            )

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear { dragHandleWidth = geo.size.width }
                    }
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { rowWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in
                        rowWidth = newValue
                    }
            }
        )
    }
}
