import ActivityKit
import Foundation

public struct FocusFlowAttributes: ActivityAttributes {
    public typealias FocusFlowContentState = ContentState

    public struct ContentState: Codable, Hashable {
        public var phase: FocusPhase
        public var secondsRemaining: Int
        public var totalSeconds: Int
        public var isPaused: Bool
        public var taskName: String?
        public var updatedAt: Date
        /// The wall-clock moment the timer should hit 0. `nil` when paused
        /// (the Live Activity / Dynamic Island freeze on the static
        /// `secondsRemaining` value) or when the timer is idle. The views
        /// render the ticking text via `Text(timerInterval:endDate...)`, so
        /// the displayed countdown updates once per second even while the
        /// host app is suspended.
        public var endDate: Date?
        public var cycleIndex: Int
        public var cycleTotal: Int

        public init(
            phase: FocusPhase,
            secondsRemaining: Int,
            totalSeconds: Int,
            isPaused: Bool,
            taskName: String?,
            updatedAt: Date = .init(),
            endDate: Date? = nil,
            cycleIndex: Int = 0,
            cycleTotal: Int = 1
        ) {
            self.phase = phase
            self.secondsRemaining = secondsRemaining
            self.totalSeconds = totalSeconds
            self.isPaused = isPaused
            self.taskName = taskName
            self.updatedAt = updatedAt
            self.endDate = endDate
            self.cycleIndex = cycleIndex
            self.cycleTotal = max(1, cycleTotal)
        }

        public init(state: SharedTimerState) {
            self.phase = state.phase
            self.secondsRemaining = state.secondsRemaining
            self.totalSeconds = state.totalSeconds
            self.isPaused = state.isPaused
            self.taskName = state.taskName
            self.updatedAt = state.updatedAt
            self.endDate = state.endDate
            self.cycleIndex = state.cycleIndex
            self.cycleTotal = state.cycleTotal
        }

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

    public var sessionId: String
    public var startedAt: Date

    public init(sessionId: String, startedAt: Date) {
        self.sessionId = sessionId
        self.startedAt = startedAt
    }
}
