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

    var body: some View {
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
                // The unchecked box is a .clear fill, which doesn't hit-test —
                // without this only the 1.5pt border ring is clickable.
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Title
            Text(task.title)
                .font(.qText(13.5))
                .foregroundStyle(task.isDone ? Theme.ink2 : Theme.ink)
                .strikethrough(task.isDone, color: Theme.ink2)
                .lineLimit(1)
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

            // Delete
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
        .hoverLift(1.0)   // shadow only; scaling rows in a list reads as jitter
    }
}
