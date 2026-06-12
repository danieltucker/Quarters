import SwiftUI
import SwiftData
import AppKit

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
            // ── Titlebar (sits in the hidden-title-bar area) ─────────────
            // TitlebarConfigurator gives the window an empty unified toolbar,
            // which makes the title bar ~52pt tall with the traffic lights
            // vertically centered in it. This strip matches that height so
            // the wordmark and coin chip center on the same line.
            HStack {
                QWordmark(size: 17)
                Spacer()
                QCoinChip(balance: balance)
            }
            .padding(.leading, 76)
            .padding(.trailing, 18)
            .frame(height: 52)
            .padding(.bottom, 2)

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
        .background(Theme.bg)
        .background { TitlebarConfigurator() }
        // .hiddenTitleBar still reserves the title bar strip as safe area;
        // extend into it so the header row sits beside the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .onAppear(perform: seedRewardsIfNeeded)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { t in
                TabSegment(tab: t, isActive: tab == t) { tab = t }
            }
        }
        .padding(4)
        .background(Theme.bg2, in: RoundedRectangle(cornerRadius: 11))
    }

    private func seedRewardsIfNeeded() {
        guard allRewards.isEmpty else { return }
        Reward.seedDefaults(into: context)
        try? context.save()
    }
}

// MARK: - Tab segment
// Owns hover state so inactive tabs brighten under the cursor.

private struct TabSegment: View {
    let tab: AppTab
    let isActive: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(tab.rawValue)
                .font(.qText(13, weight: .semibold))
                .foregroundStyle(isActive || hovering ? Theme.ink : Theme.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.card)
                            .qShadow()
                    } else if hovering {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.card.opacity(0.45))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Titlebar configurator
// An empty unified toolbar makes the title bar ~52pt tall, which vertically
// centers the traffic lights with comfortable padding. viewDidMoveToWindow
// guarantees window access (unlike makeNSView, where .window is still nil).

private struct TitlebarConfigurator: NSViewRepresentable {
    final class AccessorView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            DispatchQueue.main.async {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.titlebarSeparatorStyle = .none
                if window.toolbar == nil {
                    window.toolbarStyle = .unified
                    window.toolbar = NSToolbar()
                }
            }
        }
    }

    func makeNSView(context: Context) -> NSView { AccessorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

