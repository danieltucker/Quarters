import SwiftUI
import SwiftData

struct CheckoffView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: Session

    private var sortedTasks: [FocusTask] {
        session.tasks.sorted(by: { $0.createdAt < $1.createdAt })
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
        let base = session.blockCount * AppConfig.basePointsPerBlock

        var parts: [String] = []
        if session.wasEndedEarly {
            if taskBonus > 0 { parts.append("\(sessionPts) session + \(taskBonus) tasks") }
            let suffix = " · bonus forfeited"
            return parts.isEmpty ? suffix.trimmingCharacters(in: .whitespaces) : "\(parts[0])\(suffix)"
        }
        if bonus > 0 { parts.append("\(base) base + \(bonus) bonus") }
        if taskBonus > 0 { parts.append("+\(taskBonus) tasks") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: session.wasEndedEarly ? "pause.circle" : "bell.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(session.wasEndedEarly ? Theme.dim : Theme.gold)
                Text(session.wasEndedEarly ? "Session ended early" : "Time's up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.dim)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(totalPoints)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.gold)
                    Text("pts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.goldText)
                }
                if let breakdown = breakdownLine {
                    Text(breakdown)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.dim)
                }
            }
            .padding(.bottom, 20)

            SectionLabel("What got done? Unchecked items carry over.")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(sortedTasks) { task in
                        checkRow(task)
                    }
                }
            }
            .frame(maxHeight: 220)
            .padding(.bottom, 14)

            Button("Collect points", action: collect)
                .buttonStyle(GoldButtonStyle(wide: true))

            Spacer()
        }
        .padding(20)
    }

    private func checkRow(_ task: FocusTask) -> some View {
        Button {
            task.isDone.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: task.isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 15))
                    .foregroundStyle(task.isDone ? Theme.mint : Theme.dim)
                Text(task.title)
                    .font(.system(size: 13))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? Theme.dim : Theme.text)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .panelCard(border: task.isDone ? Theme.mint : Theme.line)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func collect() {
        let pts = totalPoints
        if pts > 0 {
            let reason = session.wasEndedEarly
                ? "\(session.completedBlocksAtEnd)-block session (ended early)"
                : "\(session.blockCount)-block session"
            context.insert(LedgerEntry(delta: pts, reason: reason))
        }
        session.pointsAwarded = pts
        session.endedAt = .now
        session.status = .completed

        // Done tasks stay attached to the session as history.
        // Undone tasks detach and carry over to the next setup screen.
        for task in session.tasks where !task.isDone {
            task.session = nil
            task.carriedOver = true
        }
    }
}
