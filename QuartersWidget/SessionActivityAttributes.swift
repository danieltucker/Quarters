import ActivityKit
import Foundation

// Widget-target copy of the focus-session Live Activity model.
//
// ActivityKit matches an activity to its widget by the attributes type *name*,
// so this struct must stay identical (name + fields) to the app target's copy
// in Quarters/SessionActivityAttributes.swift. Keep the two in sync.
struct SessionActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        var totalQuarters: Int
        var completedQuarters: Int
    }

    var sessionLabel: String
}
