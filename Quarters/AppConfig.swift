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
}
