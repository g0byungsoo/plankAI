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


// MARK: - JKKcalBar
//
// v5: the day's calorie fulfillment as ONE readable object — a
// hairline track, a neutral-ink fill, the target as a notch. Over
// target is NEVER red and never overflows: the fill rests at the
// notch and the words carry it ("a little over · tomorrow resets").

struct JKKcalBar: View {
    let kcal: Int
    let target: Int
    /// v5 pager choreography (see JKProteinArc).
    var armed: Bool = true

    @State private var awakened = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(kcal) / Double(target))
    }
    private var shownFraction: Double { awakened ? fraction : 0 }
    private var over: Bool { target > 0 && kcal > target }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 3)
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Palette.cocoaSecondary, Palette.cocoaPrimary],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * shownFraction), height: 3)
                        .animation(Motion.easedFinal, value: shownFraction)
                    // The target notch.
                    Capsule()
                        .fill(Palette.cocoaTertiary.opacity(over ? 0.9 : 0.5))
                        .frame(width: 2, height: 9)
                        .offset(x: geo.size.width - 1)
                }
                .frame(height: 9)
            }
            .frame(height: 9)

            HStack(spacing: 4) {
                Text("\(kcal)")
                    .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("of ~\(target.formatted()) kcal")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 4)
                Text(roomWord)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .footnote))
                    .foregroundStyle(Palette.cocoaSecondary)
            }
        }
        .onAppear { if armed { arm() } }
        .onChange(of: armed) { _, isArmed in
            if isArmed { arm() } else {
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { awakened = false }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kcal) of about \(target) calories today")
    }

    private var roomWord: String {
        guard target > 0 else { return "" }
        if over {
            let overBy = Int((Double(kcal - target) / 50).rounded() * 50)
            return overBy >= 50 ? "~\(overBy) over · resets tomorrow" : "at the line"
        }
        let room = Int((Double(target - kcal) / 50).rounded() * 50)
        return room > 0 ? "~\(room) left" : "at the line"
    }

    private func arm() {
        if reduceMotion { awakened = true; return }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) { awakened = true }
    }
}

//
// The everyday anchor at band scale — the device-demo steps ring.
// Auto-completes; never a chore.

// p66 — JKStepsRing deleted: zero shipping call sites (gallery-only).

// MARK: - JKKcalLine
//
// Calories as a sentence, not a gauge. "980 today · fits your plan"
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
                    .font(.custom("JeniHeroSerif-Italic", size: 16))
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
        if remaining >= 150 {
            // v7 (docs/app_v7 §1): "left" counts a budget down;
            // "room for" hands the same number back as permission.
            let rounded = max(50, Int((Double(remaining) / 50).rounded()) * 50)
            return "room for ~\(rounded.formatted())"
        }
        if remaining >= -150 { return "at the line" }
        return "over · resets tomorrow"
    }
}
