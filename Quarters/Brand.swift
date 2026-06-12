import SwiftUI

// MARK: - QMark
// The Quarters logo: a quartered circle with the top-right wedge filled.
// Reads as a clock at quarter-past (12→3) and as a coin face.

struct QMark: View {
    var size: CGFloat = 48
    var ringColor: Color = Theme.ink
    var wedgeColor: Color = Theme.accent
    var strokeWidth: CGFloat = 2.0

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 24.0   // scale: points per viewBox unit
            let cx = 12.0 * s
            let cy = 12.0 * s
            let r  = 10.0 * s
            let sw = strokeWidth * s

            // Wedge fills before circle stroke so stroke sits on top
            var wedge = Path()
            wedge.move(to: CGPoint(x: cx, y: cy))
            wedge.addLine(to: CGPoint(x: cx, y: cy - r))
            // clockwise: false = visually clockwise in SwiftUI's flipped coordinate space
            wedge.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: r,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            wedge.closeSubpath()
            context.fill(wedge, with: .color(wedgeColor))

            // Outer circle
            let circle = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            context.stroke(circle, with: .color(ringColor), lineWidth: sw)

            // Radial lines (12 o'clock and 3 o'clock from center), 75% stroke weight
            var lines = Path()
            lines.move(to: CGPoint(x: cx, y: cy))
            lines.addLine(to: CGPoint(x: cx, y: cy - r))
            lines.move(to: CGPoint(x: cx, y: cy))
            lines.addLine(to: CGPoint(x: cx + r, y: cy))
            context.stroke(lines, with: .color(ringColor),
                           style: StrokeStyle(lineWidth: sw * 0.75, lineCap: .round))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - QCoin
// Filled gold disc: rim, inner hairline ring, and top-right quarter wedge minted darker.

struct QCoin: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let s  = canvasSize.width / 24.0
            let cx = 12.0 * s
            let cy = 12.0 * s
            let r  = 11.0 * s   // outer radius
            let ri = 7.5  * s   // inner ring radius
            let wr = 10.4 * s   // wedge arc radius (inset from rim stroke)

            // Filled face
            let face = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            context.fill(face, with: .color(Theme.coin))

            // Rim stroke
            context.stroke(face, with: .color(Theme.coinDeep), lineWidth: 1.6 * s)

            // Inner hairline ring at 55% opacity
            let inner = Path(ellipseIn: CGRect(x: cx - ri, y: cy - ri, width: ri * 2, height: ri * 2))
            context.stroke(inner, with: .color(Theme.coinDeep.opacity(0.55)), lineWidth: s)

            // Minted wedge (top-right quarter, 40% opacity)
            var wedge = Path()
            wedge.move(to: CGPoint(x: cx, y: cy))
            wedge.addLine(to: CGPoint(x: cx, y: cy - wr))
            wedge.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: wr,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
            wedge.closeSubpath()
            context.fill(wedge, with: .color(Theme.coinDeep.opacity(0.4)))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - QCoinChip
// Balance display: coin glyph + mono count in a pill.

struct QCoinChip: View {
    let balance: Int

    var body: some View {
        HStack(spacing: 6) {
            QCoin(size: 17)
            Text("\(balance)")
                .font(.qMono(13.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.vertical, 4)
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .background(Theme.coinSoft, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.coinDeep, lineWidth: 0.5))
    }
}

// MARK: - QRing
// Segmented timer ring. Each segment = (360 / total) − 5°.
// Completed segments fill with accent; the active segment fills proportionally.

struct QRing: View {
    var size: CGFloat = 200
    var totalQuarters: Int          // 1–4
    var completedQuarters: Int      // fully-finished quarters
    var currentProgress: Double     // 0.0–1.0 fill of the active quarter
    var thickness: CGFloat = 11

