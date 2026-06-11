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

struct AccentButtonStyle: ButtonStyle {
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.qText(wide ? 15 : 13, weight: .bold))
            .padding(.vertical, wide ? 14 : 8)
            .padding(.horizontal, wide ? 0 : 18)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 13))
            .foregroundStyle(Theme.onAccent)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

// Legacy alias so callers that haven't been updated yet still compile
typealias GoldButtonStyle = AccentButtonStyle

struct OutlineButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.qText(12, weight: .semibold))
            .padding(.vertical, 5)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint == Theme.ink ? Theme.line2 : tint, lineWidth: 1)
            )
            .foregroundStyle(tint)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
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
