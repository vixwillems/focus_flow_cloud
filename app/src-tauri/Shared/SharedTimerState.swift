import Foundation

public enum FocusPhase: String, Codable, Hashable, Sendable, CaseIterable {
    case work
    case shortBreak
    case longBreak
    case idle

    public var displayName: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        case .idle: return "Ready"
        }
    }

    public var shortLabel: String {
        switch self {
        case .work: return "Focus"
        case .shortBreak: return "Break"
        case .longBreak: return "Long break"
        case .idle: return "Idle"
        }
    }

    public var symbol: String {
        switch self {
        case .work: return "book.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "cup.and.saucer.fill"
        case .idle: return "moon.zzz.fill"
        }
    }
}

public struct SharedTimerState: Codable, Hashable, Sendable {
    public var phase: FocusPhase
    public var secondsRemaining: Int
    public var totalSeconds: Int
    public var isPaused: Bool
    public var taskName: String?
    public var startedAt: Date?
    public var updatedAt: Date
    public var sessionId: String?
    /// The wall-clock moment the timer should hit 0. `nil` when paused
    /// (the views freeze on the static `secondsRemaining` value) or when
    /// the timer is idle. WidgetKit / ActivityKit render the ticking text
    /// via `Text(timerInterval:endDate...)`, so the displayed countdown
    /// updates once per second even while the host app is suspended.
    public var endDate: Date?
    /// 0-based index of the current / just-completed work session in the
    /// Pomodoro cycle. For a Work session that is the 2nd of 4 this is
    /// `1`; for the ShortBreak that follows that work session this is
    /// also `1` (the break doesn't get its own index — the cycle bar
    /// marks the work session that was just completed).
    public var cycleIndex: Int
    /// Total number of work sessions in a cycle (the long-break
    /// threshold). Typically 4. The cycle bar renders exactly this
    /// many segments.
    public var cycleTotal: Int

    public init(
        phase: FocusPhase = .idle,
        secondsRemaining: Int = 0,
        totalSeconds: Int = 0,
        isPaused: Bool = false,
        taskName: String? = nil,
        startedAt: Date? = nil,
        updatedAt: Date = .init(),
        sessionId: String? = nil,
        endDate: Date? = nil,
        cycleIndex: Int = 0,
        cycleTotal: Int = 1
    ) {
        self.phase = phase
        self.secondsRemaining = secondsRemaining
        self.totalSeconds = totalSeconds
        self.isPaused = isPaused
        self.taskName = taskName
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.sessionId = sessionId
        self.endDate = endDate
        self.cycleIndex = cycleIndex
        self.cycleTotal = max(1, cycleTotal)
    }

    public static let idle = SharedTimerState(phase: .idle)

    public var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        let elapsed = max(0, totalSeconds - secondsRemaining)
        return min(1, max(0, Double(elapsed) / Double(totalSeconds)))
    }

    public var displayRemaining: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }
}

public enum SharedStorage {
    public static let appGroup = "group.com.francescopio.focusflow"
    public static let stateKey = "ff.sharedTimerState"
    public static let liveActivityEnabledKey = "ff.liveActivityEnabled"
    public static let liveActivityIdKey = "ff.liveActivityId"

    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup) ?? UserDefaults.standard
    }

    public static func writeState(_ state: SharedTimerState) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: stateKey)
        }
    }

    public static func readState() -> SharedTimerState {
        guard let defaults,
              let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SharedTimerState.self, from: data) else {
            return .idle
        }
        return state
    }

    public static func isLiveActivityEnabled(default fallback: Bool = true) -> Bool {
        guard let defaults else { return fallback }
        if defaults.object(forKey: liveActivityEnabledKey) == nil { return fallback }
        return defaults.bool(forKey: liveActivityEnabledKey)
    }

    public static func setLiveActivityEnabled(_ enabled: Bool) {
        defaults?.set(enabled, forKey: liveActivityEnabledKey)
    }

    /// Write a one-line diagnostic blob to the App Group so we can inspect
    /// what the iOS app actually saw at runtime (e.g. `areActivitiesEnabled`,
    /// the App Group container path, the iOS version, etc.) from the host
    /// Mac via the App Group's shared filesystem path. The key is keyed by
    /// `diagnosticsKey` and overwritten on every call.
    public static let diagnosticsKey = "ff.diagnostics"
    public static func writeDiagnostics(_ blob: String) {
        guard let defaults else { return }
        defaults.set(blob, forKey: diagnosticsKey)
    }
    public static func readDiagnostics() -> String? {
        guard let defaults else { return nil }
        return defaults.string(forKey: diagnosticsKey)
    }
}
