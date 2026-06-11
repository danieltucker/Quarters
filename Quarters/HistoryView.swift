import SwiftUI
import SwiftData

// Full rewrite in Phase 8; alias keeps ContentView compiling in the interim.
typealias LedgerView = HistoryView

struct HistoryView: View {
    @Query(filter: #Predicate<Session> { $0.statusRaw == "completed" },
           sort: \Session.startedAt, order: .reverse) private var sessions: [Session]

    var body: some View {
        if sessions.isEmpty {
            VStack(spacing: 8) {
                Text("No history yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text("Completed sessions will appear here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.dim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel("Completed Sessions")
                        .padding(.bottom, 4)
                    ForEach(sessions) { session in
                        SessionHistoryCard(session: session)
                    }
                }
                .padding(20)
            }
        }
    }
}

private struct SessionHistoryCard: View {
    let session: Session

    private var doneTasks: [FocusTask] {
        session.tasks.filter { $0.isDone }.sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var headerLabel: String {
        session.startedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var durationLabel: String {
        let blocks = session.wasEndedEarly ? session.completedBlocksAtEnd : session.blockCount
        let suffix = session.wasEndedEarly ? " · ended early" : ""
        return "\(blocks) of \(session.blockCount) block\(session.blockCount == 1 ? "" : "s")\(suffix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text(durationLabel)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.dim)
                }
                Spacer()
                if session.pointsAwarded > 0 {
                    Text("+\(session.pointsAwarded)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.goldText)
                }
            }

            if !doneTasks.isEmpty {
                Divider().overlay(Theme.line)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(doneTasks) { task in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.mint)
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.dim)
                        }
                    }
                }
            }
        }
        .padding(14)
        .panelCard()
    }
}
