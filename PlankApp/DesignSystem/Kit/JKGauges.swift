import SwiftUI

// MARK: - JKProteinArc
//
// The protein hero — a 250° open arc (open at the bottom, where the
// note sits) with the serif numeral centered. Protein is the ONE
// gauge that earns hero treatment (GLP-1 cohort's daily anchor);
// calories deliberately never get a gauge (anti-shame: a bar that
// fills toward a ceiling reads as a budget running out).
//
// States: under target = accent arc (becoming), at/over = the arc
// settles cocoa with a soft success tick once per crossing. Over is
// NEVER a warning state.

struct JKProteinArc: View {
    let grams: Int
    let targetG: Int
    var note: String? = nil          // "lean-mass first"
    var diameter: CGFloat = 108

    @State private var celebrated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard targetG > 0 else { return 0 }
        return min(1, Double(grams) / Double(targetG))
    }
    private var met: Bool { targetG > 0 && grams >= targetG }

    // 250° sweep, opening centered at the bottom.
    private let sweep: Double = 250
    private var startAngle: Double { 90 + (360 - sweep) / 2 }   // 145°

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                arc(trim: 1, color: Palette.accentSubtle, width: 6)
                arc(trim: fraction, color: met ? Palette.cocoaPrimary : Palette.accent, width: 6)
                    .animation(Motion.easedFinal, value: fraction)

                VStack(spacing: 1) {
                    Text("\(grams)")
                        .font(.custom("JeniHeroSerif-Regular", size: 30))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(targetG)g protein")
                        .font(Typo.numeralMeta)
                        .kerning(0.1)
                        .foregroundStyle(Palette.textSecondary)
                }
                .animation(Motion.easedFinal.delay(Motion.perceptualLag), value: grams)
            }
            .frame(width: diameter, height: diameter)

            if let note {
                Text(note)
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .onChange(of: met) { _, isMet in
            guard isMet, !celebrated else { celebrated = isMet; return }
            celebrated = true
            Haptics.success()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("protein: \(grams) of \(targetG) grams")
    }

    private func arc(trim: Double, color: Color, width: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: (sweep / 360) * max(0.015, trim))
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
            .rotationEffect(.degrees(startAngle))
    }
}

// MARK: - JKStepsRing
//
// The everyday anchor at band scale — the device-demo steps ring.
// Auto-completes; never a chore.

struct JKStepsRing: View {
    let steps: Int
    let goal: Int
    var diameter: CGFloat = 64

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(steps) / Double(goal))
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Palette.accentSubtle, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.02, fraction))
                    .stroke(
                        fraction >= 1 ? Palette.cocoaPrimary : Palette.accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Motion.easedFinal, value: fraction)
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            .frame(width: diameter, height: diameter)

            VStack(spacing: 0) {
                Text(steps.formatted())
                    .font(Typo.numeralMeta)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("steps")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps")
    }
}

// MARK: - JKKcalLine
//
// Calories as a sentence, not a gauge. "980 today · fits her plan"
// with the quiet state word doing the anti-shame work. Suppressed
// cohorts render the no-numbers variant upstream (callers pass nil
// target and get the count-free line).

struct JKKcalLine: View {
    let kcal: Int
    let target: Int?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let target {
                Text("\(kcal.formatted())")
                    .font(Typo.numeralStat)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("of ~\(target.formatted()) today")
                    .font(Typo.numeralMeta)
                    .kerning(0.1)
                    .foregroundStyle(Palette.textSecondary)
                Text("·")
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.cocoaTertiary)
                Text(stateWord(kcal: kcal, target: target))
                    .font(.custom("JeniHeroSerif-Italic", size: 15))
                    .foregroundStyle(Palette.cocoaSecondary)
            } else {
                Text("plates logged, no math today")
                    .font(Typo.numeralMeta)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The whole vocabulary is anti-shame: nothing red, nothing
    /// "over budget," evenings acknowledge room honestly.
    private func stateWord(kcal: Int, target: Int) -> String {
        let f = Double(kcal) / Double(max(target, 1))
        switch f {
        case ..<0.35: return "early still"
        case ..<0.85: return "fits"
        case ..<1.05: return "landed"
        default: return "a full day"
        }
    }
}
