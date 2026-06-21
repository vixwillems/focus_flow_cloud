import ActivityKit
import SwiftUI
import WidgetKit

struct FocusFlowLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusFlowAttributes.self) { context in
            // Lock Screen / Notification Center banner
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white.opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                // Top row: phase icon (leading) + task name (center) + time (trailing).
                // The time is the only primary element; everything else is
                // subheadline or smaller.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(phaseTint(context.state.phase))
                        .frame(width: 24, height: 24)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    focusFlowCountdown(
                        endDate: context.state.endDate,
                        paused: context.state.isPaused,
                        fallback: context.state.displayRemaining,
                        font: .system(size: 28, weight: .semibold, design: .rounded),
                        activeColor: .white
                    )
                }
                DynamicIslandExpandedRegion(.center) {
                    liveActivityCenterText(state: context.state)
                }
                // Bottom row: cycle bar (leading) + caption (center) + action
                // button (trailing). This row is the "status" row — what's
                // happening in the cycle, what the user can do about it.
                DynamicIslandExpandedRegion(.bottom) {
                    liveActivityBottomRow(state: context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(phaseTint(context.state.phase))
            } compactTrailing: {
                focusFlowCountdown(
                    endDate: context.state.endDate,
                    paused: context.state.isPaused,
                    fallback: context.state.displayRemaining,
                    font: .system(size: 13, weight: .semibold, design: .rounded),
                    activeColor: phaseTint(context.state.phase)
                )
            } minimal: {
                Image(systemName: context.state.phase.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(phaseTint(context.state.phase))
            }
            .widgetURL(URL(string: "focusflow://timer"))
            .keylineTint(phaseTint(context.state.phase))
        }
    }
}

struct LockScreenLiveActivityView: View {
    let state: FocusFlowAttributes.ContentState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors(for: state.phase),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        phaseIcon(state.phase)
                            .frame(width: 16, height: 16)
                        Text(state.phase.displayName.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    if state.isPaused {
                        Text("PAUSED")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.18), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    focusFlowCountdown(
                        endDate: state.endDate,
                        paused: state.isPaused,
                        fallback: state.displayRemaining,
                        font: .system(size: 40, weight: .semibold, design: .rounded),
                        activeColor: .white
                    )
                    Spacer()
                }

                if let task = state.taskName, !task.isEmpty {
                    Text(task)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                } else {
                    Text(state.phase == .work ? "Deep focus" : "Take a breath")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .italic()
                }

                ProgressView(value: state.progress)
                    .progressViewStyle(.linear)
                    .tint(.white.opacity(0.95))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradientColors(for phase: FocusPhase) -> [Color] {
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
    }
}

func phaseIcon(_ phase: FocusPhase) -> some View {
    Image(systemName: phase.symbol)
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(phaseTint(phase))
}

func phaseTint(_ phase: FocusPhase) -> Color {
    switch phase {
    case .work: return Color(red: 0.62, green: 0.78, blue: 0.95)
    case .shortBreak: return Color(red: 0.55, green: 0.85, blue: 0.75)
    case .longBreak: return Color(red: 0.70, green: 0.85, blue: 0.55)
    case .idle: return Color(red: 0.75, green: 0.75, blue: 0.80)
    }
}

/// The single source of truth for the MM:SS countdown across every
/// surface — lock screen Live Activity, Dynamic Island (compact and
/// expanded), and the home-screen / StandBy widget. Used everywhere so
/// the four surfaces show exactly the same value at the same moment.
///
/// In-progress: `Text(timerInterval:)` is the system-cased API for
/// time-sensitive text in Live Activities and widgets. The system
/// updates the displayed text once per second without us driving a
/// `TimelineView` — and `TimelineView` is **not** guaranteed to tick
/// in iOS 16 Live Activities, which is why the previous
/// `TimelineView(.periodic(...))` implementation made the time look
/// frozen even though the `ProgressView(value: state.progress)` next
/// to it updated every 5s on state push. `Text(timerInterval:)` is the
/// supported path on iOS 16.
///
/// Overtime: when `endDate` is in the past, `Text(timerInterval:)`
/// clamps at zero — we drop down to a static `Text` formatted via
/// `formatMMSS`, which always shows the elapsed overtime as `MM:SS`
/// in red. The view rebuilds every ~5s when the host pushes a new
/// state, so the overtime ticks up at that cadence (not per-second).
/// Per-second overtime would require bumping the deployment target
/// to iOS 17, where `TimelineView` is reliably supported in Live
/// Activities.
@ViewBuilder
func focusFlowCountdown(
    endDate: Date?,
    paused: Bool,
    fallback: String,
    font: Font,
    activeColor: Color
) -> some View {
    if paused {
        Text(fallback)
            .font(font.monospacedDigit())
            .foregroundStyle(activeColor)
    } else if let endDate {
        if endDate > Date() {
            // In-progress. Using `[Date.distantPast, endDate]` as the
            // interval makes the system display `endDate - now` (the
            // time remaining). The distant-past start is so far back
            // it contributes nothing to the computation; it just has
            // to be earlier than `endDate` so the `ClosedRange` is
            // valid and `countsDown: true` shows the time until
            // `endDate`. `showsHours: false` matches the typical
            // Pomodoro duration (under 1 hour) — "25:00" not "0:25:00".
            Text(timerInterval: Date.distantPast ... endDate, countsDown: true, showsHours: false)
                .monospacedDigit()
                .font(font)
                .foregroundStyle(activeColor)
        } else {
            // Overtime. `Date()` is read at view-build time, which
            // happens on every state push (~5s in Live Activity, ~30s
            // in widget) and on the system-driven display redraw that
            // occurs when the Live Activity is foregrounded.
            let overtime = max(0, Int(Date().timeIntervalSince(endDate)))
            Text(formatMMSS(overtime))
                .font(font.monospacedDigit())
                .foregroundStyle(.red)
        }
    } else {
        Text(fallback)
            .font(font.monospacedDigit())
            .foregroundStyle(activeColor)
    }
}

