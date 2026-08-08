import SwiftUI
import UserNotifications
import RevenueCat

// MARK: - OnboardingRevealView
//
// Onboarding v2 reveal sequence — sits between the last onboarding
// question and the existing onComplete(data) hand-off. Composes 3 screens:
//
//   1. BuildingPlanLoadingView   — 25s of "we're computing your becoming
//                                  plan" with personalized sub-labels.
//   2. ProjectionPresentation    — full-bleed BecomingProjectionCard so
//                                  the curve is the whole hero, not a
//                                  small tile inside a paywall.
//   3. NudgePermissionAsk        - the founder's redesigned notification
//                                  opt-in (iOS notification-mock banner +
//                                  "tap to feel it" haptic + 3 time pills).
//                                  Post-reveal asks land far better than
//                                  mid-onboarding asks because the user has
//                                  already emotionally signed in to the plan.
//                                  HealthKit is a separate mid-onboarding
//                                  ask (case 285), so this is notifs-only.
//
// The original 4-screen plan had a MirrorSummary "your X → plan choice"
// beat between projection + permissions. Cut because the founder felt it
// read as filler — the user has just answered 60+ questions, reflecting
// 3 of them back doesn't add new information.
//
// When the projection step is unavailable (no weight-loss goal set, so
// the curve can't render), the sequence skips it rather than showing
// an empty card. Continue from the final step calls onRevealComplete()
// which hands back to OnboardingView's existing onComplete(data) flow.

struct OnboardingRevealView: View {
    let bodyFocus: Set<String>
    let sessionLengthKey: String
    let voicePreference: String
    let commitmentDaysKey: String
    let currentWeightKg: Double?
    let goalWeightKg: Double?
    let onRevealComplete: () -> Void

    // FIX 2 (2026-06-29) — cohort signals so we can compute + persist the
    // cohort-aware soft-tier floor rate ONCE, before the pace-picker /
    // projection render, so the gentle date they see matches the cohort
    // floor the calorie deficit uses (see persistSoftFloorRate).
    @AppStorage("onboardingHormonalStage") private var revealHormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var revealGlp1Status: String = ""
    @AppStorage("onboardingSleepHours")    private var revealSleepHours: String = ""
    @AppStorage("onboarding_weight_trend") private var revealWeightTrend: String = ""
    @AppStorage("onboarding_glp1_phase")   private var revealGlp1Phase: String = ""

    @State private var step: Step
    /// The review gate's "not really" path opens feedback over the
    /// reveal; on dismiss we continue to the fear beat.
    @State private var showReviewFeedback = false

    init(
        bodyFocus: Set<String>,
        sessionLengthKey: String,
        voicePreference: String,
        commitmentDaysKey: String,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        onRevealComplete: @escaping () -> Void,
        // v5: the flow already ran disclaimer (signature screen) + the
        // safety gate (care cluster); its reveal starts at the loader.
        skipsPreamble: Bool = false,
        debugStartAtFirstWeek: Bool = false,
        debugStartAtRatingAsk: Bool = false,
        debugStartAtProjection: Bool = false,
        debugStartAtCommitment: Bool = false,
        debugStartAtDisclaimer: Bool = false,
        debugStartAtBuilding: Bool = false,
        debugStartAtSafety: Bool = false,
        debugStartAtPermissions: Bool = false
    ) {
        self.bodyFocus = bodyFocus
        self.sessionLengthKey = sessionLengthKey
        self.voicePreference = voicePreference
        self.commitmentDaysKey = commitmentDaysKey
        self.currentWeightKg = currentWeightKg
        self.goalWeightKg = goalWeightKg
        self.onRevealComplete = onRevealComplete
        // DEBUG harnesses can jump straight to a specific beat so the
        // screen is screenshot-able without the full reveal sequence.
        // Production always starts at .disclaimer (the medical trust gate).
        self._step = State(initialValue:
            debugStartAtBuilding    ? .building    :
            debugStartAtSafety      ? .safety      :
            debugStartAtDisclaimer  ? .disclaimer  :
            debugStartAtCommitment  ? .commitment  :
            debugStartAtProjection  ? .projection  :
            debugStartAtRatingAsk   ? .ratingAsk   :
            debugStartAtPermissions ? .permissions :
            debugStartAtFirstWeek   ? .firstWeek   :
            skipsPreamble           ? .building    : .disclaimer)
    }

    private enum Step: Int {
        // v5 (2026-07-02): the reveal now STARTS at the building loader.
        // The medical disclaimer acknowledgment folded into the v5
        // signature screen (same medicalDisclaimerAckAtISO key), and the
        // safety gate relocated to the end of the v5 numbers act ("the
        // care part") — still pre-paywall, now also pre-vulnerability-
        // cluster, and no longer a cold shower at peak anticipation.
        // Both moves keep every side effect; only position changed.
        // Legacy v4.5 entry (--onboarding-v4) still routes disclaimer +
        // safety through these cases.
        case disclaimer
        case safety
        case building
        // Task 5 (2026-06-29) - one projection reveal. The user picks
        // her pace, then sees the SINGLE projection climax recomputed at
        // that pace: the becoming curve + calorie hero + goal date + the
        // clinician credibility strip (the former assessment's two unique
        // lines, folded in). The duplicate pace question (case 167), the
        // GoalDateReveal step, and the assessment's second curve are cut.
        // Pace persists via AppStorage (onboardingPickedTier) so the
        // post-paywall ProgramSetup just reads it back - no second pick.
        case pacePicker
        case projection
        case firstWeek
        // 2026-07-08 (founder call): the App Store review ask restored to
        // its peak-positive pre-paywall slot — right after firstWeek (she
        // has just seen her plan in motion), before the fear beat +
        // commitment + permissions, so momentum re-builds before the wall.
        // The full-screen sentiment gate (RatingSentimentScreen): "yes" →
        // native SKStoreReviewController, "not really" → feedback.
        // Eligibility (.postPlanReveal, once per install) self-skips
        // invisibly; ineligible installs advance straight to .ratingAsk.
        case reviewGate
        // v5: this slot now renders the FEAR-RESOLUTION beat (answers the
        // fear she named in Act IV); the name stays .ratingAsk for the
        // walker's step contract. The review ask is .reviewGate above.
        case ratingAsk
        // Task 7 (2026-06-28) - commitment ritual: one small promise the
        // user makes for tomorrow, in her own words, which schedules a
        // Day-1 nudge. Replaces the now-dead TrialPromisePresentation
        // (no-trial decision landed in the phase-1a activation pass).
        // T6 (2026-06-29) reorder: commitment now sits BEFORE permissions
        // so the notifications ask lands right after the promise.
        case commitment
        // The LAST pre-paywall screen - notifications ask, then the wall.
        case permissions
    }

    private var hasProjection: Bool {
        if let curr = currentWeightKg, let goal = goalWeightKg, curr > goal {
            return true
        }
        return false
    }

    var body: some View {
        ZStack {
            switch step {
            case .disclaimer:
                DisclaimerPresentation(
                    onContinue: { withAnimation(Motion.crossFade) { step = .safety } }
                )
                .transition(.opacity)
            case .safety:
                // T7 + safety-fix: the safety gate. ONLY .loss calls onPassed
                // and continues to the building loader. This includes bmi_healthy
                // (BMI 18.5-24.9): a healthy-BMI user gets a full .loss plan
                // with no cap - no adaptive note, no softening (founder decision).
                // .maintenance (pregnant/BF/ttc/low-BMI), .recovery, .blocked,
                // and .clinicianFirst all park on supportive dead-end terminals
                // inside the gate - never reaching building/paywall/app.
                SafetyGatePresentation(
                    onPassed: { withAnimation(Motion.crossFade) { step = .building } }
                )
                .transition(.opacity)
            case .building:
                BuildingPlanLoadingView(
                    bodyFocus: bodyFocus,
                    sessionLengthKey: sessionLengthKey,
                    voicePreference: voicePreference,
                    commitmentDaysKey: commitmentDaysKey,
                    onComplete: { advanceFromBuilding() }
                )
                .transition(.opacity)
            case .pacePicker:
                PacePickerPresentation(
                    currentWeightKg: currentWeightKg ?? 65,
                    goalWeightKg: goalWeightKg ?? 60,
                    onContinue: { withAnimation(Motion.crossFade) { step = .projection } }
                )
                .transition(.opacity)
            case .projection:
                ProjectionPresentation(
                    currentWeightKg: currentWeightKg,
                    goalWeightKg: goalWeightKg,
                    voicePreference: voicePreference,
                    onContinue: { withAnimation(Motion.crossFade) { step = .firstWeek } }
                )
                .transition(.opacity)
            case .firstWeek:
                FirstWeekPresentation(
                    onContinue: { advanceFromFirstWeek() }
                )
                .transition(.opacity)
            case .reviewGate:
                // 2026-07-08 (founder call): the App Store review ask,
                // restored pre-paywall at the peak-positive moment. "yes"
                // → native review; "not really" → feedback. Both advance
                // to the fear beat. markShown fired in advanceFromFirstWeek
                // so a retry can't re-ask.
                RatingSentimentScreen(
                    onYes: {
                        RatingPromptService.shared.trackSentimentResult(
                            trigger: .postPlanReveal, sentimentYes: true
                        )
                        RatingPromptService.shared.presentSystemReviewSheet()
                        withAnimation(Motion.crossFade) { step = .ratingAsk }
                    },
                    onNotReally: {
                        RatingPromptService.shared.trackSentimentResult(
                            trigger: .postPlanReveal, sentimentYes: false
                        )
                        showReviewFeedback = true
                    }
                )
                .transition(.opacity)
            case .ratingAsk:
                // v5: the fear-resolution beat (answers the fear she named
                // in Act IV; self-skips when no fear was kept). The review
                // ask is the .reviewGate step just before this.
                OV5FearResolutionPresentation(
                    onContinue: { withAnimation(Motion.crossFade) { step = .commitment } }
                )
                .transition(.opacity)
            case .commitment:
                CommitmentRitualPresentation(onContinue: {
                    withAnimation(Motion.crossFade) { step = .permissions }
                })
                .transition(.opacity)
            case .permissions:
                // v1.1.3 T6 (2026-06-29): permissions is now the LAST
                // pre-paywall beat. The commitment ritual schedules a
                // Day-1 nudge, so the notifications ask lands right after
                // the user makes the promise - then straight to the wall.
                // v1.1.3 reconcile (2026-06-29): this is the founder's
                // redesigned notification-mock nudge (banner + "tap to
                // feel it" + time pills), reclaimed from the orphaned
                // case 23. HealthKit stays its own mid-onboarding ask
                // (case 285), so this screen is notifications-only.
                NudgePermissionAsk(
                    voicePreference: voicePreference,
                    onContinue: onRevealComplete
                )
                .transition(.opacity)
            }
        }
        .task {
            // 2026-07-07 keep-wall: prefetch RevenueCat offerings while
            // she's still inside the reveal (~90s before the wall). The
            // SDK caches the response, so the wall's tier prices render
            // on FIRST paint instead of skeleton-pulsing through the
            // decisive seconds. Fire-and-forget; failures surface (and
            // retry) on the wall itself.
            guard Purchases.isConfigured else { return }
            _ = try? await Purchases.shared.offerings()
        }
        .sheet(isPresented: $showReviewFeedback, onDismiss: {
            withAnimation(Motion.crossFade) { step = .ratingAsk }
        }) {
            FeedbackView(source: "rating_gate_negative")
                .presentationDetents([.large])
                .presentationBackground(Palette.programEraBg)
        }
    }

