import SwiftUI

// v2.7 — visibility-triggered awakening with a pre-iOS-18 fallback
// (mount-time awaken, the previous behavior).
private struct JKAwakenOnVisible: ViewModifier {
    var threshold: Double
    var onVisible: () -> Void
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollVisibilityChange(threshold: threshold) { visible in
                if visible { onVisible() }
            }
        } else {
            content.onAppear { onVisible() }
        }
    }
}

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
    /// v5 pager choreography: when driven (the food story page), the
    /// sweep re-arms on every arrival; true-by-default keeps mount
    /// behavior for any future inline use.
    var armed: Bool = true

    @State private var celebrated = false
    /// v2.7 — the band wakes up: the arc draws itself and the numeral
    /// counts up on arrival instead of rendering pre-filled and dead.
    @State private var awakened = false
    /// One-shot tactile pulse on tap (discoverable, never required).
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard targetG > 0 else { return 0 }
        return min(1, Double(grams) / Double(targetG))
    }
    private var shownFraction: Double { awakened ? fraction : 0 }
    private var shownGrams: Int { awakened ? grams : 0 }
    private var met: Bool { targetG > 0 && grams >= targetG }

    // 250° sweep, opening centered at the bottom.
    private let sweep: Double = 250
    private var startAngle: Double { 90 + (360 - sweep) / 2 }   // 145°

    // v5 craft pass: the fill sweeps blush → rose (cocoa once met),
    // over a hairline track — gradient carries the life, the track
    // recedes, the tip wears a solid head with a soft halo, and the
    // target sits as a visible notch at the sweep's end.
    private var sweepGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: met
                ? [Palette.cocoaSecondary, Palette.cocoaPrimary]
                : [Palette.accentSubtle, Palette.accent]),
            center: .center,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + sweep)
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // The track — a hairline, not a second gauge.
                arcShape(trim: 1)
                    .stroke(Palette.hairlineCocoa,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))

                // The target notch at the sweep's end.
                targetNotch

                if fraction > 0 {
                    // Soft glow under the sweep.
                    arcShape(trim: shownFraction)
                        .stroke(sweepGradient,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .blur(radius: 5)
                        .opacity(0.3)
                    // The sweep itself.
                    arcShape(trim: shownFraction)
                        .stroke(sweepGradient,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    // The tip head.
                    tipDot
                }

                VStack(spacing: 1) {
                    Text("\(shownGrams)")
                        .font(.custom("JeniHeroSerif-Regular", size: diameter > 120 ? 34 : 30))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("of \(targetG)g protein")
                        .font(Typo.numeralMeta)
                        .kerning(0.1)
                        .foregroundStyle(Palette.textSecondary)
                }
                .animation(Motion.easedFinal.delay(Motion.perceptualLag), value: shownGrams)
            }
            .frame(width: diameter, height: diameter)
            .animation(Motion.easedFinal, value: shownFraction)
            .scaleEffect(pulse ? 1.035 : 1)
            .onTapGesture {
                Haptics.soft()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { pulse = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { pulse = false }
                }
            }

            if let note {
                Text(note)
                    .font(.custom("JeniHeroSerif-Italic", size: 13))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        // v2.7 — awaken on VISIBILITY, not mount: the band lives
        // below the fold, so an onAppear awakening plays unseen and
        // the user only ever meets a dead, pre-filled gauge.
        .modifier(JKAwakenOnVisible(threshold: 0.4) {
            guard armed, !awakened else { return }
            if reduceMotion {
                awakened = true
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.1)) { awakened = true }
            }
        })
        .onChange(of: armed) { _, isArmed in
            if isArmed {
                guard !awakened else { return }
                if reduceMotion {
                    awakened = true
                } else {
                    withAnimation(.easeOut(duration: 0.9).delay(0.2)) { awakened = true }
                }
            } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { awakened = false }
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

    private func arcShape(trim: Double) -> some Shape {
        Circle()
            .trim(from: 0, to: (sweep / 360) * min(1, max(0.02, trim)))
            .rotation(.degrees(startAngle))
    }

    /// The solid head riding the sweep's tip.
    @ViewBuilder private var tipDot: some View {
        let angle = Angle.degrees(startAngle + sweep * min(1, max(0.02, shownFraction)))
        let r = diameter / 2
        Circle()
            .fill(met ? Palette.cocoaPrimary : Palette.accent)
            .frame(width: 9, height: 9)
            .offset(x: CGFloat(cos(angle.radians)) * r,
                    y: CGFloat(sin(angle.radians)) * r)
            .shadow(color: (met ? Palette.cocoaPrimary : Palette.accent).opacity(0.35),
                    radius: 3)
    }

    /// The goal, visible: a quiet notch where the sweep completes.
    @ViewBuilder private var targetNotch: some View {
        let angle = Angle.degrees(startAngle + sweep)
        let r = diameter / 2
        Capsule()
            .fill(Palette.cocoaTertiary.opacity(met ? 0.9 : 0.45))
            .frame(width: 2, height: 8)
            .rotationEffect(angle + .degrees(90))
            .offset(x: CGFloat(cos(angle.radians)) * r,
                    y: CGFloat(sin(angle.radians)) * r)
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

    @State private var awakened = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(steps) / Double(goal))
    }
    private var shownFraction: Double { awakened ? fraction : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Palette.accentSubtle, lineWidth: 5)
                if fraction > 0 {
                    Circle()
                        .trim(from: 0, to: max(0.02, shownFraction))
                        .stroke(
                            fraction >= 1 ? Palette.cocoaPrimary : Palette.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(Motion.easedFinal, value: fraction)
                        .transition(.opacity)
                }
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            .frame(width: diameter, height: diameter)

            VStack(spacing: 0) {
                Text((awakened ? steps : 0).formatted())
                    .font(Typo.numeralMeta)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                    .animation(Motion.easedFinal, value: awakened)
                Text("steps")
                    .font(Typo.statLabel)
                    .kerning(0.66)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
            }
        }
        .modifier(JKAwakenOnVisible(threshold: 0.4) {
            guard !awakened else { return }
            if reduceMotion {
                awakened = true
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(0.22)) { awakened = true }
            }
        })
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

    @State private var awakened = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let target {
                Text("\((awakened ? kcal : 0).formatted())")
                    .font(Typo.numeralStat)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                    .animation(Motion.easedFinal, value: awakened)
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
        .modifier(JKAwakenOnVisible(threshold: 0.6) {
            guard !awakened else { return }
            if reduceMotion {
                awakened = true
            } else {
                withAnimation(.easeOut(duration: 0.7).delay(0.34)) { awakened = true }
            }
        })
        .accessibilityElement(children: .combine)
    }

    /// The whole vocabulary is anti-shame: nothing red, nothing
    /// "over budget," evenings acknowledge room honestly.
    /// The day answer (docs/app_v4/03_FEATURES.md §1) — the founder's
    /// "am I on track?" answered in permission grammar: concrete room
    /// left, never a red bar, never shame for a full day.
    private func stateWord(kcal: Int, target: Int) -> String {
        let remaining = target - kcal
        let f = Double(kcal) / Double(max(target, 1))
        if f < 0.35, Calendar.current.component(.hour, from: .now) < 11 {
            return "the day is open"
        }
        if remaining >= 150 {
            let rounded = max(50, Int((Double(remaining) / 50).rounded()) * 50)
            return "room for about \(rounded.formatted())"
        }
        if remaining >= -150 { return "right at the day's shape" }
        return "a fuller day. tomorrow resets"
    }
}
