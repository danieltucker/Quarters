import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif

enum AppTab: String, CaseIterable {
    case focus   = "Focus"
    case rewards = "Rewards"
    case archive = "Archive"
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var tab: AppTab = .focus
    @Namespace private var tabNS
    @State private var tabBarWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    @Query private var ledger: [LedgerEntry]
    @Query(filter: #Predicate<Session> {
        $0.statusRaw == "active" || $0.statusRaw == "awaitingCheckoff"
    }) private var openSessions: [Session]
    @Query private var allRewards: [Reward]

    @State private var coinFlights: [CoinFlightSpec] = []
    @State private var gainAmount: Int?

    @State private var celebration: RedeemCelebration?
    @State private var celebrationHits: CGFloat = 0
    @State private var celebrationToken = UUID()
    @State private var spendFlights: [CoinFlightSpec] = []

    // The chip shows `displayedBalance`, which lags the true balance during a
    // coin flight so it can tick up/down by one as each coin lands. When no
    // flight is running it tracks `balance` exactly.
    @State private var displayedBalance = 0
    @State private var animatingBalance = false

    @State private var showCoinEditor = false

    private var balance: Int { ledger.reduce(0) { $0 + $1.delta } }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header strip ─────────────────────────────────────────────
            // macOS: sits in the hidden-title-bar area. TitlebarConfigurator
            // gives the window an empty unified toolbar (~52pt tall, traffic
            // lights centered); this strip matches that height. iOS: a plain
            // padded header row under the status bar.
            HStack {
                Spacer()
                QCoinChip(balance: displayedBalance)
                    // Hidden utility: triple-tap the balance to set it directly.
                    .onTapGesture(count: 3) { showCoinEditor = true }
            }
            .padding(.trailing, 18)
            .modifier(HeaderStripStyle())
            .sheet(isPresented: $showCoinEditor) {
                CoinEditorSheet(currentBalance: balance, onSave: adjustBalance(to:))
            }

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
                case .archive:
                    ArchiveView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(
                GeometryReader { g in
                    Color.clear
                        .onAppear { contentWidth = g.size.width }
                        .onChange(of: g.size.width) { _, w in contentWidth = w }
                }
            )
            // Edge-swipe to change tabs: a horizontal swipe starting near the
            // left or right edge moves between Focus / Rewards / Archive.
            // Simultaneous + edge-gated so it never steals vertical scroll or
            // the quarter dial in the center.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { v in
                        let dx = v.translation.width
                        let dy = v.translation.height
                        guard abs(dx) > 60, abs(dx) > abs(dy) * 1.6 else { return }
                        let startX = v.startLocation.x
                        if dx > 0 && startX < 56 {
                            switchTab(by: -1)            // swipe right from left edge → previous
                        } else if dx < 0 && startX > contentWidth - 56 {
                            switchTab(by: 1)             // swipe left from right edge → next
                        }
                    }
            )
        }
        .background(Theme.bg)
        .modifier(WindowChrome())
        .overlay { coinFlightLayer }
        .overlay { celebrationLayer }
        .onAppear {
            seedRewardsIfNeeded()
            displayedBalance = balance
        }
        // Snap to the real balance for any change that isn't an in-flight
        // coin animation (e.g. launch, or a redeem with the popup disabled).
        .onChange(of: balance) { _, new in
            if !animatingBalance { displayedBalance = new }
        }
        .onReceive(NotificationCenter.default.publisher(for: .qCoinsCollected)) { note in
            guard let amount = note.userInfo?["amount"] as? Int else { return }
            playCoinFlight(amount: amount)
        }
        .onReceive(NotificationCenter.default.publisher(for: .qCoinsSpent)) { note in
            guard let amount = note.userInfo?["amount"] as? Int,
                  let icon = note.userInfo?["icon"] as? String,
                  let name = note.userInfo?["name"] as? String else { return }
            playRedeem(amount: amount, icon: icon, name: name)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { t in
                TabSegment(tab: t, isActive: tab == t, ns: tabNS)
            }
        }
        .padding(4)
        .background(Theme.bg2, in: RoundedRectangle(cornerRadius: 11))
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { tabBarWidth = g.size.width }
                    .onChange(of: g.size.width) { _, w in tabBarWidth = w }
            }
        )
        .contentShape(Rectangle())
        // One gesture serves both tap and slide: a still touch selects on
        // release; a moving touch sweeps the selection as the finger crosses
        // segments. Light grain while sliding, a solid thunk on each new tab.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    Haptics.slide()
                    selectTab(atX: value.location.x)
                }
                .onEnded { value in selectTab(atX: value.location.x) }
        )
    }

    private func selectTab(atX x: CGFloat) {
        guard tabBarWidth > 0 else { return }
        let tabs = AppTab.allCases
        let idx = min(tabs.count - 1, max(0, Int(x / (tabBarWidth / CGFloat(tabs.count)))))
        let target = tabs[idx]
        guard target != tab else { return }
        // Underdamped spring → the pill slides and wiggles as it stops.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) { tab = target }
        Haptics.land()
    }

    private func switchTab(by delta: Int) {
        let tabs = AppTab.allCases
        guard let idx = tabs.firstIndex(of: tab) else { return }
        let next = idx + delta
        guard next >= 0 && next < tabs.count else { return }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) { tab = tabs[next] }
        Haptics.land()
    }

    private func seedRewardsIfNeeded() {
        guard allRewards.isEmpty else { return }
        Reward.seedDefaults(into: context)
        try? context.save()
    }

    /// Set the balance directly by inserting an adjusting ledger entry, so the
    /// existing history is preserved and the change is recorded as a "Coin update".
    private func adjustBalance(to newValue: Int) {
        let delta = max(0, newValue) - balance
        guard delta != 0 else { return }
        context.insert(LedgerEntry(delta: delta, reason: "Coin update"))
    }

    // MARK: - Coin flight

    private var coinFlightLayer: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(coinFlights) { flight in
                    CoinFlightView(
                        // Launch from behind the Collect button, pinned at the
                        // bottom, so coins appear to spill out and fly up to the chip.
                        start: CGPoint(x: geo.size.width / 2 + flight.dx,
                                       y: geo.size.height - 48),
                        target: CGPoint(x: geo.size.width - 52, y: 26),
                        delay: flight.delay
                    ) {
                        coinFlights.removeAll { $0.id == flight.id }
                        Sounds.clink()
                        Haptics.coin()
                        // Each coin that lands ticks the counter up one.
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            displayedBalance += 1
                        }
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

    // MARK: - Redeem celebration

    @ViewBuilder
    private var celebrationLayer: some View {
        if let celebration {
            GeometryReader { geo in
                ZStack {
                    // Backdrop: dims the app and blocks a second buy click.
                    // ignoresSafeArea so it covers the title-bar strip too.
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .onTapGesture { dismissCelebration() }
                        .transition(.opacity)

                    CelebrationCard(celebration: celebration, hits: celebrationHits)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2 - 30)
                        .transition(.scale(scale: 0.82).combined(with: .opacity))

                    // Coins pour from the balance chip into the card
                    ForEach(spendFlights) { flight in
                        CoinFlightView(
                            start: CGPoint(x: geo.size.width - 52, y: 26),
                            target: CGPoint(x: geo.size.width / 2 + flight.dx / 4,
                                            y: geo.size.height / 2 - 110),
                            delay: flight.delay
                        ) {
                            spendFlights.removeAll { $0.id == flight.id }
                            Sounds.clink()
                            Haptics.coin()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                displayedBalance -= 1
                            }
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                                celebrationHits += 1
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func playRedeem(amount: Int, icon: String, name: String) {
        let phrases = ["Enjoy!", "You deserve this.", "Treat yourself.",
                       "Well earned.", "Make it count!", "Savor it."]
        celebrationHits = 0
        spendFlights.removeAll()
        animatingBalance = true   // hold the chip; coins tick it down on landing
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            celebration = RedeemCelebration(icon: icon, name: name, cost: amount,
                                            phrase: phrases.randomElement()!)
        }
        let specs = flightSpecs(amount: amount, baseDelay: 0.2, spread: -40...40)
        spendFlights.append(contentsOf: specs)
        // Auto-dismiss after the pour finishes, unless a newer celebration
        // replaced this one
        let token = UUID()
        celebrationToken = token
        let dismissAt = (specs.last?.delay ?? 0) + 1.8
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissAt) {
            if celebrationToken == token { dismissCelebration() }
        }
    }

    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.25)) { celebration = nil }
        spendFlights.removeAll()
        celebrationHits = 0
        animatingBalance = false
        displayedBalance = balance
    }

    // One sprite per coin, so the size of a haul is visible — spending 950
    // coins pours 950 coins. The stagger window compresses for big amounts
    // (pour completes within ~2.8s); the count clamp is only a render
    // safety net far above anything the economy produces.
    private func flightSpecs(amount: Int, baseDelay: Double,
                             spread: ClosedRange<CGFloat>) -> [CoinFlightSpec] {
        let count = min(amount, 1200)
        let window = min(2.8, max(0.45, Double(count) * 0.07))
        return (0..<count).map { i in
            CoinFlightSpec(delay: baseDelay + window * Double(i) / Double(max(count - 1, 1)),
                           dx: CGFloat.random(in: spread))
        }
    }

    private func playCoinFlight(amount: Int) {
        animatingBalance = true   // hold the chip at the pre-collect value
        let specs = flightSpecs(amount: amount, baseDelay: 0, spread: -60...60)
        coinFlights.append(contentsOf: specs)
        let pourEnd = (specs.last?.delay ?? 0) + 0.75
        // "+N" pops in as the first coins arrive, lingers, then fades.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5)) {
            gainAmount = amount
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + pourEnd + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) { gainAmount = nil }
            // Reconcile in case per-hit ticks drifted from the true total.
            animatingBalance = false
            displayedBalance = balance
        }
    }
}

