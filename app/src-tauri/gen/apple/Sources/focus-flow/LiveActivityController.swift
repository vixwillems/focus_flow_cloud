import ActivityKit
import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#endif

@objc(FFLiveActivity)
public final class LiveActivityController: NSObject {
    private let log = OSLog(subsystem: "com.francescopio.focusflow", category: "live-activity")
    private var currentActivityId: String?
    private let queue = DispatchQueue(label: "com.francescopio.focusflow.live-activity", qos: .userInitiated)

    @objc public static let shared = LiveActivityController()

    private override init() {
        super.init()
    }

    @objc public func isAvailable() -> Bool {
        if #available(iOS 16.2, *) {
            let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
            let iosVersion = ProcessInfo.processInfo.operatingSystemVersionString
            let bundleId = Bundle.main.bundleIdentifier ?? "?"
            let appGroupContainer = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedStorage.appGroup
            )?.path ?? "nil"
            let blob = """
            isAvailable iOS=\(iosVersion) bundle=\(bundleId) \
            areActivitiesEnabled=\(enabled ? "true" : "false") \
            appGroupContainer=\(appGroupContainer)
            """
            SharedStorage.writeDiagnostics(blob)
            os_log("%{public}@", log: log, type: .info, blob)
            return enabled
        }
        SharedStorage.writeDiagnostics("isAvailable: iOS < 16.2")
        return false
    }

    @objc public func isEnabled() -> Bool {
        return SharedStorage.isLiveActivityEnabled()
    }

    @objc public func setEnabled(_ enabled: Bool) {
        SharedStorage.setLiveActivityEnabled(enabled)
        if !enabled {
            _ = endActivity()
        }
    }

    @objc public func startActivity(
        sessionId: String,
        phaseRaw: String,
        totalSeconds: Int,
        taskName: String?
    ) -> Bool {
        guard isEnabled() else {
            os_log("Live activities disabled by user", log: log, type: .info)
            return false
        }
        guard #available(iOS 16.2, *), isAvailable() else {
            os_log("Live activities not available on this device/iOS version", log: log, type: .info)
            return false
        }
        guard totalSeconds > 0 else {
            os_log("Refusing to start activity with non-positive duration", log: log, type: .error)
            return false
        }

        let phase = FocusPhase(rawValue: phaseRaw) ?? .work
        let now = Date()
        let safeTaskName = taskName?.isEmpty == true ? nil : taskName
        let contentState = FocusFlowAttributes.ContentState(
            phase: phase,
            secondsRemaining: totalSeconds,
            totalSeconds: totalSeconds,
            isPaused: false,
            taskName: safeTaskName,
            updatedAt: now
        )
        let attributes = FocusFlowAttributes(sessionId: sessionId, startedAt: now)

        _ = endActivity()

        do {
            let content = ActivityContent(state: contentState, staleDate: now.addingTimeInterval(TimeInterval(totalSeconds + 60)))
            let activity = try Activity<FocusFlowAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            currentActivityId = activity.id
            SharedStorage.defaults?.set(activity.id, forKey: SharedStorage.liveActivityIdKey)
            SharedStorage.writeState(SharedTimerState(
                phase: phase,
                secondsRemaining: totalSeconds,
                totalSeconds: totalSeconds,
                isPaused: false,
                taskName: safeTaskName,
                startedAt: now,
                updatedAt: now,
                sessionId: sessionId
            ))
            os_log("Started live activity: %@ (phase=%{public}@, total=%d)", log: log, type: .info, activity.id, phaseRaw, totalSeconds)
            return true
        } catch {
            os_log("Failed to start live activity: %{public}@", log: log, type: .error, String(describing: error))
            return false
        }
    }

    @objc public func updateActivity(
        secondsRemaining: Int,
        isPaused: Bool,
        phaseRaw: String,
        taskName: String?
    ) -> Bool {
        guard let activityId = currentActivityId else { return false }
        guard #available(iOS 16.2, *) else { return false }

        let phase = FocusPhase(rawValue: phaseRaw) ?? .work
        let safeTaskName = taskName?.isEmpty == true ? nil : taskName
        let now = Date()

        Task {
            for activity in Activity<FocusFlowAttributes>.activities where activity.id == activityId {
                let currentTotal = max(activity.content.state.totalSeconds, secondsRemaining, 1)
                let newState = FocusFlowAttributes.ContentState(
                    phase: phase,
                    secondsRemaining: max(0, secondsRemaining),
                    totalSeconds: currentTotal,
                    isPaused: isPaused,
                    taskName: safeTaskName,
                    updatedAt: now
                )
                let staleDate = isPaused ? now.addingTimeInterval(60 * 60 * 24) : now.addingTimeInterval(TimeInterval(max(0, secondsRemaining) + 60))
                await activity.update(ActivityContent(state: newState, staleDate: staleDate))

                SharedStorage.writeState(SharedTimerState(
                    phase: phase,
                    secondsRemaining: max(0, secondsRemaining),
                    totalSeconds: currentTotal,
                    isPaused: isPaused,
                    taskName: safeTaskName,
                    startedAt: activity.attributes.startedAt,
                    updatedAt: now,
                    sessionId: activity.attributes.sessionId
                ))
                return
            }
        }
        return true
    }

    @objc public func endActivity() -> Bool {
        guard let activityId = currentActivityId else {
            SharedStorage.writeState(.idle)
            return false
        }
        currentActivityId = nil
        SharedStorage.defaults?.removeObject(forKey: SharedStorage.liveActivityIdKey)

        if #available(iOS 16.2, *) {
            Task {
                for activity in Activity<FocusFlowAttributes>.activities where activity.id == activityId {
                    let finalState = activity.content.state
                    let endContent = ActivityContent(state: finalState, staleDate: nil)
                    await activity.end(endContent, dismissalPolicy: .immediate)
                }
            }
        }
        SharedStorage.writeState(.idle)
        return true
    }

    @objc public func endAllActivities() {
        currentActivityId = nil
        SharedStorage.defaults?.removeObject(forKey: SharedStorage.liveActivityIdKey)

        if #available(iOS 16.2, *) {
            Task {
                for activity in Activity<FocusFlowAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
            }
        }
        SharedStorage.writeState(.idle)
    }
}
