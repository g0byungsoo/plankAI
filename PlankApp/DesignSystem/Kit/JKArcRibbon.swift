import SwiftUI

// MARK: - JKArcRibbon (app v4, docs/app_v4/02_JOURNEY.md)
//
// The program's shape in one hairline object: named phases as line
// segments (width ∝ weeks), the walked part inked, the current
// phase carrying a today tick at her fractional position, the
// future faint. Open-ended chapters (keeping / on-medication) run
// their final phase into a fade — a road, not a countdown.
//
// Register: ink over cream, no cards, no color coding beyond the
// palette's cocoa ladder. Draw-in = one masked trim on appear (the
// journey's entrance gesture); reduce-motion renders settled.

struct JKArcRibbon: View {
    let phases: [ArcPhase]
    let currentWeek: Int
    let totalWeeks: Int

    /// Segment gap + line weights.
    private let gap: CGFloat = 4
    private let walkedWeight: CGFloat = 2.5
    private let futureWeight: CGFloat = 1.2

    @State private var drawn = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Open-ended tables render the final phase as a fixed tail.
    private var isOpenEnded: Bool { phases.last?.isOpenEnded == true }

    /// The span the closed segments divide. Open-ended: the closed
    /// phases + a virtual tail of 40% of the walked span (min 4 wk).
    private var layoutSpans: [(phase: ArcPhase, weeks: Double)] {
        phases.map { phase in
            if phase.isOpenEnded {
                let walked = max(currentWeek - phase.weeks.lowerBound + 1, 1)
                return (phase, Double(max(walked + 3, 4)))
            }
            return (phase, Double(phase.weeks.count))
        }
    }

    var body: some View {
        GeometryReader { geo in
            let spans = layoutSpans
            let totalSpan = max(spans.reduce(0) { $0 + $1.weeks }, 1)
            let gapTotal = gap * CGFloat(max(spans.count - 1, 0))
            let unit = (geo.size.width - gapTotal) / totalSpan

            HStack(alignment: .center, spacing: gap) {
                ForEach(Array(spans.enumerated()), id: \.offset) { idx, span in
                    segment(
                        span.phase,
                        width: max(unit * span.weeks, 6),
                        isLast: idx == spans.count - 1
                    )
                }
            }
            .frame(height: 8, alignment: .center)
            .frame(maxHeight: .infinity, alignment: .center)
            .mask(
                GeometryReader { m in
                    Rectangle()
                        .frame(width: drawn ? m.size.width : 0, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
        }
        .frame(height: 12)
        .onAppear {
            guard !reduceMotion else { drawn = true; return }
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) { drawn = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11y)
    }

    @ViewBuilder
    private func segment(_ phase: ArcPhase, width: CGFloat, isLast: Bool) -> some View {
        let state = segmentState(phase)
        ZStack(alignment: .leading) {
            // The line — walked ink, current ink-heavy, future faint.
            Group {
                if isLast && isOpenEnded {
                    // The road ahead fades rather than ends.
                    LinearGradient(
                        colors: [lineColor(state), lineColor(state).opacity(0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                } else {
                    lineColor(state)
                }
            }
            .frame(height: state == .current ? walkedWeight : (state == .walked ? walkedWeight : futureWeight))
            .clipShape(Capsule())

            // Today's tick rides the current segment.
            if state == .current {
                Circle()
                    .fill(Palette.cocoaPrimary)
                    .frame(width: 5.5, height: 5.5)
                    .offset(x: max(0, min(width - 6, width * currentFraction(phase) - 3)))
                    .opacity(drawn ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.95),
                        value: drawn
                    )
            }
        }
        .frame(width: width, height: 8, alignment: .center)
    }

    private enum SegmentState { case walked, current, future }

    private func segmentState(_ phase: ArcPhase) -> SegmentState {
        if phase.weeks.contains(max(currentWeek, 1)) { return .current }
        return phase.weeks.upperBound < currentWeek ? .walked : .future
    }

    private func lineColor(_ state: SegmentState) -> Color {
        switch state {
        case .current: return Palette.cocoaPrimary
        case .walked:  return Palette.cocoaSecondary.opacity(0.55)
        case .future:  return Palette.hairlineCocoa
        }
    }

    /// Her fractional position within the current phase (week-grain).
    private func currentFraction(_ phase: ArcPhase) -> CGFloat {
        let span = phase.isOpenEnded
            ? Double(max(currentWeek - phase.weeks.lowerBound + 4, 4))
            : Double(phase.weeks.count)
        let into = Double(currentWeek - phase.weeks.lowerBound) + 0.5
        return CGFloat(max(0, min(1, into / max(span, 1))))
    }

    private var a11y: String {
        let current = phases.first { $0.weeks.contains(max(currentWeek, 1)) }
        let name = current?.name ?? "the program"
        return totalWeeks > 0 && !isOpenEnded
            ? "the arc: \(name), week \(currentWeek) of \(totalWeeks)"
            : "the arc: \(name), week \(currentWeek)"
    }
}

#if DEBUG
#Preview("losing · week 6 of 15") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        JKArcRibbon(
            phases: ProgramArc.phases(totalWeeks: 15, chapter: .losing),
            currentWeek: 6,
            totalWeeks: 15
        )
        .padding(.horizontal, 24)
    }
}

#Preview("keeping · week 9") {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        JKArcRibbon(
            phases: ProgramArc.phases(totalWeeks: 52, chapter: .keeping),
            currentWeek: 9,
            totalWeeks: 52
        )
        .padding(.horizontal, 24)
    }
}
#endif
