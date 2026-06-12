import Foundation

enum AppConfig {

    /// One focus block. Launch with `-fastBlocks` to shrink blocks to 10 seconds for testing.
    static var blockSeconds: TimeInterval {
        ProcessInfo.processInfo.arguments.contains("-fastBlocks") ? 10 : 15 * 60
    }

    static let basePointsPerBlock = 10
    static let pointsPerCompletedTask = 1
    static let bigTaskPoints = 3

    /// Commitment bonus table. Anything above base * blocks is the bonus.
    static let pointTable: [Int: Int] = [1: 10, 2: 25, 3: 45, 4: 70]

    static func points(forBlocks n: Int) -> Int {
        pointTable[n] ?? n * basePointsPerBlock
    }

    static func bonus(forBlocks n: Int) -> Int {
        points(forBlocks: n) - n * basePointsPerBlock
    }

    static func streak(from logs: [DailyLog], includingToday: Bool = false) -> Int {
        let calendar = Calendar.current
        var days = Set(logs.map { calendar.startOfDay(for: $0.date) })
        if includingToday { days.insert(calendar.startOfDay(for: .now)) }
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // Streak bonus: +0.5% of coins earned per consecutive day, capped at 5%
    // (day 10). Always rounds up, so any active streak pays at least +1.

    static let streakPercentPerDay = 0.5
    static let streakPercentCap = 5.0

    static func streakBonusPercent(forDays days: Int) -> Double {
        min(Double(days) * streakPercentPerDay, streakPercentCap)
    }

    static func streakBonus(onPoints points: Int, streakDays days: Int) -> Int {
        guard points > 0, days > 0 else { return 0 }
        return Int(ceil(Double(points) * streakBonusPercent(forDays: days) / 100.0))
    }
}
