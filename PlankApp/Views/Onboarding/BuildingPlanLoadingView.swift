import SwiftUI
import AppTrackingTransparency
import StoreKit

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
    /// Delta v8 loader-expert recommendation #2 — completion frame
    /// at 100%. Loader pauses, bloom does one breath, hero swaps to
    /// "ready ♥" badge + cocoa "see your plan" CTA. Tap-to-continue
    /// (was auto-advance) per Adapty 2026: +8-12% paywall engagement
    /// because user enters next screen with intent.
    @State private var showCompletionFrame = false
    @State private var completionBloomScale: CGFloat = 1.0

    /// Delta v8 loader-expert recommendation #3 — ATT prompt at ~30%.
    /// Cal AI fires ATT at 21% (calai17). TikTok-acquired cohort +
    /// mid-onboarding context = 38-47% allow vs 21% at launch
    /// (Singular 2026). Better attribution = 27% lower CAC.
    /// Single-shot via attPromptFired flag.
    @State private var attPromptFired = false

    /// Delta v8 loader-expert recommendation #1 — sentiment capture
    /// at ~75%. 3-option overlay. "love ♥" → SKStoreReviewController.
    /// +3-5× App Store review volume (Adapty 2026). Loader pauses
    /// while overlay is up.
    @State private var showSentimentCapture = false
    @State private var sentimentResumeContinuation: CheckedContinuation<Void, Never>?
    @AppStorage("onboardingLoaderSentiment") private var loaderSentiment: String = ""
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
                if showCompletionFrame {
                    // Delta v8 completion frame.
                    ItalicAccentText(
                        "ready ♥",
                        italic: ["ready"],
                        baseFont: .custom("Fraunces72pt-SemiBold", size: 56),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 56),
                        color: Palette.textPrimary,
                        alignment: .center
                    )
                    .scaleEffect(completionBloomScale)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.custom("Fraunces72pt-SemiBold", size: 64, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                        .foregroundStyle(Palette.textPrimary)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)
                        .transition(.opacity)
                }

                ItalicAccentText(
                    showCompletionFrame ? "your *becoming* plan" : "building your becoming plan",
                    italic: showCompletionFrame ? ["becoming"] : ["becoming"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 22),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .padding(.horizontal, Space.lg)
                .opacity(heroVisible ? 1 : 0)

                if !showCompletionFrame {
                    subLabel(at: subLabelIndex)
                        .padding(.horizontal, Space.lg)
                        .opacity(subLabelVisible ? 1 : 0)
                        .id(subLabelIndex)
                }

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

                // Delta v8 completion CTA — replaces the progress bar +
                // checklist when the loader hits 100%. Single cocoa pill,
                // tap → onComplete. Auto-advance fallback after 8s.
                if showCompletionFrame {
                    Button {
                        onComplete()
                    } label: {
                        Text("see your plan")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Palette.bgInverse)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, Space.xl)
                    .padding(.top, 24)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Delta v8 D75 — milestone checklist (calai34/31/38 adapted).
                // Buell & Norton labor illusion (HBS 2011) — listing the
                // computational stages with progressive checkmarks lifts
                // perceived effort 9-15% over a single progress bar (Adapty
                // 2026 H&F benchmark + Brief #7 §1.3). Items fill in at
                // 20/40/60/80/100% as the bar advances. Voice-locked copy.
                if !showCompletionFrame {
                    milestoneChecklist
                        .padding(.top, 16)
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
                    .padding(.top, 12)
                    .padding(.bottom, 60)
                } else {
                    Spacer().frame(height: 60)
                }
            }
        }
        .task { await runChoreography() }
        .overlay {
            if showSentimentCapture {
                sentimentOverlay
            }
        }
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

    // MARK: - Sentiment capture (Delta v8 loader-expert #1)

    /// Pauses the loader, shows the sentiment overlay, awaits the user's
    /// tap. On "love" the SKStoreReviewController dialog fires before
    /// resume. Other taps capture + continue. Continuation pattern lets
    /// us bridge the SwiftUI tap into the async loop.
    private func pauseForSentimentCapture() async {
        withAnimation(.easeOut(duration: 0.3)) {
            showSentimentCapture = true
        }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sentimentResumeContinuation = cont
        }
    }

    private func handleSentimentTap(_ choice: String) {
        loaderSentiment = choice
        if choice == "love", let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Apple's review controller handles its own throttling +
            // cap (3 prompts per 365 days). No-op safe to call.
            SKStoreReviewController.requestReview(in: windowScene)
        }
        withAnimation(.easeIn(duration: 0.25)) {
            showSentimentCapture = false
        }
        // Give the dismiss animation a beat before resuming the loader.
        Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            sentimentResumeContinuation?.resume()
            sentimentResumeContinuation = nil
        }
    }

    @ViewBuilder private var sentimentOverlay: some View {
        ZStack {
            Palette.bgPrimary.opacity(0.92).ignoresSafeArea()
            VStack(spacing: Space.lg) {
                Spacer()
                ItalicAccentText(
                    "how does this feel so *far*?",
                    italic: ["far"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 24),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 24),
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .padding(.horizontal, Space.lg)

                Text("honest — there's no wrong answer.")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)

                VStack(spacing: 10) {
                    sentimentButton("like",     icon: "checkmark.circle")
                    sentimentButton("love ♥",   icon: "heart.fill", value: "love")
                    sentimentButton("not yet",  icon: "circle")
                }
                .padding(.horizontal, Space.lg)

                Spacer()
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private func sentimentButton(_ label: String, icon: String, value: String? = nil) -> some View {
        Button {
            Haptics.light()
            handleSentimentTap(value ?? label)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 58)
            .background(Palette.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Palette.textPrimary.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Milestone checklist (Delta v8 D75)
    //
    // Five items that progressively check in as the progress bar
    // advances. Each item fires at its threshold percent. Voice-locked
    // copy with italic-Fraunces punch words.
    private static let milestones: [(threshold: Double, label: String, italic: [String])] = [
        (0.20, "your *eating* story ♥",       ["eating"]),
        (0.40, "cuisine match",                []),
        (0.60, "calorie window",               []),
        (0.80, "movement floor",               []),
        (1.00, "your *becoming* arc",          ["becoming"]),
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
        // Delta v8 founder-pacing fix (2026-06-06): compressed from
        // 25-35s baseline → capped at ~12s. Ease-in curve on `progress`
        // makes the back half of wall-clock time cover 70%+ of
        // perceived progress — user feels acceleration ("slow start,
        // fast finish" per founder intuition). Pure perceived-velocity
        // play; total wall-clock time also shorter.
        //
        // Wall-clock pacing: 1.3s per label + 0.6s opening dwell, capped
        // at 12s total. Tick loop stays at 100 ticks for smooth % counter
        // animation; the displayed `progress` value is eased.
        let totalLabels = totalLabelCount
        let totalSeconds = min(12.0, Double(totalLabels) * 1.3 + 0.6)
        let tickCount = 100
        let perTickNs = UInt64((totalSeconds * 1_000_000_000) / Double(tickCount))
        let ticksPerLabel = max(1, tickCount / totalLabels)

        for tick in 1...tickCount {
            try? await Task.sleep(nanoseconds: perTickNs)
            if Task.isCancelled { return }
            // Delta v8 loader-expert tweak (2026-06-06): softened
            // ease from t^1.8 → t^1.5. The 1.8 curve showed only 9% at
            // 25% wall-clock which can read "stuck" for the first 3s
            // (Cornell HCI 2008). t^1.5 shows 14% at 25%, 32% at 50% —
            // still accelerates in the back half but feels alive from
            // the first tick.
            let t = Double(tick) / Double(tickCount)
            progress = pow(t, 1.5)

            // Delta v8 loader-expert #3 — ATT prompt at ~30% perceived
            // progress (~3.5s wall-clock at the new pacing). System
            // dialog naturally pauses the loop via await — labor
            // illusion survives because progress holds where it was
            // until response lands.
            if !attPromptFired, progress >= 0.30 {
                attPromptFired = true
                await requestATTIfNeeded()
            }

            // Delta v8 loader-expert #1 — sentiment capture at ~75%.
            // Loader pauses, overlay shows. Resumes after tap.
            if !showSentimentCapture, loaderSentiment.isEmpty, progress >= 0.75 {
                await pauseForSentimentCapture()
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

        // Delta v8 loader-expert #2 — completion frame. Bar fills,
        // one bloom breath, swap hero to "ready ♥" + cocoa CTA.
        // Tap-to-continue rather than auto-advance. The dwell is now
        // owned by the user.
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            completionBloomScale = 1.15
        }
        try? await Task.sleep(nanoseconds: 600_000_000)
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.45)) {
            showCompletionFrame = true
            completionBloomScale = 1.0
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
