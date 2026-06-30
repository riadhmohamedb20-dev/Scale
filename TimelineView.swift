import SwiftUI

enum TimelineScope {
    case day
    case hour
}

struct TimelineView: View {
    var scope: TimelineScope = .day
    var task: TaskItem?
    var sessions: [SessionItem]
    var selectedSessionID: UUID?
    var state: TrackingState
    var startTime: Date?
    var elapsed: TimeInterval
    var displayElapsed: TimeInterval
    var currentTime: Date
    var showsCurrentTimeWhenEmpty: Bool = true
    var highlightedSessionIDs: Set<UUID> = []
    var selectedSession: SessionItem?
    var onSelectSession: (SessionItem) -> Void
    var onClearSelection: () -> Void

    private let size: CGFloat = 370
    private let outerRadius: CGFloat = 145
    private let innerRadius: CGFloat = 95
    private let maximumZoomScale: CGFloat = 4

    @State private var zoomScale: CGFloat = 1
    @State private var lastZoomScale: CGFloat = 1
    @State private var zoomOffset: CGSize = .zero
    @State private var lastZoomOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topTrailing) {
            timelineContent
                .scaleEffect(zoomScale)
                .offset(zoomOffset)
                .gesture(zoomGesture)
                .zoomPanGesture(isEnabled: isZoomed, panGesture)

            if isZoomed {
                Button {
                    resetZoom()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black.opacity(0.78))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var timelineContent: some View {
        ZStack {
            Color.clear
                .contentShape(Circle())
                .onTapGesture {
                    onClearSelection()
                }

            ForEach(visibleSessions) { session in
                let isEmphasized = isSessionEmphasized(session)

                RingSectorShape(
                    startAngle: .degrees(angleForSession(session) - 90),
                    endAngle: .degrees(angleForSession(session) + max(degreesForSession(session), 0.5) - 90),
                    outerRadius: isEmphasized ? outerRadius + 5 : outerRadius,
                    innerRadius: isEmphasized ? innerRadius - 5 : innerRadius
                )
                .fill(session.color.color.opacity(isEmphasized ? 1 : 0.75))
                .contentShape(
                    RingSectorShape(
                        startAngle: .degrees(angleForSession(session) - 90),
                        endAngle: .degrees(angleForSession(session) + max(degreesForSession(session), 6) - 90),
                        outerRadius: outerRadius + 12,
                        innerRadius: innerRadius - 12
                    )
                )
                .onTapGesture {
                    onSelectSession(session)
                }
            }

            if state != .stopped, let task, let liveSector {
                RingSectorShape(
                    startAngle: .degrees(liveSector.startAngle - 90),
                    endAngle: .degrees(liveSector.startAngle + max(liveSector.degrees, 0.5) - 90),
                    outerRadius: outerRadius,
                    innerRadius: innerRadius
                )
                .fill(task.color.color)
            }

            Circle()
                .stroke(.gray.opacity(0.38), lineWidth: 2)
                .frame(width: outerRadius * 2, height: outerRadius * 2)

            Circle()
                .stroke(.gray.opacity(0.32), lineWidth: 2)
                .frame(width: innerRadius * 2, height: innerRadius * 2)

            ForEach(tickIndices, id: \.self) { tick in
                Rectangle()
                    .fill(.gray.opacity(0.22))
                    .frame(width: 1, height: outerRadius - innerRadius)
                    .offset(y: -(innerRadius + (outerRadius - innerRadius) / 2))
                    .rotationEffect(.degrees(degreesForTick(tick)))
            }

            ForEach(labelIndices, id: \.self) { tick in
                timelineLabel(tick)
            }

            if shouldShowCurrentTimeMarker {
                currentTimeMarker
            }

            centerDisplay
                .frame(width: 180)
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var centerDisplay: some View {
        switch scope {
        case .day:
            if showsCurrentTimeWhenEmpty {
                centerCurrentTimeText
            }
        case .hour:
            centerElapsedTimerText
        }
    }

    private var centerCurrentTimeText: some View {
        VStack(spacing: 2) {
            Text(TimeCircleFormat.twentyFourHourClock(currentTime))
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)

            Text(TimeCircleFormat.seconds(currentTime))
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var centerElapsedTimerText: some View {
        VStack(spacing: 2) {
            Text(TimeCircleFormat.countdownHoursMinutes(Int(displayElapsed)))
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .allowsTightening(true)

            Text(TimeCircleFormat.countdownSeconds(Int(displayElapsed)))
                .font(.system(size: 18, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var isZoomed: Bool {
        zoomScale > 1.01 || abs(zoomOffset.width) > 0.5 || abs(zoomOffset.height) > 0.5
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = clampedScale(lastZoomScale * value)
                zoomOffset = clampedOffset(zoomOffset, scale: zoomScale)
            }
            .onEnded { value in
                zoomScale = clampedScale(lastZoomScale * value)
                zoomOffset = clampedOffset(zoomOffset, scale: zoomScale)
                lastZoomScale = zoomScale
                lastZoomOffset = zoomOffset
            }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard zoomScale > 1 else { return }

                let proposedOffset = CGSize(
                    width: lastZoomOffset.width + value.translation.width,
                    height: lastZoomOffset.height + value.translation.height
                )
                zoomOffset = clampedOffset(proposedOffset, scale: zoomScale)
            }
            .onEnded { value in
                guard zoomScale > 1 else { return }

                let proposedOffset = CGSize(
                    width: lastZoomOffset.width + value.translation.width,
                    height: lastZoomOffset.height + value.translation.height
                )
                zoomOffset = clampedOffset(proposedOffset, scale: zoomScale)
                lastZoomOffset = zoomOffset
            }
    }

    private var visibleSessions: [SessionItem] {
        sessions.filter { isSessionVisible($0) }
    }

    private func isSessionEmphasized(_ session: SessionItem) -> Bool {
        selectedSessionID == session.id || highlightedSessionIDs.contains(session.id)
    }

    private var tickIndices: [Int] {
        switch scope {
        case .day:
            return Array(0..<24)
        case .hour:
            return Array(0..<12)
        }
    }

    private var labelIndices: [Int] {
        switch scope {
        case .day:
            return Array(0..<24)
        case .hour:
            return [0, 3, 6, 9]
        }
    }

    private var liveSector: (startAngle: Double, degrees: Double)? {
        guard let startTime else { return nil }

        switch scope {
        case .day:
            return (angleForDate(startTime), elapsed / 86400 * 360)
        case .hour:
            guard let hourInterval else { return nil }

            let endTime = startTime.addingTimeInterval(elapsed)
            let clippedStart = max(startTime, hourInterval.start)
            let clippedEnd = min(endTime, hourInterval.end)
            guard clippedEnd > clippedStart else { return nil }

            return (
                angleForDate(clippedStart),
                clippedEnd.timeIntervalSince(clippedStart) / 3600 * 360
            )
        }
    }

    private var hourInterval: DateInterval? {
        Calendar.current.dateInterval(of: .hour, for: currentTime)
    }

    private var shouldShowCurrentTimeMarker: Bool {
        showsCurrentTimeWhenEmpty
    }

    private func timelineLabel(_ tick: Int) -> some View {
        let angle = degreesForTick(tick)
        let radius: CGFloat = 166
        let radians = (angle - 90) * .pi / 180
        let label = labelForTick(tick)
        let fontSize: CGFloat
        let fontWeight: Font.Weight

        switch scope {
        case .day:
            fontSize = tick % 4 == 0 ? 24 : 12
            fontWeight = tick % 4 == 0 ? .bold : .medium
        case .hour:
            fontSize = tick == 0 ? 40 : 20
            fontWeight = tick == 0 ? .heavy : .bold
        }

        return Text(label)
            .font(.system(size: fontSize, weight: fontWeight))
            .foregroundStyle(labelColor(for: tick))
            .position(
                x: size / 2 + cos(radians) * radius,
                y: size / 2 + sin(radians) * radius
            )
    }

    private func labelColor(for tick: Int) -> Color {
        switch scope {
        case .day:
            return .primary
        case .hour:
            return tick == 0 ? .primary : .secondary
        }
    }

    private var currentTimeMarker: some View {
        let angle = angleForDate(currentTime)
        let radius: CGFloat = 128
        let radians = (angle - 90) * .pi / 180
        let iconSize: CGFloat = scope == .hour ? 18 : 12
        let frameSize: CGFloat = scope == .hour ? 30 : 22

        return Image(systemName: "person.fill")
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: frameSize, height: frameSize)
            .position(
                x: size / 2 + cos(radians) * radius,
                y: size / 2 + sin(radians) * radius
            )
    }

    private func angleForDate(_ date: Date) -> Double {
        let calendar = Calendar.current
        let m = calendar.component(.minute, from: date)
        let s = calendar.component(.second, from: date)

        switch scope {
        case .day:
            let h = calendar.component(.hour, from: date)
            return Double(h * 3600 + m * 60 + s) / 86400 * 360
        case .hour:
            return Double(m * 60 + s) / 3600 * 360
        }
    }

    private func isSessionVisible(_ session: SessionItem) -> Bool {
        switch scope {
        case .day:
            return true
        case .hour:
            guard let hourInterval else { return false }
            return sessionInterval(session).intersects(hourInterval)
        }
    }

    private func sessionInterval(_ session: SessionItem) -> DateInterval {
        DateInterval(start: session.startTime, duration: session.duration)
    }

    private func angleForSession(_ session: SessionItem) -> Double {
        switch scope {
        case .day:
            return angleForDate(session.startTime)
        case .hour:
            guard let hourInterval else { return angleForDate(session.startTime) }
            return angleForDate(max(session.startTime, hourInterval.start))
        }
    }

    private func degreesForSession(_ session: SessionItem) -> Double {
        switch scope {
        case .day:
            return session.duration / 86400 * 360
        case .hour:
            guard let hourInterval else { return 0 }

            let interval = sessionInterval(session)
            let clippedStart = max(interval.start, hourInterval.start)
            let clippedEnd = min(interval.end, hourInterval.end)
            guard clippedEnd > clippedStart else { return 0 }

            return clippedEnd.timeIntervalSince(clippedStart) / 3600 * 360
        }
    }

    private func degreesForTick(_ tick: Int) -> Double {
        switch scope {
        case .day:
            return Double(tick) * 15
        case .hour:
            return Double(tick) * 30
        }
    }

    private func labelForTick(_ tick: Int) -> String {
        switch scope {
        case .day:
            return "\(tick)"
        case .hour:
            return tick == 0 ? TimeCircleFormat.hourNumber(currentTime) : "\(tick * 5)"
        }
    }

    private func resetZoom() {
        zoomScale = 1
        lastZoomScale = 1
        zoomOffset = .zero
        lastZoomOffset = .zero
    }

    private func clampedScale(_ scale: CGFloat) -> CGFloat {
        min(max(scale, 1), maximumZoomScale)
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat) -> CGSize {
        guard scale > 1 else { return .zero }

        let maximumOffset = size * (scale - 1) / 2
        return CGSize(
            width: min(max(offset.width, -maximumOffset), maximumOffset),
            height: min(max(offset.height, -maximumOffset), maximumOffset)
        )
    }

}

private extension View {
    @ViewBuilder
    func zoomPanGesture<G: Gesture>(isEnabled: Bool, _ gesture: G) -> some View {
        if isEnabled {
            simultaneousGesture(gesture)
        } else {
            self
        }
    }
}
