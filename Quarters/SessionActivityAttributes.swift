#if os(iOS)
import ActivityKit
import Foundation

/// Shared Live Activity model for the focus-session Dynamic Island / lock-screen
/// activity. iOS only — ActivityKit doesn't exist on macOS.
///
/// IMPORTANT: add this file to BOTH targets (the app and the widget extension)
/// in the File Inspector → Target Membership.
struct SessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var totalQuarters: Int
        var completedQuarters: Int
    }

    var sessionLabel: String
}
#endif