// MARK: - Coin editor (triple-tap the balance)

private struct CoinEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let currentBalance: Int
    let onSave: (Int) -> Void
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update coins")
                .font(.qText(16, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text("Set your balance directly. Your current total and history are kept — this adds a “Coin update” entry to the ledger.")
                .font(.qText(12.5))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                QCoin(size: 20)
                TextField("Balance", text: $text)
                    .textFieldStyle(.plain)
                    .font(.qMono(18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line2, lineWidth: 1))

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(OutlineButtonStyle())
                Button("Save") {
                    if let v = Int(text) { onSave(v) }
                    dismiss()
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(Int(text) == nil)
                .opacity(Int(text) == nil ? 0.4 : 1)
            }
        }
        .padding(22)
        .frame(minWidth: 320)
        .background(Theme.bg)
        #if os(iOS)
        .presentationDetents([.height(250)])
        .presentationDragIndicator(.visible)
        #endif
        .onAppear { text = String(currentBalance) }
    }
}

// MARK: - Redeem celebration pieces

private struct RedeemCelebration {
    let icon: String
    let name: String
    let cost: Int
    let phrase: String
}

private struct CelebrationCard: View {
    let celebration: RedeemCelebration
    let hits: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            Text(celebration.icon)
                .font(.system(size: 44))
                .frame(width: 84, height: 84)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 22))

            Text(celebration.name)
                .font(.qDisplay(20))
                .foregroundStyle(Theme.ink)

            Text(celebration.phrase)
                .font(.qText(14))
                .foregroundStyle(Theme.ink2)

            HStack(spacing: 5) {
                QCoin(size: 14)
                Text("−\(celebration.cost)")
                    .font(.qMono(13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 38)
        .padding(.vertical, 28)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.line, lineWidth: 1))
        .qShadow()
        .modifier(CoinHitShake(animatableData: hits))
    }
}

