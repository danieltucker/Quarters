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

    @State private var coinFlights: [CoinFlightSpec] = []
    @State private var gainAmount: Int?

    private var balance: Int { ledger.reduce(0) { $0 + $1.delta } }

    var body: some View {
        VStack(spacing: 0) {
            // ── Titlebar (sits in the hidden-title-bar area) ─────────────
            // TitlebarConfigurator gives the window an empty unified toolbar,
            // which makes the title bar ~52pt tall with the traffic lights
            // vertically centered in it. This strip matches that height so
            // the coin chip centers on the same line.
            HStack {
                Spacer()
                QCoinChip(balance: balance)
            }
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
        .overlay { coinFlightLayer }
        // .hiddenTitleBar still reserves the title bar strip as safe area;
        // extend into it so the header row sits beside the traffic lights.
        .ignoresSafeArea(.container, edges: .top)
        .onAppear(perform: seedRewardsIfNeeded)
        .onReceive(NotificationCenter.default.publisher(for: .qCoinsCollected)) { note in
            guard let amount = note.userInfo?["amount"] as? Int else { return }
            playCoinFlight(amount: amount)
        }
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

    // MARK: - Coin flight

    private var coinFlightLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(coinFlights) { flight in
                    CoinFlightView(
                        start: CGPoint(x: geo.size.width / 2 + flight.dx,
                                       y: geo.size.height * 0.55),
                        target: CGPoint(x: geo.size.width - 52, y: 26),
                        delay: flight.delay
                    ) {
                        coinFlights.removeAll { $0.id == flight.id }
                    }
                }

                if let gain = gainAmount {
                    Text("+\(gain)")
                        .font(.qMono(14, weight: .bold))
                        .foregroundStyle(Theme.coinDeep)
                        .position(x: geo.size.width - 52, y: 56)
                        .transition(.offset(y: 12).combined(with: .opacity))
                }
            }
            .allowsHitTesting(false)
        }
    }

    private func playCoinFlight(amount: Int) {
        let count = min(max(amount / 8, 3), 8)
        for i in 0..<count {
            coinFlights.append(CoinFlightSpec(delay: Double(i) * 0.07,
                                              dx: CGFloat.random(in: -60...60)))
        }
        // "+N" pops in as the first coins arrive, lingers, then fades.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5)) {
            gainAmount = amount
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.4)) { gainAmount = nil }
        }
    }
}

// MARK: - Coin flight pieces

private struct CoinFlightSpec: Identifiable {
    let id = UUID()
    let delay: Double
    let dx: CGFloat
}

private struct CoinFlightView: View {
    let start: CGPoint
    let target: CGPoint
    let delay: Double
    let onDone: () -> Void
    @State private var progress: CGFloat = 0

    var body: some View {
        QCoin(size: 16)
            .modifier(CoinFlightEffect(progress: progress, start: start, target: target))
            .onAppear {
                withAnimation(.easeIn(duration: 0.6).delay(delay)) { progress = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.75) { onDone() }
            }
    }
}

// Animatable so SwiftUI interpolates `progress` per frame and the position
// math below shapes the path — x leads (smoothstep) while y lags (power
// curve), so coins swing outward before arcing up into the chip.
private struct CoinFlightEffect: ViewModifier, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let target: CGPoint

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - 0.3 * progress)
            .opacity(progress < 0.85 ? 1 : Double(1 - (progress - 0.85) / 0.15))
            .position(
                x: start.x + (target.x - start.x) * progress * progress * (3 - 2 * progress),
                y: start.y + (target.y - start.y) * pow(progress, 1.5)
            )
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