    var body: some View {
        Canvas { context, canvasSize in
            let s        = canvasSize.width / size  // usually 1; supports GeometryReader scaling
            let cx       = canvasSize.width  / 2
            let cy       = canvasSize.height / 2
            let r        = (canvasSize.width - thickness * s) / 2
            let gapDeg   = 5.0
            let segDeg   = 360.0 / Double(totalQuarters) - gapDeg

            for i in 0..<totalQuarters {
                let startDeg = Double(i) * (segDeg + gapDeg) + gapDeg / 2.0

                // Track arc
                drawArc(context: context, cx: cx, cy: cy, r: r,
                        startDeg: startDeg, sweepDeg: segDeg,
                        color: Theme.line2, lineWidth: thickness * s)

                // Filled arc
                if i < completedQuarters {
                    drawArc(context: context, cx: cx, cy: cy, r: r,
                            startDeg: startDeg, sweepDeg: segDeg,
                            color: Theme.accent, lineWidth: thickness * s)
                } else if i == completedQuarters {
                    let sweep = segDeg * min(max(currentProgress, 0), 1)
                    drawArc(context: context, cx: cx, cy: cy, r: r,
                            startDeg: startDeg, sweepDeg: sweep,
                            color: Theme.accent, lineWidth: thickness * s)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func drawArc(context: GraphicsContext, cx: CGFloat, cy: CGFloat,
                         r: CGFloat, startDeg: Double, sweepDeg: Double,
                         color: Color, lineWidth: CGFloat) {
        // Round caps extend half the stroke width past each endpoint, which
        // bulges into the inter-segment gaps. Inset both endpoints by the
        // cap radius so the caps land exactly on the segment boundaries.
        let capDeg = Double(lineWidth / (2 * r)) * 180 / .pi
        let from = startDeg + capDeg
        let to   = startDeg + sweepDeg - capDeg
        guard to > from else { return }
        let center = CGPoint(x: cx, y: cy)
        // Design origin = 12 o'clock; SwiftUI 0° = 3 o'clock → offset by -90
        let start = Angle.degrees(from - 90)
        let end   = Angle.degrees(to - 90)
        var path = Path()
        // clockwise: false = visually clockwise due to SwiftUI's flipped Y axis
        path.addArc(center: center, radius: r, startAngle: start, endAngle: end, clockwise: false)
        context.stroke(path, with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }
}

// MARK: - QIcon
// SF Symbol wrapper matching the design icon set.

private let sfSymbolMap: [String: String] = [
    "coffee": "cup.and.saucer",
    "walk":   "figure.walk",
    "globe":  "globe",
    "game":   "gamecontroller",
    "gift":   "gift",
    "book":   "book.closed",
    "music":  "music.note",
    "check":  "checkmark",
    "plus":   "plus",
    "play":   "play.fill",
    "pause":  "pause.fill",
    "flame":  "flame.fill",
    "arrow":  "arrow.right",
    "edit":   "pencil",
    "x":      "xmark",
    "menu":   "line.3.horizontal",
    "bolt":   "bolt.fill",
]

struct QIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = .primary

    var body: some View {
        let symbol = sfSymbolMap[name] ?? name
        Image(systemName: symbol)
            .font(.system(size: size * 0.75, weight: .regular))
            .foregroundStyle(color)
            .frame(width: size, height: size)
    }
}

// MARK: - QWordmark

struct QWordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 7) {
            QMark(size: size * 1.15, strokeWidth: 2)
            Text("Quarters")
                .font(.qDisplay(size * 0.82))
                .foregroundStyle(Theme.ink)
        }
    }
}

// MARK: - Quarter picker dial
// Tapping slice n sets length to n quarters. The fill is a single
// animatable pie shape — one path means no antialiased seams between
// wedges, and animating the sweep reads as liquid pouring around the dial.

private struct PieFill: Shape {
    var fraction: Double   // 0…1 of the full circle, from 12 o'clock

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard fraction > 0.001 else { return Path() }
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2 - 1.5  // inset so ring stroke isn't clipped
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(-90),
                 endAngle: .degrees(-90 + 360 * min(fraction, 1)),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct QuarterPicker: View {
    @Binding var quarters: Int   // 1–4
    var size: CGFloat = 120
    @State private var hovering = false

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 1.5)
                .fill(Theme.card)
            PieFill(fraction: Double(quarters) / 4)
                .fill(Theme.accent)
            Circle()
                .strokeBorder(Theme.ink, lineWidth: 2)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .scaleEffect(hovering ? 1.03 : 1)
        .shadow(color: .black.opacity(hovering ? 0.10 : 0.05),
                radius: hovering ? 8 : 4, y: 2)
        // Mild underdamping lets the fill slosh slightly past the target
        // and settle back — the liquid pour.
        .animation(.spring(response: 0.55, dampingFraction: 0.68), value: quarters)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .onTapGesture { location in
            let dx = location.x - size / 2
            let dy = location.y - size / 2
            var angle = atan2(dy, dx) * 180 / .pi + 90  // rotate so 0° = 12 o'clock
            if angle < 0 { angle += 360 }
            let tapped = Int(angle / 90) + 1             // 1…4
            quarters = min(4, max(1, tapped))
        }
    }
}
