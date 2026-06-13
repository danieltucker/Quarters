import SwiftUI
import SwiftData
import Combine

struct RunningView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: Session
    @State private var now = Date.now
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval { session.elapsed(at: now) }
    private var remaining: TimeInterval { max(0, session.totalDuration - elapsed) }

    private var currentQuarter: Int {
        min(session.blockCount, Int(elapsed / AppConfig.blockSeconds) + 1)
    }
    private var completedQuarters: Int {
        min(session.blockCount, Int(elapsed / AppConfig.blockSeconds))
    }
    private var quarterProgress: Double {
        let intoQuarter = elapsed - Double(completedQuarters) * AppConfig.blockSeconds
        return intoQuarter / AppConfig.blockSeconds
    }

    private var sortedTasks: [FocusTask] {
        session.tasks.sorted { $0.createdAt < $1.createdAt }
    }
    private var doneCount: Int { sortedTasks.filter { $0.isDone }.count }
    private var taskPtsEarned: Int {
        sortedTasks.filter { $0.isDone }.reduce(0) { sum, t in
            sum + (t.isBig ? AppConfig.bigTaskPoints : AppConfig.pointsPerCompletedTask)
        }
    }

    // Minutes until next coin is minted
    private var minsToNextCoin: Int {
        let secsIntoQuarter = elapsed.truncatingRemainder(dividingBy: AppConfig.blockSeconds)
        return max(1, Int(ceil((AppConfig.blockSeconds - secsIntoQuarter) / 60)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── QRing timer ───────────────────────────────────────────
            ZStack {
                QRing(
                    size: 216,
                    totalQuarters: session.blockCount,
                    completedQuarters: completedQuarters,
                    currentProgress: quarterProgress,
                    thickness: 11
                )

                VStack(spacing: 2) {
                    Text(timeString(remaining))
                        .font(.qMono(44, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()

                    Text("Quarter \(currentQuarter) of \(session.blockCount)".uppercased())
                        .font(.qText(11.5, weight: .bold))
                        .kerning(1.0)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.top, 8)

            // ── Caption ───────────────────────────────────────────────
            Group {
                if completedQuarters == 0 {
                    Text("First coin is \(minsToNextCoin) minute\(minsToNextCoin == 1 ? "" : "s") away.")
                } else {
                    Text("\(completedQuarters) coin\(completedQuarters == 1 ? "" : "s") minted — the next is \(minsToNextCoin) minute\(minsToNextCoin == 1 ? "" : "s") away.")
                }
            }
            .font(.qText(12.5))
            .foregroundStyle(Theme.ink2)
            .multilineTextAlignment(.center)
            .padding(.top, 12)
            .padding(.bottom, 18)

            // ── Session goals (scrolls; ring and footer stay fixed) ───
            SectionLabel("Session goals",
                         right: "\(doneCount) of \(sortedTasks.count) done")
                .padding(.bottom, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(sortedTasks) { task in
                            TaskRow(task: task, showBigToggle: true)
                        }

                        // ── Add task inline ───────────────────────────
                        HStack(spacing: 8) {
                            TextField("Add a task…", text: $draft)
                                .textFieldStyle(.plain)
                                .font(.qText(13.5))
                                .foregroundStyle(Theme.ink)
                                .padding(.horizontal, 13)
                                .frame(height: 40)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
                                .overlay(RoundedRectangle(cornerRadius: 11)
                                    .strokeBorder(Theme.line2, lineWidth: 1.5))
                                .focused($inputFocused)
                                .onSubmit(addTask)

                            Button(action: addTask) {
                                QIcon(name: "plus", size: 16, color: Theme.ink2)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11)
                                        .strokeBorder(Theme.line2, lineWidth: 1.5))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 3)
                        .id("addRow")
                    }
                    .padding(.bottom, 4)
                }
                // Keep the add row above the keyboard when it appears.
                .onChange(of: inputFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("addRow", anchor: .bottom)
                    }
                }
            }

            // ── Footer (always visible) ───────────────────────────────
            Button("End early", action: endEarly)
                .buttonStyle(OutlineButtonStyle(tint: Theme.ink2))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .onReceive(tick) { date in
            now = date
            checkForCompletion()
        }
        .onAppear { checkForCompletion() }
    }

    // MARK: - Actions

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let task = FocusTask(title: title)
        context.insert(task)
        task.session = session
        draft = ""
    }

    private func endEarly() {
        session.wasEndedEarly = true
        session.completedBlocksAtEnd = Int(elapsed / AppConfig.blockSeconds)
        session.status = .awaitingCheckoff
        Notifications.cancelSessionEnd()
    }

    private func checkForCompletion() {
        guard session.status == .active else { return }
        if Date.now >= session.endTime {
            session.completedBlocksAtEnd = session.blockCount
            session.status = .awaitingCheckoff
            Sounds.tripleBeep()
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
