import SwiftUI
import SwiftData
import Combine

struct RunningView: View {
    @Environment(\.modelContext) private var context
    @Bindable var session: Session
    @State private var now = Date.now
    @State private var draft = ""
    @FocusState private var inputFocused: Bool
    @State private var pendingDeletes: Set<PersistentIdentifier> = []
    @State private var showReorder = false

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
        session.tasks
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder < $1.sortOrder }
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
            // Everything above the footer scrolls, so the ring can move out
            // of the way in landscape where it would otherwise hide the goals.
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // ── QRing timer ───────────────────────────────
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

                        // ── Caption ───────────────────────────────────
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

                        // ── Session goals ─────────────────────────────
                        HStack {
                            SectionLabel("Session goals",
                                         right: sortedTasks.count > 1 ? nil : "\(doneCount) of \(sortedTasks.count) done")
                            if sortedTasks.count > 1 {
                                Spacer()
                                Text("\(doneCount)/\(sortedTasks.count)")
                                    .font(.qText(12, weight: .semibold))
                                    .foregroundStyle(Theme.green)
                                Button("Reorder") { showReorder = true }
                                    .buttonStyle(OutlineButtonStyle(tint: Theme.ink2))
                            }
                        }
                        .padding(.bottom, 10)

                        // ── Add task inline (at top, matching SetupView) ──
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
                        .padding(.bottom, 10)
                        .id("addRow")

                        VStack(spacing: 7) {
                            ForEach(sortedTasks) { task in
                                Group {
                                    if pendingDeletes.contains(task.id) {
                                        UndoDeleteRow { undoDelete(task) }
                                    } else {
                                        TaskRow(task: task, showBigToggle: true,
                                                onDelete: { requestDelete(task) })
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .animation(.spring(response: 0.38, dampingFraction: 0.8),
                                   value: sortedTasks.map(\.sortOrder))
                        .animation(.easeInOut(duration: 0.25), value: pendingDeletes)
                        .padding(.bottom, 4)
                    }
                }
                // Scroll input into view when keyboard appears.
                .onChange(of: inputFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("addRow", anchor: .top)
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
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
        .sheet(isPresented: $showReorder) {
            ReorderSheet(tasks: sortedTasks) { ordered in
                for (i, task) in ordered.enumerated() { task.sortOrder = i }
            }
        }
        .onReceive(tick) { date in
            now = date
            checkForCompletion()
        }
        // Refresh the Live Activity's "Quarter X of Y" + progress each time a
        // quarter is minted (the countdown itself ticks on its own).
        .onChange(of: completedQuarters) { _, completed in
            LiveActivity.update(startDate: session.startedAt,
                                endDate: session.endTime,
                                totalQuarters: session.blockCount,
                                completedQuarters: completed)
        }
        .onAppear {
            initializeTaskSortOrdersIfNeeded()
            checkForCompletion()
        }
    }

    // MARK: - Actions

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let minOrder = sortedTasks.map(\.sortOrder).min() ?? 0
        let task = FocusTask(title: title)
        task.sortOrder = minOrder - 1
        task.session = session
        draft = ""
        inputFocused = false   // dismiss keyboard
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            context.insert(task)
        }
        Haptics.pop()
    }

    /// Assign unique sort orders to session tasks that all have the default (0).
    private func initializeTaskSortOrdersIfNeeded() {
        let tasks = session.tasks
        guard tasks.count > 1, tasks.allSatisfy({ $0.sortOrder == 0 }) else { return }
        let sorted = tasks.sorted { $0.createdAt < $1.createdAt }
        for (i, task) in sorted.enumerated() { task.sortOrder = i }
    }

    // MARK: - Undo-delete

    private func requestDelete(_ task: FocusTask) {
        let id = task.id
        Haptics.pop()
        withAnimation(.easeInOut(duration: 0.25)) { _ = pendingDeletes.insert(id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard pendingDeletes.contains(id) else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                context.delete(task)
                pendingDeletes.remove(id)
            }
        }
    }

    private func undoDelete(_ task: FocusTask) {
        Haptics.tick()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            pendingDeletes.remove(task.id)
        }
    }

    private func endEarly() {
        session.wasEndedEarly = true
        session.completedBlocksAtEnd = Int(elapsed / AppConfig.blockSeconds)
        session.status = .awaitingCheckoff
        Notifications.cancelSessionEnd()
        LiveActivity.end()
    }

    private func checkForCompletion() {
        guard session.status == .active else { return }
        if Date.now >= session.endTime {
            session.completedBlocksAtEnd = session.blockCount
            session.status = .awaitingCheckoff
            Sounds.tripleBeep()
            LiveActivity.end()
        }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
