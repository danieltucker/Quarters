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

    @State private var showReorder = false

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
                    HStack {
                        SectionLabel("What will you get done?",
                                     right: backlog.count > 1 ? nil : "+1 coin per task")
                        if backlog.count > 1 {
                            Spacer()
                            Button("Reorder") { showReorder = true }
                                .buttonStyle(OutlineButtonStyle(tint: Theme.ink2))
                        }
                    }
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
                            ForEach(backlog) { task in
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

            // ── Start button (pinned to the very bottom) ──────────────
            // Streak hint sits above the button so the button is the last
            // element, flush to the bottom edge (tighter on iOS).
            VStack(spacing: 0) {
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
                .padding(.bottom, 9)

                Button(action: start) {
                    HStack(spacing: 9) {
                        QIcon(name: "play", size: 15, color: Theme.onAccent)
                        Text("Start \(minutes)-minute session")
                    }
                }
                .buttonStyle(AccentButtonStyle(wide: true))
                .disabled(committedBacklog.isEmpty)
                .opacity(committedBacklog.isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, startButtonBottomPadding)
        }
        // Tap any empty area to dismiss the keyboard (rows/buttons/field
        // capture their own taps first).
        .contentShape(Rectangle())
        .onTapGesture { goalFocused = false }
        .sheet(isPresented: $showReorder) {
            ReorderSheet(tasks: backlog) { ordered in
                for (i, task) in ordered.enumerated() { task.sortOrder = i }
            }
        }
    }

    // iOS: hug the bottom edge (safe area still keeps it off the home
    // indicator). macOS: keep the roomier inset.
    private var startButtonBottomPadding: CGFloat {
        #if os(iOS)
        6
        #else
        22
        #endif
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
    var onDelete: (() -> Void)? = nil

    @State private var showEditModal = false
    @State private var editDraft = ""

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            // Tap anywhere on the row (outside the controls) opens edit.
            // No drag gesture lives on the row, so the ScrollView scrolls
            // freely; reordering happens in a dedicated sheet.
            .onTapGesture {
                editDraft = task.title
                showEditModal = true
            }
            .sheet(isPresented: $showEditModal) {
                EditTaskModal(task: task, draft: $editDraft)
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

// MARK: - Reorder sheet
// Native List + .onMove gives real drag-to-reorder that works on both iOS and
// macOS. Reordering mutates a local copy for smoothness; the new order is
// written back to sortOrder on Done.

struct ReorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var items: [FocusTask]
    let onCommit: ([FocusTask]) -> Void

    init(tasks: [FocusTask], onCommit: @escaping ([FocusTask]) -> Void) {
        _items = State(initialValue: tasks)
        self.onCommit = onCommit
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Reorder goals")
                    .font(.qText(16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Button("Done") {
                    onCommit(items)
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            List {
                ForEach(items) { task in
                    HStack(spacing: 10) {
                        if task.isBig {
                            QIcon(name: "bolt", size: 13, color: Theme.accent)
                        }
                        Text(task.title)
                            .font(.qText(14))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Theme.card)
                    .listRowSeparatorTint(Theme.line)
                }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
        }
        .frame(minWidth: 340, minHeight: 360)
        .background(Theme.bg)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
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
