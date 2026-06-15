import Foundation
import os
#if os(iOS)
import ActivityKit
#endif

private let liveLog = Logger(subsystem: "Quarters", category: "LiveActivity")

/// Starts / updates / ends the focus-session Live Activity (Dynamic Island +
/// lock screen). The countdown itself animates on its own via Text/ProgressView
/// timerInterval in the widget, so no push updates are needed — we only update
/// on quarter boundaries to refresh the "Quarter X of Y" label and progress.
///
/// Every call is a no-op on macOS (no ActivityKit) or when the user has Live
/// Activities turned off, so it's safe to call unconditionally.
enum LiveActivity {

    static func start(startDate: Date, endDate: Date, totalQuarters: Int) {
        #if os(iOS)
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        liveLog.notice("start() — areActivitiesEnabled=\(enabled, privacy: .public)")
        guard enabled else { return }
        endAll()   // never run two at once
        let attributes = SessionActivityAttributes(sessionLabel: "Focus session")
        let state = SessionActivityAttributes.ContentState(
            startDate: startDate, endDate: endDate,
            totalQuarters: totalQuarters, completedQuarters: 0)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate))
            liveLog.notice("started Live Activity id=\(activity.id, privacy: .public)")
        } catch {
            liveLog.error("Activity.request failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    static func update(startDate: Date, endDate: Date, totalQuarters: Int, completedQuarters: Int) {
        #if os(iOS)
        let state = SessionActivityAttributes.ContentState(
            startDate: startDate, endDate: endDate,
            totalQuarters: totalQuarters, completedQuarters: completedQuarters)
        Task {
            for activity in Activity<SessionActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: endDate))
            }
        }
        #endif
    }

    static func end() {
        endAll()
    }

    private static func endAll() {
        #if os(iOS)
        Task {
            for activity in Activity<SessionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
