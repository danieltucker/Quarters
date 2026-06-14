import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context
    @State private var quarters = 2   // 1–4
    @State private var draft = ""
    @FocusState private var goalFocused: Bool

    @Query(sort: \FocusTask.sortOrder) private var allTasks: [FocusTask]
    private var backlog: [FocusTask] { allTasks.filter { $0.session == nil && !$0.isArchived } }

    // Tasks awaiting their undo window; rendered as an "Undo delete" placeholder
    // and permanently removed when the window lapses.
    @State private var pendingDeletes: Set<PersistentIdentifier> = []
    private var committedBacklog: [FocusTask] { backlog.filter { !pendingDeletes.contains($0.id) } }

    @Query private var dailyLogs: [DailyLog]
    private var streakDays: Int { AppConfig.streak(from: dailyLogs) }

    private var minutes: Int { quarters * 15 }
    private var coinCount: Int { AppConfig.points(forBlocks: quarters) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ── Header ────────────────────────────────────────────
                    SectionLabel("How long can you give?",
                                 right: "\(coinCount) coin\(coinCount == 1 ? "" : "s") + streak bonus")
                        .padding(.bottom, 14)

                    // ── Quarter picker + details ──────────────────────────
                    HStack(alignment: .center, spacing: 22) {
                        QuarterPicker(quarters: $quarters, size: 120)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(quarters) quarter\(quarters == 1 ? "" : "s")")
                                .font(.qDisplay(24))
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText(value: Double(quarters)))

                            (Text("\(minutes) minutes · mints ")
                                .font(.qText(13))
                                .foregroundStyle(Theme.ink2)
                            + Text("\(coinCount) coin\(coinCount == 1 ? "" : "s")")
                                .font(.qText(13, weight: .bold))
                                .foregroundStyle(Theme.ink))
                                .contentTransition(.numericText(value: Double(coinCount)))

                            // Duration chips
                            HStack(spacing: 6) {
                                ForEach([1, 2, 3, 4], id: \.self) { q in
                                    let active = q == quarters
                                    Button { quarters = q } label: {
                                        Text("\(q * 15)m")
                                            .font(.qMono(11.5, weight: .semibold))
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 9)
                                            .background(
                                                active ? Theme.accent : Theme.card,
                                                in: RoundedRectangle(cornerRadius: 7)
                                            )
                                            .foregroundStyle(active ? Theme.onAccent : Theme.ink2)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 7)
                                                    .strokeBorder(
                                                        active ? Theme.accentDeep : Theme.line,
                                                        lineWidth: 1
                                                    )
                                            )
                                            .scaleEffect(active ? 1.07 : 1)
                                            .contentShape(Rectangle())
                                            .hoverLift(1.06)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.line, lineWidth: 1))
                    .qShadow()
                    .animation(.spring(response: 0.32, dampingFraction: 0.75), value: quarters)
                    .padding(.bottom, 20)

                    // ── Goals ─────────────────────────────────────────────
                    SectionLabel("What will you get done?", right: "+1 coin per task")
                        .padding(.bottom, 10)

                    // Add goal input
                    HStack(spacing: 8) {
                        TextField("Add a goal…", text: $draft)
                            .textFieldStyle(.plain)
                            .font(.qText(13.5))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 13)
                            .frame(height: 40)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(Theme.line2, lineWidth: 1.5))
                            .focused($goalFocused)
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
                    .id("addGoal")

                    // Task rows
                    if backlog.isEmpty {
                        Text("No goals yet — name one thing to get done.")
                            .font(.qText(13))
                            .foregroundStyle(Theme.ink3)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 7) {
                            ForEach(Array(backlog.enumerated()), id: \.element.id) { index, task in
                                Group {
                                    if pendingDeletes.contains(task.id) {
                                        UndoDeleteRow { undoDelete(task) }
                                    } else {
                                        TaskRow(task: task, showBigToggle: true, reorderable: true,
                                                onDelete: { requestDelete(task) },
                                                onMoveUp:   index > 0                  ? { moveTask(task, up: true)  } : nil,
                                                onMoveDown: index < backlog.count - 1  ? { moveTask(task, up: false) } : nil)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.88, anchor: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                            }
                        }
                        .animation(.spring(response: 0.38, dampingFraction: 0.8),
                                   value: backlog.map(\.sortOrder))
                        .animation(.easeInOut(duration: 0.25), value: pendingDeletes)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 14)
            }
            // Keep the goal field above the keyboard when it appears.
            .onChange(of: goalFocused) { _, focused in
                guard focused else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("addGoal", anchor: .center)
                }
            }
            .onAppear { initializeSortOrdersIfNeeded() }
            }

            // ── Start button (always pinned to bottom) ────────────────
            VStack(spacing: 0) {
                Button(action: start) {
                    HStack(spacing: 9) {
                        QIcon(name: "play", size: 15, color: Theme.onAccent)
                        Text("Start \(minutes)-minute session")
                    }
                }
                .buttonStyle(AccentButtonStyle(wide: true))
                .disabled(committedBacklog.isEmpty)
                .opacity(committedBacklog.isEmpty ? 0.4 : 1)

                // Streak hint
                HStack(spacing: 4) {
                    Text(streakDays > 0
                         ? "\(streakDays)-day streak · +\(String(format: "%g", AppConfig.streakBonusPercent(forDays: streakDays)))% coins · finish today to keep it"
                         : "Start your streak today")
                        .font(.qText(11.5))
                        .foregroundStyle(Theme.ink2)
                    QIcon(name: "flame", size: 13,
                          color: streakDays > 0 ? Theme.accent : Theme.ink3)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 9)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
        // Tap any empty area to dismiss the keyboard (rows/buttons/field
        // capture their own taps first).
        .contentShape(Rectangle())
        .onTapGesture { goalFocused = false }
    }

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        // New tasks go to the TOP of the list (lowest sortOrder wins).
        let minOrder = backlog.map(\.sortOrder).min() ?? 0
        let task = FocusTask(title: title)
        task.sortOrder = minOrder - 1
        draft = ""
        goalFocused = false   // dismiss keyboard immediately
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            context.insert(task)
        }
        Haptics.pop()
    }

    /// Assign unique sort orders to any group of tasks all sitting at the
    /// default value (0). Runs once on first appearance after a migration.
    private func initializeSortOrdersIfNeeded() {
        let tasks = allTasks.filter { $0.session == nil }
        guard tasks.count > 1, tasks.allSatisfy({ $0.sortOrder == 0 }) else { return }
        let sorted = tasks.sorted { $0.createdAt < $1.createdAt }
        for (i, task) in sorted.enumerated() { task.sortOrder = i }
    }

    /// Swap the task one position up or down in the sorted backlog.
    private func moveTask(_ task: FocusTask, up: Bool) {
        let tasks = backlog   // computed fresh each call
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let targetIdx = up ? idx - 1 : idx + 1
        guard targetIdx >= 0 && targetIdx < tasks.count else { return }
        let other = tasks[targetIdx]
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let temp = task.sortOrder
            task.sortOrder = other.sortOrder
            other.sortOrder = temp
        }
        Haptics.tick()
    }

    private func start() {
        let session = Session(blockCount: quarters)
        context.insert(session)
        for task in committedBacklog { task.session = session }
        Notifications.scheduleSessionEnd(at: session.endTime, blockCount: quarters)
    }

    // MARK: - Undo-delete

    /// Mark a task pending-delete: it becomes an "Undo delete" placeholder for
    /// a few seconds, then is permanently removed if the window lapses.
    private func requestDelete(_ task: FocusTask) {
        let id = task.id
        Haptics.pop()
        withAnimation(.easeInOut(duration: 0.25)) { _ = pendingDeletes.insert(id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard pendingDeletes.contains(id) else { return }   // undone in the meantime
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
}

// MARK: - Shared task row (used in Setup, Running, and Checkoff)

struct TaskRow: View {
    @Bindable var task: FocusTask
    var showBigToggle: Bool = true
    var reorderable: Bool = false
    var onDelete: (() -> Void)? = nil
    var onMoveUp: (() -> Void)? = nil
    var onMoveDown: (() -> Void)? = nil

    // Edit + reorder state
    @State private var showEditModal = false
    @State private var editDraft = ""
    @State private var lifted = false        // picked up for reorder
    @State private var movedSteps = 0        // slots moved this drag

    // One slot ≈ row height + spacing. Crossing this much drag moves one place.
    private let slotHeight: CGFloat = 54

    var body: some View {
        rowContent
            .scaleEffect(lifted ? 1.04 : 1)
            .shadow(color: .black.opacity(lifted ? 0.18 : 0), radius: lifted ? 12 : 0, y: 4)
            .zIndex(lifted ? 10 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: lifted)
            .contentShape(Rectangle())
            // Tap anywhere on the row (outside the controls) opens edit.
            .onTapGesture {
                editDraft = task.title
                showEditModal = true
            }
            // Long-press to pick up, then drag to move one slot at a time.
            // Gating reorder behind the hold means a normal finger-drag is never
            // captured here, so the enclosing ScrollView pans freely.
            .gesture(reorderGesture, including: reorderable ? .all : .subviews)
            .sheet(isPresented: $showEditModal) {
                EditTaskModal(task: task, draft: $editDraft)
            }
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                if !lifted {
                    lifted = true
                    movedSteps = 0
                    Haptics.pop()
                }
                let desired = Int((drag.translation.height / slotHeight).rounded())
                if desired > movedSteps, let down = onMoveDown {
                    down(); movedSteps += 1; Haptics.tick()
                } else if desired < movedSteps, let up = onMoveUp {
                    up(); movedSteps -= 1; Haptics.tick()
                }
            }
            .onEnded { _ in
                lifted = false
                movedSteps = 0
            }
    }

    // MARK: - Row content

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 10) {
            // Checkbox
            Button {
                task.isDone.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(task.isDone ? .clear : Theme.line2, lineWidth: 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(task.isDone ? Theme.green : .clear)
                        )
                    if task.isDone {
                        QIcon(name: "check", size: 12, color: Theme.card)
                    }
                }
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Title — wraps instead of truncating
            Text(task.title)
                .font(.qText(13.5))
                .foregroundStyle(task.isDone ? Theme.ink2 : Theme.ink)
                .strikethrough(task.isDone, color: Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Carried badge
            if task.carriedOver {
                Text("CARRIED")
                    .font(.qMono(10, weight: .bold))
                    .foregroundStyle(Theme.coinDeep)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 7)
                    .background(Theme.coinSoft, in: RoundedRectangle(cornerRadius: 5))
            }

            // Big task toggle
            if showBigToggle {
                Button {
                    task.isBig.toggle()
                } label: {
                    QIcon(name: "bolt", size: 14,
                          color: task.isBig ? Theme.accent : Theme.ink3)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Mark as big task (+3 coins)")

                if task.isBig {
                    Text("+3")
                        .font(.qMono(10, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 5)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 4))
                }
            }

            // Explicit delete button (shown in setup / carried tasks)
            if let onDelete {
                Button(action: onDelete) {
                    QIcon(name: "x", size: 13, color: Theme.ink3)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(
                    task.isDone ? Theme.green.opacity(0.5) : Theme.line,
                    lineWidth: 1
                )
        )
        .hoverLift(1.0)
    }
}

// MARK: - Undo-delete placeholder
// Holds a deleted task's slot for the undo window: a dashed outline that
// fades out when the window lapses or the row is restored.

struct UndoDeleteRow: View {
    var onUndo: () -> Void

    var body: some View {
        Button(action: onUndo) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .semibold))
                Text("Undo delete")
                    .font(.qText(13, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Theme.ink3)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Theme.line2,
                                  style: StrokeStyle(lineWidth: 1.5, dash: [5]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit task modal

struct EditTaskModal: View {
    @Bindable var task: FocusTask
    @Binding var draft: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit task")
                .font(.qText(16, weight: .bold))
                .foregroundStyle(Theme.ink)

            TextField("Task name", text: $draft)
                .textFieldStyle(.plain)
                .font(.qText(14))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 13)
                .frame(height: 46)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(Theme.accent, lineWidth: 1.5)
                )
                .focused($isFocused)
                .onSubmit { save() }

            HStack(spacing: 10) {
                // Archive moves the task out of the active list
                Button {
                    task.isArchived = true
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 11))
                        Text("Archive")
                            .font(.qText(13))
                    }
                    .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)

                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineButtonStyle(tint: Theme.ink2))
                Button("Save") { save() }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .presentationDetents([.height(216)])
        .presentationBackground(.ultraThinMaterial)
        .presentationCornerRadius(24)
        .onAppear { isFocused = true }
    }

    private func save() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { task.title = trimmed }
        dismiss()
    }
}
