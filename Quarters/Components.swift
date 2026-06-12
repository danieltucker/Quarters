import SwiftUI

// MARK: - Section label

struct SectionLabel: View {
    let text: String
    var right: String? = nil
    init(_ text: String, right: String? = nil) {
        self.text = text
        self.right = right
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(.qText(11, weight: .bold))
                .kerning(1.3)
                .foregroundStyle(Theme.ink2)
            if let right {
                Spacer()
                Text(right)
                    .font(.qText(12, weight: .semibold))
                    .foregroundStyle(Theme.green)
            }
        }
    }
}

// MARK: - Button styles
// Each style's body lives in a nested View so it can own @State for hover.
// Hover feedback is gated on isEnabled so disabled buttons stay inert.

struct AccentButtonStyle: ButtonStyle {
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, wide: wide)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let wide: Bool
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.qText(wide ? 15 : 13, weight: .bold))
                .padding(.vertical, wide ? 14 : 8)
                .padding(.horizontal, wide ? 0 : 18)
                .frame(maxWidth: wide ? .infinity : nil)
                .background(
                    hovering && isEnabled ? Theme.accentDeep : Theme.accent,
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .foregroundStyle(Theme.onAccent)
                .contentShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: Theme.accentDeep.opacity(hovering && isEnabled ? 0.30 : 0),
                        radius: 8, y: 3)
                .scaleEffect(configuration.isPressed ? 0.97
                             : (hovering && isEnabled && !wide ? 1.03 : 1))
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

// Legacy alias so callers that haven't been updated yet still compile
typealias GoldButtonStyle = AccentButtonStyle

struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, tint: tint)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.qText(12, weight: .semibold))
                .padding(.vertical, 5)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(hovering && isEnabled ? Theme.card : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(tint == Theme.ink ? Theme.line2 : tint, lineWidth: 1)
                )
                .foregroundStyle(tint)
                // The interior was transparent and didn't hit-test — only the
                // text and 1pt border were clickable without this.
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .scaleEffect(configuration.isPressed ? 0.96
                             : (hovering && isEnabled ? 1.04 : 1))
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

// Fixed-size round icon button — consistent 28×28 with a full hit area.

struct IconButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink2

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, tint: tint)
    }

    private struct StyleBody: View {
        let configuration: Configuration
        let tint: Color
        @State private var hovering = false

        var body: some View {
            configuration.label
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovering ? Theme.card2 : Theme.card))
                .overlay(Circle().strokeBorder(
                    tint == Theme.ink2 ? Theme.line2 : tint.opacity(0.5), lineWidth: 1))
                .contentShape(Circle())
                .scaleEffect(configuration.isPressed ? 0.90 : (hovering ? 1.08 : 1))
                .animation(.easeOut(duration: 0.12), value: hovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { hovering = $0 }
        }
    }
}

// MARK: - Hover lift
// Reusable hover affordance for cards and rows: soft shadow + optional scale.

struct HoverLift: ViewModifier {
    var scale: CGFloat = 1.015
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(hovering ? 0.07 : 0), radius: 8, y: 3)
            .scaleEffect(hovering ? scale : 1)
            .animation(.easeOut(duration: 0.15), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift(_ scale: CGFloat = 1.015) -> some View {
        modifier(HoverLift(scale: scale))
    }
}

// MARK: - Card surface modifier

struct QCard: ViewModifier {
    var borderColor: Color = Theme.line

    func body(content: Content) -> some View {
        content
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(borderColor, lineWidth: 1))
    }
}

extension View {
    func qCard(border: Color = Theme.line) -> some View { modifier(QCard(borderColor: border)) }
    // Legacy alias
    func panelCard(border: Color = Theme.line) -> some View { qCard(border: border) }
}

// MARK: - Segmented block bar (legacy; replaced by QRing in RunningView Phase 6)

struct BlockBar: View {
    let blockCount: Int
    let elapsed: TimeInterval

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<blockCount, id: \.self) { i in
                let start = Double(i) * AppConfig.blockSeconds
                let frac  = min(1, max(0, (elapsed - start) / AppConfig.blockSeconds))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.bg2)
                            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                        Capsule()
                            .fill(frac >= 1 ? Theme.green : Theme.accent)
                            .frame(width: geo.size.width * frac)
                            .animation(.linear(duration: 0.5), value: frac)
                    }
                }
                .frame(height: 14)
            }
        }
    }
}

// MARK: - Type-erased button style (used by RewardsView)

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}
