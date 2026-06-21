import SwiftUI
import WidgetKit

struct FocusFlowStandByWidget: Widget {
    let kind: String = "FocusFlowStandByWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StandByProvider()) { entry in
            FocusFlowStandByEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    backgroundGradient(for: entry.phase)
                }
        }
        .configurationDisplayName("FocusFlow")
        .description("A calm view of your current focus session. Looks at home as a widget and at night on StandBy.")
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .systemSmall,
            .systemMedium,
            .systemLarge,
        ])
    }
}

struct StandByEntry: TimelineEntry {
    let date: Date
    let state: SharedTimerState
    var phase: FocusPhase { state.phase }
}

struct StandByProvider: TimelineProvider {
    func placeholder(in context: Context) -> StandByEntry {
        StandByEntry(date: .init(), state: sampleState())
    }

    func getSnapshot(in context: Context, completion: @escaping (StandByEntry) -> Void) {
        completion(StandByEntry(date: .init(), state: SharedStorage.readState()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StandByEntry>) -> Void) {
        let now = Date()
        let state = SharedStorage.readState()
        let current = StandByEntry(date: now, state: state)

        // No endDate means either idle (no session) or paused (frozen). In
        // both cases a single entry is enough — Text(timerInterval:) won't
        // tick without an endDate, and the static secondsRemaining is the
        // truth anyway.
        guard state.phase != .idle, let endDate = state.endDate, !state.isPaused else {
            completion(Timeline(entries: [current], policy: .after(now.addingTimeInterval(60 * 5))))
            return
        }

        var entries: [StandByEntry] = [current]
        let total = state.totalSeconds > 0 ? state.totalSeconds : max(1, Int(endDate.timeIntervalSince(state.startedAt ?? now)))
        let remaining = max(0, Int(endDate.timeIntervalSince(now).rounded(.down)))

        let stepSeconds: Int = (total > 60 * 30) ? 60 : 30
        for offset in stride(from: stepSeconds, through: max(stepSeconds, remaining), by: stepSeconds) {
            let date = now.addingTimeInterval(TimeInterval(offset))
            let newRemaining = max(0, Int(endDate.timeIntervalSince(date).rounded(.down)))
            let entryState = SharedTimerState(
                phase: state.phase,
                secondsRemaining: newRemaining,
                totalSeconds: total,
                isPaused: state.isPaused,
                taskName: state.taskName,
                startedAt: state.startedAt,
                updatedAt: date,
                sessionId: state.sessionId,
                endDate: endDate
            )
            entries.append(StandByEntry(date: date, state: entryState))
        }

        let refreshAt = max(endDate.addingTimeInterval(60), now.addingTimeInterval(60 * 30))
        completion(Timeline(entries: entries, policy: .after(refreshAt)))
    }

    private func sampleState() -> SharedTimerState {
        SharedTimerState(
            phase: .work,
            secondsRemaining: 25 * 60,
            totalSeconds: 25 * 60,
            isPaused: false,
            taskName: "Write project plan",
            startedAt: .init(),
            updatedAt: .init(),
            sessionId: "preview"
        )
    }
}

struct FocusFlowStandByEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StandByEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        case .systemSmall:
            SystemSmallView(entry: entry)
        case .systemMedium:
            SystemMediumView(entry: entry)
        case .systemLarge:
            SystemLargeView(entry: entry)
        default:
            SystemSmallView(entry: entry)
        }
    }
}

// MARK: - Accessory (Lock Screen + StandBy) variants

private struct AccessoryRectangularView: View {
    let entry: StandByEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.phase.symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(entry.phase.shortLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.0)
            }
            .foregroundStyle(.primary)

            if entry.phase == .idle {
                Text("Ready to focus")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
            } else {
                focusFlowCountdown(
                    endDate: entry.state.endDate,
                    paused: entry.state.isPaused,
                    fallback: entry.state.displayRemaining,
                    font: .system(.title3, design: .rounded).monospacedDigit().weight(.semibold),
                    activeColor: .primary
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AccessoryCircularView: View {
    let entry: StandByEntry

    var body: some View {
        if entry.phase == .idle {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.primary)
        } else {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.state.progress))
                    .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -1) {
                    Image(systemName: entry.phase.symbol)
                        .font(.system(size: 11, weight: .semibold))
                    focusFlowCountdown(
                        endDate: entry.state.endDate,
                        paused: entry.state.isPaused,
                        fallback: entry.state.displayRemaining,
                        font: .system(size: 11, weight: .semibold, design: .rounded).monospacedDigit(),
                        activeColor: .primary
                    )
                }
            }
        }
    }
}

