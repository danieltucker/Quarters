import SwiftUI
import SwiftData

struct SetupView: View {
    @Environment(\.modelContext) private var context
    @State private var quarters = 2   // 1–4
    @State private var draft = ""
    @FocusState private var goalFocused: Bool

    @Query(sort: \FocusTask.createdAt) private var allTasks: [FocusTask]
    private var backlog: [FocusTask] { allTasks.filter { $0.session == nil } }

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
                            ForEach(backlog) { task in
                                TaskRow(task: task, showBigToggle: true, onDelete: {
                                    context.delete(task)
                                })
                            }
                        }
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
                .disabled(backlog.isEmpty)
                .opacity(backlog.isEmpty ? 0.4 : 1)

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
    }

    private func addTask() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        context.insert(FocusTask(title: title))
        try? context.save()
        draft = ""
    }

    private func start() {
        let session = Session(blockCount: quarters)
        context.insert(session)
        for task in backlog { task.session = session }
        Notifications.scheduleSessionEnd(at: session.endTime, blockCount: quarters)
    }
}

// MARK: - Shared task row (used in Setup, Running, and Checkoff)

struct TaskRow: View {
    @Bindable var task: FocusTask
    var showBigToggle: Bool = true
    var onDelete: (() -> Void)? = nil

    // Swipe gesture state
    @State private var dragX: CGFloat = 0

    // Long-press / edit state
    @State private var showEditModal = false
    @State private var editDraft = ""
    @State private var longPressScale: CGFloat = 1.0

    private let swipeThreshold: CGFloat = 72

    var body: some View {
        ZStack {
            // ── Swipe reveal backgrounds ───────────────────────────────
            // Right-swipe: green complete background
            RoundedRectangle(cornerRadius: 11)
                .fill(Theme.green.opacity(min(0.28, dragX / (swipeThreshold * 1.5))))
                .overlay(alignment: .leading) {
                    QIcon(name: "check", size: 18, color: Theme.green)
                        .padding(.leading, 16)
                        .opacity(min(1, dragX / swipeThreshold))
                        .scaleEffect(0.4 + 0.6 * min(1, dragX / swipeThreshold))
                }
                .opacity(dragX > 0 ? 1 : 0)

            // Left-swipe: red delete background
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.red.opacity(min(0.22, -dragX / (swipeThreshold * 1.5))))
                .overlay(alignment: .trailing) {
                    QIcon(name: "trash", size: 17, color: Color.red)
                        .padding(.trailing, 16)
                        .opacity(min(1, -dragX / swipeThreshold))
                        .scaleEffect(0.4 + 0.6 * min(1, -dragX / swipeThreshold))
                }
                .opacity(dragX < 0 ? 1 : 0)

            // ── Row content ───────────────────────────────────────────
            rowContent
                .offset(x: dragX)
                .scaleEffect(longPressScale)
                .animation(.spring(response: 0.15, dampingFraction: 0.5), value: longPressScale)
        }
        // Swipe gesture
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { v in
                    let dx = v.translation.width
                    let dy = v.translation.height
                    // Only commit to horizontal swipes
                    guard abs(dx) > abs(dy) else { return }
                    // Right swipe blocked if already done
                    if dx > 0 && task.isDone { return }
                    // Left swipe blocked if no delete handler
                    if dx < 0 && onDelete == nil { return }
                    dragX = dx
                }
                .onEnded { v in
                    let dx = v.translation.width
                    if dx >= swipeThreshold && !task.isDone {
                        // Complete ✓
                        Haptics.softPop()
                        task.isDone = true
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragX = 0 }
                    } else if dx <= -swipeThreshold, let del = onDelete {
                        // Delete ✕
                        Haptics.pop()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { dragX = -420 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { del() }
                    } else {
                        // Spring back
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.70)) { dragX = 0 }
                    }
                }
        )
        // Long press to edit
        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 10) {
            editDraft = task.title
            Haptics.pop()
            // Pop scale up then settle
            withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { longPressScale = 1.05 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { longPressScale = 1.0 }
                showEditModal = true
            }
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

// MARK: - Edit task modal

struct EditTaskModal: View {
    @Bindable var task: FocusTask
    @Binding var draft: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineButtonStyle(tint: Theme.ink2))
                Button("Save") { save() }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .presentationDetents([.height(196)])
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
