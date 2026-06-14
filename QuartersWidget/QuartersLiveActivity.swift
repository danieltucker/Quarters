import ActivityKit
import WidgetKit
import SwiftUI

// Brand colors (mirrors Theme — the widget target doesn't share the app's
// Theme/fonts, so they're inlined here to keep the extension self-contained).
private enum QWidget {
    static let bg     = Color(red: 0xF5/255, green: 0xEF/255, blue: 0xE2/255)
    static let ink    = Color(red: 0x33/255, green: 0x29/255, blue: 0x1C/255)
    static let accent = Color(red: 0xC0/255, green: 0x5B/255, blue: 0x2B/255)
    static let track  = Color(red: 0xDC/255, green: 0xCF/255, blue: 0xB2/255)
}

struct QuartersLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SessionActivityAttributes.self) { context in
            // ── Lock screen / banner ──────────────────────────────────
            lockScreen(context.state)
                .padding(16)
                .activityBackgroundTint(QWidget.bg)
                .activitySystemActionForegroundColor(QWidget.ink)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    quarterMark
                        .frame(width: 30, height: 30)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: range(context.state), countsDown: true)
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                        .foregroundStyle(QWidget.ink)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quarter \(currentQuarter(context.state)) of \(context.state.totalQuarters)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(QWidget.accent)
                        ProgressView(timerInterval: range(context.state), countsDown: false) {
                            EmptyView()
                        } currentValueLabel: { EmptyView() }
                        .tint(QWidget.accent)
                    }
                }
            } compactLeading: {
                quarterMark.frame(width: 18, height: 18)
            } compactTrailing: {
                Text(timerInterval: range(context.state), countsDown: true)
                    .font(.system(.body, design: .rounded).monospacedDigit())
                    .foregroundStyle(QWidget.ink)
                    .frame(width: 48)
            } minimal: {
                quarterMark.frame(width: 18, height: 18)
            }
            .keylineTint(QWidget.accent)
        }
    }

    // Lock-screen / banner layout
    private func lockScreen(_ state: SessionActivityAttributes.ContentState) -> some View {
        HStack(spacing: 14) {
            quarterMark.frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text("Quarter \(currentQuarter(state)) of \(state.totalQuarters)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(QWidget.ink)
                ProgressView(timerInterval: range(state), countsDown: false) {
                    EmptyView()
                } currentValueLabel: { EmptyView() }
                .tint(QWidget.accent)
            }

            Text(timerInterval: range(state), countsDown: true)
                .font(.system(.title2, design: .rounded).monospacedDigit())
                .foregroundStyle(QWidget.ink)
                .frame(width: 78)
        }
    }

    // Small quartered-circle brand mark (a filled top-right wedge over a ring).
    private var quarterMark: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                Circle().fill(QWidget.bg)
                Path { p in
                    let c = CGPoint(x: r, y: r)
                    p.move(to: c)
                    p.addLine(to: CGPoint(x: r, y: r - r))
                    p.addArc(center: c, radius: r, startAngle: .degrees(-90),
                             endAngle: .degrees(0), clockwise: false)
                    p.closeSubpath()
                }
                .fill(QWidget.accent)
                Circle().strokeBorder(QWidget.ink, lineWidth: max(1.4, r * 0.16))
            }
        }
    }

    private func range(_ s: SessionActivityAttributes.ContentState) -> ClosedRange<Date> {
        let end = max(s.endDate, s.startDate.addingTimeInterval(1))
        return s.startDate...end
    }

    private func currentQuarter(_ s: SessionActivityAttributes.ContentState) -> Int {
        min(s.totalQuarters, s.completedQuarters + 1)
    }
}
