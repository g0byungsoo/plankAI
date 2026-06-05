import SwiftUI

// MARK: - BuildingPlanLoadingView
//
// Onboarding v2 Phase 5 / Component 2-of-4. The 25s "we're computing
// your becoming plan" beat in the reveal sequence. Per Noom research
// this is the reciprocity peak — users who watch a personalized plan
// "build" out of their own answers convert at materially higher rates
// than users who get the reveal instantly, because the wait makes the
// plan feel earned + investment-anchored.
//
// Critical: every sub-label has to reference REAL collected onboarding
// fields (bodyFocus / sessionLength / voicePreference / commitmentDays).
// Generic "analyzing your profile..." text reads as fake. Personalized
// references — "factoring in your flat-belly focus", "matching your
// gentle pace" — read as the model actually doing work.
//
// Composition mirrors AffirmationLoaderScreen on purpose so the two
// loaders (auth bootstrap, plan build) feel like one family: central
// breathing bloom, 4-sticker scatter, single italic-Fraunces line.
// What differs: rotating sub-label every ~3s, "becoming" italic punch
// word on the hero, no retry surface (this loader can't fail — it's
// time-based, not network-based).

struct BuildingPlanLoadingView: View {
    let bodyFocus: Set<String>
    let sessionLengthKey: String
    let voicePreference: String
    let commitmentDaysKey: String
    let onComplete: () -> Void

    @State private var subLabelIndex: Int = 0
    @State private var subLabelVisible = false
    @State private var heroVisible = false
    @State private var stickerRevealCount = 0
    @State private var pulse = false
    @State private var bloomScale: CGFloat = 0.92
    @State private var bloomVisible = false
    // 2026-06-01: % counter + progress bar pulled from the dropped v1
    // loadingCarouselScreen (case 180). Animates 0 → 100 over the same
    // 25-35s window that the sub-labels rotate through, so the user
    // sees a concrete "your plan is computing" signal alongside the
    // personalized narration.
    @State private var progress: Double = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // v2-A5: read the credibility-grade fields the user filled during
    // A2-A4 directly from AppStorage so the loader's sub-labels reflect
    // them. Empty / "prefer not to say" values cause the matching label
    // to drop out — the loader narrates only what the user actually
    // surfaced, never fabricated context.
    @AppStorage("onboardingSleepHours")        private var sleepHours: String = ""
    @AppStorage("onboardingStressLevel")       private var stressLevel: String = ""
    @AppStorage("onboardingEatingCadence")     private var eatingCadence: String = ""
    @AppStorage("onboardingEatingWindow")      private var eatingWindow: String = ""
    @AppStorage("onboardingPriorAttempts")     private var priorAttempts: String = ""
    @AppStorage("onboardingHormonalStage")     private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")      private var glp1Status: String = ""

