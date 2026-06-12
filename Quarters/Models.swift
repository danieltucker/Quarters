import Foundation
import SwiftData

// MARK: - Session

enum SessionStatus: String, Codable {
    case active
    case awaitingCheckoff
    case completed
}

@Model
final class Session {
    var blockCount: Int
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    var wasEndedEarly: Bool
    var completedBlocksAtEnd: Int
    var pointsAwarded: Int

    @Relationship(deleteRule: .nullify, inverse: \FocusTask.session)
    var tasks: [FocusTask] = []

    init(blockCount: Int, startedAt: Date = .now) {
        self.blockCount = blockCount
        self.startedAt = startedAt
        self.statusRaw = SessionStatus.active.rawValue
        self.wasEndedEarly = false
        self.completedBlocksAtEnd = 0
        self.pointsAwarded = 0
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .completed }
        set { statusRaw = newValue.rawValue }
    }

    var totalDuration: TimeInterval { Double(blockCount) * AppConfig.blockSeconds }
    var endTime: Date { startedAt.addingTimeInterval(totalDuration) }

    func elapsed(at date: Date = .now) -> TimeInterval {
        min(totalDuration, max(0, date.timeIntervalSince(startedAt)))
    }

    /// Points due at checkoff: full table on completion, base per finished block if ended early.
    var pointsDue: Int {
        wasEndedEarly
            ? completedBlocksAtEnd * AppConfig.basePointsPerBlock
            : AppConfig.points(forBlocks: blockCount)
    }
}

// MARK: - FocusTask

@Model
final class FocusTask {
    var title: String
    var isDone: Bool
    var carriedOver: Bool
    // Inline default is required: schema migration must backfill rows that
    // predate this attribute, and a mandatory attribute with no default
    // makes the whole container fail to open (error 134110).
    var isBig: Bool = false
    var createdAt: Date
    var session: Session?

    init(title: String, carriedOver: Bool = false) {
        self.title = title
        self.isDone = false
        self.carriedOver = carriedOver
        self.isBig = false
        self.createdAt = .now
        self.session = nil
    }
}

// MARK: - LedgerEntry

/// The points balance is always the sum of ledger deltas. Never stored directly.
@Model
final class LedgerEntry {
    var timestamp: Date
    var delta: Int
    var reason: String

    init(delta: Int, reason: String) {
        self.timestamp = .now
        self.delta = delta
        self.reason = reason
    }
}

// MARK: - DailyLog

/// One record per calendar day the user completes a session.
/// Used to compute the current streak without walking session history.
@Model
final class DailyLog {
    var date: Date   // stored as start-of-day in local timezone

    init() {
        self.date = Calendar.current.startOfDay(for: .now)
    }
}

// MARK: - Reward

@Model
final class Reward {
    var icon: String
    var name: String
    var detail: String
    var cost: Int
    var sortOrder: Int
    var isArchived: Bool

    init(icon: String, name: String, detail: String, cost: Int, sortOrder: Int) {
        self.icon = icon
        self.name = name
        self.detail = detail
        self.cost = cost
        self.sortOrder = sortOrder
        self.isArchived = false
    }

    static func seedDefaults(into context: ModelContext) {
        let defaults: [(String, String, String, Int)] = [
            ("☕", "Coffee", "Brew one, savor it", 20),
            ("🚶", "15-min walk", "Cheap on purpose. Go.", 25),
            ("🌐", "15 min browsing", "Guilt-free rabbit holes", 35),
            ("🎮", "15 min gaming", "The premium vice", 40),
        ]
        for (i, d) in defaults.enumerated() {
            context.insert(Reward(icon: d.0, name: d.1, detail: d.2, cost: d.3, sortOrder: i))
        }
    }
}
