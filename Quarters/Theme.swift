import SwiftUI
import AppKit

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

// MARK: - Warm Mint color tokens (Direction 1)

enum Theme {
    // Backgrounds
    static let bg       = Color(light: "#F5EFE2", dark: "#1F1912")
    static let bg2      = Color(light: "#EFE6D3", dark: "#181310")
    static let card     = Color(light: "#FFFCF4", dark: "#2B2317")
    static let card2    = Color(light: "#FAF4E6", dark: "#261F14")

    // Text
    static let ink      = Color(light: "#33291C", dark: "#F2E9D6")
    static let ink2     = Color(light: "#84765F", dark: "#A6977C")
    static let ink3     = Color(light: "#B0A48C", dark: "#6E624E")

    // Borders
    static let line     = Color(light: "#E7DCC4", dark: "#3B3122")
    static let line2    = Color(light: "#DCCFB2", dark: "#483C29")

    // Accent — copper
    static let accent       = Color(light: "#C05B2B", dark: "#E0793F")
    static let accentDeep   = Color(light: "#9C4520", dark: "#C05B2B")
    static let accentSoft   = Color(light: "#F4DCC9", dark: "#43301F")
    static let onAccent     = Color(light: "#FFF6EC", dark: "#271509")

    // Positive / green
    static let green        = Color(light: "#4E7A58", dark: "#84B389")
    static let greenSoft    = Color(light: "#DEE9DC", dark: "#2A3526")

    // Coin — gold
    static let coin         = Color(light: "#C99B45", dark: "#D9B25F")
    static let coinBright   = Color(light: "#EFD27A", dark: "#F2DA8C")
    static let coinDeep     = Color(light: "#A37B2F", dark: "#B8923F")
    static let coinSoft     = Color(light: "#F1E2BC", dark: "#41351C")
}

// MARK: - Typography helpers
// Fonts must be bundled in the Xcode target and declared via ATSApplicationFontsPath.
// See font-setup instructions in the project README.

extension Font {
    // Bricolage Grotesque — display numbers, headlines
    static func qDisplay(_ size: CGFloat, weight: Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .heavy, .black: name = "BricolageGrotesque-ExtraBold"
        default: name = "BricolageGrotesque-Bold"
        }
        return .custom(name, size: size)
    }

    // Onest — body text, labels, buttons
    static func qText(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .semibold, .heavy, .black: name = "Onest-Bold"
        case .medium: name = "Onest-Medium"
        default: name = "Onest-Regular"
        }
        return .custom(name, size: size)
    }

    // Spline Sans Mono — timer, coin counts, durations
    // Variant prefix is SplineSansMonoRoman (nameID 25), not SplineSansMono.
    static func qMono(_ size: CGFloat, weight: Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .semibold, .bold, .heavy: name = "SplineSansMonoRoman-SemiBold"
        case .medium: name = "SplineSansMonoRoman-Medium"
        default: name = "SplineSansMono-Regular"   // nameID 6 default instance
        }
        return .custom(name, size: size)
    }
}

// MARK: - Legacy aliases (removed view-by-view in Phases 4–8)

extension Theme {
    static let panel    = card
    static let panel2   = bg2
    static let text     = ink
    static let dim      = ink2
    static let gold     = accent
    static let goldText = accent
    static let goldBg   = accentSoft
    static let mint     = green
    static let onGold   = onAccent
    static let red      = Color(light: "#C94840", dark: "#E0625C")
}

// MARK: - Shadow modifier

struct QShadow: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color(light: "#33291C", dark: "#000000").opacity(0.06), radius: 1, y: 1)
            .shadow(color: Color(light: "#33291C", dark: "#000000").opacity(0.18), radius: 12, y: 4)
    }
}

extension View {
    func qShadow() -> some View { modifier(QShadow()) }
}