    private static let placements: [StickerPlacement] = [
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.18, y: 0.16),
                         size: 38, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.84, y: 0.20),
                         size: 32, rotation: 14, phaseDelay: 0.35),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.16, y: 0.82),
                         size: 36, rotation: 8, phaseDelay: 0.60),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.86, y: 0.80),
                         size: 30, rotation: -8, phaseDelay: 0.85),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            centralBloom

            GeometryReader { geo in
                ZStack {
                    ForEach(
                        Array(Self.placements.prefix(stickerRevealCount).enumerated()),
                        id: \.element.id
                    ) { _, p in
                        Sticker(placement: p)
                            .position(
                                x: p.position.x * geo.size.width,
                                y: p.position.y * geo.size.height
                            )
                    }
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: Space.lg) {
                Spacer()

                // Hero % counter — 64pt Fraunces, visual anchor.
                // Sits inside the central bloom so the bloom reads as
                // a soft halo around the number. monospacedDigit keeps
                // digit columns the same width across 1-, 2-, and
                // 3-digit values; contentTransition(.numericText())
                // was dropped 2026-06-01 because custom fonts (Fraunces)
                // lack the OpenType digit-positioning tables it needs,
                // which left stale glyphs overlapping at the 99→100
                // transition.
                Text("\(Int(progress * 100))%")
                    .font(.custom("Fraunces72pt-SemiBold", size: 64, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(heroVisible ? 1 : 0)
                    .scaleEffect(heroVisible ? 1.0 : 0.96)

                ItalicAccentText(
                    "building your becoming plan",
                    italic: ["becoming"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 22),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .padding(.horizontal, Space.lg)
                .opacity(heroVisible ? 1 : 0)

                subLabel(at: subLabelIndex)
                    .padding(.horizontal, Space.lg)
                    .opacity(subLabelVisible ? 1 : 0)
                    .id(subLabelIndex)

                Spacer()

                // Gradient progress bar — secondary "your plan is
                // computing" signal. Pulled from v1 loadingCarousel.
                // Same cocoa → accent → stateGood gradient so the
                // visual register matches the rest of the brand.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.divider).frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [
                                    Palette.bgInverse.opacity(0.6),
                                    Palette.accent,
                                    Palette.stateGood.opacity(0.85),
                                ],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(progress),
                                   height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, Space.xl)
                .opacity(heroVisible ? 1 : 0)

                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Palette.accent.opacity(pulse ? 0.8 : 0.2))
                            .frame(width: 6, height: 6)
                            .animation(
                                .easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.15),
                                value: pulse
                            )
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
        }
        .task { await runChoreography() }
    }

    // MARK: - Central bloom
    //
    // Same three-ring soft pink bloom that AffirmationLoaderScreen uses,
    // matched intentionally so the two app-loaders feel like one family.
    // Reduce-motion holds at the mid scale.

    private var centralBloom: some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.07))
                .frame(width: 220, height: 220)
                .scaleEffect(bloomScale)
                .blur(radius: 24)
            Circle()
                .fill(Palette.accent.opacity(0.14))
                .frame(width: 140, height: 140)
                .scaleEffect(bloomScale)
                .blur(radius: 10)
            Circle()
                .fill(Palette.accent.opacity(0.22))
                .frame(width: 72, height: 72)
                .scaleEffect(bloomScale)
                .blur(radius: 3)
        }
        .opacity(bloomVisible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Sub-label content
    //
    // Eight rotating labels at ~3s each = ~24s of choreography. Each
    // pulls a real onboarding field via the labelizers below. Final
    // label uses italic-Fraunces "becoming" as the JeniFit voice signal.

    @ViewBuilder
    private func subLabel(at index: Int) -> some View {
        let labels = subLabels
        if index >= labels.count {
            // Closer — italic-Fraunces "your becoming, ready". Always the
            // last beat regardless of how many credibility-grade labels
            // the user surfaced upstream.
            ItalicAccentText(
                "your becoming, ready",
                italic: ["becoming"],
                baseFont: .custom("Fraunces72pt-Regular", size: 14),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 14),
                color: Palette.textSecondary,
                alignment: .center
            )
        } else {
            Text(labels[index])
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Dynamically-built sub-label list. Each new credibility-grade field
    /// (sleep, stress, eating, hormonal stage, GLP-1, previous attempts)
    /// contributes a label ONLY if the user answered it — empty values
    /// drop out so the loader never narrates context the user didn't
    /// give us. Order roughly mirrors the question flow so the loading
    /// reads as a recap of her own answers, not a generic script.
    private var subLabels: [String] {
        var labels: [String] = []
        labels.append("factoring in your \(bodyFocusLabel) focus…")
        labels.append("setting your starting plank duration…")
        if !priorAttempts.isEmpty && priorAttempts != "none" {
            labels.append("learning from what didn't work last time…")
        }
        if !sleepHours.isEmpty {
            labels.append(sleepLoaderLabel)
        }
        if isStressNoticeable {
            labels.append("weighting cortisol load…")
        }
        if !eatingCadence.isEmpty {
            labels.append("shaping around how you eat…")
        }
        labels.append("calibrating for your \(sessionLengthMinutes)-minute window…")
        if !hormonalStage.isEmpty && hormonalStage != "prefer_not_say" {
            labels.append("adapting to your cycle, week by week…")
        }
        if glp1Status == "current" {
            labels.append("protecting lean mass through the change…")
        }
        labels.append("matching your \(paceLabel) pace…")
        labels.append("planning around your \(commitmentDaysCount)-day commit…")
        labels.append("computing your projection curve…")
        return labels
    }

    private var totalLabelCount: Int { subLabels.count + 1 }  // +1 for closer

    private var sleepLoaderLabel: String {
        switch sleepHours {
        case "under5", "five6": return "accounting for short-sleep recovery…"
        case "six7":            return "accounting for your sleep window…"
        case "seven8":          return "accounting for solid sleep…"
        case "eightPlus":       return "accounting for deep recovery…"
        default:                return "accounting for your sleep window…"
        }
    }

    private var isStressNoticeable: Bool {
        stressLevel == "heavy" || stressLevel == "overwhelmed"
    }

    // MARK: - Label helpers
    //
    // These mirror the existing recap helpers in OnboardingView so the
    // copy stays consistent across the flow. Kept local to this view
    // because OnboardingView's helpers are private; duplicating ~6 lines
    // is cheaper than threading a callback or exposing them.

    private var bodyFocusLabel: String {
        let labels: [String: String] = [
            "flatBelly": "flat belly",
            "tonedArms": "toned arms",
            "roundButt": "round glutes",
            "slimLegs":  "slim legs",
            "fullBody":  "full body"
        ]
        if let first = bodyFocus.first, let label = labels[first] { return label }
        return "full body"
    }

    private var sessionLengthMinutes: Int {
        switch sessionLengthKey {
        case "five":    return 5
        case "ten":     return 10
        case "fifteen": return 15
        case "twenty":  return 20
        default:        return 7
        }
    }

    private var commitmentDaysCount: Int {
        switch commitmentDaysKey {
        case "three": return 3
        case "five":  return 5
        case "seven": return 7
        default:      return 5
        }
    }

    private var paceLabel: String {
        switch voicePreference {
        case "encouraging": return "gentle"
        case "balanced":    return "steady"
        case "roast":       return "ambitious"
        default:            return "steady"
        }
    }

    // MARK: - Choreography
    //
    // Total runtime auto-scales to label count: v2 users who surfaced
    // credibility-grade fields (sleep, stress, eating, hormonal, GLP-1,
    // previous attempts) see more sub-labels and a proportionally longer
    // loader. We target ~2.5s per label rather than the prior 3.1s so a
    // fully-populated 14-label loader still fits a reasonable ~35s budget.
    // Skeleton users (no v2 fields) land back near the original 25s.
    // Last label is the italic "your becoming, ready" closer; it sits
    // for an extra 0.6s before onComplete fires so the arrival reads
    // as a moment, not a transition flicker.

    @MainActor
    private func runChoreography() async {
        withAnimation(.easeOut(duration: 0.8)) { bloomVisible = true }
        if reduceMotion {
            bloomScale = 1.0
        } else {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                bloomScale = 1.08
            }
        }

        withAnimation(Motion.entranceSoft) { heroVisible = true }
        pulse = true

        try? await Task.sleep(nanoseconds: 200_000_000)
        for _ in Self.placements.indices {
            stickerRevealCount += 1
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        if reduceMotion {
            subLabelVisible = true
        } else {
            withAnimation(Motion.entranceSoft) { subLabelVisible = true }
        }

        // Unified tick loop — drives % counter, progress bar, and sub-
        // label rotation in lockstep. Previous implementation used
        // `withAnimation(.linear(duration:)) { progress = 1.0 }` which
        // doesn't animate Text content (Text reads the final value
        // only), leaving the % counter stuck at 0 while the bar
        // animated. This loop ticks `progress` in 1% steps so the
        // Text re-renders on every body invocation alongside the bar.
        //
        // 100 ticks over `totalSeconds` (~25-35s depending on label
        // count). Sub-label rotation triggers at boundaries — whenever
        // the tick crosses a `100/totalLabels` step, the label fades
        // forward.
        let totalLabels = totalLabelCount
        let totalSeconds = Double(totalLabels) * 2.5 + 0.6
        let tickCount = 100
        let perTickNs = UInt64((totalSeconds * 1_000_000_000) / Double(tickCount))
        let ticksPerLabel = max(1, tickCount / totalLabels)

        for tick in 1...tickCount {
            try? await Task.sleep(nanoseconds: perTickNs)
            if Task.isCancelled { return }
            progress = Double(tick) / Double(tickCount)

            // Rotate sub-label when we cross a label boundary.
            // Cap at totalLabels - 1 so we don't overflow at tick 100.
            let nextIndex = min(tick / ticksPerLabel, totalLabels - 1)
            if nextIndex > subLabelIndex {
                if reduceMotion {
                    subLabelIndex = nextIndex
                } else {
                    withAnimation(.easeIn(duration: 0.2)) { subLabelVisible = false }
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if Task.isCancelled { return }
                    subLabelIndex = nextIndex
                    withAnimation(.easeOut(duration: 0.3)) { subLabelVisible = true }
                }
            }
        }

        // Closing dwell — last label ("your becoming, ready") sits at
        // 100% for a beat so the arrival reads as a moment.
        try? await Task.sleep(nanoseconds: 600_000_000)
        if Task.isCancelled { return }
        onComplete()
    }
}

#Preview {
    BuildingPlanLoadingView(
        bodyFocus: ["flatBelly"],
        sessionLengthKey: "ten",
        voicePreference: "encouraging",
        commitmentDaysKey: "five",
        onComplete: {}
    )
}
