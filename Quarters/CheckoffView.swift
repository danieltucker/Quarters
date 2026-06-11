import SwiftUI
import SwiftData

struct CheckoffView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: Session

    private var sortedTasks: [FocusTask] {
        session.tasks.sorted { $0.createdAt < $1.createdAt }
    }

    private var taskBonus: Int {
        sortedTasks.filter { $0.isDone }.reduce(0) { sum, task in
            sum + (task.isBig ? AppConfig.bigTaskPoints : AppConfig.pointsPerCompletedTask)
        }
    }

    private var totalPoints: Int { session.pointsDue + taskBonus }

    private var breakdownLine: String? {
        let sessionPts = session.pointsDue
        let bonus = AppConfig.bonus(forBlocks: session.blockCount)
        let base  = session.blockCount * AppConfig.basePointsPerBlock
        var parts: [String] = []
        if session.wasEndedEarly {
            if taskBonus > 0 { parts.append("\(sessionPts) session + \(taskBonus) tasks") }
            let suffix = " · bonus forfeited"
            return parts.isEmpty ? suffix.trimmingCharacters(in: .whitespaces)
                                 : "\(parts[0])\(suffix)"
        }
        if bonus > 0 { parts.append("\(base) base + \(bonus) bonus") }
        if taskBonus > 0 { parts.append("+\(taskBonus) tasks") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Result header ─────────────────────────────────────────
            VStack(spacing: 6) {
                QCoin(size: 28)
                    .opacity(session.wasEndedEarly ? 0.45 : 1)

                Text(session.wasEndedEarly ? "Session ended early" : "Time's up")
                    .font(.qText(15, weight: .semibold))
                    .foregroundStyle(Theme.ink2)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(totalPoints)")
                        .font(.qDisplay(32))
                        .foregroundStyle(Theme.coin)
                    Text("coins")
                        .font(.qText(16, weight: .semibold))
                        .foregroundStyle(Theme.coinDeep)
                }

                if let breakdown = breakdownLine {
                    Text(breakdown)
                        .font(.qMono(11))
                        .foregroundStyle(Theme.ink2)
                }
            }
            .padding(.bottom, 20)

            // ── Task checkoff ─────────────────────────────────────────
            SectionLabel("What got done? Unchecked items carry over.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 7) {
                    ForEach(sortedTasks) { task in
                        TaskRow(task: task, showBigToggle: false)
                    }
                }
            }
            .frame(maxHeight: 220)
            .padding(.bottom, 14)

            Button("Collect \(totalPoints) coins", action: collect)
                .buttonStyle(AccentButtonStyle(wide: true))

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 22)
    }

    private func collect() {
        let pts = totalPoints
        if pts > 0 {
            let reason = session.wasEndedEarly
                ? "\(session.completedBlocksAtEnd)-quarter session (ended early)"
                : "\(session.blockCount)-quarter session"
            context.insert(LedgerEntry(delta: pts, reason: reason))
        }
        session.pointsAwarded = pts
        session.endedAt = .now
        session.status = .completed

        for task in session.tasks where !task.isDone {
            task.session = nil
            task.carriedOver = true
        }
    }
}