    /// After firstWeek, gate the review ask: an eligible install sees it
    /// once (RatingPromptService flag + 30-day cooldown), everyone else
    /// advances straight to the fear beat.
    private func advanceFromFirstWeek() {
        if RatingPromptService.shared.isEligible(for: .postPlanReveal) {
            RatingPromptService.shared.markShown(.postPlanReveal)
            RatingPromptService.shared.trackGateShown(.postPlanReveal)
            withAnimation(Motion.crossFade) { step = .reviewGate }
        } else {
            withAnimation(Motion.crossFade) { step = .ratingAsk }
        }
    }

    private func advanceFromBuilding() {
        // FIX 2 (2026-06-29): persist the cohort-aware soft floor BEFORE the
        // pace-picker renders, so its soft-row week count + the projection
        // date both draw gentle at the cohort floor (not a flat 0.005).
        persistSoftFloorRate()
        // T5/T6 (2026-06-29): building → pacePicker → projection →
        // firstWeek → commitment → permissions when we have a loss goal.
        // PacePicker sits next to the projection it recomputes, so the
        // single projection reveal reflects the chosen pace.
        // FIX 3 (2026-06-29): never gut the reveal. With a loss goal -> full
        // pace-picker + projection. With weights but NO loss (delta <= 0,
        // maintenance) -> still show the projection (maintenance-framed: the
        // calorie/identity reveal renders, the curve gracefully omits) so she
        // reaches a coherent climax before the wall. Only a user with no
        // weight data at all falls through to firstWeek.
        let next: Step
        if hasProjection {
            next = .pacePicker
        } else if currentWeightKg != nil && goalWeightKg != nil {
            next = .projection
        } else {
            next = .firstWeek
        }
        withAnimation(Motion.crossFade) { step = next }
    }

    /// FIX 2 (2026-06-29): compute the cohort soft-tier floor from the
    /// collected cohort signals and stash it in UserDefaults so every
    /// `ProjectionMath.weeklyFraction(paceKey: "gentle")` reader (the reveal
    /// date, pace-row weeks, paywall hero, becoming card) derives the soft
    /// date from the SAME rate the calorie deficit uses. The floor is
    /// independent of sex + weight (compute() ignores sex for the rate math),
    /// so a placeholder sex is fine here. Defaults to 0.005 for a non-cohort
    /// user, which leaves behavior unchanged.
    private func persistSoftFloorRate() {
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg ?? 65,
            goalWeightKg:    goalWeightKg    ?? 60,
            sex:             .unspecified,
            age:             nil,
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: revealGlp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: revealHormonalStage),
            isShortSleeper:   ProgramGoalCalculator.isShortSleeper(from: revealSleepHours),
            weightTrendKey:   revealWeightTrend,
            glp1PhaseKey:     revealGlp1Phase
        ))
        UserDefaults.standard.set(window.lossRateFloor, forKey: ProjectionMath.softFloorDefaultsKey)
    }
}

// MARK: - SafetyGatePresentation (Task 7)
//
// Pre-paywall safety gate. Sits in the reveal step machine right after the
// disclaimer and before the building loader, so the SCOFF + pregnancy +
// medication + BMI screen runs EXACTLY ONCE, BEFORE the hard paywall.
//
// Why pre-paywall: charging a user and THEN routing a pregnant / under-18 /
// ED / insulin user to a "this isn't for you" terminal is a medical +
// refund + App Review 5.1.1 risk. The disclaimer step already covers the
// informed-consent beat (it writes medicalDisclaimerAckAtISO), so this gate
// only needs the pregnancy + SCOFF collection screens; the medication
// signal comes from the onboarding question (onboarding_medication_status,
// Task 4).
//
// Branch contract:
//   .loss (all cases, including bmi_healthy) -> onPassed() -> building -> paywall.
//      Healthy-BMI (18.5-24.9) is a full .loss user - no cap, no adaptive note,
//      no softening. The BMI-18.5 goal-weight picker floor (minimumGoalWeightKg)
//      prevents targeting an underweight goal; that is the only guard this cohort
//      needs. Founder decision 2026-06-29: TikTok cohort in the healthy range
//      wants to lose weight for aesthetic/fitness reasons; that is a valid goal.
//   .maintenance (pregnant / breastfeeding / ttc / BMI < 18.5)
//                             -> SafetyRecoveryView(.maintenance) DEAD-END
//   .recovery (ED)            -> SafetyRecoveryView(.eatingDisorder) DEAD-END
//   .blocked (under 18)       -> SafetyRecoveryView(.underage)       DEAD-END
//   .clinicianFirst (insulin) -> SafetyRecoveryView(.clinicianFirst) DEAD-END
//
// DEAD-END = a supportive screen whose CTA no-ops; it NEVER calls onPassed,
// so a screened-out user never reaches the building loader, the paywall, or
// any app content. This preserves the hard-paywall free-access invariant:
// the terminals are pre-paywall exits, not app access.
//
// Writes safety_screen_completed = true on resolution so the post-enrollment
// SafetyCheckInView (PlanView, legacy users) never re-prompts a user who
// already passed this gate. The post-paywall ProgramSetupSubflow no longer
// screens (de-duplicated in T7), so safetyAssessment runs once, here.

struct SafetyGatePresentation: View {
    let onPassed: () -> Void
    /// DEBUG-only fast path: skip the pregnancy + SCOFF screens and assess
    /// directly from seeded AppStorage so each branch is screenshot-able in
    /// one launch (no taps). Production always runs the real screens.
    var debugAutoAssess: Bool = false

    @AppStorage("onboardingCurrentWeightKg")    private var currentWeightKg: Double = 65
    @AppStorage("onboardingGoalWeightKg")       private var goalWeightKg: Double = 60
    @AppStorage("onboardingHeightCm")           private var heightCm: Double = 0
    @AppStorage("onboardingAgeRange")           private var ageRange: String = ""
    @AppStorage("onboarding_medication_status") private var medicationStatus: String = ""
    @AppStorage("onboarding_glp1_status")       private var glp1Status: String = ""
    @AppStorage("onboarding_weight_trend")      private var weightTrend: String = ""
    // v1.1.3 (2026-06-29): explicit goal direction (case 1330). Lets the gate
    // preserve a maintenance CHOICE for an otherwise-safe (.loss) user.
    @AppStorage("onboarding_goal_direction")    private var goalDirection: String = ""

    // Persisted safety outputs. pregnancyStatus + scoff counts are written
    // by the collection screens here; safety_screen_completed + program_mode
    // are read back downstream (PlanView legacy check-in, program build).
    @AppStorage("safety_pregnancy_status")      private var pregnancyStatus: String = ""
    @AppStorage("safety_scoff_yes")             private var scoffYes: Int = -1
    @AppStorage("safety_scoff_core")            private var scoffCore: Int = -1
    @AppStorage("safety_screen_completed")      private var safetyScreenCompleted: Bool = false
    @AppStorage("program_mode")                 private var programMode: String = "loss"
    // The adaptation, persisted so it is ACTUALLY APPLIED downstream (the
    // projection reveal + the post-paywall program build), not just reflected
    // in the gate note. paceCap: -1 = no cap (uncapped loss user); 0 = hard
    // zero-deficit (pregnant / ED / low-BMI); 0.0025 = gentle 0.25%/wk floor.
    // numericSuppression: hide all numeric loss targets (calorie / goal date /
    // loss curve) for clinically-unsafe-to-quantify cohorts (ED + pregnant).
    @AppStorage("safety_pace_cap")              private var safetyPaceCap: Double = -1
    @AppStorage("safety_numeric_suppression")   private var safetyNumericSuppression: Bool = false

    @State private var phase: Phase
    private enum Phase: Equatable {
        case pregnancy
        case scoff
        case terminal(SafetyTerminalVariant)
    }

    init(onPassed: @escaping () -> Void, debugAutoAssess: Bool = false) {
        self.onPassed = onPassed
        self.debugAutoAssess = debugAutoAssess
        // v7 D2 — the male persona skips the pregnancy screen (a male
        // answer at the gender beat stated male physiology for the
        // math; asking about pregnancy after that reads as the flow
        // not listening). The SCOFF still runs for everyone. An empty
        // pregnancy status assesses as none — the same value the
        // "none of these" tap writes semantically.
        let male = UserDefaults.standard.string(forKey: "onboardingGender") == "male"
        _phase = State(initialValue: male ? .scoff : .pregnancy)
    }

    var body: some View {
        Group {
            switch phase {
            case .pregnancy:
                SafetyPregnancyView(onComplete: handlePregnancy)
            case .scoff:
                SCOFFScreenView(onComplete: handleScoff)
            case .terminal(let variant):
                // Access-for-all (founder 2026-06-29): every cohort PROCEEDS
                // to the paywall with an ADAPTED plan (paceCap / numeric
                // suppression), never a dead-end. The supportive note's CTA
                // advances via onPassed().
                SafetyRecoveryView(variant: variant, onContinueGently: { onPassed() })
            }
        }
        .onAppear {
            if debugAutoAssess { route(assess()) }
        }
    }

    private func handlePregnancy(_ status: String) {
        pregnancyStatus = status
        withAnimation(Motion.crossFade) { phase = .scoff }
    }

    private func handleScoff(_ yes: Int, _ core: Int) {
        scoffYes = yes
        scoffCore = core
        route(assess())
    }

    private func assess() -> ProgramGoalCalculator.SafetyAssessment {
        ProgramGoalCalculator.safetyAssessment(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: safeGoalWeightKg,
            heightCm: heightCm,
            ageRange: ageRange,
            scoffYesCount: scoffYes,
            pregnancyStatus: pregnancyStatus,
            medicationKey: medicationStatus,
            glp1StatusKey: glp1Status,
            weightTrendKey: weightTrend,
            scoffCoreYesCount: scoffCore
        ))
    }

    /// Never assess against a goal below BMI 18.5 (matches the program
    /// build's clamp). Height comes from onboarding; 0 = unknown (skip).
    private var safeGoalWeightKg: Double {
        guard heightCm > 0 else { return goalWeightKg }
        return max(goalWeightKg, ProgramGoalCalculator.weightForBMI(18.5, heightCm: heightCm))
    }

    private func route(_ a: ProgramGoalCalculator.SafetyAssessment) {
        // v1.1.3 (2026-06-29): honor an explicit maintenance CHOICE (case 1330)
        // when the user is otherwise safe. A healthy choice-maintainer assesses
        // as .loss (goal == current, no safety flag), which would otherwise
        // overwrite her "maintenance" program_mode back to "loss". Genuine
        // safety modes (recovery / blocked / clinicianFirst / safety-maintenance)
        // are MORE protective and still take precedence — they only ever fire
        // for non-.loss assessments.
        if a.mode == .loss
            && (goalDirection == "maintain" || goalDirection == "maintain_kept") {
            programMode = ProgramGoalCalculator.ProgramMode.maintenance.rawValue
        } else {
            programMode = a.mode.rawValue
        }
        safetyScreenCompleted = true
        // Persist the adaptation so it is genuinely applied (projection reveal
        // + post-paywall program build), not just narrated in the gate note.
        safetyPaceCap = a.paceCap ?? -1
        safetyNumericSuppression = a.numericSuppression
        switch a.mode {
        case .loss:
            // The ONLY mode that passes the gate. Includes bmi_healthy
            // (BMI 18.5-24.9): healthy-BMI gets a full normal loss plan -
            // no cap, no adaptive note. The BMI-18.5 goal-weight picker
            // floor prevents underweight targeting. Continues to building.
            onPassed()
        case .maintenance:
            // Pregnant / breastfeeding / ttc / BMI < 18.5. These get an
            // ADAPTED plan (no deficit via paceCap + numeric suppression),
            // a brief supportive note, then they PROCEED to the paywall -
            // access for everyone (founder 2026-06-29). lowBMI selects copy.
            let variant = SafetyTerminalVariant.maintenance(lowBMI: a.reasonKey == "bmi_low")
            withAnimation(Motion.crossFade) { phase = .terminal(variant) }
        case .recovery:
            // ED-screen positive: non-numeric supportive plan + non-blocking
            // resources, then proceed to the paywall.
            withAnimation(Motion.crossFade) { phase = .terminal(.eatingDisorder) }
        case .blocked:
            // Under 18: gentlest habit-first plan + guardian note, then proceed.
            withAnimation(Motion.crossFade) { phase = .terminal(.underage) }
        case .clinicianFirst:
            // Insulin / sulfonylurea: clinician-aware plan + review note, then proceed.
            withAnimation(Motion.crossFade) { phase = .terminal(.clinicianFirst) }
        }
    }
}

