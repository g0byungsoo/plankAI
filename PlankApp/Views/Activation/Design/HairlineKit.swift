import SwiftUI

// MARK: - HairlineKit
//
// The "calm lab readout" primitives for activation screens: a precise
// hairline rule, a tick row that fills in sequence, and a label/value
// readout block separated by those rules. A single thin precise
// hairline is the clinical accent in the design system; this kit is its
// canonical home so every activation surface draws it the same weight
// and tint.

// MARK: HairlineRule
//
// A precise ~0.75pt rule in the subtle cocoa hairline token. The 0.75
// weight (never 1.0) is the whole difference between "clinical" and
// "bordered": see the Tokens.swift cocoa-scale note.
struct HairlineRule: View {
    var color: Color = Palette.hairlineCocoa
    var thickness: CGFloat = 0.75

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

// MARK: TickRow
//
// `total` thin vertical ticks; `filled` of them rendered solid cocoa,
// the remainder hollow. Reads as a quiet progress specimen ("4 of 5
// this week"). Options:
//   - animateFill: each fill springs in in sequence on appear.
//   - pulseLast:   the newest (highest-index) fill does a soft scale
//                  pulse so the most-recent gain is felt.
//
// Reduce Motion: ticks render in their final state, no spring, no pulse.
struct TickRow: View {
    let filled: Int
    let total: Int
    var animateFill: Bool = false
    var pulseLast: Bool = false

    /// Tick geometry. Tuned to read as precise marks, not bars.
    var tickWidth: CGFloat = 2
    var tickHeight: CGFloat = 22
    var spacing: CGFloat = 10
    var filledColor: Color = Palette.cocoaPrimary
    var hollowColor: Color = Palette.hairlineCocoa

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var pulse = false

    private var clampedFilled: Int { max(0, min(filled, total)) }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                tick(at: index)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(clampedFilled) of \(total)")
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            if animateFill {
                appeared = true
            } else {
                appeared = true
            }
            if pulseLast {
                // Soft one-shot pulse on the newest fill, after the
                // sequence has had time to land.
                let lead = animateFill ? Double(clampedFilled) * Motion.cascadeTight + 0.2 : 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + lead) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.55)) { pulse = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.easeOut(duration: 0.25)) { pulse = false }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tick(at index: Int) -> some View {
        let isFilled = index < clampedFilled
        let isNewest = index == clampedFilled - 1
        let shown = reduceMotion || !animateFill || appeared

        Capsule(style: .continuous)
            .fill(isFilled ? filledColor : hollowColor)
            .frame(width: tickWidth, height: tickHeight)
            .opacity(isFilled ? (shown ? 1 : 0) : 1)
            .scaleEffect(
                y: scaleY(isFilled: isFilled, isNewest: isNewest, shown: shown),
                anchor: .bottom
            )
            .animation(
                reduceMotion ? nil
                    : .spring(response: 0.4, dampingFraction: 0.7)
                        .delay(animateFill && isFilled ? Double(index) * Motion.cascadeTight : 0),
                value: appeared
            )
    }

    private func scaleY(isFilled: Bool, isNewest: Bool, shown: Bool) -> CGFloat {
        if isFilled && animateFill && !shown && !reduceMotion { return 0.2 }
        if isNewest && pulse && !reduceMotion { return 1.14 }
        return 1.0
    }
}

#if DEBUG
#Preview("HairlineKit") {
    ZStack {
        GrainfieldBackground()
        VStack(alignment: .leading, spacing: 28) {
            TickRow(filled: 4, total: 5, animateFill: true, pulseLast: true)
            HairlineRule()
        }
        .padding(28)
    }
}
#endif
