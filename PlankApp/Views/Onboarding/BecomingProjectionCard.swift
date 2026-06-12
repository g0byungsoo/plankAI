import SwiftUI

// MARK: - BecomingProjectionCard
//
// Standalone reusable curve card. Originally built inline in PaywallView
// (v6 paywall redesign 2026-05-31). Extracted 2026-05-31 so the
// onboarding v2 reveal sequence (Phase 5) can render the same visual
// element pre-paywall.
//
// Single highest-leverage paywall element per research (Noom universal
// pattern). Renders ONLY when the user has current + goal weight (with
// goal < current). No graceful "empty state" — view returns EmptyView
// when data is missing, so callers can rely on `if BecomingProjectionCard
// shows, the user has a weight-loss goal."
//
// Brand lock: scrapbook chrome (24pt corners, 1.5pt warm-red border, hard
// offset shadow), hand-drawn cubic-bezier curve in warm-red, flower3D
// sticker at curve endpoint, italic-Fraunces "plotted" punch word.

struct BecomingProjectionCard: View {
    let currentWeightKg: Double?
    let goalWeightKg: Double?
    /// 2026-06-06 — paywall compact variant. Paywall wants a short
    /// projection chip (~110pt total) so 3 tier cards can fit on
    /// one screen. Reveal screen keeps the full 110pt chart.
    var chartHeight: CGFloat = 110

    // Pace unification (2026-06-11): rate + date + label all derive
    // from the user's picked pace. Pre-fix this card hard-coded 0.75%
    // and labeled the rate from the COACH VOICE key ("encouraging" →
    // "gentle pace"), so the paywall showed "~1.2 lb/wk · gentle pace"
    // — steady-rate math under a gentle label.
    @AppStorage(ProjectionMath.paceDefaultsKey) private var paceChoice: String = ""

    // v4.6 — the curve draws itself on appear (0.9s ease-out) with the
    // gradient fill fading in behind it. Reduce-motion snaps to drawn.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var curveDrawn = false

    @ViewBuilder
    var body: some View {
        if let curr = currentWeightKg, let goal = goalWeightKg, curr > goal {
            let unit = WeightUnit.current
            let currentDisp = unit.display(fromKg: curr)
            let goalDisp = unit.display(fromKg: goal)
            let perWeek = unit.display(fromKg: curr * ProjectionMath.weeklyFraction(paceKey: paceChoice))
            let dateText = projectedDateText(currentKg: curr, goalKg: goal)

            VStack(alignment: .leading, spacing: 14) {
                // Delta v8 (2026-06-06) — inner card title removed.
                // The OUTER reveal screen already says "your becoming,
                // plotted" as the headline. Repeating it inside the
                // chart card was redundant. The chart speaks for
                // itself with the today/end labels + the curve.

                // Chart: Y-axis labels on left + curve + endpoint sticker
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .trailing) {
                        Text("\(formatWeight(currentDisp)) \(unit.label)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                        Spacer(minLength: 0)
                        Text("\(formatWeight(goalDisp)) \(unit.label)")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 11))
                            .foregroundStyle(Palette.accent)
                    }
                    .frame(width: 44, height: chartHeight)

                    GeometryReader { geo in
                        ZStack(alignment: .topLeading) {
                            BecomingCurveFillShape()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Palette.accent.opacity(0.14),
                                            Palette.accent.opacity(0.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .opacity(curveDrawn ? 1 : 0)
                            BecomingCurveShape()
                                .trim(from: 0, to: curveDrawn ? 1 : 0)
                                .stroke(
                                    Palette.accent,
                                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                                )
                            Image("sticker_flower_3d")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(-6))
                                .scaleEffect(curveDrawn ? 1 : 0.4)
                                .opacity(curveDrawn ? 1 : 0)
                                .position(
                                    x: geo.size.width - 16,
                                    y: geo.size.height - 14
                                )
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(height: chartHeight)
                    .onAppear {
                        if reduceMotion {
                            curveDrawn = true
                        } else {
                            withAnimation(.easeOut(duration: 0.9).delay(0.25)) {
                                curveDrawn = true
                            }
                        }
                    }
                }

                // X-axis labels — bonus per-week pace below the right tick
                HStack {
                    Text("today")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, 54)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(dateText ?? "")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                            .foregroundStyle(Palette.accent)
                        Text("~\(formatWeight(perWeek)) \(unit.label)/wk · \(paceLabel)")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(16)
            .scrapbookCardBackground()
        }
    }

    // MARK: - Helpers

    /// 2026-06-01: routed through `ProjectionMath.formattedShortDate(...)`
    /// — the single source of truth across onboarding screens + this card.
    /// Previously this method had its own independent ACSM math that
    /// could drift from the onboarding screens; consolidating eliminates
    /// the drift entirely.
    private func projectedDateText(currentKg: Double, goalKg: Double) -> String? {
        ProjectionMath.formattedShortDate(currentKg: currentKg, goalKg: goalKg, paceKey: paceChoice)
    }

    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private var paceLabel: String {
        ProjectionMath.paceLabel(paceKey: paceChoice)
    }
}

// MARK: - BecomingCurveShape
//
// Hand-drawn-feel weight-loss projection curve. Cubic bezier from
// top-left (current weight) to bottom-right (goal weight) with control
// points that create a gentle initial drop, then sustained descent
// (mimics how real weight-loss curves actually look — fast initial loss
// from water + glycogen, then steady fat loss).
//
// Moved here 2026-05-31 from inline-in-PaywallView so onboarding reveal
// can render the same curve.

struct BecomingCurveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topY = rect.minY + 6
        let bottomY = rect.maxY - 14
        let leftX = rect.minX + 2
        let rightX = rect.maxX - 24

        path.move(to: CGPoint(x: leftX, y: topY))
        path.addCurve(
            to: CGPoint(x: rightX, y: bottomY),
            control1: CGPoint(
                x: leftX + (rightX - leftX) * 0.42,
                y: topY + (bottomY - topY) * 0.08
            ),
            control2: CGPoint(
                x: leftX + (rightX - leftX) * 0.72,
                y: bottomY - (bottomY - topY) * 0.04
            )
        )
        return path
    }
}

// MARK: - BecomingCurveFillShape
//
// Same curve as BecomingCurveShape but closed at the bottom so it can
// be filled with a vertical gradient. Creates the soft accent-tint
// "halo" below the curve.

struct BecomingCurveFillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topY = rect.minY + 6
        let bottomY = rect.maxY - 14
        let leftX = rect.minX + 2
        let rightX = rect.maxX - 24

        path.move(to: CGPoint(x: leftX, y: topY))
        path.addCurve(
            to: CGPoint(x: rightX, y: bottomY),
            control1: CGPoint(
                x: leftX + (rightX - leftX) * 0.42,
                y: topY + (bottomY - topY) * 0.08
            ),
            control2: CGPoint(
                x: leftX + (rightX - leftX) * 0.72,
                y: bottomY - (bottomY - topY) * 0.04
            )
        )
        path.addLine(to: CGPoint(x: rightX, y: rect.maxY))
        path.addLine(to: CGPoint(x: leftX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