#if DEBUG
// Debug harness for `--debug-safety-gate`. Auto-assesses from seeded
// AppStorage so each branch is one launch + one screenshot:
//   insulin       -> clinician-first terminal (/tmp/t7_clinician.png)
//   scoff >= 2    -> recovery terminal        (/tmp/t7_recovery.png)
//   pregnant      -> maintenance terminal     (/tmp/maintenance_terminal.png)
//   clean         -> "safety passed" proceed marker (/tmp/t7_loss.png)
// The passed marker proves a clean user PROCEEDS toward the wall and does
// NOT land on app content (no MainTabView).
struct SafetyGateDebugHarness: View {
    @State private var passed = false
    var body: some View {
        ZStack {
            if passed {
                ZStack {
                    Palette.programBgPrimary.ignoresSafeArea()
                    VStack(spacing: 14) {
                        ItalicAccentText(
                            "safety passed.",
                            italic: ["passed"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .fixedSize(horizontal: false, vertical: true)
                        Text("continuing to build your plan, then the paywall.")
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Space.lg)
                }
            } else {
                SafetyGatePresentation(onPassed: { passed = true }, debugAutoAssess: true)
            }
        }
    }
}

// Debug harness for `--debug-projection-suppressed`. Seeds the persisted
// safety-suppression flag in init (synchronously, before body builds, so the
// projection's @AppStorage reads it) then jumps to the projection with a REAL
// loss delta. Proves the adaptation is applied: a suppressed cohort gets the
// non-numeric reveal even though current (75) > goal (65).
struct SuppressedProjectionDebugHarness: View {
    init() {
        UserDefaults.standard.set(true, forKey: "safety_numeric_suppression")
    }
    var body: some View {
        OnboardingRevealView(
            bodyFocus: ["flatBelly"],
            sessionLengthKey: "ten",
            voicePreference: "encouraging",
            commitmentDaysKey: "five",
            currentWeightKg: 75,
            goalWeightKg: 65,
            onRevealComplete: {},
            debugStartAtProjection: true
        )
    }
}
#endif

// MARK: - DisclaimerPresentation
//
// Medical trust gate - the FIRST screen every user sees in OnboardingRevealView.
// Layout: GrainfieldBackground alive-cream surface with a staggered cascade:
//   HEADLINE  - "first, a quick check." (JeniHeroSerif, italic punch on "quick")
//   BODY      - 4 points separated by HairlineRules
//   TRUST     - soft trust line + dusty-rose heart (text-presentation, NOT emoji red)
//   CTA       - "i understand" docked below scroll zone
//
// On acknowledge: writes medicalDisclaimerAckAtISO to AppStorage (ISO8601 string)
// and fires ActivationHaptics.shared.commit(). handleOnboardingComplete reads
// this key back to persist on UserRecord.medicalDisclaimerAckAt.
//
// Hard constraints: no em-dashes, no red, no sticker scatter, reduce-motion safe,
// content fits above docked button.

private struct DisclaimerPresentation: View {
    let onContinue: () -> Void

    // AppStorage key that handleOnboardingComplete reads back to persist on
    // UserRecord. Written on acknowledgment; left empty if user never taps.
    @AppStorage("medicalDisclaimerAckAtISO") private var ackAtISO: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // The four substance points - rendered as a clinical checklist inside
    // the intake card. Copy unchanged from the prior pass (no em-dashes;
    // semicolons + periods only).
    private let points: [String] = [
        "this builds a weight-loss plan; it is not medical advice.",
        "not for use during pregnancy, or by anyone under 18.",
        "if you have a medical condition or a history of disordered eating, please talk to your clinician first.",
        "we use what you share to build and adjust your plan."
    ]

    // Staggered cascade reveal states
    @State private var markVisible      = false
    @State private var headlineVisible  = false
    @State private var cardVisible      = false
    @State private var revealedRows     = 0       // checklist rows populated so far
    @State private var credVisible      = false
    @State private var trustVisible     = false
    @State private var ctaVisible       = false

    var body: some View {
        ZStack {
            // bgPrimary cream is the ONLY background per the locked color
            // tokens. The Grainfield gives the cream a paper-and-light
            // depth so the intake card reads as a real document on a desk,
            // not a flat legal screen.
            GrainfieldBackground()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: Space.hero)

                        // CLINICAL HEADER - tracked-caps chart label on the
                        // left, a thin medical cross mark in a hairline ring
                        // on the right. The recognizable-but-restrained
                        // "this is a considered intake" motif. Hairline rule
                        // beneath turns the pair into a document header.
                        HStack(alignment: .center) {
                            Text("a quick safety check")
                                .font(Typo.kicker)
                                .kerning(0.18 * 10)
                                .textCase(.uppercase)
                                .foregroundStyle(Palette.cocoaTertiary)
                            Spacer(minLength: 12)
                            ClinicalCrossMark()
                                .frame(width: 26, height: 26)
                        }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(markVisible ? 1 : 0)
                        .animation(Motion.entranceSoft, value: markVisible)

                        Spacer().frame(height: 12)

                        HairlineRule()
                            .padding(.horizontal, Space.screenPadding)
                            .opacity(markVisible ? 1 : 0)
                            .animation(Motion.entranceSoft, value: markVisible)

                        Spacer().frame(height: Space.lg)

                        // HEADLINE - her75 editorial register. "quick" as the
                        // italic punch word frames this as a brief pause, not
                        // a barrier.
                        ItalicAccentText(
                            "first, a quick check.",
                            italic: ["quick"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .leading
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(headlineVisible ? 1 : 0)
                        .offset(y: reduceMotion ? 0 : (headlineVisible ? 0 : 10))
                        .animation(Motion.entrance, value: headlineVisible)

                        Spacer().frame(height: 10)

                        Text("a few honest things before we build your plan.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Space.screenPadding)
                            .opacity(headlineVisible ? 1 : 0)
                            .animation(Motion.entranceSoft, value: headlineVisible)

                        Spacer().frame(height: Space.lg)

                        // INTAKE CARD - the four points as a considered
                        // clinical checklist. Elevated cream stock + a single
                        // hairline border reads as a chart/form, not a wall of
                        // text. Each row carries a small drawn check in a
                        // hairline ring; rows populate in sequence so the form
                        // visibly fills in.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(points.enumerated()), id: \.offset) { idx, point in
                                checklistRow(point, index: idx)
                                if idx < points.count - 1 {
                                    HairlineRule()
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.bgElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Palette.hairlineCocoa, lineWidth: 1)
                        )
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(cardVisible ? 1 : 0)
                        .offset(y: reduceMotion ? 0 : (cardVisible ? 0 : 10))
                        .animation(Motion.entrance, value: cardVisible)

                        Spacer().frame(height: Space.md)

                        // CREDIBILITY CUE - honest, not overclaimed. A small
                        // check + tracked micro-label, built from the same
                        // HairlineKit register as the checklist marks.
                        HStack(alignment: .center, spacing: Space.sm) {
                            CheckGlyph()
                                .frame(width: 15, height: 15)
                            Text("grounded in established weight-loss guidance.")
                                .font(Typo.statLabel)
                                .kerning(0.04 * 11)
                                .foregroundStyle(Palette.cocoaSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(credVisible ? 1 : 0)
                        .animation(Motion.entranceSoft, value: credVisible)

                        Spacer().frame(height: Space.lg)

                        // TRUST LINE - the warm close. Heart uses the
                        // text-presentation selector (\u{FE0E}) so it renders
                        // in dusty rose, NOT emoji red.
                        HStack(alignment: .top, spacing: Space.xs) {
                            Text("we'd rather pace you slowly than promise something that won't last.")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(trustVisible ? 1 : 0)
                        .animation(Motion.entranceSoft, value: trustVisible)

                        Spacer().frame(height: Space.md)
                    }
                }

                // Docked CTA band. JFContinueButton already pads horizontal
                // Space.lg + bottom 24 internally; the bgPrimary band keeps
                // scroll content from bleeding behind it on short devices.
                JFContinueButton(label: "i understand", action: acknowledge)
                    .padding(.top, 8)
                    .background(Palette.bgPrimary)
                    .opacity(ctaVisible ? 1 : 0)
                    .animation(Motion.entranceSoft, value: ctaVisible)
            }
        }
        .task {
            // Warm the haptic generator on appear so the first play
            // has no latency.
            ActivationHaptics.shared.prepare()

            // Cascade: header mark -> headline+sub -> card -> rows fill in
            // sequence -> credibility -> trust -> CTA. Per-element animation
            // gates keep reduce-motion landings offset-free.
            withAnimation(Motion.entranceSoft) { markVisible = true }
            try? await Task.sleep(nanoseconds: 240_000_000)

            withAnimation(Motion.entrance) { headlineVisible = true }
            try? await Task.sleep(nanoseconds: 360_000_000)

            withAnimation(Motion.entrance) { cardVisible = true }
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Rows populate one at a time so the form reads as filling in.
            for i in 1...points.count {
                withAnimation(Motion.entrance) { revealedRows = i }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            try? await Task.sleep(nanoseconds: 120_000_000)

            withAnimation(Motion.entranceSoft) { credVisible = true }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(Motion.entranceSoft) { trustVisible = true }
            try? await Task.sleep(nanoseconds: 240_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    // Checklist row: a small hairline-ringed check + the point text.
    // Rows fade/rise in as `revealedRows` advances so the card populates
    // rather than slamming in as a block.
    @ViewBuilder
    private func checklistRow(_ text: String, index: Int) -> some View {
        let shown = reduceMotion || index < revealedRows
        HStack(alignment: .top, spacing: 12) {
            ChecklistMark()
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Space.md)
        .opacity(shown ? 1 : 0)
        .offset(y: reduceMotion ? 0 : (shown ? 0 : 6))
        .animation(Motion.entrance, value: revealedRows)
    }

    // Acknowledge: haptic fires BEFORE any state change so it lands while
    // the user's finger is still in contact. AppStorage write creates the
    // ISO timestamp; handleOnboardingComplete reads it back and sets
    // UserRecord.medicalDisclaimerAckAt.
    private func acknowledge() {
        ActivationHaptics.shared.commit()
        ackAtISO = ISO8601DateFormatter().string(from: Date())
        onContinue()
    }
}

// MARK: - Clinical marks (DisclaimerPresentation)
//
// Small drawn glyphs that give the disclaimer its clinical-but-warm
// register without a single bitmap asset. All stroked in the cocoa
// hairline scale so they sit in the same "calm lab readout" family as
// HairlineKit.

// A thin check stroke - the atomic checklist mark.
private struct CheckGlyph: View {
    var color: Color = Palette.cocoaSecondary
    var lineWidth: CGFloat = 1.4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.20, y: h * 0.54))
                p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.74))
                p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.28))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

// A check inside a faint hairline ring - the per-row checklist marker.
private struct ChecklistMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(Palette.hairlineCocoa, lineWidth: 1)
            CheckGlyph().padding(5)
        }
        .accessibilityHidden(true)
    }
}