// Each whole increment of `hits` runs one sine cycle: the card jolts
// sideways with a hint of rotation as a coin lands, then settles.
private struct CoinHitShake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let phase = animatableData * .pi * 2
        let dx = sin(phase) * 4
        let rot = sin(phase) * 0.012
        var t = CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
        t = t.rotated(by: rot)
        t = t.translatedBy(x: -size.width / 2 + dx, y: -size.height / 2)
        return ProjectionTransform(t)
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
    var ns: Namespace.ID
    @State private var hovering = false

    var body: some View {
        // Pure visual — selection is handled by the tab bar's shared gesture
        // so a single drag can sweep across all segments.
        Text(tab.rawValue)
            .font(.qText(13, weight: .semibold))
            .foregroundStyle(isActive || hovering ? Theme.ink : Theme.ink2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isActive {
                    // One shared pill slides between segments via the
                    // matched geometry; the spring on `tab` does the motion.
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.card)
                        .qShadow()
                        .matchedGeometryEffect(id: "activeTab", in: ns)
                } else if hovering {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.card.opacity(0.45))
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Platform chrome

// Header strip sizing: macOS matches the 52pt unified-toolbar title bar so
// the chip centers on the traffic lights' line; iOS is a plain header row.
private struct HeaderStripStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .frame(height: 52)
            .padding(.bottom, 2)
        #else
        content
            .padding(.top, 10)
            .padding(.bottom, 6)
        #endif
    }
}

// macOS window dressing: transparent unified-toolbar title bar, and content
// extended into the title bar strip (still reserved as safe area by
// .hiddenTitleBar). iOS needs neither.
private struct WindowChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background { TitlebarConfigurator() }
            .ignoresSafeArea(.container, edges: .top)
        #else
        content
        #endif
    }
}

#if os(macOS)
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
#endif

