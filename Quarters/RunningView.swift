import SwiftUI
import Combine

struct RunningView: View {
    @Bindable var session: Session
    @State private var now = Date.now

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval { session.elapsed(at: now) }
    private var remaining: TimeInterval { max(0, session.totalDuration - elapsed) }
    private var currentBlock: Int {
        min(session.blockCount, Int(elapsed / AppConfig.blockSeconds) + 1)
    }

    private var checkedCount: Int { session.tasks.filter { $0.isDone }.count }
    private var taskPtsEarned: Int {
        session.tasks.filter { $0.isDone }.reduce(0) { sum, t in
            sum + (t.isBig ? AppConfig.bigTaskPoints : AppConfig.pointsPerCompletedTask)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                SectionLabel("Block \(currentBlock) of \(session.blockCount)")
                Spacer()
                if checkedCount > 0 {
                    let pts = checkedCount * AppConfig.pointsPerCompletedTask
                    Text("+\(pts) task pt\(pts == 1 ? "" : "s")")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.mint)
                }
            }
            .padding(.top, 24)

            Text(timeString(remaining))
                .font(.system(size: 62, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
                .padding(.vertical, 8)

            BlockBar(blockCount: session.blockCount, elapsed: elapsed)
                .padding(.bottom, 24)

            VStack(spacing: 6) {
                ForEach(session.tasks.sorted(by: { $0.createdAt < $1.createdAt })) { task in
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
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .panelCard(border: task.isDone ? Theme.mint : Theme.line)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button("End early", action: endEarly)
                    .buttonStyle(OutlineButtonStyle(tint: Theme.red))
            }
            .padding(.top, 24)

            Spacer()
        }
        .padding(20)
        .onReceive(tick) { date in
            now = date
            checkForCompletion()
        }
        .onAppear { checkForCompletion() }
    }

    /// Timestamp-driven: works correctly even if the app was quit or the Mac slept mid-session.
    private func checkForCompletion() {
        guard session.status == .active else { return }
        if Date.now >= session.endTime {
            session.completedBlocksAtEnd = session.blockCount
            session.status = .awaitingCheckoff
            Sounds.tripleBeep()
        }
    }

    private func endEarly() {
        session.wasEndedEarly = true
        session.completedBlocksAtEnd = Int(elapsed / AppConfig.blockSeconds)
        session.status = .awaitingCheckoff
        Notifications.cancelSessionEnd()
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