// A thin medical cross inside a hairline ring - the header trust motif.
// Two rounded capsules so the cross reads as drawn, not a font glyph.
// Promoted to internal (2026-06-29) so the safety gate in
// OnboardingComponents can share the same clinical-intake header motif.
struct ClinicalCrossMark: View {
    var body: some View {
        ZStack {
            Circle().stroke(Palette.hairlineCocoa, lineWidth: 1)
            Capsule(style: .continuous)
                .fill(Palette.cocoaSecondary)
                .frame(width: 2, height: 11)
            Capsule(style: .continuous)
                .fill(Palette.cocoaSecondary)
                .frame(width: 11, height: 2)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - ProjectionPresentation
//
// Full-bleed wrapper around BecomingProjectionCard. Headline frames the
// card as "your becoming, plotted" — italic-Fraunces punch word per the
// brand voice. The card itself already renders the scrapbook chrome +
// curve + endpoint sticker, so this view only adds the surrounding
// composition (header + Continue).

private struct ProjectionPresentation: View {
    let currentWeightKg: Double?
    let goalWeightKg: Double?
    let voicePreference: String
    let onContinue: () -> Void

    @State private var heroVisible = false
    @State private var calorieVisible = false
    @State private var cardVisible = false
    // Task 5 (2026-06-29): clinician credibility strip, folded in from
    // the now-cut assessment step. Reveals just after the curve card.
    @State private var credibilityVisible = false
    @State private var contextVisible = false
    @State private var ctaVisible = false
    // v3 P11.6+ (2026-06-10) — per-tile cascade counter for the 6
    // proof tiles. Driven by an async chain that fires after
    // calorieVisible flips true; uses `Motion.cascadeTight = 0.06s`
    // per [[feedback-her75-motion-vocabulary]] so the cluster reads
    // as one moment with a hint of order, not a list animation.
    // Reduce-motion gate: when env value is true, all 6 land
    // immediately (revealedTiles set to 6 in the body's task).
    @State private var revealedTiles: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Delta v7 D68 — diet-first reveal: calorie target hero, weight
    // curve secondary, workout tertiary. Calorie estimate is a rough
    // starting number (Helms-style 22 kcal/kg w/ 1300-2000 clamp); the
    // MacroFactor honesty caption ("we'll learn your real number…")
    // is the trust signal that lets us ship without a full TDEE
    // computation in v1.0.7. Real adaptive TDEE lands in v1.0.8.
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    // v2-A5: surface the credibility-grade inputs back to the user
    // below the projection card so she sees her vulnerable answers
    // were actually used. Only renders chips for fields she filled —
    // empty / "prefer not to say" values drop out so the row never
    // narrates context she didn't give us.
    @AppStorage("onboardingSleepHours")      private var sleepHours: String = ""
    @AppStorage("onboardingEatingCadence")   private var eatingCadence: String = ""
    @AppStorage("onboardingHormonalStage")   private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")    private var glp1Status: String = ""
    // Task 1 (2026-06-29): TDEE-based calorie target - collected fields
    // needed for the Mifflin-St Jeor formula and pace-implied deficit.
    @AppStorage("onboardingPickedTier")      private var pickedTierRaw: String = "medium"
    @AppStorage("onboardingHeightCm")        private var heightCm: Double = 0
    @AppStorage("onboardingAgeRange")        private var ageRange: String = ""
    @AppStorage("onb_v4_movement_baseline")  private var movementBaseline: String = ""
    // T2 (2026-06-29): weight trend + GLP-1 phase now move pacing.
    @AppStorage("onboarding_weight_trend")   private var weightTrend: String = ""
    @AppStorage("onboarding_glp1_phase")     private var glp1Phase: String = ""
    // FIX 4 (2026-06-29): collected gender (case 130) -> BMR-formula sex.
    @AppStorage("onboardingGender")          private var gender: String = ""
    // Persuasion FIX 4 (2026-06-29): true once she passed the pre-paywall
    // safety gate. Surfaced as a quiet "safety-screened" receipt on the
    // credibility strip - honest (she passed it to get here) + trust-building
    // for the scam-wary buyer. No competitor runs this screen.
    @AppStorage("safety_screen_completed")   private var safetyScreenCompleted: Bool = false
    // Safety adaptation, written at the gate (SafetyGatePresentation.route).
    // These make the adaptation REAL on the reveal: a zero pace cap routes to
    // the non-numeric maintenance reveal, and a >=0 cap clamps the picked rate.
    @AppStorage("safety_pace_cap")            private var safetyPaceCap: Double = -1
    @AppStorage("safety_numeric_suppression") private var safetyNumericSuppression: Bool = false
    // v1.1.3 (2026-06-29): explicit goal direction (case 1330). A "recomp"
    // (tone-up) choice clamps the deficit to a gentle glide so the calorie
    // number reflects the gentler pace she chose, not her picked tier.
    // maintain / maintain_kept reach the maintenance reveal via goal == current
    // (isMaintenanceReveal), so they need no special-case here.
    @AppStorage("onboarding_goal_direction")  private var goalDirection: String = ""

    /// Gentle tone-up deficit (~0.25%/wk) for the recomp cohort. Below the
    /// 0.5% default floor — a small, lean-mass-sparing deficit.
    private let recompGentleRate: Double = 0.0025

    /// FIX 3 (2026-06-29): true when she has weights but no loss delta
    /// (already at / below goal). Drives the maintenance-framed reveal so a
    /// delta-0 user reaches a coherent climax instead of a gutted screen.
    /// Also true for safety-suppressed cohorts (ED + pregnant) and any
    /// zero-pace-cap cohort: they get the same non-numeric "your plan, steady"
    /// reveal - NO calorie hero, NO goal date, NO loss curve.
    private var isMaintenanceReveal: Bool {
        if safetyNumericSuppression || safetyPaceCap == 0 { return true }
        guard let curr = currentWeightKg, let goal = goalWeightKg else { return false }
        return curr <= goal
    }

    /// True ONLY for safety-suppressed cohorts (ED + pregnant via
    /// numericSuppression, plus any zero-pace-cap cohort like low-BMI). When
    /// true, EVERY numeric loss target is omitted: no calorie hero, no goal /
    /// becoming date, no loss curve - matching the clamped program build. A
    /// plain delta-0 maintenance user (curr <= goal, no safety flag) is NOT
    /// suppressed: she keeps the maintenance-TDEE calorie + card (FIX 3).
    private var suppressNumbers: Bool {
        safetyNumericSuppression || safetyPaceCap == 0
    }

    var body: some View {
        ZStack {
            // FIX 2 (2026-06-29): the reveal peak now sits on the same
            // alive cream surface as the disclaimer + commitment, not a
            // flat fill. programBgPrimary aliases to cream bgPrimary;
            // Grainfield adds the paper-and-light depth so the peak reads
            // as the most composed surface in the flow, not the plainest.
            GrainfieldBackground(intensity: 0.06)

            // Content scrolls; the CTA is docked below via safeAreaInset
            // (see the modifier on the ZStack). The 6-tile multi-proof
            // grid grows content past the viewport on most devices, so
            // the scroll + docked-CTA split keeps headline + CTA on screen.
            VStack(spacing: 0) {
              ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.md)

                        // v3 P11.6 (2026-06-10) — promoted to heroHeadline
                        // (42pt SemiBold). Plan reveal is THE hero
                        // moment of onboarding; questionHero (34pt)
                        // read as too small after the her75
                        // standardization pass.
                        // v4 R1 (2026-06-10) — CLIP FIX. Founder device
                        // screenshot showed this hero bleeding off both
                        // screen edges: no horizontal padding + no wrap
                        // allowance at 38pt. Padding + fixedSize lets it
                        // wrap inside the safe width.
                        ItalicAccentText(
                            isMaintenanceReveal ? "your plan, steady" : projectionHeadline,
                            italic: isMaintenanceReveal ? ["steady"] : ["plotted"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        // FIX 3: maintenance subhead when there's no loss delta
                        // (the curve omits, so a weeks line would read as a
                        // broken promise). v6 P3: the loss sub speaks HER
                        // computed horizon, not a hardcoded "12 weeks".
                        Text(isMaintenanceReveal
                             ? "you're right where you want to be. here's the fuel to hold it."
                             : projectionSubLine)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        // v6 P3 — THE CURVE LEADS. The single most
                        // persuasive object in the funnel opens the peak
                        // screen instead of living below the fold (the
                        // founder's 08-01 walk caught the tile card
                        // burying it). Omitted for EVERY maintenance
                        // reveal — the safety-suppressed cohorts
                        // (pregnant / ED / zero-cap) AND the choice
                        // maintainers — so no one off the loss path ever
                        // sees a loss trajectory.
                        if !isMaintenanceReveal {
                            BecomingProjectionCard(
                                currentWeightKg: currentWeightKg,
                                goalWeightKg: goalWeightKg,
                                chartHeight: 130
                            )
                            .padding(.horizontal, Space.md)
                            .opacity(cardVisible ? 1 : 0)
                            .scaleEffect(cardVisible ? 1.0 : 0.97)

                            // The honesty caption belongs to the curve it
                            // hedges (it floated orphaned inside the old
                            // tile grid).
                            Text("an estimate, not a promise.")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, -6)
                                .opacity(cardVisible ? 1 : 0)
                        }

                        if let kcal = estimatedCalorieTarget {
                            planTilesCard(kcal: kcal)
                                .padding(.horizontal, Space.lg)
                                .opacity(calorieVisible ? 1 : 0)
                                .scaleEffect(calorieVisible ? 1.0 : 0.97)
                            // Persuasion FIX 5 (2026-06-29): reciprocity gift.
                            // The target already persists to foodDailyTarget on
                            // this reveal, so it IS hers before the wall -
                            // provenance-clean. Frame it as owned, not teased.
                            Text("these numbers are yours to keep.")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, Space.lg)
                                .opacity(calorieVisible ? 1 : 0)
                        }

                        // Task 5 (2026-06-29): clinician credibility strip,
                        // merged from the cut assessment step. A single
                        // hairline rule + the credibility line + (only when a
                        // cohort modifier gentled the floor) the provenance
                        // line. HairlineKit register so it reads as a calm lab
                        // annotation under the curve, not a second card. The
                        // assessment's ArcSparkline (the duplicate 3rd curve)
                        // is dropped - the BecomingProjectionCard is the one
                        // curve now.
                        credibilityStrip
                            .id("credibility")
                            .padding(.horizontal, Space.lg)
                            .opacity(credibilityVisible ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (credibilityVisible ? 0 : 6))
                            .animation(Motion.entrance, value: credibilityVisible)

                        // v5 (2026-07-02): causal receipts replace the
                        // context chips. Chips listed inputs without
                        // consequence (personalization theater); each
                        // receipt row renders ONLY when its key is set
                        // AND the matching engine modifier actually
                        // fired — the quiz proven as computation.
                        if !causalReceipts.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(causalReceipts.enumerated()), id: \.offset) { idx, r in
                                    if idx > 0 {
                                        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.33)
                                    }
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(r.0)
                                            .font(Typo.caption)
                                            .foregroundStyle(Palette.cocoaTertiary)
                                        Spacer(minLength: 12)
                                        ItalicAccentText(
                                            r.1, italic: r.2,
                                            baseFont: .custom("DMSans-Medium", size: 13),
                                            italicFont: .custom("JeniHeroSerif-Italic", size: 15),
                                            color: Palette.textPrimary,
                                            alignment: .trailing
                                        )
                                    }
                                    .padding(.vertical, 10)
                                }
                            }
                            .padding(.horizontal, Space.lg + Space.sm)
                            .opacity(contextVisible ? 1 : 0)
                        }

