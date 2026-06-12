import SwiftUI
import AppTrackingTransparency

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
// v4.5 R4 (2026-06-11) — her75 IMG_6280 register: Didone hero +
// 2pt hairline bar on cream silence. The labor illusion survives in
// the rotating personalized sub-line + quiet milestone list; the
// chrome (bloom, sticker scatter, % counter, gradient bar) does not.

struct BuildingPlanLoadingView: View {
    let bodyFocus: Set<String>
    let sessionLengthKey: String
    let voicePreference: String
    let commitmentDaysKey: String
    let onComplete: () -> Void

    @State private var subLabelIndex: Int = 0
    @State private var subLabelVisible = false
    @State private var heroVisible = false
    /// Delta v8 loader-expert recommendation #2 — completion frame
    /// at 100%. Hero swaps to "your plan, ready." + cocoa CTA. Tap-to-continue
    /// (was auto-advance) per Adapty 2026: +8-12% paywall engagement
    /// because user enters next screen with intent.
    @State private var showCompletionFrame = false

    /// Delta v8 loader-expert recommendation #3 — ATT prompt at ~30%.
    /// Cal AI fires ATT at 21% (calai17). TikTok-acquired cohort +
    /// mid-onboarding context = 38-47% allow vs 21% at launch
    /// (Singular 2026). Better attribution = 27% lower CAC.
    /// Single-shot via attPromptFired flag.
    @State private var attPromptFired = false

    // Delta v8 loader-expert #1 (sentiment capture at ~75% + "love" →
    // SKStoreReviewController) RETIRED 2026-06-07. It was double-firing
    // SKStoreReviewController against the post-plan-reveal review
    // prompt (case 215) — neither side called RatingPromptService.markShown,
    // so both passed eligibility and the user got two rating asks in
    // ~60 seconds. Post-plan-reveal is the research-grade slot
    // (post-wow-moment); loader-position was the weaker trigger
    // (during a loading animation, before the user has seen anything
    // tailored to them) and was burning the Apple 3/365 quota on the
    // wrong moment. Founder verdict: drop entirely.
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

    var body: some View {
        ZStack {
            // v8 P8.5: onboarding closer for the v1.1 program era. Uses
            // programBgPrimary directly (not the conditional helper) —
            // the user is crossing INTO the program here, so pink is
            // the welcome before the programEraEnabled flag flips on
            // enrollment commit.
            Palette.programBgPrimary.ignoresSafeArea()

            // v4.5 R4 — her75 IMG_6280 register: Didone hero + hairline
            // bar on cream silence. The labor illusion survives in the
            // rotating personalized sub-line + quiet milestone list
            // (Buell & Norton; Adapty 2026 +9-15%) — the chrome doesn't.
            VStack(spacing: 0) {
                Spacer()

                ItalicAccentText(
                    showCompletionFrame ? "your plan, ready." : "personalizing your plan",
                    italic: ["your"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .padding(.horizontal, Space.lg)
                .opacity(heroVisible ? 1 : 0)
                .scaleEffect(heroVisible ? 1.0 : 0.97)
                .animation(Motion.entrance, value: showCompletionFrame)

                Spacer().frame(height: Space.lg + 4)

                // Hairline progress — 200pt, 2pt, cocoa on faint track
                // (her75's exact loading bar). Holds during the ATT
                // pause so the stop reads as deliberate.
                if !showCompletionFrame {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.divider.opacity(0.6))
                            .frame(width: 200, height: 2)
                        Capsule()
                            .fill(Palette.bgInverse)
                            .frame(width: 200 * CGFloat(progress), height: 2)
                    }
                    .opacity(heroVisible ? 1 : 0)

                    Spacer().frame(height: Space.lg)

                    subLabel(at: subLabelIndex)
                        .padding(.horizontal, Space.lg)
                        .opacity(subLabelVisible ? 0.9 : 0)
                        .id(subLabelIndex)
                }

                if showCompletionFrame {
                    JFContinueButton(label: "see your plan", action: onComplete)
                        .padding(.horizontal, Space.xl)
                        .padding(.top, Space.lg)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                if !showCompletionFrame {
                    milestoneChecklist
                        .padding(.horizontal, Space.xl + Space.lg)
                        .padding(.bottom, 72)
                        .opacity(heroVisible ? 0.85 : 0)
                } else {
                    Spacer().frame(height: 72)
                }
            }
        }
        .task { await runChoreography() }
    }

    // MARK: - ATT prompt (Delta v8 loader-expert #3)

    /// Fires the system ATT dialog if status is `.notDetermined`. The
    /// await blocks the loader's tick loop, so progress holds at the
    /// pre-prompt value until the user responds. PostHog distinct_id
    /// continues working regardless of response — only IDFA-bound
    /// attribution depends on `.authorized`.
    private func requestATTIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return
        }
        // Small dwell so the user sees the % stop incrementing before
        // the system dialog appears — gives the pause a visual beat.
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    // MARK: - Milestone checklist (Delta v8 D75)
    //
    // Five items that progressively check in as the progress bar
    // advances. Each item fires at its threshold percent. Voice-locked
    // copy with italic-Fraunces punch words.
    private static let milestones: [(threshold: Double, label: String, italic: [String])] = [
        (0.20, "your eating story ♥",         ["eating"]),
        (0.40, "cuisine match",                []),
        (0.60, "calorie window",               []),
        (0.80, "movement floor",               []),
        (1.00, "your becoming arc",            ["becoming"]),
    ]

