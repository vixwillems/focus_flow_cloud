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
                DynamicIslandExpandedRegion(.leading) {
                    phaseIcon(context.state.phase)
                        .frame(width: 28, height: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.displayRemaining)
                        .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.phase.displayName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let task = context.state.taskName, !task.isEmpty {
                        Text(task)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(context.state.isPaused ? "Paused" : "Focusing")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } compactLeading: {
                phaseIcon(context.state.phase)
            } compactTrailing: {
                Text(context.state.displayRemaining)
                    .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(phaseTint(context.state.phase))
            } minimal: {
                phaseIcon(context.state.phase)
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
                    Text(state.displayRemaining)
                        .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
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