                        Spacer().frame(height: Space.md)
                    }
                }
                // 2026-06-29 conviction Beat 3 — DEBUG-only harness to
                // screenshot the promoted "science behind your pace"
                // credential card, which lives below the projection curve
                // (off the first viewport). Auto-scrolls to it after the
                // reveal cascade settles. No effect in release.
                #if DEBUG
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("--debug-projection-credibility") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                proxy.scrollTo("credibility", anchor: .center)
                            }
                        }
                    }
                }
                #endif
              }
            }
        }
        // FIX 1 (2026-06-29): canonical JFContinueButton docked via
        // safeAreaInset, replacing the hand-rolled 52pt italic-Fraunces
        // cocoa capsule. her75 CTAs are functional sans, height 56, with
        // the locked disabled / press / haptic states.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue)
                .padding(.top, 8)
                .background(Palette.bgPrimary)
                .opacity(ctaVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: ctaVisible)
        }
        .task {
            // v6 release pass — canonical reveal reach (once; the name
            // reuses the previously-unfired legacy plan_reveal_viewed
            // so dashboards keep one vocabulary).
            V6Funnel.track("plan_reveal_viewed", once: true, properties: [
                "variant": isMaintenanceReveal ? "maintenance" : "loss",
            ])
            // v6 P3 cascade: headline → THE CURVE (the object she came
            // for) → the four plan tiles → credibility → receipts →
            // continue. The curve draws itself (BecomingProjectionCard
            // owns the 0.9s trim) while the tiles stagger in beneath.
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(Motion.entrance) { cardVisible = true }
            // Stamp foodDailyTarget so Home reads the same number she
            // saw at reveal (avoids the "where did 1650 come from?"
            // moment on first Home open).
            if let kcal = estimatedCalorieTarget, foodDailyTarget == 0 {
                foodDailyTarget = Double(kcal)
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(Motion.entrance) { calorieVisible = true }
            // v3 P11.6+ — per-tile cascade, now four true tiles. Tiles
            // land 0.06s apart from when the grid appears so the
            // cluster reads choreographed, not bulk-faded.
            if reduceMotion {
                revealedTiles = 4
            } else {
                for i in 0..<4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Motion.cascadeTight) {
                        withAnimation(Motion.entranceSoft) {
                            revealedTiles = i + 1
                        }
                    }
                }
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(Motion.entrance) { credibilityVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { contextVisible = true }
            try? await Task.sleep(nanoseconds: 350_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    /// v6 P3 — the loss sub speaks HER computed horizon through the
    /// same ProjectionMath every other surface reads. Falls back to a
    /// horizonless line when the weeks can't compute.
    /// v7 persona law at the reveal (outside the OV5 machine, so read
    /// the canonical key): the her-register renders only for an
    /// explicit "female" answer.
    private var isHerPersona: Bool {
        UserDefaults.standard.string(forKey: "onboardingGender") == "female"
    }

    /// v7 D7 — the conceit headline ("your becoming, plotted") gave way
    /// to the computed horizon: her number in the hero, for everyone.
    private var projectionHeadline: String {
        if let curr = currentWeightKg, let goal = goalWeightKg,
           let weeks = ProjectionMath.projectedWeeks(
               currentKg: curr, goalKg: goal,
               paceKey: UserDefaults.standard.string(forKey: ProjectionMath.paceDefaultsKey)
           ) {
            return "your next \(weeks) weeks, plotted"
        }
        return "your plan, plotted"
    }

    /// v7 W4 — the sub is the OUTCOME ECHO: her Act-I answer, named
    /// back at the peak (falsifiable personalization — a different
    /// answer produces a different line). The provenance clause stays.
    private var projectionSubLine: String {
        let outcomes: [String: String] = [
            "noise": "built first to quiet the food noise.",
            "myself": "built to get you back to feeling like yourself.",
            "energy": "built for steady energy.",
            "clothes": "built toward clothes that fit right.",
            "keep": "built to keep off what you lost.",
        ]
        if let o = outcomes[UserDefaults.standard.string(forKey: "onb_v5_outcome") ?? ""] {
            return "\(o) drawn from your answers."
        }
        return "your care plan, drawn from your answers."
    }

    // MARK: - Clinician credibility strip (Task 5)

    /// Hairline credibility strip rendered under the projection curve,
    /// merged from the cut assessment step. Uses HairlineKit's HairlineRule
    /// so it sits in the calm lab-readout register. The provenance line is
    /// omitted (not rendered empty) when no cohort modifier applied.
    // 2026-06-29 (conviction audit, Beat 3): PROMOTED from a loose stack
    // of textSecondary captions (which read as a legal footer) into ONE
    // designed "the science behind your pace" credential card. A titled
    // header + a hairline-bracketed table of accent-marker credential
    // rows, each pairing an honest claim (cocoa register) with a
    // tracked-caps SOURCE tag — so the rigor reads as a credential to a
    // scam-wary buyer, not a disclaimer. Attribution only: NWCR is
    // characterized honestly, no fabricated stat, no numeric promise.
    // Reduce-motion is already gated at the call site (credibilityVisible).
    private var credibilityStrip: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title — the promotion from footer to credential section.
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: 14, height: 1.5)
                Text("the science behind your pace")
                    .font(Typo.captionTracked)
                    .textCase(.uppercase)
                    .kerning(1.8)
                    .foregroundStyle(Palette.cocoaSecondary)
            }
            .padding(.bottom, Space.sm)

            HairlineRule()

            // Cohort provenance (only when a modifier gentled the floor) —
            // rendered as the LEAD credential so "calibrated for you" lands
            // first. Omitted entirely on the default pace.
            if let provenance = provenanceLine {
                paceCredentialRow(claim: provenance, source: "calibrated for you")
                HairlineRule()
            }
            paceCredentialRow(
                claim: "paced to the 0.5-1% a week range clinicians use. slower is what lasts.",
                source: "ACSM"
            )
            HairlineRule()
            paceCredentialRow(
                claim: isHerPersona
                    ? "women who keep it off lose slowly, and ride out the stalls."
                    : "people who keep it off lose slowly, and ride out the stalls.",
                source: "national weight control registry"
            )
            HairlineRule()
            // v8 Stage A (04_DECISIONS FR — expectations): the
            // credible first milestone replaces fantasy speed.
            // Educational framing only — no promise, no timeline,
            // her pace stays hers.
            paceCredentialRow(
                claim: isHerPersona
                    ? "the first milestone that moves health is 5-7%. for most women it arrives well before a final goal, each at her own pace."
                    : "the first milestone that moves health is 5-7%. for most people it arrives well before a final goal.",
                source: "fda benchmark \u{00B7} diabetes prevention program"
            )
            // Persuasion FIX 4 (2026-06-29): quiet safety-screen receipt.
            // Honest - she passed the pre-paywall gate to reach this screen.
            // Check glyph (not a heart) keeps the terminal-heart rule clean.
            if safetyScreenCompleted {
                HairlineRule()
                paceCredentialRow(
                    claim: "safety-screened before you started.",
                    source: "pre-paywall check \u{2713}"
                )
            }
            HairlineRule()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One credential row — an accent marker, an honest claim in the
    /// legible cocoa register, and a tracked-caps SOURCE tag beneath.
    private func paceCredentialRow(claim: String, source: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(claim)
                    .font(.custom("DMSans-Regular", size: 14))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source)
                    .font(Typo.captionTracked)
                    .textCase(.uppercase)
                    .kerning(1.6)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }

    /// One-line provenance tied to the cohort flag that gentled the floor
    /// rate. Returns nil when no modifier applied (default pace) so the
    /// line is fully omitted, not rendered empty. Every branch traces to a
    /// real collected field (sleep / GLP-1 status / hormonal stage).
    private var provenanceLine: String? {
        if ProgramGoalCalculator.isShortSleeper(from: sleepHours) {
            return "because you sleep around 6 hours, we set a gentler pace."
        }
        if ProgramGoalCalculator.isGLP1User(from: glp1Status) {
            return "because of your body's signals right now, we paced this gently."
        }
        if ProgramGoalCalculator.isPerimenopausal(from: hormonalStage) {
            return "because of where your body is, we paced this gently."
        }
        return nil
    }

    // MARK: - Calorie target hero (D68 / Task 1)

    /// Window for the cohort-derived soft-pace floor. Matches the same
    /// ProgramGoalCalculator.compute call in PacePickerPresentation so
    /// both surfaces derive from one consistent set of cohort inputs.
    private var revealWindow: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg ?? 65,
            goalWeightKg:    goalWeightKg    ?? 60,
            sex:             ProgramGoalCalculator.sex(fromGenderKey: gender),
            age:             nil,
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:   ProgramGoalCalculator.isShortSleeper(from: sleepHours),
            weightTrendKey:   weightTrend,
            glp1PhaseKey:     glp1Phase
        ))
    }

    /// Loss rate for the picked pace tier - the SAME rate that draws
    /// the goal date on the projection card. Hard = 1%/wk,
    /// Medium = 0.75%/wk, Soft = cohort floor from ProgramGoalCalculator
    /// (0.5%, 0.4%, or 0.3% depending on sleep/GLP-1/perimenopause).
    /// FIX 3: a maintenance reveal (no loss delta) uses a 0 deficit so the
    /// calorie number is an honest maintenance TDEE, not a phantom deficit.
    private var pickedLossRatePctPerWeek: Double {
        if isMaintenanceReveal { return 0 }
        let tier = IntensityTier(rawValue: pickedTierRaw) ?? .medium
        let tierRate: Double = {
            switch tier {
            case .hard:   return 0.01
            case .medium: return 0.0075
            case .soft:   return revealWindow.lossRateFloor
            }
        }()
        // Clamp to the safety pace cap when one was set at the gate. paceCap 0
        // -> rate 0 (no deficit); 0.0025 -> gentle 0.25%/wk; -1 -> uncapped.
        var rate = tierRate
        if safetyPaceCap >= 0 { rate = min(rate, safetyPaceCap) }
        // v1.1.3: a recomp (tone-up) choice glides gently regardless of tier.
        if goalDirection == "recomp" { rate = min(rate, recompGentleRate) }
        return rate
    }

    /// TDEE-based daily calorie target from collected onboarding fields.
    ///
    /// Formula: Mifflin-St Jeor TDEE minus a daily deficit derived from
    /// `pickedLossRatePctPerWeek` (Hall 2012: 7700 kcal/kg ramp approx).
    /// Clamped to >= max(1200, BMR) and <= 3500. Returns nil when current
    /// weight is not yet collected (skip the calorie hero card entirely).
    ///
    /// Every input traces to a real collected field:
    ///   weightKg      <- currentWeightKg (passed from OnboardingView)
    ///   heightCm      <- onboardingHeightCm (0 -> fallback 165cm for cohort)
    ///   age           <- onboardingAgeRange via EnergyLedger.ageMidpoint
    ///   activityKey   <- onb_v4_movement_baseline (movement baseline Q)
    ///   lossRate      <- onboardingPickedTier via pickedLossRatePctPerWeek
    private var estimatedCalorieTarget: Int? {
        // Safety-suppressed cohorts (ED / pregnant / zero-pace-cap) get NO
        // numeric target at all. Returning nil here is the single chokepoint:
        // it drops the calorie hero card AND skips the foodDailyTarget stamp in
        // the reveal cascade, so no loss number is shown or persisted for her.
        if suppressNumbers { return nil }
        guard let kg = currentWeightKg, kg > 0 else {
            #if DEBUG
            print("[D68] calorie hero SKIPPED — currentWeightKg=\(currentWeightKg ?? -1)")
            #endif
            return nil
        }
        // Height: use collected value; fall back to 165cm when not yet set
        // so the hero always renders and stays plausible for the cohort.
        let height = heightCm > 0 ? heightCm : 165.0
        let age    = EnergyLedger.ageMidpoint(fromRange: ageRange)
        let kcal   = CalorieTargetCalculator.dailyTarget(
            currentWeightKg:      kg,
            heightCm:             height,
            age:                  age,
            sex:                  ProgramGoalCalculator.sex(fromGenderKey: gender),
            activityKey:          movementBaseline,
            lossRatePctPerWeek:   pickedLossRatePctPerWeek
        )
        #if DEBUG
        print("[D68] calorie hero - kg=\(kg) h=\(height) age=\(age) " +
              "activity=\(movementBaseline) tier=\(pickedTierRaw) " +
              "rate=\(pickedLossRatePctPerWeek) kcal=\(kcal)")
        #endif
        return kcal
    }

    /// Protein floor — v6 P3: routed through the ONE formula
    /// (TargetsService.proteinTargetG: 1.6 g/kg GLP-1-current, 1.2
    /// default, advisory-band capped). The local 1.6-for-everyone this
    /// replaces showed a non-GLP-1 user a higher floor at the reveal
    /// than the app would hold her to on day one — the exact
    /// same-number-everywhere drift TargetsService exists to kill.
    private var estimatedProteinFloor: Int? {
        guard let kg = currentWeightKg, kg > 0, !suppressNumbers else { return nil }
        return TargetsService.proteinTargetG(weightKg: kg)
    }

    // (v6 P3: the date tile died with the D74 grid — the arrival date
    // lives on the curve via BecomingProjectionCard; its goalDateText
    // helper left with it per the dead-code rule.)

    /// v6 P3 — the four TRUE plan tiles. The D74-era grid sold a
    /// product that no longer ships ("5-min plank a day", "14-day
    /// becoming arc" — plankAI artifacts); every tile now names a
    /// daily-decision truth of the CURRENT product, each number with
    /// its basis (rigor lives in numbers; law 2 of the v6 direction).
    /// The date tile is gone — the arrival date lives on the curve.
    @ViewBuilder
    private func planTilesCard(kcal: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                staggeredTile(at: 0) {
                    proofTile(
                        eyebrow: "calories",
                        value: "\(kcal)",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 30),
                        sub: "from your height, weight + pace"
                    )
                }
                staggeredTile(at: 1) {
                    proofTile(
                        eyebrow: "protein floor",
                        value: estimatedProteinFloor.map { "\($0)g" } ?? "set daily",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 30),
                        sub: "protects muscle while you lose"
                    )
                }
            }

            HStack(spacing: 10) {
                staggeredTile(at: 2) {
                    proofTile(
                        eyebrow: "movement",
                        value: "7,500",
                        valueFont: .custom("Fraunces72pt-SemiBold", size: 22),
                        sub: "steps · counted for you"
                    )
                }
                staggeredTile(at: 3) {
                    proofTile(
                        eyebrow: "weigh-ins",
                        value: "the trend",
                        valueFont: .custom("Fraunces72pt-SemiBoldItalic", size: 22),
                        sub: "read the week, never the day"
                    )
                }
            }

            Text("a starting plan. we'll tune yours over the first few weeks")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // FIX 5 (2026-06-29): the inline 24pt accent-border card is the
        // canonical `.scrapbookCard()` chrome duplicated by hand.
        .scrapbookCard()
    }

    /// v3 P11.6+ (2026-06-10) — per-tile cascade wrapper. Tile at
    /// `index` shows once `revealedTiles > index`; off-state is
    /// opacity 0 + 8pt y-offset (matches LineCascadeText's settle).
    /// Animation tied to `revealedTiles` so the parent's stepwise
    /// counter advances drive the per-tile reveal.
    @ViewBuilder
    private func staggeredTile<Content: View>(at index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(reduceMotion || index < revealedTiles ? 1 : 0)
            .offset(y: reduceMotion || index < revealedTiles ? 0 : 8)
            .animation(.easeOut(duration: 0.32), value: revealedTiles)
    }

    @ViewBuilder
    private func proofTile(eyebrow: String, value: String, valueFont: Font, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.lowercase)
            Text(value)
                .font(valueFont)
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(sub)
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.bgPrimary.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.textPrimary.opacity(0.06), lineWidth: 0.5)
        )
    }

    /// Compose the 2-3 muted context chips from the user's filled
    /// credibility-grade inputs. Each chip is a short lowercase phrase
    /// matching the brand voice — no labels, no values, just the
    /// derived context ("6-7 hr sleep" not "sleep: six7"). Order is
    /// stable so the row reads the same way every time.
    /// (cause, consequence, italic words). Each row requires BOTH the
    /// stored answer and the live engine modifier — the same flag
    /// helpers ProgramGoalCalculator used, so a row can never claim an
    /// adjustment that didn't happen. Cohort rows name the cohort
    /// plainly (she disclosed; euphemism reads as embarrassment).
    private var causalReceipts: [(String, String, [String])] {
        var rows: [(String, String, [String])] = []
        if ProgramGoalCalculator.isGLP1User(from: glp1Status) {
            rows.append(("because you're on a GLP-1", "protein leads your plate", ["protein"]))
        } else if glp1Status == "past" {
            rows.append(("because you stopped the shot", "keeping it is the first goal", ["keeping"]))
        }
        if ProgramGoalCalculator.isShortSleeper(from: sleepHours) {
            rows.append(("because you sleep under six", "we paced you gentler", ["gentler"]))
        }
        if ProgramGoalCalculator.isPerimenopausal(from: hormonalStage) {
            rows.append(("because you're in peri", "strength + sleep cues lead", ["lead"]))
        }
        if ProgramGoalCalculator.isRegainRisk(from: weightTrend) {
            rows.append(("because it came back before", "the pace protects the after", ["after"]))
        }
        return Array(rows.prefix(3))
    }
}

