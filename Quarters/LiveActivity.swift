import Foundation
#if os(iOS)
import ActivityKit
#endif

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
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endAll()   // never run two at once
        let attributes = SessionActivityAttributes(sessionLabel: "Focus session")
        let state = SessionActivityAttributes.ContentState(
            startDate: startDate, endDate: endDate,
            totalQuarters: totalQuarters, completedQuarters: 0)
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: endDate))
        } catch {
            // Request can fail (system limits, disabled mid-flight) — ignore.
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
