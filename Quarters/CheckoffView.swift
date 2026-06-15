import SwiftUI
import SwiftData

struct CheckoffView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: Session
    @Query private var dailyLogs: [DailyLog]

    private var sortedTasks: [FocusTask] {
        session.tasks
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var taskBonus: Int {
        sortedTasks.filter { $0.isDone }.reduce(0) { sum, task in
            sum + (task.isBig ? AppConfig.bigTaskPoints : AppConfig.pointsPerCompletedTask)
        }
    }

    // Today counts toward the streak even though its DailyLog isn't inserted
    // until collect() — finishing this session is what extends the streak.
    private var streakDays: Int {
        AppConfig.streak(from: dailyLogs, includingToday: true)
    }

    private var streakBonus: Int {
        AppConfig.streakBonus(onPoints: session.pointsDue + taskBonus, streakDays: streakDays)
    }

    private var totalPoints: Int { session.pointsDue + taskBonus + streakBonus }

    private var breakdownLine: String? {
        let sessionPts = session.pointsDue
        let bonus = AppConfig.bonus(forBlocks: session.blockCount)
        let base  = session.blockCount * AppConfig.basePointsPerBlock
        var parts: [String] = []
        if session.wasEndedEarly {
            if taskBonus > 0 { parts.append("\(sessionPts) session + \(taskBonus) tasks") }
            if streakBonus > 0 { parts.append("+\(streakBonus) streak") }
            let suffix = " · bonus forfeited"
            return parts.isEmpty ? suffix.trimmingCharacters(in: .whitespaces)
                                 : "\(parts.joined(separator: " · "))\(suffix)"
        }
        if bonus > 0 { parts.append("\(base) base + \(bonus) bonus") }
        if taskBonus > 0 { parts.append("+\(taskBonus) tasks") }
        if streakBonus > 0 { parts.append("+\(streakBonus) streak") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header + task list scroll; the Collect button stays pinned to
            // the bottom of the window.
            ScrollView {
                VStack(spacing: 0) {
                    // ── Result header ─────────────────────────────────
                    VStack(spacing: 6) {
                        QCoin(size: 28)
                            .opacity(session.wasEndedEarly ? 0.45 : 1)

                        Text(session.wasEndedEarly ? "Session ended early" : "Time's up")
                            .font(.qText(15, weight: .semibold))
                            .foregroundStyle(Theme.ink2)

                        if totalPoints > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("+\(totalPoints)")
                                    .font(.qDisplay(32))
                                    .foregroundStyle(Theme.coin)
                                Text("coins")
                                    .font(.qText(16, weight: .semibold))
                                    .foregroundStyle(Theme.coinDeep)
                            }
                        } else {
                            Text("You earned 0 coins")
                                .font(.qDisplay(22))
                                .foregroundStyle(Theme.ink2)
                        }

                        if let breakdown = breakdownLine {
                            Text(breakdown)
                                .font(.qMono(11))
                                .foregroundStyle(Theme.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)

                    // ── Task checkoff ─────────────────────────────────
                    SectionLabel("What got done? Unchecked items carry over.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 10)

                    VStack(spacing: 7) {
                        ForEach(sortedTasks) { task in
                            TaskRow(task: task, showBigToggle: false)
                        }
                    }
                    .padding(.bottom, 4)
                }
                .padding(.top, 8)
            }

            // ── Collect (pinned to bottom) ────────────────────────────
            // Can't "collect" nothing — say Done when the haul is zero.
            Button(totalPoints > 0 ? "Collect \(totalPoints) coins" : "Done",
                   action: collect)
                .buttonStyle(AccentButtonStyle(wide: true))
                .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .onAppear(perform: Notifications.clearDelivered)
    }

    private func collect() {
        let pts = totalPoints
        if pts > 0 {
            let reason = session.wasEndedEarly
                ? "\(session.completedBlocksAtEnd)-quarter session (ended early)"
                : "\(session.blockCount)-quarter session"
            context.insert(LedgerEntry(delta: pts, reason: reason))
            NotificationCenter.default.post(name: .qCoinsCollected, object: nil,
                                            userInfo: ["amount": pts])
        }
        session.pointsAwarded = pts
        session.endedAt = .now
        session.status = .completed

        let todayStart = Calendar.current.startOfDay(for: .now)
        if !dailyLogs.contains(where: { Calendar.current.startOfDay(for: $0.date) == todayStart }) {
            context.insert(DailyLog())
        }

        for task in session.tasks where !task.isDone && !task.isArchived {
            task.session = nil
            task.carriedOver = true
        }
    }
}