/// Tiny wrap-aware chip row. Each chip is a soft outlined capsule with
/// lowercase text. Used here for the projection context row and any
/// future "her actual answers" surfacing moments. Wraps to multiple
/// rows when the chip count exceeds the available width.
private struct FlowingChips: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().stroke(Palette.divider, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - NudgePermissionAsk
//
// The founder's #1 onboarding redesign: the notification opt-in, rebuilt
// as a true-to-iOS notification-mock banner ("want a nudge from jeni?")
// that drops in + buzzes on appear, a "tap to feel it" CoreHaptics replay,
// and three time pills (morning / afternoon / evening) that map straight
// to scheduleDailyReminder. It used to live as case 23 (cameraSetupScreen)
// in OnboardingView; T8 cut that case from the flow as "redundant," which
// orphaned the redesign and left the plainer paired-row ask as the only
// notification beat the user saw. v1.1.3 reconcile (2026-06-29): the
// redesigned nudge is now the LIVE permission ask, here at the tail of the
// reveal cascade (the last pre-paywall beat). The HealthKit ask is
// unaffected - it is its own mid-onboarding screen (case 285,
// HealthKitPermissionScreen), so this screen stays notifications-only.
//
// Persists the user's choice the same way the old case 23 did: writes
// `plankTime` + `notificationsEnabled` to the canonical keys (read back
// by NotificationTimeBucket + NotificationSettingsView + onComplete) and
// schedules the daily reminder at the picked bucket on grant.

private struct NudgePermissionAsk: View {
    let voicePreference: String
    let onContinue: () -> Void

    // Canonical keys. The nudge runs inside the reveal (a separate view
    // from OnboardingView, which already assembled its completion data),
    // so it writes the keys directly; OnboardingView's onRevealComplete
    // re-reads them into the persisted OnboardingData before onComplete.
    @AppStorage("plankTime") private var plankTime: String = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    // v5 (2026-07-02): the mock banner carries HER promise as the payload
    // (the literal Day-1 push she'll receive), so the ask reads "want us
    // to hold you to it?" — a personal contract, not app marketing. The
    // old voice-switched bodies cited coaches cut from the flow in v9.
    @AppStorage("day1PromiseAction") private var promiseAction: String = ""
    @AppStorage("day1PromiseAnchor") private var promiseAnchor: String = ""
    @AppStorage("day1PromiseTimeISO") private var promiseTimeISO: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroVisible = false
    @State private var bannerVisible = false
    @State private var pillsVisible = false
    @State private var requesting = false

    private var previewTitle: String {
        promiseAction.isEmpty ? "five minutes, today." : "your promise, gently."
    }

    /// "arrives mornings, around 7 am" — derived from the bucket her
    /// promise seeded; falls back to morning copy pre-seed.
    private var nudgeTimeLine: String {
        let bucket = plankTime.isEmpty
            ? (Self.bucket(fromPromiseISO: promiseTimeISO) ?? "morning")
            : plankTime
        switch bucket {
        case "afternoon": return "arrives afternoons, around 1 pm · change anytime in settings"
        case "evening": return "arrives evenings, around 7 pm · change anytime in settings"
        default: return "arrives mornings, around 7 am · change anytime in settings"
        }
    }

    private var previewBody: String {
        if !promiseAction.isEmpty {
            let anchor = promiseAnchor.isEmpty ? "tomorrow" : promiseAnchor
            return "\(anchor) · \(promiseAction)"
        }
        return "five minutes is enough today. small moves still count."
    }

    var body: some View {
        ZStack {
            // Surface unify (2026-06-27): share the app-wide GrainfieldBackground
            // with the rest of the reveal + onboarding so the pre-paywall handoff
            // sits on the one premium surface (was Palette.programBgPrimary).
            GrainfieldBackground()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Space.lg)

                    // Delta v8 D76 headline preserved. Italic on "nudge"
                    // per the locked voice-signal rules.
                    (Text("want a ").font(Typo.title)
                     + Text("nudge").font(Typo.titleItalic)
                     + Text(" from jeni?").font(Typo.title))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(heroVisible ? 1 : 0)

                    Spacer().frame(height: Space.xs)

                    Text("one quiet one a day. nothing nagging.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                        .opacity(heroVisible ? 1 : 0)

                    Spacer().frame(height: Space.lg)

                    // The hero: a true-to-iOS notification banner that drops
                    // in + buzzes on appear and replays the buzz on tap, so
                    // she feels exactly what jeni's nudge will feel like
                    // before granting permission.
                    NudgeNotificationBanner(
                        title: previewTitle,
                        message: previewBody
                    )
                    .padding(.horizontal, Space.screenPadding)
                    .opacity(bannerVisible ? 1 : 0)

                    Spacer().frame(height: Space.md)

                    // 2026-07-07: the trial-safety promise row is DEAD.
                    // It promised "if you start a trial, we remind you
                    // before it ends" in an app that sells no trial and
                    // schedules no renewal push (TrialEndNotification-
                    // Service is disabled) — a stale promise one beat
                    // before the wall is a trust leak, not reassurance.
                    // The banner above + the arrives-line below carry
                    // this beat's whole cashable story: one nudge a day,
                    // at her hour, changeable in settings.

                    // Round 2 (2026-07-02): the time rows are GONE. Her
                    // promise already chose tomorrow's hour — the banner
                    // wears it, and plankTime seeds from the same choice
                    // (.onAppear below). One decision on this screen:
                    // allow. A quiet line says when the nudge arrives.
                    Text(nudgeTimeLine)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .padding(.horizontal, Space.lg)
                        .opacity(pillsVisible ? 1 : 0)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                JFContinueButton(
                    label: "allow notifications",
                    action: { allow() },
                    isLoading: requesting,
                    firesHaptic: false
                )

                Button {
                    Haptics.light()
                    notificationsEnabled = false
                    onContinue()
                } label: {
                    Text("not right now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PressFeedbackStyle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, 32)
            .opacity(pillsVisible ? 1 : 0)
        }
        .onAppear {
            // v5 merged time anchor: the promise beat already asked when
            // tomorrow starts — her chosen hour OWNS the daily-nudge
            // bucket (a stale earlier value must never contradict the
            // promise she just sealed; the round-3 walk showed exactly
            // that: promise 8am, arrives-line "afternoons").
            if let promised = Self.bucket(fromPromiseISO: promiseTimeISO) {
                plankTime = promised
            } else if plankTime.isEmpty {
                plankTime = "morning"
            }
        }
        .task {
            // Reduce-motion: skip the staggered fade-rise (the banner
            // self-gates its own drop + keeps the haptic) but still reveal
            // every element so nothing is left invisible.
            guard !reduceMotion else {
                heroVisible = true; bannerVisible = true; pillsVisible = true
                return
            }
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 220_000_000)
            withAnimation(Motion.entrance) { bannerVisible = true }
            try? await Task.sleep(nanoseconds: 300_000_000)
            withAnimation(Motion.entranceSoft) { pillsVisible = true }
        }
    }

    private func allow() {
        guard !requesting else { return }
        Haptics.medium()
        requesting = true
        Task {
            let granted = await NotificationPermission.requestOrOpenSettings()
            await MainActor.run {
                notificationsEnabled = granted
                if granted {
                    NotificationPermission.scheduleDailyReminder(at: reminderTimeFromBucket(plankTime))
                    // Release audit 2026-08-08 — the Day-1 promise
                    // seals on the PREVIOUS beat, where authorization
                    // is still .notDetermined, so its schedule call
                    // no-ops for every fresh install; the stamp then
                    // suppresses the fallback day1_morning too — net
                    // zero Day-1 push for new users (the exact D0→D1
                    // surface the v1.1.2 retention fix targeted).
                    // Back-fill here, the first moment permission
                    // actually exists.
                    if !promiseTimeISO.isEmpty,
                       let date = ISO8601DateFormatter().date(from: promiseTimeISO),
                       date > .now {
                        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
                        let body = NotificationPermission.day1PromiseBody(
                            action: promiseAction,
                            anchor: promiseAnchor,
                            userName: name.isEmpty ? nil : name
                        )
                        NotificationPermission.scheduleDay1Promise(at: date, body: body)
                    }
                }
                requesting = false
                onContinue()
            }
        }
    }

    // Bucket -> wall-clock time. morning 7am / afternoon 1pm / evening 7pm
    // (mirrors the former case 23 mapping so the scheduled cue is identical).
    /// Promise-hour → nudge bucket (8am → morning, 12pm → afternoon,
    /// 6pm → evening). nil when no promise time was set.
    private static func bucket(fromPromiseISO iso: String) -> String? {
        guard !iso.isEmpty,
              let date = ISO8601DateFormatter().date(from: iso) else { return nil }
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case ..<11: return "morning"
        case 11..<16: return "afternoon"
        default: return "evening"
        }
    }

    private func reminderTimeFromBucket(_ bucket: String) -> Date {
        let hour: Int = {
            switch bucket {
            case "morning":   return 7
            case "afternoon": return 13
            case "evening":   return 19
            default:          return 9
            }
        }()
        return Calendar.current.date(from: DateComponents(hour: hour)) ?? Date()
    }
}

#Preview {
    OnboardingRevealView(
        bodyFocus: ["flatBelly"],
        sessionLengthKey: "ten",
        voicePreference: "encouraging",
        commitmentDaysKey: "five",
        currentWeightKg: 75,
        goalWeightKg: 65,
        onRevealComplete: {}
    )
}

