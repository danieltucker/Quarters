import SwiftUI
import SwiftData

// Sheet target: wraps an optional Reward (nil = create new) so the sheet can
// be driven by sheet(item:), which builds the form with the right reward —
// sheet(isPresented:) raced against the editingReward state write and opened
// a blank "new reward" form when editing.
private struct RewardFormTarget: Identifiable {
    let id = UUID()
    let reward: Reward?
}

struct RewardsView: View {
    @Environment(\.modelContext) private var context
    let balance: Int

    @State private var editMode = false
    @State private var formTarget: RewardFormTarget?

    @Query(filter: #Predicate<Reward> { !$0.isArchived },
           sort: \Reward.sortOrder) private var rewards: [Reward]
    @Query(sort: \LedgerEntry.timestamp, order: .reverse) private var ledger: [LedgerEntry]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Header ─────────────────────────────────────────────
                HStack {
                    SectionLabel(editMode ? "Editing rewards" : "Spend your coins")
                    Spacer()
                    Button(editMode ? "Done" : "Edit") { editMode.toggle() }
                        .buttonStyle(OutlineButtonStyle())
                }
                .padding(.bottom, 14)

                // ── Card grid ──────────────────────────────────────────
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(rewards) { reward in
                        rewardCard(reward)
                    }
                    if editMode {
                        addCard
                    }
                }
                .padding(.bottom, 14)

                // ── Footer hint ────────────────────────────────────────
                if !editMode, let cheapest = rewards.filter({ balance < $0.cost }).min(by: { $0.cost < $1.cost }) {
                    let quartersNeeded = Int(ceil(Double(cheapest.cost - balance) / 10.0))
                    HStack(spacing: 8) {
                        QCoin(size: 14)
                        Text("About \(quartersNeeded) more quarter\(quartersNeeded == 1 ? "" : "s") covers \(cheapest.name).")
                            .font(.qText(12))
                            .foregroundStyle(Theme.ink2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Theme.line, lineWidth: 1))
                    .padding(.bottom, 14)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
        }
        .sheet(item: $formTarget) { target in
            RewardForm(reward: target.reward, nextSortOrder: rewards.count)
        }
    }

    // MARK: - Reward card

    private func rewardCard(_ reward: Reward) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon tile + edit controls
            HStack(alignment: .top) {
                Text(reward.icon)
                    .font(.system(size: 26))
                    .frame(width: 48, height: 48)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 14))

                Spacer()

                if editMode {
                    Button {
                        formTarget = RewardFormTarget(reward: reward)
                    } label: {
                        QIcon(name: "edit", size: 13, color: Theme.ink2)
                    }
                    .buttonStyle(IconButtonStyle())

                    Button {
                        reward.isArchived = true
                    } label: {
                        QIcon(name: "x", size: 12, color: Theme.accent)
                    }
                    .buttonStyle(IconButtonStyle(tint: Theme.accent))
                }
            }

            Text(reward.name)
                .font(.qText(14, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text(reward.detail)
                .font(.qText(11))
                .foregroundStyle(Theme.ink2)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                .lineLimit(2)

            if editMode {
                HStack(spacing: 4) {
                    QCoin(size: 12)
                    Text("\(reward.cost) coins")
                        .font(.qMono(12))
                        .foregroundStyle(Theme.accent)
                }
            } else {
                redeemArea(reward)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 1))
        .hoverLift()
    }

    @ViewBuilder
    private func redeemArea(_ reward: Reward) -> some View {
        if balance >= reward.cost {
            // Affordable: copper redeem pill
            Button { redeem(reward) } label: {
                HStack(spacing: 5) {
                    QCoin(size: 13)
                    Text("\(reward.cost)")
                        .font(.qMono(12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Theme.accentDeep.opacity(0.4), lineWidth: 1))
                .contentShape(Rectangle())
                .hoverLift(1.03)
            }
            .buttonStyle(.plain)
        } else {
            // Saving up: coin-gold progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.coinSoft)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.coin)
                            .frame(width: geo.size.width * min(1, Double(balance) / Double(reward.cost)))
                    }
                }
                .frame(height: 5)

                HStack(spacing: 4) {
                    QCoin(size: 11)
                    Text("\(balance) / \(reward.cost) · saving up")
                        .font(.qMono(10))
                        .foregroundStyle(Theme.coinDeep)
                }
            }
        }
    }

    private var addCard: some View {
        Button {
            formTarget = RewardFormTarget(reward: nil)
        } label: {
            VStack {
                QIcon(name: "plus", size: 20, color: Theme.ink3)
                Text("Add reward")
                    .font(.qText(13, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.line2, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            )
            .contentShape(Rectangle())
            .hoverLift(1.01)
        }
        .buttonStyle(.plain)
    }

    private func redeem(_ reward: Reward) {
        context.insert(LedgerEntry(delta: -reward.cost,
                                   reason: "Redeemed: \(reward.icon) \(reward.name)"))
    }
}

// MARK: - Add / edit form

struct RewardForm: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let reward: Reward?
    let nextSortOrder: Int

    @State private var icon     = "🎁"
    @State private var name     = ""
    @State private var detail   = ""
    @State private var costText = ""
    @State private var showingEmojiPicker = false

    private static let emojiOptions: [String] = [
        "☕", "🍵", "🍫", "🍪", "🍩", "🧁", "🍦", "🍕",
        "🍔", "🌮", "🍿", "🍺", "🍷", "🥤", "🍎", "🧋",
        "🚶", "🏃", "🚴", "🧘", "🏋️", "⚽", "🏖️", "🌳",
        "🎮", "🕹️", "🎬", "📺", "🎵", "🎧", "🎸", "🎨",
        "📖", "📚", "🧩", "♟️", "🛁", "💆", "😴", "🛋️",
        "🌐", "📱", "💻", "🛍️", "💸", "🎁", "⭐", "🏆",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(reward == nil ? "New reward" : "Edit reward")

            HStack(alignment: .top, spacing: 12) {
                // Emoji tile → curated picker in a popover
                Button { showingEmojiPicker = true } label: {
                    Text(icon)
                        .font(.system(size: 30))
                        .frame(width: 64, height: 64)
                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Theme.line2, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .hoverLift(1.04)
                .help("Choose an icon")
                .popover(isPresented: $showingEmojiPicker, arrowEdge: .bottom) {
                    emojiGrid
                }

                VStack(spacing: 8) {
                    formField("Reward name", text: $name)

                    HStack(spacing: 8) {
                        formField("Cost", text: $costText)
                            .frame(width: 90)
                        QCoin(size: 15)
                        Text("coins")
                            .font(.qText(12.5))
                            .foregroundStyle(Theme.ink2)
                        Spacer()
                    }
                }
            }

            formField("Short description (optional)", text: $detail)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineButtonStyle())
                Button("Save reward", action: save)
                    .buttonStyle(AccentButtonStyle())
                    .disabled(!valid)
                    .opacity(valid ? 1 : 0.4)
            }
            .padding(.top, 2)
        }
        .padding(22)
        .frame(width: 380)
        .background(Theme.bg)
        .onAppear {
            guard let r = reward else { return }
            icon = r.icon; name = r.name; detail = r.detail; costText = String(r.cost)
        }
    }

    private var emojiGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 4), count: 8),
                  spacing: 4) {
            ForEach(Self.emojiOptions, id: \.self) { emoji in
                Button {
                    icon = emoji
                    showingEmojiPicker = false
                } label: {
                    Text(emoji)
                        .font(.system(size: 21))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(emoji == icon ? Theme.accentSoft : .clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
    }

    private func formField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.qText(13))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Theme.line2, lineWidth: 1))
    }

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Int(costText) ?? 0) > 0
    }

    private func save() {
        let cost      = Int(costText) ?? 0
        let finalIcon = icon.trimmingCharacters(in: .whitespaces).isEmpty ? "🎁" : icon
        if let r = reward {
            r.icon = finalIcon; r.name = name; r.detail = detail; r.cost = cost
        } else {
            context.insert(Reward(icon: finalIcon, name: name, detail: detail,
                                  cost: cost, sortOrder: nextSortOrder))
        }
        dismiss()
    }
}