    @ViewBuilder private var milestoneChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<Self.milestones.count, id: \.self) { i in
                let m = Self.milestones[i]
                let done = progress >= m.threshold
                HStack(spacing: 10) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(done ? Palette.accent : Palette.textSecondary.opacity(0.4))
                        .animation(.easeOut(duration: 0.3), value: done)
                    if m.italic.isEmpty {
                        Text(m.label)
                            .font(.system(size: 13))
                            .foregroundStyle(done ? Palette.textPrimary : Palette.textSecondary)
                    } else {
                        ItalicAccentText(
                            m.label.replacingOccurrences(of: "*", with: ""),
                            italic: m.italic,
                            baseFont: .system(size: 13),
                            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13),
                            color: done ? Palette.textPrimary : Palette.textSecondary
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        withAnimation(Motion.entranceSoft) { heroVisible = true }

        try? await Task.sleep(nanoseconds: 300_000_000)

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
        // Delta v8 founder-pacing fix v3 (2026-06-06): two-phase whip curve
        // replaces the single t^1.5 power curve. Founder feedback:
        // "still feels not accelerating fast enough at later phase."
        //
        // Single power curves trade off "stuck early" vs "limp end."
        // t^1.5 felt alive early but anticlimactic at the finish;
        // t^2.5 felt stuck for the first 3 seconds. The two-phase
        // shape solves both:
        //
        //   - Phase 1 (first 60% of wall-clock): gentle ease-in from
        //     0 → 50% progress. Bar moves visibly from tick one, no
        //     "stuck" frame (Cornell HCI 2008 < 10% / 3s threshold).
        //   - Phase 2 (last 40% of wall-clock): exponential ease-out
        //     from 50 → 100% with a steep slope at the transition.
        //     Velocity at the boundary jumps ~2.4× — the actual whip
        //     the founder is asking for. Last 4 seconds cover the
        //     second half of perceived progress.
        //
        // Buell & Norton labor illusion is unaffected: total computed
        // labels still surface, milestones still tick at 20/40/60/80/100,
        // ATT + sentiment beats still land at the same progress values
        // (now mapped to different wall-clock instants — ATT around 4s,
        // sentiment around 7.5s of a 10.5s total).
        //
        // Total time tightened 12.0s → 10.5s.
        let totalLabels = totalLabelCount
        let totalSeconds = min(10.5, Double(totalLabels) * 1.2 + 0.5)
        let tickCount = 100
        let perTickNs = UInt64((totalSeconds * 1_000_000_000) / Double(tickCount))
        let ticksPerLabel = max(1, tickCount / totalLabels)

        // Pre-computed normalizer so phase 2 lands cleanly at 1.0 even
        // with a steep decay constant. exp(-3) ≈ 0.0498; normalizing by
        // (1 - exp(-3)) ≈ 0.9502 makes the curve span exactly 0.50 → 1.0.
        let phase2K: Double = 3.0
        let phase2Norm: Double = 1.0 / (1.0 - exp(-phase2K))

        for tick in 1...tickCount {
            try? await Task.sleep(nanoseconds: perTickNs)
            if Task.isCancelled { return }
            let t = Double(tick) / Double(tickCount)
            if t < 0.6 {
                // Phase 1 — gentle ease-in to 50% over first 60% of time.
                let s = t / 0.6
                progress = 0.50 * pow(s, 1.2)
            } else {
                // Phase 2 — exponential whip from 50% → 100% over last
                // 40% of time. Steep slope at the boundary, smooth land.
                let s = (t - 0.6) / 0.4
                progress = 0.50 + 0.50 * (1.0 - exp(-phase2K * s)) * phase2Norm
            }

            // Delta v8 loader-expert #3 — ATT prompt at ~30% perceived
            // progress (~3.5s wall-clock at the new pacing). System
            // dialog naturally pauses the loop via await — labor
            // illusion survives because progress holds where it was
            // until response lands.
            if !attPromptFired, progress >= 0.30 {
                attPromptFired = true
                await requestATTIfNeeded()
            }

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

        // Completion frame — bar fills, beat of silence, hero swaps to
        // "your plan, ready." + cocoa CTA. Tap-to-continue; the dwell
        // is owned by the user.
        try? await Task.sleep(nanoseconds: 700_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.45)) {
            showCompletionFrame = true
        }
        // Auto-advance fallback after 8s for reduce-motion + edge cases
        // where the user doesn't tap. Founder testing 2026-06-06: most
        // users tap within 2-3s; 8s is the safety net.
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if Task.isCancelled { return }
        if showCompletionFrame {
            onComplete()
        }
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