// MARK: - FirstWeekPresentation
//
// v9 P9.1 (her75 onboarding restructure). The "your first week" beat
// that lands between the weight projection and the paired permissions
// ask, so the user holds her plan before the paywall. The 7-day strip
// (FirstWeekPreview) mirrors the real program rhythm — archetype day
// identity + tier-driven workout cadence + real week-1 minutes — all
// keyed off the tier the user just picked on PacePicker (read back
// from the onboardingPickedTier AppStorage key, default .medium).

private struct FirstWeekPresentation: View {

    let onContinue: () -> Void

    // v9 P9.2: tier is now read from AppStorage so the week reflects
    // whatever the user just picked on PacePicker. The pickedTier
    // value also persists across to ProgramSetup post-paywall (one
    // pick, two consumers).
    @AppStorage("onboardingPickedTier") private var pickedTierRaw: String = "medium"
    @AppStorage("onboarding_glp1_status") private var railsGlp1Status: String = ""

    @State private var heroVisible = false
    @State private var weekVisible = false
    @State private var ctaVisible = false

    /// GLP-1 cohorts (on the shot or in the after) get the protein-first
    /// snap rail — the number their branch was promised.
    private var isGlp1Rails: Bool {
        railsGlp1Status == "current" || railsGlp1Status == "past"
    }

    /// Her shot day as a weekday word ("thursdays"), nil when skipped.
    private var shotWord: String? {
        let w = UserDefaults.standard.string(forKey: "onb_v5_shot_day") ?? ""
        let full = [
            "mon": "mondays", "tue": "tuesdays", "wed": "wednesdays",
            "thu": "thursdays", "fri": "fridays", "sat": "saturdays",
            "sun": "sundays",
        ]
        return full[w]
    }