private struct AccessoryInlineView: View {
    let entry: StandByEntry

    var body: some View {
        if entry.phase == .idle {
            Label("FocusFlow ready", systemImage: entry.phase.symbol)
        } else {
            Label("\(entry.phase.shortLabel) · \(entry.state.displayRemaining)", systemImage: entry.phase.symbol)
        }
    }
}

// MARK: - System family variants (Home screen, calm gradient)

private struct SystemSmallView: View {
    let entry: StandByEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: entry.phase.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(entry.phase.shortLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)

            if entry.phase == .idle {
                Text("Ready")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Open FocusFlow to begin a session.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            } else {
                focusFlowCountdown(
                    endDate: entry.state.endDate,
                    paused: entry.state.isPaused,
                    fallback: entry.state.displayRemaining,
                    font: .system(size: 32, weight: .semibold, design: .rounded).monospacedDigit(),
                    activeColor: .white
                )
                if let task = entry.state.taskName, !task.isEmpty {
                    Text(task)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SystemMediumView: View {
    let entry: StandByEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: entry.phase.symbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(entry.phase.shortLabel.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }

                if entry.phase == .idle {
                    Text("Ready")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Open FocusFlow to start a session.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                } else {
                    focusFlowCountdown(
                        endDate: entry.state.endDate,
                        paused: entry.state.isPaused,
                        fallback: entry.state.displayRemaining,
                        font: .system(size: 44, weight: .semibold, design: .rounded).monospacedDigit(),
                        activeColor: .white
                    )
                    if let task = entry.state.taskName, !task.isEmpty {
                        Text(task)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    } else {
                        Text(entry.state.isPaused ? "Paused" : "In progress")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(.white.opacity(0.18), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.state.progress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(percent(entry.state.progress))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)
        }
        .padding(16)
    }

    private func percent(_ p: Double) -> String { "\(Int(p * 100))%" }
}

private struct SystemLargeView: View {
    let entry: StandByEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: entry.phase.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(entry.phase.shortLabel.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("FocusFlow")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            if entry.phase == .idle {
                Text("Ready to focus")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Tap the FocusFlow app to start a Pomodoro session. The timer will appear here and on your Lock Screen.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(4)
            } else {
                focusFlowCountdown(
                    endDate: entry.state.endDate,
                    paused: entry.state.isPaused,
                    fallback: entry.state.displayRemaining,
                    font: .system(size: 56, weight: .semibold, design: .rounded).monospacedDigit(),
                    activeColor: .white
                )
                ProgressView(value: entry.state.progress)
                    .tint(.white)
                if let task = entry.state.taskName, !task.isEmpty {
                    Text(task)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
                Text(entry.state.isPaused ? "Paused" : "In progress")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Background gradient

@ViewBuilder
func backgroundGradient(for phase: FocusPhase) -> some View {
    // Match the lock-screen Live Activity gradient so the widget and the Live
    // Activity read as the same surface. Previously this function ignored its
    // `phase` argument and always rendered the dark-blue work gradient.
    let colors: [Color] = {
        switch phase {
        case .work:
            return [Color(red: 0.16, green: 0.20, blue: 0.31),
                    Color(red: 0.09, green: 0.13, blue: 0.22)]
        case .shortBreak:
            return [Color(red: 0.12, green: 0.32, blue: 0.30),
                    Color(red: 0.06, green: 0.20, blue: 0.20)]
        case .longBreak:
            return [Color(red: 0.22, green: 0.27, blue: 0.16),
                    Color(red: 0.12, green: 0.16, blue: 0.08)]
        case .idle:
            return [Color(red: 0.18, green: 0.18, blue: 0.22),
                    Color(red: 0.10, green: 0.10, blue: 0.14)]
        }
    }()
    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
}
