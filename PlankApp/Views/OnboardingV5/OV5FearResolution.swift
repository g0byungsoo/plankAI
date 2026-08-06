import SwiftUI

// MARK: - OV5FearResolutionPresentation
//
// The objection beat that replaced the pre-wall rating ask (intent
// bleed — rating lives post-purchase). One screen, keyed to the fear
// she said "yes, that's me" to, answering it with a SHIPPING plan
// mechanic — reset weeks, her real terminal date, the ACSM pace line.
// Skips silently (zero frames) when no fear was kept. Post-reveal is
// where doubt resurfaces; this meets it with her own plan.

struct OV5FearResolutionPresentation: View {
    let onContinue: () -> Void

    @AppStorage("onb_fear_quickResults") private var fearQuick = ""
    @AppStorage("onb_fear_anotherDiet") private var fearDiet = ""
    @AppStorage("onb_fear_priorAttempt") private var fearPrior = ""
    @AppStorage("onb_fear_offramp") private var fearOfframp = ""
    @AppStorage("onb_fear_regain") private var fearRegain = ""
    @AppStorage("onboardingPickedTier") private var pickedTierRaw = "medium"
    @AppStorage("onboardingCurrentWeightKg") private var storedCurrentKg = 0.0
    @AppStorage("onboardingGoalWeightKg") private var storedGoalKg = 0.0
    @AppStorage("onb_v5_weight_kg") private var v5CurrentKg = 0.0
    @AppStorage("onb_v5_goal_kg") private var v5GoalKg = 0.0

    private struct Resolution {
        let fear: String
        let fearItalic: [String]
        let answer: String
        let answerItalic: [String]
        let mechanic: String
    }

    var body: some View {
        Group {
            if let r = resolution {
                content(r)
            } else {
                // No fears kept — the beat doesn't exist for her.
                Color.clear.onAppear { onContinue() }
            }
        }
    }

    private func content(_ r: Resolution) -> some View {
        ZStack {
            GrainfieldBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()

                // Her fear, struck through as it is answered.
                StruckStatement(text: r.fear, italic: r.fearItalic)
                    .padding(.horizontal, Space.lg)

                ItalicAccentText(
                    r.answer,
                    italic: r.answerItalic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    alignment: .center
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)
                .ov5Beat2(extraDelay: 0.45)

                Text(r.mechanic)
                    .font(Typo.teachSub)
                    .lineSpacing(Typo.teachSubLineSpacing)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.lg)
                    .ov5Beat2(extraDelay: 0.7)

                Spacer()

                JFContinueButton(label: "keep going", action: onContinue)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.md)
                    .ov5Beat2(extraDelay: 0.9)
            }
        }
    }

    private var currentKg: Double { v5CurrentKg > 0 ? v5CurrentKg : storedCurrentKg }
    private var goalKg: Double { v5GoalKg > 0 ? v5GoalKg : storedGoalKg }

    private var resolution: Resolution? {
        // Cohort fears first — the most specific doubt wins the beat.
        if fearRegain == "yes" {
            return Resolution(
                fear: "it all comes back now that i've stopped.",
                fearItalic: ["stopped."],
                answer: "keeping it off is its own practice.",
                answerItalic: ["becoming."],
                mechanic: "your plan runs maintenance as a practice: protein first, the trend line over the daily number, and weigh-ins that read the week, not the day."
            )
        }
        if fearOfframp == "yes" {
            return Resolution(
                fear: "what happens when i stop?",
                fearItalic: ["stop?"],
                answer: "the rhythm stays.",
                answerItalic: ["stays."],
                mechanic: "everything the plan builds is yours, not the prescription's. protein, steps, the daily pattern. whenever that chapter ends, this one holds."
            )
        }
        if fearPrior == "yes" {
            return Resolution(
                fear: "i give up after the first hard day.",
                fearItalic: ["hard"],
                answer: "we planned for the day you'd usually quit.",
                answerItalic: ["quit."],
                mechanic: "your plan carries built-in reset weeks. a bad day is in the math. tomorrow resets, nothing is forfeited."
            )
        }
        if fearDiet == "yes" {
            let weeksLine: String
            if let weeks = ProjectionMath.projectedWeeks(
                currentKg: currentKg, goalKg: goalKg,
                paceKey: ProjectionMath.paceKey(forTier: pickedTierRaw)
            ) {
                weeksLine = "your plan runs about \(weeks) weeks, then shifts to keeping. a program with an end, not a diet without one."
            } else {
                weeksLine = "your plan is a program with an end and a keeping phase. not a diet without one."
            }
            return Resolution(
                fear: "this turns into another diet.",
                fearItalic: ["another diet."],
                answer: "this one ends.",
                answerItalic: ["ends."],
                mechanic: weeksLine + " no forbidden foods. nothing to earn."
            )
        }
        if fearQuick == "yes" {
            return Resolution(
                fear: "apps that promise quick results.",
                fearItalic: ["quick"],
                answer: "no overnight promises.",
                answerItalic: ["promises."],
                mechanic: "your pace sits inside the 0.5-1% a week band ACSM guidance uses, and the projection you just saw is an estimate, not a promise. slow is the strategy."
            )
        }
        return nil
    }
}

/// A centered serif statement that draws its own strikethrough after
/// landing — her fear, answered.
private struct StruckStatement: View {
    let text: String
    let italic: [String]
    @State private var strike: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ItalicAccentText(
            text,
            italic: italic,
            baseFont: .custom("JeniHeroSerif-Regular", size: 24),
            italicFont: .custom("JeniHeroSerif-Italic", size: 24),
            color: Palette.cocoaSecondary,
            alignment: .center
        )
        .overlay {
            GeometryReader { geo in
                Capsule()
                    .fill(Palette.accent.opacity(0.65))
                    .frame(width: geo.size.width * strike, height: 1.8)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            if reduceMotion { strike = 1; return }
            withAnimation(.easeOut(duration: 0.35).delay(0.55)) { strike = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Haptics.soft() }
        }
    }
}