    var body: some View {
        ZStack {
            // FIX 2 (2026-06-29): same alive cream surface as the
            // projection peak — continuity into the next reveal beat, on
            // the disclaimer's Grainfield tier rather than a flat fill.
            GrainfieldBackground()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.xl)

                        // v3 P11.6 — promoted to heroHeadline 42pt.
                        ItalicAccentText(
                            "your first week of care.",
                            italic: ["first"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        Text("the rhythm your plan runs on.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        // The strip owns its own reveal — tiles deal in
                        // on a left→right cascade (see DayTile.task), so
                        // no group opacity/offset gating here.
                        FirstWeekPreview(
                            tier: IntensityTier(rawValue: pickedTierRaw) ?? .medium
                        )

                        Text("you can change pace or rest days anytime.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(weekVisible ? 1 : 0)

                        // v6 P4 — the promise made CONCRETE: tomorrow
                        // morning's actual checklist day, in the same
                        // device frame the welcome sold (the abstract
                        // rail list + the it-girl cutout it replaces
                        // described surfaces this mock simply shows;
                        // law 4 — sell the current product only).
                        JFDeviceDemoFrame(height: 330, lockedScene: 0)
                            .opacity(weekVisible ? 1 : 0)
                            .offset(y: weekVisible ? 0 : 12)
                            .padding(.top, Space.sm)
                            .accessibilityLabel("tomorrow morning in jeni: your daily checklist with move, add a meal, steps, and the method")

                        Text("tomorrow morning, as it will actually look.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .opacity(weekVisible ? 1 : 0)

                        // The two cohort truths the mock can't show —
                        // GLP-1 rails keep their lines (clinical
                        // register for the medication rhythm).
                        if isGlp1Rails {
                            VStack(alignment: .leading, spacing: 10) {
                                firstWeekRail(base: "add your plate · ", italic: "protein", suffix: " is the number to watch")
                                // v8 Stage A — the medication rhythm joins
                                // her care plan's shape ONLY when she
                                // offered a shot day (current cohort).
                                // Clinical register: plain line, no italic
                                // accent, no warmth vocabulary.
                                if railsGlp1Status == "current", let shotWord {
                                    firstWeekRail(
                                        base: "medication rhythm · \(shotWord) anchor the week",
                                        italic: "", suffix: ""
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Space.lg + Space.md)
                            .opacity(weekVisible ? 1 : 0)
                        }

                        Spacer().frame(height: Space.lg)
                    }
                }
            }
        }
        // FIX 1 (2026-06-29): canonical JFContinueButton docked via
        // safeAreaInset, replacing the hand-rolled italic-Fraunces capsule.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue)
                .padding(.top, 8)
                .background(Palette.bgPrimary)
                .opacity(ctaVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: ctaVisible)
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entrance) { weekVisible = true }
            try? await Task.sleep(nanoseconds: 320_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    // One everyday-rail row, folded in from case 21's day-one card.
    // Serif italic punch on the key word (the her75 sticky-note register,
    // done typographically) over a small cocoa bullet.
    private func firstWeekRail(base: String, italic: String, suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(Palette.textSecondary.opacity(0.4))
                .frame(width: 4, height: 4)
                .offset(y: -3)
            (Text(base).font(.custom("DMSans-Regular", size: 14))
             + Text(italic).font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
             + Text(suffix).font(.custom("DMSans-Regular", size: 14)))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PacePickerPresentation (v9 P9.2)
//
// "how fast feels right?" — the her75-onboarding-register intensity
// picker. Three scrapbookCards stacked (NOT pills; pills compress
// too much for first contact). Per-tier subtitle pulls from
// ProgramGoalCalculator.Window so the user sees their actual derived
// week count inline. Selection writes onboardingPickedTier; both
// FirstWeekPresentation and (eventually) ProgramSetupSubflow read
// from the same key — one pick, every downstream consumer respects it.

private struct PacePickerPresentation: View {

    let currentWeightKg: Double
    let goalWeightKg: Double
    let onContinue: () -> Void

    @AppStorage("onboardingPickedTier") private var pickedTierRaw: String = "medium"
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""
    // v3 P11.2 (2026-06-10) — sleep now load-bearing in the engine.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""
    // T2 (2026-06-29): weight trend + GLP-1 phase now move pacing.
    @AppStorage("onboarding_weight_trend") private var weightTrend: String = ""
    @AppStorage("onboarding_glp1_phase")   private var glp1Phase: String = ""
    // FIX 4 (2026-06-29): collected gender (case 130) -> BMR-formula sex.
    @AppStorage("onboardingGender")        private var gender: String = ""

    @State private var heroVisible = false
    @State private var rowsVisible = false
    @State private var ctaVisible = false
    // Round 2 (2026-07-02): no pre-selected pace. The stored default
    // ("medium") exists for downstream readers, but the ROWS render
    // unchosen until she commits one — the pace must be her decision,
    // not a form default. Continue gates on the pick.
    @State private var hasPicked = false

    private var window: ProgramGoalCalculator.Window {
        ProgramGoalCalculator.compute(.init(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            sex: ProgramGoalCalculator.sex(fromGenderKey: gender),
            age: nil,
            // v3 P11.2 (2026-06-10) — routed through engine-v2 helpers
            // so cohort-flag mappings stay DRY. Sleep now adjusts the
            // window per Nedeltcheva 2010 (~55% fat-loss penalty at
            // <6h, mostly traded for lean-mass cost).
            isGLP1User:        ProgramGoalCalculator.isGLP1User(from: glp1Status),
            isPerimenopausal:  ProgramGoalCalculator.isPerimenopausal(from: hormonalStage),
            isShortSleeper:    ProgramGoalCalculator.isShortSleeper(from: sleepHours),
            weightTrendKey:    weightTrend,
            glp1PhaseKey:      glp1Phase
        ))
    }

    var body: some View {
        ZStack {
            Palette.programBgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Space.lg) {
                        Spacer().frame(height: Space.xl)

                        // v3 P11.6 — promoted to heroHeadline 42pt.
                        // v7 register — autonomy verb over feelings-frame.
                        ItalicAccentText(
                            "pick your pace.",
                            italic: ["your"],
                            baseFont: Typo.heroHeadline,
                            italicFont: Typo.heroHeadlineItalic,
                            color: Palette.textPrimary,
                            alignment: .center
                        )
                        .kerning(-0.4)
                        .lineSpacing(Typo.heroHeadlineLineGap)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.screenPadding)
                        .opacity(heroVisible ? 1 : 0)
                        .scaleEffect(heroVisible ? 1.0 : 0.96)

                        Text("ACSM-safe range. you can change this later.")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .opacity(heroVisible ? 1 : 0)

                        // v6 P3 — each row translates its clinical rate
                        // into HER number (unit-aware, from her entered
                        // weight — rigor law: number + unit + basis).
                        VStack(spacing: 12) {
                            paceRow(tier: .soft,   title: "soft",
                                    tagline: taglineFor(rate: 0.005, suffix: "room for life."))
                            paceRow(tier: .medium, title: "steady",
                                    tagline: taglineFor(rate: 0.0075, suffix: "the middle of the safe band."))
                            paceRow(tier: .hard,   title: "focused",
                                    tagline: taglineFor(rate: 0.01, suffix: "fastest healthy pace."))
                        }
                        .padding(.horizontal, Space.lg)
                        .opacity(rowsVisible ? 1 : 0)
                        .offset(y: rowsVisible ? 0 : 12)

                        Spacer().frame(height: Space.lg)
                    }
                }
            }
        }
        // FIX 1 (2026-06-29): canonical JFContinueButton docked via
        // safeAreaInset, replacing the hand-rolled italic-Fraunces capsule.
        .safeAreaInset(edge: .bottom) {
            JFContinueButton(label: "continue", action: onContinue, isEnabled: hasPicked)
                .padding(.top, 8)
                .background(Palette.bgPrimary)
                .opacity(ctaVisible ? 1 : 0)
                .animation(Motion.entranceSoft, value: ctaVisible)
        }
        .task {
            withAnimation(Motion.entrance) { heroVisible = true }
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(Motion.entrance) { rowsVisible = true }
            try? await Task.sleep(nanoseconds: 280_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    /// "0.5% a week ≈ 1.0 lb for you · room for life." — the clinical
    /// rate translated into her display unit from her entered weight.
    private func taglineFor(rate: Double, suffix: String) -> String {
        let pctLabel = rate == 0.005 ? "0.5%" : rate == 0.0075 ? "0.75%" : "1%"
        guard currentWeightKg > 0 else { return "\(pctLabel) a week. \(suffix)" }
        let unit = WeightUnit.current
        let perWeek = unit.display(fromKg: currentWeightKg * rate)
        let s = String(format: perWeek < 10 ? "%.1f" : "%.0f", perWeek)
        return "\(pctLabel) a week \u{2248} \(s) \(unit.label) for you. \(suffix)"
    }

    private func paceRow(tier: IntensityTier, title: String, tagline: String) -> some View {
        let selected = hasPicked && pickedTierRaw == tier.rawValue
        // Pace unification (2026-06-11): row weeks come from the same
        // ProjectionMath the pace selector + paywall use, so the number
        // here never disagrees with the dates she already saw.
        let weeks = ProjectionMath.projectedWeeks(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: ProjectionMath.paceKey(forTier: tier.rawValue)
        ) ?? window.weeks(for: tier)
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { hasPicked = true }
            pickedTierRaw = tier.rawValue
            // Write back to the canonical pace key so every downstream
            // surface (goal-date reveal, paywall chart, day-one card)
            // re-dates with the re-picked pace.
            UserDefaults.standard.set(
                ProjectionMath.paceKey(forTier: tier.rawValue),
                forKey: ProjectionMath.paceDefaultsKey
            )
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // v6 P3 — the slope glyph: one curve family at three
                // steepnesses, so the pace choice reads visually
                // before the words are read.
                PaceSlopeGlyph(
                    depth: tier == .hard ? 0.85 : tier == .medium ? 0.6 : 0.35,
                    emphasized: selected
                )
                .frame(width: 30, height: 22)
                .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.cocoaPrimary)
                    Text(tagline)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(weeks)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(Palette.accent)
                    Text("weeks")
                        .font(Typo.eyebrow)
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(selected ? Palette.accentSubtle.opacity(0.45) : Palette.programCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        selected ? Palette.cocoaPrimary : Palette.accent.opacity(0.5),
                        lineWidth: 1.5
                    )
            )
            .programPaperShadow()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) pace, \(weeks) weeks, \(tagline)\(selected ? ", selected" : "")")
    }
}

// MARK: - PaceSlopeGlyph (v6 P3)
//
// One curve family at three steepnesses — the pace choice read
// visually before the words are. The BecomingCurveShape control
// grammar at glyph scale; selected rows ink the slope in accent.
private struct PaceSlopeGlyph: View {
    /// 0…1 — how deep the curve falls across the glyph.
    let depth: CGFloat
    let emphasized: Bool

    var body: some View {
        PaceSlopeShape(depth: depth)
            .stroke(
                emphasized ? Palette.accent : Palette.cocoaSecondary.opacity(0.55),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .accessibilityHidden(true)
    }
}

private struct PaceSlopeShape: Shape {
    let depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let startY = rect.minY + 2
        let endY = rect.minY + 2 + (rect.height - 4) * depth
        p.move(to: CGPoint(x: rect.minX, y: startY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: endY),
            control1: CGPoint(x: rect.minX + rect.width * 0.45, y: startY),
            control2: CGPoint(x: rect.minX + rect.width * 0.65, y: endY)
        )
        return p
    }
}

// MARK: - CommitmentRitualPresentation (Task 7, 2026-06-28 - premium redesign)
//
// Replaces the now-dead TrialPromisePresentation (no-trial decision,
// phase-1a activation pass). The emotional climax of the reveal: one
// small promise for tomorrow, in the user's own words, which schedules
// a Day-1 nudge at the time she chooses.
//
// Layout - three zones stacked tight to kill the hollow middle:
//
//   HERO     - "before the plan, one *promise*." (JeniHeroSerif)
//
//   PANEL    - One unified chip instrument. Rounded card with a
//              barely-there 4% cocoa fill + a visible 22% cocoa border
//              at 1pt. Inside: WHEN / WHAT / TIME groups in tracked-caps
//              micro-labels. Reads as a single instrument being SET,
//              not three loose floating rows.
//
//   PROMISE  - Bridge: tracked-caps "YOUR PROMISE:" in textSecondary
//              (visibly present) + a 20%-cocoa 0.75pt divider line.
//              Then the live replay in JeniHeroSerif below it, so
//              the bridge is visibly the OUTPUT of the panel above.
//
// Motion: staggered cascade (hero -> panel -> bridge label -> replay
// -> CTA). All offset-based motion gated on reduceMotion.
// Haptics: prepare() on appear; tick() on each chip select (scale
// pulse on the chosen chip); commit() on CTA before persist+schedule.
//
// GLP-1 thread: if onboarding_glp1_status == "current", the default
// action chip is "get protein in" and the replay body stays fixed to
// "you'll protect your muscle." Phase-1b deepens this.
//
// On Continue: persists day1PromiseAction/Anchor/TimeISO, schedules
// the one-shot Day-1 nudge via NotificationPermission.scheduleDay1Promise
// if notifications are authorized, then calls onContinue().

private struct CommitmentRitualPresentation: View {
    let onContinue: () -> Void

    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("userName")               private var userName: String = ""

    // Persisted outputs — consumed by the Day-1 surfacing + push.
    @AppStorage("day1PromiseAction")  private var storedAction: String = ""
    @AppStorage("day1PromiseAnchor")  private var storedAnchor: String = ""
    @AppStorage("day1PromiseTimeISO") private var storedTimeISO: String = ""

    @State private var arrived = false
    @State private var sealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: the promise, composed
    //
    // Founder steer (2026-08-06): this beat sat between the plan and
    // the paywall asking for THREE taps across when / what / time —
    // pure friction at the highest-intent moment of the funnel. It is
    // now an oath screen: one sentence the engine already knows, one
    // action. Everything it used to ask, it now infers:
    //   WHAT   the action she just rehearsed (snap demo → snap; the
    //          GLP-1 current cohort keeps its clinical row)
    //   WHEN   morning — the anchor the Day-1 push speaks
    //   TIME   8am tomorrow, the default the picker led with anyway
    // Changing it later is one tap in settings, where changing your
    // mind belongs.

    private var didSnapDemo: Bool {
        let meal = UserDefaults.standard.string(forKey: "onb_v5_snap_demo_meal") ?? ""
        return !meal.isEmpty && meal != "skipped"
    }

    private var action: String {
        if glp1Status == "current" { return "protect your muscle" }
        return didSnapDemo ? "snap your first real meal" : "log your first meal"
    }

    private var anchor: String { "morning" }

    private var promiseDate: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text("your first promise")
                    .font(Typo.kicker)
                    .kerning(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .jeniArrive(arrived, index: 0)

                ItalicAccentText(
                    "tomorrow morning, you'll \(action).",
                    italic: [action + "."],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.md)
                .jeniArrive(arrived, index: 1)

                Text("one small thing, at 8am. that's the whole ask.")
                    .font(Typo.teachSub)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.md)
                    .jeniArrive(arrived, index: 2)

                Spacer(minLength: 0)

                HoldToPromiseButton(
                    label: "hold to promise",
                    onSeal: { seal() },
                    holdDuration: 1.1
                )
                .jeniArrive(arrived, index: 3)
                .opacity(sealed ? 0 : 1)
                .animation(.easeOut(duration: 0.3), value: sealed)
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.sm)
            .frame(maxWidth: .infinity, alignment: .leading)

            if sealed {
                // The classic burst — bigger, rounder, and it opens
                // above the sentence instead of climbing through it.
                LottieEffectView(.fireworks)
                    .scaleEffect(1.15)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // It opens ABOVE the sentence — a firework in the
                    // sky over the promise, not a sticker on the words.
                    .offset(y: -170)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GrainfieldBackground().ignoresSafeArea())
        .task {
            EffectAnimation.fireworks.preload()
            try? await Task.sleep(nanoseconds: 60_000_000)
            arrived = true
        }
    }

    // MARK: - Seal → persist → schedule → advance

    private func seal() {
        guard !sealed else { return }
        withAnimation(.easeOut(duration: 0.25)) { sealed = true }

        storedAction = action
        storedAnchor = anchor
        let chosenDate = promiseDate
        storedTimeISO = ISO8601DateFormatter().string(from: chosenDate)

        // Build the body in her own words; only schedule when the OS
        // will actually deliver it.
        let body = NotificationPermission.day1PromiseBody(
            action: action,
            anchor: anchor,
            userName: userName.isEmpty ? nil : userName
        )
        // The burst gets its beat before the next surface takes over.
        let dwell: UInt64 = reduceMotion ? 220_000_000 : 1_450_000_000
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional {
                NotificationPermission.scheduleDay1Promise(at: chosenDate, body: body)
            }
            try? await Task.sleep(nanoseconds: dwell)
            await MainActor.run { onContinue() }
        }
    }
}

// MARK: - HoldPromiseDebugHarness
//
// Debug harness for `--debug-hold-promise`: renders the real commitment
// ritual in isolation (skipping the ~53-screen onboarding) so the
// resting "hold to promise" seal can be screenshotted. Add
// `--debug-hold-auto-seal` to auto-run the hold on appear and capture
// the sealed "promised" state; `onContinue` is a no-op so the sealed
// pill stays put for the screenshot instead of advancing.
struct HoldPromiseDebugHarness: View {
    var body: some View {
        CommitmentRitualPresentation(onContinue: {})
    }
}
