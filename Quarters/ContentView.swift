import SwiftUI
import SwiftData

enum AppTab: String, CaseIterable {
    case focus   = "Focus"
    case rewards = "Rewards"
    case ledger  = "Ledger"
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .focus

    @Query private var ledger: [LedgerEntry]
    @Query(filter: #Predicate<Session> {
        $0.statusRaw == "active" || $0.statusRaw == "awaitingCheckoff"
    }) private var openSessions: [Session]
    @Query private var allRewards: [Reward]

    private var balance: Int { ledger.reduce(0) { $0 + $1.delta } }

    var body: some View {
        VStack(spacing: 0) {
            // ── Titlebar ────────────────────────────────────────────────
            HStack {
                QWordmark(size: 17)
                Spacer()
                QCoinChip(balance: balance)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Tab switcher ─────────────────────────────────────────────
            tabBar
                .padding(.horizontal, 18)
                .padding(.bottom, 10)

            // ── Content ──────────────────────────────────────────────────
            Group {
                switch tab {
                case .focus:
                    if let session = openSessions.first {
                        if session.status == .active {
                            RunningView(session: session)
                        } else {
                            CheckoffView(session: session)
                        }
                    } else {
                        SetupView()
                    }
                case .rewards:
                    RewardsView(balance: balance)
                case .ledger:
                    LedgerView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 8)
        .background(Theme.bg)
        .navigationTitle("")
        .onAppear(perform: seedRewardsIfNeeded)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    tab = t
                } label: {
                    Text(t.rawValue)
                        .font(.qText(13, weight: .semibold))
                        .foregroundStyle(tab == t ? Theme.ink : Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if tab == t {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.card)
                                    .qShadow()
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.bg2, in: RoundedRectangle(cornerRadius: 11))
    }

    private func seedRewardsIfNeeded() {
        guard allRewards.isEmpty else { return }
        Reward.seedDefaults(into: context)
    }
}