// MARK: - Dynamic Island helpers

/// Centre text in the top row. The task name during a work session;
/// "Take a breath" / "Long break" during breaks. Falls back to a generic
/// "Pomodoro session" label when there's no task and we're in a work
/// session.
@ViewBuilder
func liveActivityCenterText(state: FocusFlowAttributes.ContentState) -> some View {
    if state.phase == .shortBreak {
        Text("Take a breath")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    } else if state.phase == .longBreak {
        Text("Long break")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    } else if let task = state.taskName, !task.isEmpty {
        Text(task)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    } else {
        Text("Pomodoro session")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.7))
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Full bottom row: 4-segment cycle bar (leading), caption (centre),
/// action button (trailing). Pauses hide the button (the user has to
/// resume via the app) and the caption becomes "PAUSED".
@ViewBuilder
func liveActivityBottomRow(state: FocusFlowAttributes.ContentState) -> some View {
    HStack(spacing: 10) {
        cycleBar(state: state)
        cycleCaption(state: state)
        Spacer(minLength: 0)
        if !state.isPaused {
            liveActivityActionButton(state: state)
        }
    }
}

/// Horizontal 4-segment cycle bar. The "now" segment is rendered in
/// the phase tint at full opacity; segments before it are at reduced
/// opacity; segments after it are unfilled outlines. This is the only
/// progress indicator on the Live Activity — the time itself already
/// shows elapsed/remaining seconds, and a redundant bar would compete.
@ViewBuilder
func cycleBar(state: FocusFlowAttributes.ContentState) -> some View {
    let total = max(1, state.cycleTotal)
    let active = min(max(0, state.cycleIndex), total - 1)
    HStack(spacing: 3) {
        ForEach(0..<total, id: \.self) { i in
            Capsule()
                .fill(segmentFill(i: i, active: active, phase: state.phase))
                .frame(width: 14, height: 4)
        }
    }
}

func segmentFill(i: Int, active: Int, phase: FocusPhase) -> Color {
    let tint = phaseTint(phase)
    if i < active { return tint.opacity(0.45) }
    if i == active { return tint }
    return Color.white.opacity(0.15)
}

/// Small caption next to the cycle bar: "Work 2 of 4", "Short break 1",
/// "Long break", or, during overtime, "Over X:XX" in red. When paused
/// the caption shows "PAUSED" in yellow.
///
/// Overtime uses a static `Text` (read at view-build time) rather than
/// a `TimelineView` — for the same reason as `focusFlowCountdown`:
/// `TimelineView` does not reliably tick in iOS 16 Live Activities.
/// The view rebuilds every ~5s on state push, so the overtime text
/// refreshes at that cadence.
@ViewBuilder
func cycleCaption(state: FocusFlowAttributes.ContentState) -> some View {
    if state.isPaused {
        Text("PAUSED")
            .font(.caption2.weight(.bold))
            .tracking(1.0)
            .foregroundStyle(.yellow)
    } else if let endDate = state.endDate, endDate <= Date() {
        let overtime = max(0, Int(Date().timeIntervalSince(endDate)))
        Text("Over \(formatMMSS(overtime))")
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.red)
    } else {
        Text(captionLabel(state: state))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
    }
}

/// Tappable action button that links to `focusflow://break` so the
/// Svelte app can dispatch a `breakEvent` over the WebSocket. The label
/// is context-aware: "Break" while focusing, "Skip" during a break.
/// Hidden entirely when paused (the user should resume via the app).
///
/// Note: requires the `focusflow` URL scheme to be registered in
/// `Info.plist` (see the `CFBundleURLTypes` block in `project.yml`)
/// and a deep-link handler in the Svelte app to actually send the
/// WS event. The host app on iOS opens the URL when the button is
/// tapped; without a registered scheme the tap is a no-op.
@ViewBuilder
func liveActivityActionButton(state: FocusFlowAttributes.ContentState) -> some View {
    let (label, icon) = actionButtonLabelAndIcon(state: state)
    Link(destination: URL(string: "focusflow://break")!) {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(phaseTint(state.phase).opacity(0.22), in: Capsule())
        .foregroundStyle(phaseTint(state.phase))
    }
}

func actionButtonLabelAndIcon(state: FocusFlowAttributes.ContentState) -> (String, String) {
    switch state.phase {
    case .work: return ("Break", "cup.and.saucer.fill")
    case .shortBreak, .longBreak: return ("Skip", "forward.end.fill")
    case .idle: return ("Start", "play.fill")
    }
}

func captionLabel(state: FocusFlowAttributes.ContentState) -> String {
    let total = max(1, state.cycleTotal)
    let active = min(max(0, state.cycleIndex), total - 1)
    switch state.phase {
    case .work: return "Work \(active + 1) of \(total)"
    case .shortBreak: return "Short break"
    case .longBreak: return "Long break"
    case .idle: return "Ready"
    }
}

func formatMMSS(_ totalSeconds: Int) -> String {
    let s = max(0, totalSeconds)
    return String(format: "%02d:%02d", s / 60, s % 60)
}
