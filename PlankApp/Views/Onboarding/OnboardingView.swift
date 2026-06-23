import SwiftUI
import AVFoundation
import AVKit
// StoreKit moved to RatingPromptService (2026-05-30 epic #1 child #6) —
// onboarding no longer talks to SKStoreReviewController directly.

// MARK: - Onboarding Flow
// Interleaved: 2-3 questions → education/celebration → repeat
// Every question requires Continue. Instant feedback on answers.
// Gradient blobs + animated SF Symbols + photo slots for stock images.

// MARK: - VideoHero
//
// Bundle video player wrapped for the Welcome hero block. AVPlayerViewController
// gives us proper retain semantics on the underlying AVPlayerLayer; the
// equivalent UIView wrapping AVPlayerLayer directly tends to leak the player
// when the host view recycles. Loops via AVPlayerItemDidPlayToEndTime —
// actionAtItemEnd = .none keeps the player from pausing at the natural end
// so the seek-to-zero + play handler fires cleanly.

private struct VideoHero: UIViewControllerRepresentable {
    let videoName: String
    let videoExtension: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.view.backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: videoName, withExtension: videoExtension) else {
            return controller
        }
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none
        controller.player = player

        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(
        _ uiViewController: AVPlayerViewController,
        coordinator: Coordinator
    ) {
        if let observer = coordinator.observer {
            NotificationCenter.default.removeObserver(observer)
        }
        uiViewController.player?.pause()
        uiViewController.player = nil
    }

    final class Coordinator {
        var observer: NSObjectProtocol?
    }
}

struct OnboardingView: View {
    @State private var screen: Int
    @State private var dir = 1

    init(onComplete: @escaping (OnboardingData) -> Void) {
        self.onComplete = onComplete
        #if DEBUG
        // Deep-link a specific onboarding screen for sim capture, e.g.
        // `--onboarding-screen 286`. Pair with `--uitest-fresh-onboarding`.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--onboarding-screen"), i + 1 < args.count,
           let n = Int(args[i + 1]) {
            self._screen = State(wrappedValue: n)
        } else {
            self._screen = State(wrappedValue: 0)
        }
        #else
        self._screen = State(wrappedValue: 0)
        #endif
    }
    @State private var feedback = ""
    @State private var showFeedback = false
    @State private var showConfetti = false
    @State private var showWelcomeSignInSheet = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    // Onboarding review prompt — fires once per install via SKStoreReviewController
    // gated by a soft "Loving JeniFit?" prefilter (case 215). Persisted so a back-
    // nav into onboarding or a fresh launch mid-flow doesn't double-prompt; iOS
    // also caps requestReview() to 3 per 365 days regardless.
    @AppStorage("onboardingReviewPromptShown") private var onboardingReviewPromptShown = false
    // v3 dead-code rip (2026-06-10) — onboardingV2Enabled gate
    // removed. v2 is the only path; v1 was the pre-v1.0.6 fallback
    // (shipped 2026-06-03 as default). AppStorage key
    // `onboarding_v2_enabled` left in UserDefaults for legacy installs
    // — nothing reads it now. DebugAuthView's v2_enabled toggle is
    // also removed.
    @State private var showRevealSequence = false
    @State private var pendingRevealData: OnboardingData? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Data — legacy
    @State private var goal = ""
    /// 2026-05-30 (epic #1 child #7): TikTok/IG/friend attribution. Asked
    /// once right after Q1 (becoming goal). Persisted to UserRecord +
    /// Supabase. Empty string = not yet answered. One of: "tiktok",
    /// "instagram", "friend", "app_store", "google", "other".
    @State private var acquisitionSource = ""

    /// 2026-05-30 (epic #1 child #6): vision-injection questions for
    /// future food + scan rails. Session-scope ONLY — NOT persisted to
    /// UserRecord, NOT a Supabase column, NOT consumed by
    /// WorkoutGenerator. The sole purpose in v1.0.7 is (a) sunk-cost
    /// lift and (b) plan-reveal echo personalization (IKEA effect).
    /// When food + scan ship in v2/v3 they'll re-collect their own
    /// inputs in their own onboarding/setup flows.
    @State private var eatingContext: Set<String> = []      // Q237
    @State private var dailyActivityLevel = ""              // Q238
    @State private var bodyPhotoReadiness = ""              // Q239
    @State private var experience = ""
    // v4.5 R3 (2026-06-11) — movement baseline merges activity level +
    // experience into one Q (v4 plan §D). New storage, never reuses old
    // columns; derived mirrors keep every legacy consumer fed.
    @AppStorage("onb_v4_movement_baseline") private var movementBaseline = ""
    @State private var baseline = ""
    @State private var barriers: Set<String> = []
    @State private var ageRange = ""
    @State private var activityLevel = ""
    // 17b: ageYears is the wheel source of truth; ageRange string
    // mirror updates on Continue so downstream code paths keep
    // reading the legacy bucket keys unchanged.
    @State private var ageYears: Int = 25
    @State private var focusArea = ""
    @State private var plankTime = ""
    @State private var commitmentDays = ""
    @State private var sessionLength = ""
    @State private var notificationsEnabled = false
    @State private var notificationTime = Calendar.current.date(from: DateComponents(hour: 7)) ?? Date()
    @State private var name = ""
    @State private var voicePreference = "encouraging"

    // Data — JeniFit phase 4 additions. Defaults match OnboardingData
    // defaults so values are safe to read before the user touches them.
    @State private var bodyFocus: Set<String> = []
    @State private var motivation = ""
    @State private var workoutLocation = ""
    @State private var workoutStyle: Set<String> = []
    // Bundle E net-new optional context. NOT load-bearing for the
    // current personalization logic (WorkoutGenerator doesn't read
    // these). They're collected so the user feels heard and so we
    // can wire them into plan adjustments later without backfill.
    // Persisted to UserDefaults only — no SwiftData / Supabase schema
    // change. Mirrored from local @State on advance via the question
    // helper's existing onChange→sel write path.
    @State private var monthSignals: Set<String> = []
    @State private var priorWorkouts: Set<String> = []
    @State private var gender = ""
    @State private var heightCm: Double = 170
    @State private var currentWeightKg: Double = 65
    @State private var goalWeightKg: Double = 60
    @State private var bodyTypeCurrent: Int = 3
    @State private var bodyTypeDesired: Int = 3
    @State private var identityFeeling = ""
    @State private var rewardChoice = ""
    @State private var relatability1: Bool? = nil
    @State private var relatability2: Bool? = nil
    @State private var relatability3: Bool? = nil
    // v2 consolidates the 3 yes/no relatability screens into one multi-
    // select (case 153). Source of truth in v2; synced back to the three
    // legacy Bool? fields on advance so finish() / derivedBarriers /
    // PostHog funnel events all keep working unchanged.

    // v2-A2 credibility-grade fields. @AppStorage directly so any future
    // consumer (paywall headline variants, Becoming-tab future-rail tiles,
    // notification timing logic, food rail) can read them without schema
    // changes. Default empty string = unanswered; case-level Continue
    // requires a selection so empty only persists if the user closes the
    // app mid-flow.
    @AppStorage("onboardingSleepHours")    private var sleepHours: String = ""
    @AppStorage("onboardingStressLevel")   private var stressLevel: String = ""
    @AppStorage("onboardingEatingCadence") private var eatingCadence: String = ""
    @AppStorage("onboardingEatingWindow")  private var eatingWindow: String = ""
    /// Delta v8 + food rail W5-T6 — cuisine multi-select (case 169).
    /// CSV of cuisine keys (american, italian, korean, etc.). Feeds the
    /// FoodVisionService system prompt as anti-cultural-bias accuracy
    /// lift — Cal AI's per-bench failure mode is non-American cuisine
    /// identification (Brief #4 §2). Multi-select so users who eat
    /// across cuisines (typical for the cohort) get the full prompt
    /// context, not a forced single bucket.
    @AppStorage("onboardingCuisinePreference") private var cuisinePreferenceCSV: String = ""

    /// v9 P9.9 — non-scale-victory commitment moment (case 136). CSV
    /// of NSV keys (core, energy, clothes, sleep). Replaces the cut
    /// body-image slider screens (134/135) as the conversion-load-
    /// bearing "I'm picking the version of me I want" hook.
    /// her75 designer + conversion expert both flagged this slot as
    /// essential; outcome cards keep the commitment without the AI-
    /// body asset. Downstream: feeds becoming-tab adaptive copy +
    /// trial-day-2 affirmation push (future phase consumers).
    @AppStorage("onboardingNsvPriority") private var nsvPriorityCSV: String = ""

    // v2-A3 identity + previous-attempt block. Same AppStorage pattern.
    @AppStorage("onboardingPriorAttempts")    private var priorAttempts: String = ""
    @AppStorage("onboardingPriorWin")         private var priorWin: String = ""
    @AppStorage("onboardingFoodRelationship") private var foodRelationship: String = ""
    // v3 C1 (2026-06-10) — `onboardingCommitConfidence` collected via
    // case 165 was never read by any downstream consumer (paywall
    // copy didn't ramp; Day-21 win-back didn't reference it). Case +
    // declaration removed; AppStorage key left untouched in
    // UserDefaults so legacy installs read no value.
    /// Delta v8 D87 — sunk-cost activation Q ("tried everything
    /// already?"). 3 options drive downstream tone calibration. Per
    /// the Cal AI culture brief, the few-vs-many distinction lets
    /// reciprocity copy ramp on prior-attempts cohort. New case 168.
    @AppStorage("onboardingTriedBefore") private var triedBefore: String = ""
    // v3 P11.1.B (2026-06-10) — BetterMe S2 psychometric Yes/No fears.
    // Bem 1972 self-perception: fear-coded first-person statements force
    // dichotomous identity commitment. Each flag persists to AppStorage
    // so downstream (paywall closing line, Day-2 trial notification)
    // can resurface the named fear as a resolved promise. String
    // encoding ("yes"/"no"/"") because @AppStorage doesn't support
    // Bool? natively — case bodies wrap a Binding<Bool?> over the
    // stored string.
    @AppStorage("onb_fear_quickResults") private var fearQuickResults: String = ""
    @AppStorage("onb_fear_anotherDiet")  private var fearAnotherDiet: String = ""
    @AppStorage("onb_fear_priorAttempt") private var fearPriorAttempt: String = ""
    // v3 P11.1.C (2026-06-10) — BetterMe A6 two-checkbox consent.
    // Personalize is the required gate (must be checked to advance);
    // day-2 check-in is opt-out + drives the trial-week notification
    // pre-prime per [[project-trial-week-notifications]]. Both default
    // pre-checked (lower friction); user can uncheck either.
    @AppStorage("onb_consent_personalize") private var consentPersonalize: Bool = true
    @AppStorage("onb_consent_day2")        private var consentDay2: Bool = true
    /// Delta v8 D73 — pace selector (gentle/steady/focused). Drives
    /// weekly weight-loss target + downstream calorie computation.
    /// Per the WL expert brief, this is the single highest-leverage
    /// question-level addition to the onboarding flow. New case 167.
    ///
    /// 2026-06-07: default was "steady" — which violated the design
    /// intent ("steady is recommended, not selected automatically"
    /// per case 167's comment). Every fresh install saw "steady"
    /// pre-selected. Now defaults to "" so case 167 starts unselected;
    /// the "most chosen pace" caption on the steady row carries the
    /// soft recommendation without anchoring the radio dot.
    @AppStorage("onboardingPaceChoice") private var paceChoice: String = ""

    // v2-A4 cohort signal. GLP-1 status uses the AppStorage key reserved
    // in the prior v2 plan (onboarding_glp1_status, value space:
    // none/considering/past/current). Hormonal stage covers the 22-35
    // women audience straddle (cycling regularly / peri / postmenopausal /
    // postpartum / private). Both skip-friendly via a "prefer not to say"
    // option — vulnerability questions need the explicit-skip escape.
    @AppStorage("onboardingHormonalStage") private var hormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var glp1Status: String = ""
    // v1.1 (2026-06-23) medical-grade intake: GLP-1 titration/duration phase,
    // captured ONLY when glp1Status == "current" (case 1641). The single
    // highest-value GLP-1 detail — drives protein-emphasis coaching for the
    // early-titration cohort. Self-reported, no brand name, no dose.
    // NOTE: like glp1Status, this is AppStorage-only and not yet synced
    // (see docs/medical_grade_survey_audit_2026_06_23.md — persistence P0).
    @AppStorage("onboarding_glp1_phase")   private var glp1Phase: String = ""
    // v1.1 (2026-06-23) medical-grade: weight trajectory at intake (case 1320).
    // Direction-of-travel is the clinical signal a single current-weight point
    // can't give — recent rapid loss (esp. on a GLP-1) shifts lean-mass risk +
    // pacing; cycling flags regain risk. AppStorage-only for now (persistence P0).
    @AppStorage("onboarding_weight_trend") private var weightTrend: String = ""

    /// Wipes every single-select v2 field back to "" so no option renders
    /// pre-highlighted on the first visit to each question. Called once
    /// per onboarding session from the welcome choreography (welcomeAppeared
    /// gate). Production users on a fresh install hit this with already-
    /// empty values (no-op); the call shows its value on dev re-runs and
    /// account-delete-then-re-onboard paths where stale AppStorage from a
    /// prior run would otherwise leak through as pre-selected answers.
    /// Don't add multi-select / numeric fields here — those are answered
    /// elsewhere with different defaults that aren't visually misleading.
    private func resetSingleSelectOnboardingFields() {
        sleepHours = ""
        stressLevel = ""
        eatingCadence = ""
        eatingWindow = ""
        priorAttempts = ""
        priorWin = ""
        foodRelationship = ""
        hormonalStage = ""
        glp1Status = ""
        // 2026-06-07: the three Delta v7/v8 single-selects that landed
        // after this reset was written. Each was leaking through as a
        // pre-selected radio dot on re-runs of onboarding (founder
        // bug report on "tried everything already?" — case 168).
        triedBefore = ""
        // v3 C1 — commitConfidence AppStorage declaration removed
        // alongside case 165; no reset needed.
        paceChoice = ""
        // 2026-06-10: cuisine multi-select + program tier single-select
        // were also leaking through. Founder bug report on the cuisine
        // question (case 169) showing italian/korean/japanese/chinese
        // pre-selected on a fresh re-run. Same reason both: AppStorage
        // persists across runs and neither key was in this reset.
        cuisinePreferenceCSV = ""
        nsvPriorityCSV = ""
        UserDefaults.standard.removeObject(forKey: "onboardingPickedTier")
        // 2026-06-11 founder bug report: movement question (case 8)
        // opened with "walks here and there" pre-selected on re-runs.
        // Same persistence leak; the v4 key landed after this reset.
        movementBaseline = ""
        // Fear psychometrics leak the same way (yes/no pre-answered).
        fearQuickResults = ""
        fearAnotherDiet = ""
        fearPriorAttempt = ""
    }

    // v4.6 — notification-banner drop-in on the nudge screen (case 11).
    @State private var nudgeBannerDropped = false

    // v4.6 — welcome demo frame page cycler (plan / camera / steps).
    @State private var welcomeDemoPage = 0

    // v4.6 round 3 — cohort marquee (case 283). 12 it-girl profiles.
    @State private var cohortMarqueeIndex = 0
    private static let cohortMarqueeAssets: [String] = [
        "onb-cohort-1", "onb-cohort-2", "onb-cohort-3",
        "onb-profile-latte", "onb-profile-cap", "onb-profile-scarf",
        "onb-profile-bun", "onb-profile-phone", "onb-profile-smoothie",
        "onb-profile-towel", "onb-profile-braid", "onb-profile-book",
    ]

    // Confirmation badge state — fired only at strategic commits
    // (5–7 across the full flow), not after every question. Goal is
    // moments of acknowledgement, not constant noise.
    @State private var pendingConfirmation: String? = nil
    @State private var showConfirmation = false

    // Analyze
    @State private var analyzing = false
    @State private var analyzePercent = 0
    @State private var planRevealed = false
    // 17d-2: stagger flags + sparkle burst for the plan reveal moment.
    // Each flag flips on its own timeline so the moment lands as a
    // sequence — coach photo first, then the headline beats, then
    // the plan cards — instead of everything fading in at once.
    @State private var planHeadlineVisible = false
    @State private var showPlanSources = false
    @State private var planCardsVisible = false
    @State private var planCtaVisible = false
    @State private var proofCount = 0
    @State private var celebVisible = false

    // Education screen animations
    @State private var factVisible = false
    @State private var featureVisible = false
    @State private var beforeAfterVisible = false
    @State private var personalStatVisible = false

    // Phase 5 — prediction / loading / plan reveal animations
    @State private var carouselProgress: CGFloat = 0
    @State private var carouselFrame: Int = 0
    @State private var carouselDone = false

    // ── Brand promises (case 240, post-2026-05-30 reframe) ────────
    // Replaces the press-and-hold consent signature ritual. Three
    // single-tap promise screens that fire immediately after plan
    // reveal (case 21). brandPromiseIndex is the current screen
    // (0..<brandPromises.count); brandPromisesStartTime tracks the
    // first appear so .onDisappear can attribute abandons accurately.
    @State private var brandPromiseIndex: Int = 0
    @State private var brandPromisesStartTime: Date?

    // ── Method preview (case 250) state ────────────────────────
    // AVAudioPlayer is held as State so it survives view updates while
    // the sample plays. Graceful no-op when the bundled clip is missing
    // (file ships separately via ElevenLabs script — see the
    // playMethodPreviewSample helper for the exact line to voice).
    @State private var methodPreviewAudioPlayer: AVAudioPlayer?
    @State private var methodPreviewIsPlaying: Bool = false
    @State private var methodPreviewAudioMissing: Bool = false

    // ── Habit-window quiz (case 270) state ─────────────────────
    // habitQuizSelected = -1 means "no answer yet"; 0/1/2 = picked
    // option. habitQuizRevealed flips true on pick and gates the
    // reveal copy + the CTA's continue-vs-tap-to-reveal behavior.
    @State private var habitQuizSelected: Int = -1
    @State private var habitQuizRevealed: Bool = false
    // 17d-2: rotating proof line — short status copy that cycles
    // alongside the headline so the screen reads as actively working,
    // not staring at a static "Building your plan…".
    @State private var carouselProofIndex: Int = 0

    // Smart-default flags for the Part 3 sliders. Flip on first mount of
    // the matching screen so we seed from the user's prior answer
    // (currentWeightKg / bodyTypeCurrent) instead of a hardcoded default.
    // Going back through the flow keeps the user's later edits intact —
    // the flag stays true once flipped.
    @State private var goalWeightInitialized = false
    @State private var bodyTypeDesiredInitialized = false

    let onComplete: (OnboardingData) -> Void

    var body: some View {
        ZStack(alignment: .top) {
            // v8 P8.9: onboarding crosses INTO the program era — pink
            // canvas directly (not the conditional helper) per the her75
            // brand-loading register. Closer screens already use
            // programBgPrimary; this gives the question flow the same
            // identity from screen 1 forward.
            Palette.programBgPrimary.ignoresSafeArea()

            // v3 P11.6 (2026-06-10) — navBar pinned via ZStack top
            // alignment, NOT inside a VStack with currentScreen.
            // Founder QA: long-content screens were pushing the progress
            // bar around because the VStack flexed with content height.
            // Now navBar lives in its own z-layer (zIndex 5) anchored
            // to the safe-area top, and currentScreen flows under it
            // with a reserved top padding so content never hides behind.
            currentScreen
                .id(screen)
                // her75 Phase 2 §3 — fixed 64pt reserve matching the
                // locked 56pt nav region + 8pt buffer. CONSTANT on
                // every nav-bearing screen so the hero start Y is
                // identical page-to-page.
                .padding(.top, (screen >= 1 && !analyzing && screen != 20) ? 64 : 0)
                // v3 P11.3 — JFPageTransition replaces the simple
                // opacity cross-fade with the her75 page-turn breath
                // (exit 200ms → 60ms gap → entrance 350ms).
                .transition(JFPageTransition.standard)
                .onAppear { Analytics.captureScreen("Onboarding/case-\(screen)") }
                .onChange(of: screen) { _, newCase in
                    Analytics.captureScreen("Onboarding/case-\(newCase)")
                }

            if screen >= 1 && !analyzing && screen != 20 {
                navBar
                    .background(Palette.programBgPrimary)
                    .zIndex(5)
                    .transition(.opacity)
            }

            if analyzing { analyzingScreen.transition(.opacity).zIndex(10) }

            // Centered feedback interstitial
            if showFeedback {
                ZStack {
                    Palette.bgPrimary.opacity(0.95).ignoresSafeArea()
                    VStack(spacing: Space.md) {
                        Text("✓")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                            .background(Palette.accent)
                            .clipShape(Circle())

                        Text(feedback)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                }
                .transition(.opacity)
                .zIndex(15)
            }

            if showConfetti { ConfettiView().ignoresSafeArea().allowsHitTesting(false).zIndex(20) }

            // ConfirmationBadge — strategic post-commit acknowledgement
            // moments. Appears for ~1.4s before the next-screen advance,
            // anchored to the bottom so it feels like a natural toast
            // from the Continue button rather than a modal interruption.
            if showConfirmation, let msg = pendingConfirmation {
                VStack {
                    Spacer()
                    ConfirmationBadge(message: msg, accentSticker: .heartGlossy)
                        .padding(.bottom, Space.xl)
                }
                .transition(.opacity)
                .zIndex(18)
            }

        }
        .fullScreenCover(isPresented: $showRevealSequence) {
            OnboardingRevealView(
                bodyFocus: bodyFocus,
                sessionLengthKey: sessionLength,
                voicePreference: voicePreference,
                commitmentDaysKey: commitmentDays,
                currentWeightKg: currentWeightKg,
                goalWeightKg: goalWeightKg,
                onRevealComplete: {
                    if var data = pendingRevealData {
                        pendingRevealData = nil
                        // The reveal PacePicker may have re-picked the
                        // pace after this data was assembled; refresh
                        // the cadence-derived fields so the stored plan
                        // matches what she committed to.
                        applyCadenceDerivations()
                        data.commitmentDaysPerWeek = commitmentDaysCount(commitmentDays)
                        data.sessionLengthMinutes = sessionLengthMinutes(sessionLength)
                        showRevealSequence = false
                        onComplete(data)
                    } else {
                        showRevealSequence = false
                    }
                }
            )
        }
        .sheet(isPresented: $showWelcomeSignInSheet) {
            NavigationStack {
                SignInPromptView(onContinue:  {
                    // After Apple/email/cancel closes the prompt: if the user
                    // is now signed in (non-anonymous), they're recovering an
                    // existing account — skip the rest of onboarding and
                    // hand off to MainTabView. AppSync.onAuthChanged will
                    // hydrate UserRecord/SessionLog/DayProgress from the cloud.
                    showWelcomeSignInSheet = false
                    if !AuthService.shared.isAnonymous {
                        hasCompletedOnboarding = true
                    }
                }, mode: .signIn)
                .background(Palette.bgPrimary)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showWelcomeSignInSheet = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .accessibilityLabel("Close sign in")
                    }
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        feedback = msg
        withAnimation(Motion.gentleSpring) { showFeedback = true }
        Haptics.soft()
    }

    private func hideToast() {
        withAnimation(Motion.exit) { showFeedback = false }
    }

    // Flow (25 screens):
    // 0:  Welcome
    // 1:  Q — Goal
    // 2:  Q — Experience
    // 3:  Q — Baseline (skip if never)
    // 4:  E — Chart ("most quit at 20s")
    // 5:  Q — Barriers
    // 6:  C — Personalized celebration
    // 7:  Q — Age range
    // 8:  Q — Activity level
    // 9:  E — "Did you know" core fact
    // 10: Q — Focus area
    // 11: Q — When do you plank
    // 12: E — Form vs Time
    // 13: E — What makes us different (feature showcase)
    // 14: S — Social proof (counter)
    // 15: S — Testimonial
    // 16: E — Before/after stat
    // 17: Q — Commitment (days/week)
    // 18: Q — Name
    // 19: Trainer selector
    // 20: Analyzing
    // 21: Plan reveal
    // 22: E — Personalized stat
    // 23: Camera setup
    // 24: Paywall

    @ViewBuilder private var currentScreen: some View {
        switch screen {
        case 0: welcome

        // ─── Section dividers ───────────────────────────────────
        // D2 (2026-06-01): brand-voice pass on all 6 section dividers
        // — lowercase + tighter copy. Case 200 specifically threads the
        // D1 wedge ("less noise, more her") into the supporting line so
        // the opening reel reads as one system. Other dividers get
        // lowercase + slightly more direct copy that matches the
        // founder voice from case 230's "real person, not chatbot."
        // v9 P9.8 — bridges rewritten per her75 closing-pass spec:
        // line-cascade with haptic per line, single sticker (one per
        // part for warmth without competing with the reveal), lowercase
        // eyebrow ("part one" not "PART 1"). Copy tightened to 2-4
        // words per line per the succinct-Gen-Z voice rule.
        // v4.5 R4 (2026-06-11) — dividers 6 → 2 in-flow (200 "your
        // story", 205 "almost yours"; 280 bridge carries "the numbers").
        // Single Didone line, no PART eyebrow, no supporting copy —
        // her75 IMG_6280 silence. Cases 201/202/204 deleted (orphans),
        // 203 cut from flow (the becoming divider read as filler
        // between the vulnerability cluster and identity Q).
        case 200: SectionDividerScreen(
            title: "your story",
            dwellSeconds: 1.6,
            onAdvance: { go(230) }
        )
        case 205: SectionDividerScreen(
            title: "almost yours",
            dwellSeconds: 1.6,
            onAdvance: { go(3) }
        )

        // ─── Recap card — "so here's you" ───────────────────────
        // Mid-flow recap reflecting 4 of the user's own answers back to
        // them. Noom-pattern earned-plan beat: the user sees their
        // inputs surfaced, which makes the downstream plan reveal feel
        // built-for-them rather than generic. Research: Rhodes &
        // de Bruijn 2013 — barrier resolution language closes ~50% of
        // the intention-behavior gap. No DB writes; reads existing
        // already-collected state (bodyFocus, sessionLength,
        // commitmentDays, relatability1/2/3).
        case 206: recapCardScreen

        // ─── Educational priming screens (Bundle E) ──────────────
        // Each is a single brief teach beat woven into the flow at a
        // research-validated position. See educationalScreen helper
        // for the layout pattern. No skip — full opt-in priming.
        case 230: educationalAntiShameScreen     // merged 230+231 (v4.5 R4)
        case 234: educationalPlateauScreen       // before plan reveal
        case 166: educationalPreEatScreen        // delta v7 — diet-first wedge early

        // ─── N1 — "anything we should know about this month?" ────
        // Hormonal-acknowledgment moment. Net-new question, but no
        // DB column change — `monthSignals` is local @State only.
        // Multi-select. Cycle-aware framing for the women 22-35
        // demographic — Wild.AI / FitrWoman 2026 pattern.
        case 235: jfMulti(
            "anything we should know about this month?",
            sub: "no pressure. multi-pick. helps jeni adjust intensity.",
            opts: [
                ("lowEnergy", "low energy",         nil, "battery.25"),
                ("cramps",    "cramps",             nil, "heart.slash"),
                ("sleepOff",  "sleep is off",       nil, "moon.zzz"),
                ("greatDay",  "feeling great",      nil, "sparkles"),
                ("noneNow",   "none of those",      nil, "checkmark"),
            ],
            sel: $monthSignals, next: 237
        )

        // ─── Vision injection (Q237/238/239, epic #1 child #6) ─────
        // Three @State-only questions seeding future food + scan +
        // movement rails. Sole v1.0.7 purpose: lift sunk cost + power
        // plan-reveal echo lines (IKEA effect). NOT persisted, NOT
        // consumed by WorkoutGenerator. Future features re-collect.
        case 237: jfMulti(
            "what does eating feel like for most days?",
            sub: "no judgement. multi-pick.",
            opts: [
                ("steady",       "steady",          nil, "leaf"),
                ("stress_eaten", "stress-eaten",    nil, "cloud.rain"),
                ("skipped",      "skipped meals",   nil, "circle.dashed"),
                ("forgot",       "forgot to eat",   nil, "moon.zzz"),
                ("mostly_ok",    "mostly mindful",  nil, "sparkles"),
            ],
            sel: $eatingContext, next: 238
        )

        case 238: jfQuestion(
            "outside of workouts, how much do you move?",
            sub: "rough sense is fine.",
            opts: [
                ("mostly_seated",   "mostly seated",        nil, "chair.lounge"),
                ("errands",         "errands here and there", nil, "figure.walk"),
                ("on_my_feet",      "i'm on my feet a lot",  nil, "shoe.2"),
            ],
            sel: $dailyActivityLevel, next: 239
        )

        case 239: jfQuestion(
            "how do you feel about photos of yourself right now?",
            sub: "no wrong answer. we'll never ask you to share one.",
            opts: [
                ("avoid",       "i avoid them",       nil, "eye.slash"),
                ("working_on",  "i'm working on it",  nil, "arrow.up.heart"),
                ("okay",        "i'm okay",           nil, "checkmark.circle"),
                ("like_them",   "i like them",        nil, "heart.fill"),
            ],
            sel: $bodyPhotoReadiness, next: 141
        )

        // ─── N2 — "what's worked before — and what hasn't?" ──────
        // Bridge between Q2 (current training) and Q8 (activity).
        // Net-new question, also @State only — no DB change. The
        // "what's worked before" Q is the most consistent question
        // across Noom / BetterMe / Lasta that JeniFit doesn't ask.
        case 236: jfMulti(
            "what's worked before. what hasn't?",
            sub: "multi-pick. we'll lean into what stuck.",
            opts: [
                ("homeWorkouts", "home workouts",  nil, "house"),
                ("gymRoutine",   "gym",            nil, "dumbbell.fill"),
                ("classes",      "group classes",  nil, "person.3.fill"),
                ("running",      "running / cardio", nil, "figure.run"),
                ("nothingStuck", "nothing's stuck", nil, "arrow.uturn.backward"),
            ],
            sel: $priorWorkouts, next: 8
        )

        // ─── Part 1 — Your story ────────────────────────────────
        // v3 dead-code rip (2026-06-10) — onboarding-v1 branch removed.
        // v1 was the pre-2026-06-03 flow; v1.0.6 shipped v2 as default
        // for every install. No realistic user is still mid-v1 by now.
        // Per [[feedback-dead-code]].
        case 1: jfQuestion(
            // v2 soft "why" — rewritten 2026-06-01 per
            // feedback_copy_succinct_genz memory: 2-4 word labels,
            // concrete > abstract.
            "what's your why?",
            sub: nil,  // her75 Phase 3
            italic: ["your why"],
            opts: [
                ("loseWeight",  "lose weight",       nil, "leaf"),
                ("fullBody",    "tone all over",     nil, "sparkles"),
                ("toneCore",    "stronger core",     nil, "circle.hexagongrid"),
                ("growGlutes",  "build glutes",      nil, "arrow.up.circle"),
                ("slimLegs",    "lean legs",         nil, "wind"),
            ],
            sel: $goal, next: 100
        )

        // ─── Attribution (epic #1 child #7, 2026-05-30) ──────────
        // "how did you hear about jenifit?" — single-select, slot
        // right after Q1 per the 200+ app teardown research. JeniFit
        // is $0 CAC organic TikTok — this is the ONE signal we have
        // for which creator/post is actually converting. Persisted to
        // UserRecord + Supabase (durable cross-device signal).
        // D5 (2026-06-01): brand-voice pass on attribution screen.
        // TitleCase labels ("TikTok", "Instagram", "App Store search")
        // dropped to lowercase per brand voice lock. Sub-copy tightened
        // to "the one we want to thank" — singular, intimate, matches
        // the founder voice from case 230. Same pill register as Q1
        // (consistency compounds trust per first-screen research).
        case 100: jfQuestion(
            "how did you hear about jenifit?",
            sub: nil,  // her75 Phase 3
            italic: ["jenifit"],  // punch the brand name, not the function verb
            opts: [
                ("tiktok",     "tiktok",              nil, "play.rectangle.fill"),
                ("instagram",  "instagram",           nil, "camera.fill"),
                ("friend",     "a friend told me",    nil, "person.2.fill"),
                ("app_store",  "app store search",    nil, "magnifyingglass"),
                ("google",     "google search",       nil, "globe"),
                ("other",      "somewhere else",      nil, "ellipsis.circle"),
            ],
            // Delta v8 D87 — routes to sunk-cost activation Q (case 168)
            // BEFORE the food wedge starts. v1 users walk past 168 via
            // resolveNext to whatever comes next in v1FlowOrder.
            sel: $acquisitionSource, next: 168,
            strikeUnselected: true
        )

        // v4.5 R3 (2026-06-11) — cases 110 (bodyFocus), 2 (experience),
        // 25 (session length), 17 (commit days) cut per v4 plan §D.
        // bodyFocus stays an empty set (= full-body program semantics);
        // experience/cadence/length derive from movement baseline + tier.

        case 111: jfQuestion(
            // C4 redo (2026-06-01) per feedback_copy_succinct_genz —
            // labels are now 2-4 words, no subtitles. Prior shipped
            // copy ("to make peace with my body. / the war's been
            // long enough.") was too literary for Gen-Z attention
            // span. Same enum values preserved.
            "what's the real reason?",
            sub: nil,  // v3 her75 editorial register — drop labor sub
            opts: [
                ("getShaped",  "look like myself",  nil, "sparkles"),
                ("lookBetter", "be in my photos",   nil, "camera"),
                ("summer",     "fit a moment",      nil, "calendar"),
                ("confidence", "stop obsessing",    nil, "infinity"),
                ("selfLove",   "love my body",      nil, "heart"),
            ],
            sel: $motivation, next: 201
        )

        // v4.5 R3 (2026-06-11) — movement baseline replaces the old
        // activity slider (and the cut experience / session-length /
        // commit-days questions). One Q; the program derives cadence
        // and session length from tier × baseline. Derivations run in
        // applyMovementDerivations() on advance.
        case 8: jfQuestion(
            "how does movement fit your life right now?",
            sub: nil,
            italic: ["movement"],
            opts: [
                ("barely",      "barely, honestly",         nil, nil),
                ("walks",       "walks here and there",     nil, nil),
                ("regular_ish", "regular-ish",              nil, nil),
                ("very_active", "very active",              nil, nil),
            ],
            sel: Binding(
                get: { movementBaseline },
                set: { movementBaseline = $0; applyMovementDerivations() }
            ),
            next: 280,
            confirmation: "your plan starts where you are ♥"
        )

        case 120: jfQuestion(
            "Where will you train?",
            sub: nil,  // v3 her75 editorial register
            opts: [
                ("home",    "At home",     "Living room, bedroom, anywhere", "house"),
                ("gym",     "At the gym",  "Equipment access, classes",      "dumbbell.fill"),
                ("outdoor", "Outdoor",     "Park, trails, fresh air",        "tree.fill"),
                ("either",  "Mix of both", "Wherever I feel like",           "shuffle"),
            ],
            sel: $workoutLocation, next: 121
        )

        case 121: jfMulti(
            "What kind of workouts feel good?",
            sub: "Pick whatever you actually enjoy. Multi-pick fine.",
            opts: [
                ("hiit",     "HIIT",              nil, "flame.fill"),
                ("pilates",  "Pilates-inspired",  nil, "figure.flexibility"),
                ("strength", "Strength training", nil, "dumbbell.fill"),
                ("yoga",     "Yoga / mobility",   nil, "figure.mind.and.body"),
                ("dance",    "Dance / cardio",    nil, "music.note"),
                ("walking",  "Walking / steady",  nil, "figure.walk"),
            ],
            // Routes to E1-c (case 232, five-min science) before
            // case 25 session-length. Pre-empts the "is 5 enough?"
            // doubt before the answer.
            sel: $workoutStyle, next: 232
        )

        // ─── Part 3 — About you (biometrics) ────────────────────
        case 130: jfQuestion(
            // was Title Case — out of step with the lowercase brand voice
            // every other live screen uses (v1.1 batch-3 voice sweep).
            "what's your gender?",
            sub: nil,  // v3 her75 editorial register
            opts: [
                ("female",    "female",            nil, "person.fill"),
                ("male",      "male",              nil, "person.fill"),
                ("nonbinary", "non-binary",        nil, "person.crop.circle"),
                ("private",   "prefer not to say", nil, "person.crop.circle.badge.questionmark"),
            ],
            sel: $gender, next: 7
        )

        case 7: ageWheelScreen()

        case 131: jfSliderScreen(
            "how tall are you?",
            sub: nil,  // v3 her75 editorial register
            valueMetric: $heightCm,
            metric: Self.heightMetricRuler,
            imperial: Self.heightImperialRuler,
            toMetric: { inches in inches * Self.cmPerInch },
            fromMetric: { cm in (cm / Self.cmPerInch).rounded() },
            next: 132
        )

        case 132: jfHorizontalSliderScreen(
            "what's your current weight?",
            sub: nil,
            italic: ["your"],  // v3 her75 editorial register
            valueMetric: $currentWeightKg,
            metric: Self.weightMetricRuler,
            imperial: Self.weightImperialRuler,
            toMetric: { lb in lb / Self.lbPerKg },
            fromMetric: { kg in (kg * Self.lbPerKg).rounded() },
            next: 1320,  // v1.1 — via weight-trajectory (1320) before goal
            // Affirmation beat — sensitive numeric input. Research:
            // Noom-pattern validation after weight entry reduces drop.
            // Gen-Z casual lowercase to match the audience voice.
            confirmation: "okay. that's the hard one. ♥",
            annotation: {
                bmiAnnotation(weightKg: currentWeightKg, heightCm: heightCm)
            }
        )

        case 133: jfHorizontalSliderScreen(
            "and your goal weight?",
            sub: nil,
            italic: ["your"],  // her75 Phase 1 §1.3 — hero carries the screen
            valueMetric: $goalWeightKg,
            metric: Self.weightMetricRuler,
            imperial: Self.weightImperialRuler,
            toMetric: { lb in lb / Self.lbPerKg },
            fromMetric: { kg in (kg * Self.lbPerKg).rounded() },
            // Band visualizes the loss range between goal and current.
            // Only render when goal < current (loss); maintain/gain
            // hides the band so the ruler stays clean.
            bandMetric: goalWeightKg < currentWeightKg
                ? goalWeightKg...currentWeightKg
                : nil,
            next: 134,
            // Reciprocity beat — Phase 2 (2026 research). Acknowledges
            // the weight-share moment with peer-voice empathy instead
            // of the older "honest pace" pace-coded line. RevenueCat
            // teardown finding: immediate emotional reciprocity after
            // sensitive disclosures lifts conversion materially.
            confirmation: "thank you. that's the hard one. ♥",
            annotation: {
                goalWeightAnnotation(currentKg: currentWeightKg, goalKg: goalWeightKg, heightCm: heightCm)
            }
        )

        // ─── 1320 — weight trajectory (medical-grade, v1.1) ────────────
        // Sits between current weight (132) and goal (133). A single
        // current-weight point can't tell us direction of travel, which is
        // the real clinical signal: recent rapid loss (esp. on a GLP-1)
        // changes lean-mass risk + realistic pacing; "up and down" flags
        // weight-cycling / regain risk. Self-reported, no number required.
        case 1320: jfQuestion(
            "where's your weight been heading?",
            sub: nil,
            italic: ["heading"],
            opts: [
                ("climbing",  "climbing",            nil, "arrow.up.right"),
                ("stable",    "about the same",      nil, "arrow.right"),
                ("declining", "slowly coming down",  nil, "arrow.down.right"),
                ("cycling",   "up and down",         nil, "arrow.up.arrow.down"),
            ],
            sel: $weightTrend, next: 133
        )
        .onAppear {
            // Seed the goal weight from the user's current weight on
            // first mount so the slider opens at "no change yet" rather
            // than the previous hardcoded 60 kg default. User actively
            // drags down/up from there.
            if !goalWeightInitialized {
                goalWeightKg = currentWeightKg
                goalWeightInitialized = true
            }
        }

        case 134: jfBodyTypeScreen(
            // Shortened from "Where are you now?" to one short line so
            // the title fits one row at 32pt — keeps the model image
            // generous and matches the new case 135 title pattern.
            "your starting point.",
            sub: "Visual reference, not a number on a scale.",
            position: $bodyTypeCurrent,
            labels: ["Cut", "Lean", "Athletic", "Average", "Curvy", "Soft"],
            next: 135
        )

        case 135: jfBodyTypeScreen(
            // Shortened from "Where do you want to be?" — that wrapped
            // to 2 lines on standard-height devices, shrinking the
            // model picture. "your goal." fits one line guaranteed.
            "your goal.",
            sub: "What we're moving you toward.",
            position: $bodyTypeDesired,
            labels: ["Cut", "Lean", "Athletic", "Average", "Curvy", "Soft"],
            maxPosition: bodyTypeCurrent,
            markerPosition: bodyTypeCurrent,
            contextLine: "You said you're at: \(["Cut", "Lean", "Athletic", "Average", "Curvy", "Soft"][bodyTypeCurrent])",
            // Routes to case 160 (reshape transition) → case 161 (first
            // prediction) → case 203. PostHog 2026-05-26 audit found
            // case 135 was going direct to 203 — skipping both screens.
            // flowOrder had them sequential (134, 135, 160, 161, 203);
            // forward routing didn't match. Fixed.
            next: 160
        )
        .onAppear {
            // Seed desired body type from current on first mount. The
            // maxPosition clamp prevents the user from picking a body
            // type "less lean" than where they are today (track visually
            // shortens to the current position). The markerPosition +
            // contextLine show the current position as read-only
            // reference so the goal screen feels like a continuation
            // rather than an isolated picker.
            if !bodyTypeDesiredInitialized {
                bodyTypeDesired = bodyTypeCurrent
                bodyTypeDesiredInitialized = true
            }
        }

        // ─── Part 4 — How you want to feel ──────────────────────
        // v3 P11.9 (2026-06-10) — StickerScatter removed for her75
        // editorial restraint. her75 question screens have ZERO
        // sticker scatter; the brand moments (welcome + plan reveal +
        // celebration) keep theirs. Question screens stay clean.
        case 140:
            // v4.5 (2026-06-11) — her75 "why do you want to complete a
            // challenge" register: 2-col photo cards (Grok editorial
            // cutouts, faces obscured) instead of text rows. The
            // identity Q is the emotional peak of ch.4 — it earns the
            // only photo-card grid in the flow.
            jfPhotoChoice(
                "which one is the new you?",
                italic: ["new"],
                opts: [
                    ("powerful", "powerful", "onb-identity-powerful"),
                    ("calm",     "calm",     "onb-identity-calm"),
                    ("light",    "light",    "onb-identity-light"),
                    ("strong",   "strong",   "onb-identity-strong"),
                    ("radiant",  "radiant",  "onb-identity-radiant"),
                ],
                sel: $identityFeeling,
                next: 158,
                confirmation: "got it. we'll build around that."
            )

        case 141: jfQuestion(
            "What's the reward when you hit the goal?",
            sub: "The thing you'll do for yourself when this lands.",
            opts: [
                ("clothes",  "New clothes",        "Treat my new look",      nil),
                ("trip",     "Take a trip",        "Celebrate somewhere",    nil),
                ("photos",   "Photos of myself",   "Document the change",    nil),
                ("personal", "Personal day",       "Just for me",            nil),
                ("treat",    "Treat myself",       "Something I've wanted",  nil),
            ],
            sel: $rewardChoice, next: 142,
            confirmation: "We see you. Your reasons are real.",
            stickers: [
                "clothes":  .bowSatin,
                "trip":     .seashell,
                "photos":   .cameraLineart,
                "personal": .heartsLineart,
                "treat":    .cherries,
            ]
        )

        // 17d-3: comparison screen — JeniFit vs generic plans.
        // Slots between Q141 (reward) and the Part 5 section
        // divider (204) so the user lands on a "you've been promised
        // this before, here's what's actually coming" beat right
        // after they name their reward.
        case 142: comparisonScreen

        // ─── Video demo (145, epic #1 child #8) ─────────────────
        // 10-15s silent loop of an actual plank session. Slot is
        // post-comparison so the "JeniFit vs generic" frame lands
        // immediately followed by "and here's what it actually
        // looks like." Article research: "Nobody reads features.
        // Everyone watches them." Auto-skips when the asset file
        // is missing (founder ships `jeni_session_demo.mp4`
        // separately) and when reduce-motion is on (still frame
        // not yet shipped — falls through to next case).
        case 145: videoDemoScreen

        // v4.5 (2026-06-11): cases 150/151/152 (v1 barrier yes/no chain)
        // and 153 (v2 barrier multi-select) deleted. The barrier multi
        // read as a duplicate of the 171/172/173 fear psychometrics one
        // chapter earlier; founder kept the statement screens. The
        // legacy relatability1/2/3 flags now derive from the fear
        // answers at assembly so derivedBarriers, the Becoming barrier
        // card, and the PostHog funnel keep their signal.

        // ─── v2-A2: Credibility-grade vulnerability block ───────────
        // Sleep + stress + eating cadence + eating window. Placed in
        // Act 4 of v2FlowOrder (between month-signals and comparison)
        // so they land after the user has already invested in identity
        // + biometrics — vulnerability last, per the placement research.
        // Each wraps WeAskBecauseRow with a real citation. AppStorage
        // backs each field for cross-feature consumers.

        case 154: jfQuestion(
            "how much sleep do you usually get?",
            sub: nil,
            italic: ["you"],
            opts: [
                ("under5",  "under 5 hours",  nil, "moon.zzz"),
                ("five6",   "5 to 6",         nil, "moon"),
                ("six7",    "6 to 7",         nil, "moon.stars"),
                ("seven8",  "7 to 8",         nil, "sparkles"),
                ("eightPlus","8 or more",     nil, "leaf"),
            ],
            sel: $sleepHours, next: 155,
            // C5 (2026-06-01): affirmation beat after sleep input.
            // Per succinctness rule — 3-5 words max.
            confirmation: "noted. sleep matters here."
        )

        case 155: jfQuestion(
            "what's stress like for you right now?",
            sub: nil,
            opts: [
                ("low",          "low",         nil, "leaf"),
                ("manageable",   "manageable",  nil, "wind"),
                ("heavy",        "heavy",       nil, "cloud.rain"),
                ("overwhelmed",  "overwhelmed", nil, "cloud.bolt"),
            ],
            // Delta v7 — eating cadence/window moved to early food block,
            // so stress now routes to hormonal stage (163) directly.
            sel: $stressLevel, next: 163,
            // C5: affirmation beat after stress disclosure.
            confirmation: "we got you."
        )

        case 156: jfQuestion(
            "how do you usually eat?",
            sub: nil,
            opts: [
                ("one_meal",    "one meal",        nil, "fork.knife"),
                ("two_meals",   "2 + snacks",      nil, "cup.and.saucer"),
                ("three_meals", "3 steady meals",  nil, "carrot"),
                ("grazing",     "grazing all day", nil, "leaf"),
                // "chaos" labelled the user's own life as chaotic — the
                // clearest anti-shame slip in the food cluster. Neutral
                // descriptor, same "no fixed cadence" signal (key unchanged).
                ("chaotic",     "no real pattern", nil, "wind.snow"),
            ],
            sel: $eatingCadence, next: 157
        )

        case 157: jfQuestion(
            // "when do you stop eating?" read as a willpower cutoff + the
            // ascending ladder implied earlier=better (a TRE value judgment,
            // also evidence-weak). "wind down" = same circadian signal, no
            // restriction coding.
            "when does eating wind down?",
            sub: nil,
            opts: [
                ("before_7", "before 7pm",  nil, "sunrise"),
                ("by_8",     "7 to 8pm",    nil, "sun.horizon"),
                ("by_10",    "8 to 10pm",   nil, "moon"),
                ("late",     "after 10pm",  nil, "moon.zzz"),
                ("varies",   "varies",      nil, "cloud"),
            ],
            // Delta v7 — routes to prior-win (159) which still has
            // "logging_food" as an option. After food wedge completes
            // we hand off to Act 2 (workout) via 201.
            sel: $eatingWindow, next: 159
        )

        // ─── v2-A3: Identity + previous-attempt anchor block ────────
        // Placed BEFORE A2's vulnerability block in v2FlowOrder so the
        // softer identity inputs land first (Prochaska stages-of-change
        // logic + Bandura self-efficacy anchor). "Previous attempts" is
        // the reciprocity beat ("we've been there"); "what worked"
        // surfaces her own evidence; "food relationship" calibrates
        // tone (mechanical vs affective).

        case 158: jfQuestion(
            "how many serious attempts in the last few years?",
            sub: nil,  // v3 her75 editorial register
            opts: [
                ("none",       "first time",   nil, "leaf"),
                ("one_two",    "1 or 2",       nil, "1.circle"),
                ("three_five", "3 to 5",       nil, "3.circle"),
                ("many",       "lost count",   nil, "infinity"),
            ],
            // Delta v7 — prior win moved to early food block, so prior
            // attempts now routes directly to sleep in Act 4.
            sel: $priorAttempts, next: 154,
            // C5: affirmation beat after a skeptic-aware prior-attempts
            // disclosure. The user just admitted she's tried before;
            // brand voice acknowledges without overpromising.
            confirmation: "reading you. you're not alone here."
        )

        case 159: jfQuestion(
            // 2026-06-01: dropped "more walks" — overlapped "daily
            // movement" semantically, and the 6th option pushed the
            // pill stack off-screen on smaller iPhones. walking_more
            // enum value kept in the data model but unused in the UI.
            "what's worked, even briefly?",
            sub: nil,  // v3 her75 editorial register
            opts: [
                ("moving_daily",  "daily movement",  nil, "figure.walk"),
                ("eating_window", "eating window",   nil, "clock"),
                ("cutting_sugar", "less sugar",      nil, "drop"),
                ("logging_food",  "tracking food",   nil, "list.clipboard"),
                // "nothing yet" terminated on a deficit; the highest-shame
                // user lands here. Agentic, in-progress framing (key kept).
                ("nothing_yet",   "still figuring it out", nil, "questionmark.circle"),
            ],
            // Delta v8 (2026-06-06) — closes the food wedge block,
            // routes to the cuisine Q (case 169) which is now the final
            // food-wedge screen before the workout block.
            sel: $priorWin, next: 169
        )

        // ─── Delta v8 + W5-T6 — cuisine multi-select (case 169) ────
        //
        // Final food-wedge screen. Feeds FoodVisionService system
        // prompt for cohort accuracy — Cal AI's per-bench failure mode
        // is non-American cuisine identification (food rail plan §22 +
        // Brief #4 §2). The cohort eats across cuisines so this is
        // multi-select, not single-pick. Saves as CSV to
        // `onboardingCuisinePreference` AppStorage; the vision service
        // reads + parses on each scan dispatch.
        //
        // Routes to case 110 (next in v2 flow after the wedge).
        // resolveNext handles the old `next: 201` fallback for v1.
        // v4.6 (2026-06-11) — revived from the v3 C6 cut per founder
        // direction (cuisine signal lifts in-app calorie-vision
        // accuracy) and upgraded to the it-girl photo grid: one food
        // cutout per option, multi-select.
        case 169: jfPhotoMulti(
            "what's usually on your plate?",
            sub: "pick all the ones that show up often.",
            italic: ["plate"],
            opts: [
                ("american",      "american",      "onb-cuisine-american"),
                ("italian",       "italian",       "onb-cuisine-italian"),
                ("mexican",       "mexican",       "onb-cuisine-mexican"),
                ("eastAsian",     "east asian",    "onb-cuisine-eastasian"),
                ("southAsian",    "south asian",   "onb-cuisine-southasian"),
                ("mediterranean", "mediterranean", "onb-cuisine-mediterranean"),
            ],
            sel: Binding<Set<String>>(
                get: {
                    Set(cuisinePreferenceCSV
                        .split(separator: ",")
                        .map(String.init)
                        .filter { !$0.isEmpty })
                },
                set: { newValue in
                    cuisinePreferenceCSV = newValue.sorted().joined(separator: ",")
                }
            ),
            next: 110
        )

        // v9 P9.9 (her75 + conversion-expert spec, 2026-06-10) — the
        // commitment-moment screen that replaces the cut body-image
        // sliders (134/135). Multi-select NSV cards. Founder reasoning:
        // body-image visualization is a conversion-load-bearing
        // "I'm picking the version of me I want" hook (+21% trial-to-
        // paid lift per Adapty 2026), but the AI-rendered women asset
        // was off-brand for the her75 register. Outcome cards preserve
        // the commitment moment in a brand-safe vehicle + collect a
        // downstream-useful NSV signal we didn't have before.
        case 136: jfMulti(
            "what lands first?",
            sub: "pick what you'll feel before the scale moves.",
            opts: [
                ("core",    "core that holds",         nil, "figure.core.training"),
                ("energy",  "energy that lasts",       nil, "bolt"),
                ("clothes", "clothes that fit right",  nil, "tshirt"),
                ("sleep",   "sleep that resets",       nil, "moon.stars"),
            ],
            sel: Binding<Set<String>>(
                get: {
                    Set(nsvPriorityCSV
                        .split(separator: ",")
                        .map(String.init)
                        .filter { !$0.isEmpty })
                },
                set: { newValue in
                    nsvPriorityCSV = newValue.sorted().joined(separator: ",")
                }
            ),
            next: 160,
            confirmation: "we'll watch for these."
        )

        case 162: jfQuestion(
            "what is food, mostly?",
            sub: nil,
            italic: ["food"],  // v3 her75 editorial register
            // v3 P11.1 deferred (BetterMe A2) — self-narration option
            // labels. Title stays one-word so the row reads at a glance;
            // subtitle carries the first-person commitment line.
            // Self-perception theory (Bem 1972) — naming the
            // relationship commits to it.
            //
            // v3 P11.8 density audit (2026-06-10) — restructured from
            // single-string "keyword · descriptor" titles (which
            // wrapped to 2 lines at iPhone 13 mini width + pushed
            // card height to ~96pt × 5 = overflow) to (title, subtitle)
            // tuple so each row stays ~72pt + the descriptor still
            // reads as the self-narration commitment line.
            opts: [
                ("fuel",         "fuel",         "i eat to function",        "bolt"),
                ("comfort",      "comfort",      "food is how i decompress", "heart"),
                ("love",         "love",         "cooking + sharing is joy", "heart.text.square"),
                ("control",      "control",      "i track it closely",       "slider.horizontal.3"),
                ("complicated",  "complicated",  "not a clean answer",       "circle.dashed"),
            ],
            // Delta v7 — routes to the new pre-eat permission wedge
            // (case 166) instead of the sleep Q. The food block now
            // sits at the top of onboarding.
            sel: $foodRelationship, next: 166
        )

        // ─── v2-A4: Cohort signal — hormonal stage + GLP-1 status ────
        // The deepest vulnerability tier. Land LAST in Act 4 (right
        // before the comparison frame at 142) so the user has already
        // invested ~50 screens and trusts the container. Both include
        // an explicit "prefer not to say" — sensitive questions need
        // the skip escape per the placement research.

        case 163: jfQuestion(
            "what stage are you in?",
            // sub dropped 2026-06-10 — was "we adjust to where your
            // body is.", which restated what the trust anchor below
            // already says ("hormonal stage shifts hunger, energy,
            // and recovery"). Two near-identical sub-lines were
            // pushing the option pills + Continue button off-screen.
            sub: nil,
            opts: [
                ("cycling",         "cycling regularly",   nil, "calendar"),
                ("irregular",       "irregular cycle",     nil, "calendar.badge.exclamationmark"),
                ("postpartum",      "postpartum",          nil, "figure.and.child.holdinghands"),
                ("perimenopause",   "perimenopause",       nil, "thermometer"),
                ("postmenopause",   "postmenopause",       nil, "leaf"),
                ("prefer_not_say",  "prefer not to say",   nil, "lock"),
            ],
            sel: $hormonalStage, next: 164,
            // C5: affirmation beat after hormonal disclosure.
            confirmation: "we adjust for this.",
            // v3 P11.1.A (2026-06-10) — BetterMe A4 duty-of-care
            // inline cards. Renders only on cohort-specific selections
            // where actual program adaptation is required. NOT
            // scolding, NOT a warning — signals care + competence.
            inlineFeedback: [
                "postpartum":    ("we adjust for postpartum.", "no plank or supine work for the first 6 weeks. talk to your doctor before starting any program."),
                "perimenopause": ("we adjust for peri.", "we lean into strength + sleep cues. hunger and mood ride differently here, and we factor that in."),
                "irregular":     ("we adjust for irregular cycles.", "we don't anchor the plan to a textbook 28-day cycle. expect more weight-by-week, less day-by-day."),
            ]
        )

        // ─── v3 C1 (2026-06-10) — case 165 (commitConfidence) CUT ──
        // Delta v7 D67 commitment-confidence Q was a pure psychological
        // beat (the act of staking in was the value). After 9 months of
        // data, `onboardingCommitConfidence` was never read by any
        // downstream consumer (paywall, generator, notifs, Becoming).
        // The Cal AI sunk-cost lock from S4 sign-in (P11.1.C) covers
        // the same mechanism more honestly. AppStorage key retained
        // for migration safety; the question is gone.

        // ─── v3 P11.1.B (2026-06-10) — pace selector upgraded ──────
        // Cal AI S2 spec from `docs/onboarding_v3_addlist_synthesis_
        // 2026_06_10.md`. Now ships:
        //  - Live "weeks to becoming" callout per tier (was hardcoded
        //    static ranges); ACSM 0.5 / 0.75 / 1.0 %/wk band applied to
        //    the user's actual weight delta.
        //  - Coquette stickers (seashell / bowIridescent / sparkleGlossy)
        //    in place of SF Symbols (tortoise/hare/flame) — the asset
        //    pack already ships these per [[feedback-design-theme]].
        //  - Care framing on focused tier (NO red triangle, NO loose-
        //    skin language — both rejected per Cal AI teardown §4 #4).
        //
        // Per the synthesis: "the single most-screenshotted onboarding
        // screen on Reddit; pace selectors with live-update callouts
        // lift commitment-phase conversion +12-18%." Originating screen:
        // calai13/14/15.
        case 167: jfQuestion(
            "how do you want to get there?",
            sub: nil,
            italic: ["you"],  // v3 her75 editorial register — pace selector goes silent
            opts: paceSelectorOpts(),
            sel: Binding(
                get: { paceChoice },
                set: { paceChoice = $0; applyCadenceDerivations() }
            ), next: 203,
            confirmation: "got it ♥",
            // her75 Phase 3 — audit said cut this inlineFeedback as
            // filler; KEPT deliberately. It's the informed-consent
            // mechanism on the focused tier (Cal AI's red-triangle
            // warning done anti-shame, founder-locked per the v3
            // synthesis), renders only on selection, duty-of-care-
            // adjacent like 163/164.
            inlineFeedback: [
                "focused": ("we'll match the pace.", "moves quickly. sleep + protein floor matter more here than calorie math. soft week when life gets loud ♥"),
            ],
            stickers: [
                "gentle":  .seashell,
                "steady":  .bowIridescent,
                "focused": .sparkleGlossy,
            ]
        )

        // ─── Delta v8 D87 — sunk-cost activation (case 168) ────────
        // Cal AI's calai10 pattern adapted. 3 options (not 2) per
        // WL + Culture briefs: first try / a few times / many times.
        // The few-vs-many distinction drives downstream copy ramp.
        // Slot between attribution (100) and food relationship (162)
        // so it lands BEFORE the food wedge.
        case 168: jfQuestion(
            // v1.1 batch-1 (2026-06-23) — softened from "tried everything
            // already?", which presumed exhaustive failure and read as an
            // indictment to the shame-sensitive cohort (and excluded the
            // first-timer). "been here before?" captures the same sunk-cost
            // signal as neutral recognition, not a verdict.
            "been here before?",
            sub: nil,
            italic: ["here"],
            opts: [
                ("first",       "this is my first real try",   nil, "sparkles"),
                ("fewTimes",    "yes, a few times",            nil, "checkmark.circle"),
                // heart.circle (not the arrow.clockwise loop) so the
                // most-tried, highest-intent woman reads as seen, not
                // stuck going in circles.
                ("manyTimes",   "yes, many times",             nil, "heart.circle"),
            ],
            // 283 (cohort credibility) sits between 168 and 162 in
            // v2FlowOrder; a direct next: 162 hint was silently skipping
            // it (caught by the v4.5 walker — the huddle never rendered
            // in any run).
            sel: $triedBefore, next: 283,
            confirmation: "okay ♥",
            strikeUnselected: true
        )

        case 164: jfQuestion(
            "any weight meds right now?",
            sub: nil,
            italic: ["weight meds"],  // v3 her75 editorial register
            opts: [
                ("none",         "no",                nil, "leaf"),
                ("considering",  "considering it",    nil, "questionmark.circle"),
                ("past",         "in the past",       nil, "clock.arrow.circlepath"),
                ("current",      "on a GLP-1 now",    nil, "cross.case"),
                ("prefer_not_say","prefer not to say",nil, "lock"),
            ],
            // Medical-grade follow-up (v1.1): the "on a GLP-1 now" cohort
            // routes to the titration-phase detail (1641); everyone else
            // rejoins at the reciprocity beat (282). Explicit in-flow hint
            // so resolveNext honors it (1641 sits between 164 and 282 in
            // v2FlowOrder, so the old `142` fallback would have mis-routed).
            sel: $glp1Status, next: glp1Status == "current" ? 1641 : 282,
            // Delta v8 D86 — reciprocity beat (Culture brief). After
            // the deepest vulnerability Q (GLP-1 + hormonal stage Qs
            // immediately prior), explicit gratitude lands as the
            // strongest single trust signal in the cohort. Replaces
            // "no judgment, ever." (which was safety-beat, this is
            // reciprocity-beat — research shows the latter converts
            // higher in TikTok-acquired Gen-Z WL).
            confirmation: "thank you for being honest ♥",
            // v3 P11.1.A (2026-06-10) — BetterMe A4 duty-of-care
            // inline cards for GLP-1 cohort (~30% of v1 traffic per
            // [[feedback-calorie-competitor-landscape-2026]]). Care
            // framing + concrete adaptation, never satire of the meds.
            inlineFeedback: [
                "current":     ("we adjust for GLP-1.", "satiety-aware portions, protein floor, no restrictive windows. we lean into what your appetite is already telling you."),
                "past":        ("we adjust for post-GLP-1.", "the first 12 weeks off-meds are about keeping what you built. we match the cadence + protein."),
                "considering": ("med or no med, we work.", "the plan reads your data the same way either path you choose ♥"),
            ]
        )

        // ─── 1641 — GLP-1 titration / duration (medical-grade, v1.1) ────
        // Conditional follow-up, shown ONLY when 164 == "on a GLP-1 now".
        // Titration phase is the single highest-value GLP-1 signal: it
        // predicts side-effect burden, appetite-suppression depth, and
        // lean-mass risk → it routes protein-emphasis coaching for the
        // early-titration cohort. Self-reported, NO brand name, NO dose,
        // non-actionable (Apple 5.2.1 / FTC floors). Rejoins at 282.
        case 1641: jfQuestion(
            "how long have you been on it?",
            sub: nil,
            italic: ["how long"],
            opts: [
                ("just_started", "just started",       nil, "hourglass.bottomhalf.filled"),
                ("few_months",   "a few months in",    nil, "hourglass"),
                ("established",  "6+ months, steady",   nil, "checkmark.seal"),
                ("prefer_not",   "prefer not to say",   nil, "lock"),
            ],
            sel: $glp1Phase, next: 282,
            confirmation: "got it. that shapes your plan.",
            inlineFeedback: [
                "just_started": ("early days, noted.", "the first weeks lean on protein and steady fuel while appetite shifts. we factor that in."),
            ]
        )

        // ─── v3 P11.1.C (2026-06-10) — Apple Health relocate (285) ──
        //
        // Cal AI S5 — HK ask moved from post-reveal (PairedPermissionsAsk
        // tail of OnboardingRevealView) to mid-onboarding. Originating
        // pattern: calai23. By moving HK ahead of the plan reveal, the
        // projection screen can cite the user's actual steps baseline,
        // and the post-reveal moment doesn't carry permission friction.
        // +5-9% paywall→trial + +1.4× Day-7 retention (Adapty 2026).
        //
        // Slot: between case 284 (consent) and 234 (plateau teach). The
        // consent screen has just established what we'll use her data
        // for — HK ask lands as the natural next beat of "yes, pull
        // what you already track."
        //
        // PairedPermissionsAsk (in OnboardingRevealView) becomes
        // notifications-only after this lands — HK has already fired.
        case 285: HealthKitPermissionScreen(onAdvance: { go(234) })

        // ─── v4.5 (2026-06-11) — realistic-target reframe (case 286) ──
        // Cal AI calai12 slot done the JeniFit way: effort-down reframe
        // between goal weight (133) and the NSV commitment moment (136).
        // REAL citation (Wing & Phelan 2005), no "90% of users" theater.
        // Personal line derives from her own numbers per the data-
        // provenance rule.
        case 286: realisticTargetScreen

        // ─── v3 P11.1.C (2026-06-10) — 2-checkbox consent (case 284) ──
        //
        // BetterMe A6 explicit health-data consent. Friction-positive:
        // explicit consent IS a commitment device (Cialdini foot-in-
        // the-door). Personalize is the required gate; day-2 check-in
        // is opt-out + unlocks the trial-week notification system per
        // [[project-trial-week-notifications]] with explicit
        // affirmative consent rather than just OS-permission grant.
        // Slot: after name (18), before plateau teach (234) — final
        // commit beat before the educational + reveal lands.
        case 284: VStack(spacing: 0) {
            Spacer()
            ItalicAccentText(
                "before we build your plan.",
                italic: ["build"],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .padding(.horizontal, Space.screenPadding)
            Spacer().frame(height: Space.xl)
            VStack(spacing: 12) {
                consentRow(
                    isOn: $consentPersonalize,
                    title: "use my answers to personalize my plan",
                    italicWord: "personalize",
                    required: true
                )
                consentRow(
                    isOn: $consentDay2,
                    title: "send me a day-2 check-in so i don't lose momentum",
                    italicWord: "day-2",
                    required: false
                )
            }
            .padding(.horizontal, Space.lg)
            Spacer()
            // v3 P11.6 — JFContinueButton (required gate via isEnabled).
            JFContinueButton(
                label: "i agree",
                action: { go(234) },
                isEnabled: consentPersonalize
            )
        }

        // ─── v3 P11.1.B (2026-06-10) — Reciprocity beat (case 282) ──
        //
        // Cal AI A7 dedicated reciprocity screen. Originally shipped
        // with a Grok 3D-sticker illustration (heart-padlock); pulled
        // 2026-06-10 per founder QA — Grok abstract stickers clashed
        // with the cream bg + didn't carry her75 editorial weight.
        // Now pure typography per the her75 simplest-screens register
        // ("Personalizing *your* space" pattern from IMG_6280). Art
        // direction pending design + cultural + art expert teardown
        // — when locked, swap in either a real-photo collage or a
        // curated coquette-sticker arrangement that holds editorial
        // weight at hero size.
        case 282: bridgeScreen(
            headline: "thank you for being honest.",
            italicWords: ["honest."],
            next: 171  // routes to first psychometric fear
        )

        // ─── v3 P11.1.B (2026-06-10) — Cohort credibility (case 283) ──
        //
        // BetterMe A5 cohort-specific social proof. Pattern-language
        // (not a fabricated count) until ~250 paid users land. Slot:
        // late Ch1 after the sunk-cost activation Q (168).
        //
        // Grok bow-huddle illustration pulled 2026-06-10 per founder
        // QA. Pending art-direction decision (her75 photo collage vs
        // curated sticker arrangement vs pure typography). For now,
        // pure typography + sub line — restraint per the her75
        // simplest-screens register.
        case 283: VStack(spacing: 0) {
            Spacer()
            // v4.6 round 9 — circular avatar conveyor. Reads as women
            // joining in real time: a new circle slides in from the
            // right every 1.6s, the oldest slips out left, the newest
            // arrival lands slightly larger then settles into the row.
            // Clean: 4 framed circles, one motion, nothing else.
            HStack(spacing: 14) {
                ForEach(0..<4, id: \.self) { slot in
                    let i = cohortMarqueeIndex + slot
                    let asset = Self.cohortMarqueeAssets[i % Self.cohortMarqueeAssets.count]
                    let isNewest = slot == 3
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: isNewest ? 72 : 64, height: isNewest ? 72 : 64)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
                        .id("\(asset)-\(i)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing)
                                .combined(with: .scale(scale: 0.6))
                                .combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(height: 80)
            .clipped()
            .accessibilityHidden(true)
            .padding(.bottom, Space.lg)
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(Motion.gentleSpring) {
                        cohortMarqueeIndex = (cohortMarqueeIndex + 1)
                            % Self.cohortMarqueeAssets.count
                    }
                }
            }
            ItalicAccentText(
                "women like you are already inside.",
                italic: ["like you"],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .center
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .padding(.horizontal, Space.screenPadding)
            Spacer().frame(height: Space.lg)
            // Reworded for provenance: "#1 barrier" was an unsubstantiated
            // numeric superlative + "your patterns match" over-claimed an
            // analytic match from a few taps. Now a non-ranked self-report
            // descriptor + belonging line; age band widened off the hardcoded
            // 25-34 (the cohort is 22-35, so the tails contradicted it).
            Text("women in their 20s and 30s who name food noise as the hard part. you'll fit right in.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            // v3 P11.6 — JFContinueButton for her75-register consistency.
            JFContinueButton(label: "continue") { go(162) }
        }

        // ─── v3 P11.1.B (2026-06-10) — Bridge screens ────────────────
        //
        // BetterMe A3 affirmation-only pauses between major chapter
        // transitions. Pacing variance lifts completion 3-5% (Adapty
        // 2026); the screen reads as the brand acknowledging the
        // user mid-flow rather than just extracting answers. Slot:
        //   - 280: between case 17 (commit days, Ch2 end) and case 231
        //          (gender, Ch3 start) — "now the numbers" softener
        //   - 281: between case 164 (GLP-1, last vulnerability) and
        //          171 (first psychometric fear) — recognition pause
        //          before the dichotomous-commitment Qs land.

        case 280: bridgeScreen(
            headline: "now the numbers.",
            italicWords: ["numbers."],
            supporting: "never shared. never sold.",
            next: 130
        )

        // ─── v3 P11.1.B (2026-06-10) — Psychometric Yes/No fears ────
        //
        // BetterMe S2 pattern (betterme22-23). Bem 1972 self-perception:
        // fear-coded first-person statements force dichotomous identity
        // commitment. The cohort either names the fear (now JeniFit is
        // the resolver, and downstream paywall + Day-2 notif can
        // resurface the named fear as a resolved promise) OR denies it
        // (cheap tap forward). Either branch advances.
        //
        // Slot: between case 164 (GLP-1, the last vulnerability Q) and
        // case 260 (tier ladder). The user has already invested ~40+
        // screens by here; the fears land as recognition, not extraction.
        //
        // Per [[feedback-her75-editorial-register]] the jfYesNo helper's
        // prefix/italic/suffix triplet acts as the headline — no
        // explanatory sub. Italic falls on the verb that carries the
        // fear's *meaning* ("promise", "another", "given up").

        case 171: jfYesNo(
            prefix: "i don't trust apps that ",
            italic: "promise",
            suffix: " quick results.",
            bind: Binding<Bool?>(
                get: { fearQuickResults == "yes" ? true : (fearQuickResults == "no" ? false : nil) },
                // Also seeds the legacy relatability flag (case 153 cut
                // 2026-06-11) so the recap card + derivedBarriers keep
                // their barrier signal.
                set: {
                    fearQuickResults = $0 == true ? "yes" : ($0 == false ? "no" : "")
                    relatability2 = $0
                }
            ),
            next: 172,
            accentImage: "onb-itgirl-psych-water"
        )

        case 172: jfYesNo(
            prefix: "i'm afraid this is going to feel like ",
            italic: "another",
            suffix: " diet.",
            bind: Binding<Bool?>(
                get: { fearAnotherDiet == "yes" ? true : (fearAnotherDiet == "no" ? false : nil) },
                set: {
                    fearAnotherDiet = $0 == true ? "yes" : ($0 == false ? "no" : "")
                    relatability1 = $0
                }
            ),
            next: 173,
            accentImage: "onb-itgirl-psych-hoodie"
        )

        case 173: jfYesNo(
            prefix: "i've tried this before and ",
            italic: "given up",
            suffix: " after the first hard day.",
            bind: Binding<Bool?>(
                get: { fearPriorAttempt == "yes" ? true : (fearPriorAttempt == "no" ? false : nil) },
                set: {
                    fearPriorAttempt = $0 == true ? "yes" : ($0 == false ? "no" : "")
                    relatability3 = $0
                }
            ),
            next: 260,
            confirmation: "we hear you. ♥",
            accentImage: "onb-itgirl-psych-stretch"
        )

        // ─── Part 6 — Ready to start ────────────────────────────
        // v3 P11.9 (2026-06-10) — StickerScatter removed; her75
        // editorial restraint on question screens.
        case 3:
            jfQuestion(
                    "how long can you hold a plank?",
                    sub: nil,  // her75 Phase 1 — "Not sure" option carries the affordance
                    opts: [
                        ("under15",   "Under 15s",  "Just starting",       "stopwatch"),
                        ("fifteen30", "15-30s",     "Building a base",     "stopwatch.fill"),
                        ("thirty60",  "30-60s",     "Solid foundation",    "timer"),
                        ("sixtyPlus", "60+ seconds","Strong already",      "flame.fill"),
                        ("notSure",   "Not sure",   "We'll figure it out", "questionmark.circle"),
                    ],
                    sel: $baseline, next: 11
                )

        // v3 P11.1.C (2026-06-10) — Cal AI A8 notification pre-prime.
        // Was: "When should we send your daily reminder?" — labor-coded.
        // Now: her75 hero "want a nudge from *jeni*?" + mockup iOS
        // notification preview visual + time-of-day pills. The mockup
        // primes the iOS permission dialog that fires later (+34% allow
        // rate per Apple dev session 2024). NO pointing-finger emoji.
        // her75 Phase 1 §3(d) (2026-06-10) — ScrollView REMOVED. With
        // the 38pt re-ladder + 3 pills + 1 mockup card the content
        // fits one viewport on iPhone 13 mini. her75 onboarding is
        // one-viewport per screen; if it doesn't fit, the screen has
        // too much content.
        case 11: VStack(spacing: 0) {
            jfHeader("want a nudge from jeni?")
                .padding(.top, Space.md)
            Spacer().frame(height: Space.lg)
            HStack(spacing: 10) {
                // Real app-icon treatment (founder QA 2026-06-11): the
                // bow logo on a white icon tile, like the actual banner.
                // Full-bleed app-icon tile — the pink jenifit logo fills
                // the squircle edge-to-edge like a real push banner (was a
                // small bow inset on a white tile, which read as "not
                // filled with the logo").
                Image("logo_jenifit_bow")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 38, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    HStack {
                        Text("jenifit")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("now")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    // The mock mirrors the REAL daily reminder she'll
                    // receive (title + body from NotificationPermission),
                    // so the preview is the actual promise the app keeps.
                    Text("five minutes, today.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    ItalicAccentText(
                        "small moves still count. they always have ♥",
                        italic: ["always"],
                        baseFont: .system(size: 13),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 13),
                        color: Palette.textSecondary,
                        alignment: .leading
                    )
                    .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.bgElevated)
                    .shadow(color: Palette.cocoaPrimary.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, Space.screenPadding)
            // Apple-banner drop-in: slides down from above with the
            // system spring, lands with a soft tick. Reduce-motion snaps.
            .offset(y: nudgeBannerDropped ? 0 : -72)
            .opacity(nudgeBannerDropped ? 1 : 0)
            .onAppear {
                guard !nudgeBannerDropped else { return }
                if reduceMotion {
                    nudgeBannerDropped = true
                } else {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.74).delay(0.4)) {
                        nudgeBannerDropped = true
                    }
                    // Land the haptic with the banner's visual settle
                    // (0.4 delay + ~0.45 spring), not before it.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        Haptics.soft()
                    }
                }
            }
            Spacer().frame(height: Space.md)
            VStack(spacing: 10) {
                ForEach([
                    ("morning",   "morning",   "around 7 am",   "sunrise"),
                    ("afternoon", "afternoon", "around 1 pm",   "sun.max"),
                    ("evening",   "evening",   "around 7 pm",   "moon.stars"),
                ], id: \.0) { opt in
                    OnboardingOptionCard(
                        icon: opt.3,
                        title: opt.1,
                        subtitle: opt.2,
                        isSelected: plankTime == opt.0,
                        action: {
                            Haptics.light()
                            plankTime = opt.0
                        }
                    )
                }
            }
            .padding(.horizontal, Space.screenPadding)
            Spacer()
            JFContinueButton(
                label: "continue",
                action: { advance(to: 18, confirmation: nil) },
                isEnabled: !plankTime.isEmpty
            )
        }

        case 18: nameInput
        case 19: coachSelector

        // ─── Phase 5 — prediction / loading / plan reveal ─────
        case 160: reshapeTransitionScreen
        case 161: firstPredictionScreen
        case 170: rePredictionScreen
        case 180: loadingCarouselScreen
        // case 181 finalPredictionScreen dropped 2026-06-01 (C1).
        // Was the 5th projection-chart appearance in onboarding and
        // duplicated the reveal sequence's ProjectionPresentation.
        // Loading carousel (180) now routes directly to 234 (plateau
        // pre-frame). Definition kept below for reference / quick
        // restore if needed.

        // ─── Post-question pipeline ─────
        case 20: EmptyView() // legacy analyzing overlay marker — superseded by 180
        case 21: planRevealScreen
        case 22: personalStatScreen
        case 23: cameraSetupScreen
        case 215: reviewPromptScreen

        // ─── Method preview (250) — "what you get with me" ──────────
        // Post-2026-05-30 flow: sits between brand promises (240) and
        // review prefilter (215). Previews the daily 5-min ritual (the
        // only post-purchase feature). Honest teaser of the 5-day arc +
        // Jeni audio sample so the user sees what they're about to be
        // asked to pay for — promises already extracted at 240, so the
        // method preview is purely product-forward.
        case 250: methodPreviewScreen

        // ─── Tier-ladder identity preview (260) ─────────────────────
        // Phase 3 conversion beat. 3 milestone cards: week 1 / 3 / 8
        // with identity-coded labels (building → steady → stronger).
        // Companion to the past-vs-steady comparison at case 142.
        // Bandura/Annesi 2011 self-efficacy + Mastery Curve frame —
        // names what *feels* different, not what number you hit.
        case 260: tierLadderScreen

        // ─── Habit-window quiz (270) ────────────────────────────────
        // Phase 4 education-as-quiz. Teaches the 12-week habit window
        // (Lally 2010 / Kaushal & Rhodes 2015) — JeniFit's evidence-
        // aligned planning frame — as a 3-option pick with research-
        // cited reveal. Delivers value pre-paywall; antidote to the
        // "long onboarding = extraction" perception that kills women's
        // wellness app conversion in 2026.
        case 270: habitWindowQuizScreen

        // ─── Brand promises (240) — Jeni-promises-to-her reframe ────
        // Three single-tap promise screens (heart/bow/sparkle) replacing
        // the press-and-hold consent signature ritual as of 2026-05-30
        // (epic #1 child #5). Now fires IMMEDIATELY after plan reveal
        // (21 → 240 → 250 → 215 → 26 → 22 → 23 → finish), not after
        // method preview. Reciprocity > forced commitment for TikTok-
        // acquired Gen Z; IKEA effect freshest right after plan reveal.
        case 240: brandPromisesScreen
        // Delta v8 D82 — post-reveal sunk-cost lock. Case 26 now lands
        // IMMEDIATELY after the reveal (250) and IMMEDIATELY before the
        // rating + final beats, framed as preserving the becoming plan
        // she just saw. The `.sunkCostLock` mode swaps the headline
        // copy + hero sticker; the auth mechanics are unchanged.
        // 240 (brandPromises) and 22 (personal stat) are removed from
        // v2FlowOrder per D83. Routes to 215 (rating prompt) — case 215
        // gracefully skips itself when the rating trigger is ineligible.
        case 26: SignInPromptView(onContinue: { Haptics.medium(); go(215) },
                                  mode: .sunkCostLock)

        // Legacy showcase screens (kept for Phase 5 reuse, not in flow)
        case 4: chartScreen
        case 5: multiView("What usually\nstops you?", sub: "Pick all that apply.", opts: [
            ("boring", "Workouts get boring"), ("dontKnow", "Don't know what to do"),
            ("motivation", "Hard to stay consistent"), ("time", "Never have time"),
            ("injury", "Worried about doing it wrong"),
        ], sel: $barriers, next: 7)
        case 6: celebrationScreen
        case 9: didYouKnowScreen
        case 10: jfQuestion("Legacy single-focus", sub: nil, opts: [("fullCore", "Full core", nil, nil)], sel: $focusArea, next: 11)
        case 12: formScreen
        case 13: featureShowcaseScreen
        case 14: socialProofScreen
        case 15: testimonialScreen
        case 16: beforeAfterScreen

        default: EmptyView()
        }
    }

    // MARK: - Nav

    /// Temporal order of screens. Raw indices aren't monotonic — section
    /// dividers (200–205) interleave with question screens. The progress
    /// bar uses position-in-flow, not raw screen number, so the bar
    /// always advances forward when the user advances forward, regardless
    /// of the underlying number jumping around.
    ///
    /// Phase 4 reorganized the question content into six parts:
    ///   Part 1 — Your story            (200) → goal, bodyFocus, motivation
    ///   Part 2 — How you move now      (201) → experience, activity, location, style, length, days
    ///   Part 3 — About you             (202) → gender, age, height, weights, body types
    ///   Part 4 — How you want to feel  (203) → identity, reward
    ///   Part 5 — What stops you        (204) → 3 yes/no relatability prompts
    ///   Part 6 — Ready to start        (205) → plank baseline, time, name, coach
    /// followed by the existing analysis / plan reveal / paywall pipeline
    /// (20–24) which Phase 5 will rebuild. Sign-in prompt (26) sits
    /// between plan reveal and personal stat as before.
    // v3 dead-code rip (2026-06-10) — v1FlowOrder removed entirely.
    // v1 was the pre-v1.0.6 flow; v1.0.6 (shipped 2026-06-03) made
    // v2FlowOrder the default for every install. Orphan v1-only case
    // bodies (110/111/120/121/141/142/145/150/151/152/170/201/202/204/
    // 235/236/237/238/239/240/270/22/19) stay compiled but are no
    // longer reachable from flowOrder; future pass can prune them
    // surgically. Per [[feedback-dead-code]] this rip kills the most
    // dangerous dead code (the parallel flow definition) without
    // risking the orphan-case surgery in one pass.

    // v3 flow order — the only path. 55 cases including the v3 P11
    // additions (chapter IA + 9 new screens — 171/172/173 psychometric
    // + 280/281 bridges + 282 reciprocity + 283 cohort + 284 consent +
    // 285 Apple Health).
    private static let v2FlowOrder: [Int] = [
        // Act 1 — Soft entry: welcome → anti-shame anchor → soft "why" →
        // attribution. Low-stakes commitment, get her one screen in.
        200, 230, 1, 100,
        //
        // Delta v8 D87 — sunk-cost activation Q FIRST (case 168).
        168,
        // v3 P11.1.B (2026-06-10) — cohort credibility slot (case 283,
        // BetterMe A5). Patterns-match copy (NOT a fabricated count)
        // sits right after the sunk-cost activation Q so the user has
        // stated intent before social proof tries to validate it. Swap
        // pattern copy for real count when ~250 paid users land.
        283,
        //
        // Delta v7 + v8 — FOOD WEDGE early. Diet-first pivot signal.
        //   162 (food relationship) → 166 (pre-eat permission wedge,
        //   educational) → 156 (eating cadence) → 157 (eating window) →
        //   159 (prior one-thing-worked).
        //
        // v3 C6 (2026-06-10) — cut 169 (cuisine multi-select). The
        // cuisine signal is only consumed by FoodSettings + the food
        // vision prompt; collect it in-app post-paywall instead of
        // adding the friction screen here. Per the Cal AI + BetterMe
        // teardown synthesis.
        // v4.6 (2026-06-11) — 169 (cuisine photo grid) revived from the
        // v3 C6 cut; the cuisine signal feeds the in-app calorie-vision
        // prompt and the cohort eats across cuisines.
        162, 166, 156, 157, 159, 169,
        //
        // Act 2 — Workout/activity (demoted, post-food-wedge).
        // v3 C2 (2026-06-10) — cut 270 (habit-window quiz). The
        // educational quiz read 0 downstream consumers (`habitQuizSelected`
        // is set but never read); no signal value, only friction.
        8,
        // v3 P11.1.B bridge #1 — "now the numbers" pause before Ch3
        // biometric cluster. BetterMe A3 pacing variance.
        280,
        // Act 3 — Biometric core. D83 cut 202 (section divider).
        // v9 P9.8/P9.9 (founder QA 2026-06-10): CUT 134 + 135 (body-
        // image slider screens with AI-rendered women in athleisure)
        // — off-brand for the her75 register. The conversion-load-
        // bearing commitment moment is now case 136 (NSV outcome
        // cards), positioned in the same slot. Both her75 designer
        // and the Gen-Z conversion expert independently specced this
        // replacement pattern.
        130, 7, 131, 132, 1320, 133, 286, 136,
        160, 161,
        // Delta v8 D73 — pace selector (case 167).
        167,
        // Act 4 — Vulnerability + cohort signal. D83 cut 235
        // (month-signals — hormonal stage 163 captures the same
        // cycle-awareness signal at lower vulnerability cost).
        //
        // v3 C4 (2026-06-10) — cut 142 (comparison frame). Off-brand
        // "you vs them" copy; replaced by the cohort-credibility slot
        // in P11.1.B (BetterMe A5 pattern, real cohort framing not
        // adversarial comparison).
        140, 158, 154, 155, 163, 164, 1641,
        // v3 P11.1.B reciprocity beat (case 282, Cal AI A7) — dedicated
        // screen acknowledging the vulnerable disclosures. Goes BEFORE
        // the bridge #2 + psychometric fears so the trust compound
        // lands while the disclosure is still fresh.
        282,
        // v3 P11.1.B (2026-06-10) — BetterMe S2 psychometric Yes/No
        // fears. 3 fear-coded first-person statements (Bem 1972
        // self-perception). Slot between vulnerability cluster and
        // tier ladder so the user has already invested ~40 screens
        // and the fears land as recognition, not extraction.
        171, 172, 173,
        // v3 cuts (2026-06-10) — C1: 165 (commitConfidence, fully
        // dead — written, never read). C5: 145 (video demo, defer
        // A/B v1.5). C3: 170 (re-prediction, redundant with 161
        // first prediction — same numbers, same chrome).
        260,
        // Act 5 — Reveal + commit. D83 cut 204 (section divider).
        // Delta v8 D82 final tail: reveal → sign-in → rating → finish.
        // Cut: 240 (brandPromises — reads 2018 startup register),
        // 22 (personalStat — duplicates the projection card from the
        // reveal).
        //
        // Case 215 (rating prompt) RESTORED 2026-06-06 per founder
        // feedback. The loader sentiment overlay's "love ♥" tap fires
        // SKStoreReviewController as a side effect but doesn't read as
        // "asking about rating" — that's a 3-way sentiment chip. Case
        // 215 is the explicit "love your plan?" ask. Apple's
        // 3-prompts-per-365-days throttle on SKStoreReviewController
        // prevents users from seeing the rating modal twice in the
        // same onboarding (loader "love" path OR case 215, never both).
        // Position: post-sign-in, pre-final — fires while she's still
        // on the post-reveal + post-commit high.
        // v4.5 (2026-06-11): 153 (barrier multi) cut — duplicated the
        // 171/172/173 fear psychometrics; relatability derives from those.
        206,
        // v9 P9.8 — case 19 (coach selector) cut per founder QA
        // 2026-06-10. Default to Jeni until Kira + Sam are app-wide
        // production-ready; conversion expert confirmed LOW risk
        // (coach pickers are retention levers, not trial-start
        // levers). Discoverability moves to Settings > "your coach"
        // post-paywall.
        205, 3, 11, 18,
        // v3 P11.1.C (2026-06-10) — 2-checkbox consent (BetterMe A6).
        // Final commit beat before the plateau teach + plan reveal.
        284,
        // v3 P11.1.C (2026-06-10) — Apple Health relocate (Cal AI S5).
        // HK ask lands here (mid-onboarding) so the projection can cite
        // real steps. PairedPermissionsAsk in OnboardingRevealView is
        // now notifications-only.
        285,
        234, 21, 250, 26, 215, 23,
    ]

    // v3 dead-code rip (2026-06-10) — collapsed from a conditional
    // v1/v2 picker to a single source. v2 is the only flow.
    private var flowOrder: [Int] { Self.v2FlowOrder }

    // ── v3 chapter IA (2026-06-10, BetterMe S3 pattern) ─────────────
    //
    // 5-chapter map. Surfaces a tiny lowercase eyebrow above the
    // progress bar so each new chapter is felt as a sub-goal
    // (Kivetz et al. 2006 goal-gradient). Post-reveal cases
    // (250, 26, 215, 23) are intentionally absent — "almost there"
    // stops being accurate the moment the plan has been shown.
    private static let chapterMap: [Int: Int] = [
        // 1 — about you
        200: 1, 230: 1, 1: 1, 100: 1, 168: 1, 283: 1,  // cohort credibility (P11.1.B)
        // 2 — your *rhythm*
        162: 2, 166: 2, 156: 2, 157: 2, 159: 2, 169: 2,
        8: 2,
        // 3 — what *fits*
        280: 3,  // bridge "now the numbers" (P11.1.B)
        130: 3, 7: 3, 131: 3, 132: 3, 133: 3, 286: 3, 136: 3,
        160: 3, 161: 3, 167: 3,
        // 4 — your *why*
        140: 4, 158: 4, 154: 4, 155: 4, 163: 4, 164: 4,
        282: 4,  // reciprocity beat after vulnerability cluster (P11.1.B)
        171: 4, 172: 4, 173: 4,  // psychometric Yes/No fears (P11.1.B)
        260: 4, 206: 4,
        // 5 — *almost there*  (BetterMe S4 — sunk-cost amplifier on
        // the highest-friction screens, pre-reveal only)
        205: 5, 3: 5, 11: 5, 18: 5, 284: 5, 285: 5, 234: 5, 21: 5,
    ]

    private var currentChapter: Int { Self.chapterMap[screen] ?? 0 }

    /// Returns (base lowercase text, italic punch word).
    /// Chapter 1 has no italic word; later chapters always italicize
    /// the punch word per the locked her75 typography rule.
    fileprivate static func chapterEyebrowParts(_ idx: Int) -> (base: String, italic: String)? {
        switch idx {
        case 1: return ("about you", "")
        case 2: return ("your rhythm", "rhythm")
        case 3: return ("what fits", "fits")
        case 4: return ("your why", "why")
        case 5: return ("almost there", "almost there")
        default: return nil
        }
    }

    // Highest flowOrder position the user has reached so far. Updated
    // monotonically in `go(_:)` — back-nav decreases `screen` but
    // never decreases `maxProgressPos`, so the progress bar holds its
    // farthest mark instead of retreating. User feedback 2026-06-01:
    // bar going up + down on back-nav reads as "did i lose progress?"
    // and undermines the goal-gradient effect (Hull 1932, Kivetz).
    @State private var maxProgressPos: Int = 0

    private var progressFraction: CGFloat {
        let denom = max(flowOrder.count, 1)
        return CGFloat(maxProgressPos + 1) / CGFloat(denom)
    }

    private var navBar: some View {
        // her75 Phase 2 §3 (2026-06-10) — NAV REGION PINNED AT EXACTLY
        // 56pt ALWAYS. The founder's "progress bar shifts" complaint
        // traced to 4 causes the audit identified:
        //   1. the eyebrow's if-let inserted/removed 22pt of height
        //      when the chapter label appeared/disappeared
        //   2. variable hero heights changed the bar-to-content gap
        //   3. ScrollView-vs-not mismatches changed visual top inset
        //   4. the whole navBar animated on chapter change
        // Fix 1 + 4 live here: the eyebrow gets a FIXED 10pt ZStack
        // slot (renders empty when no chapter), and only the eyebrow
        // CONTENT fades — the bar row never moves and never animates.
        // Fixes 2 + 3 land in the archetype templates.
        VStack(spacing: 6) {
            // Fixed 10pt eyebrow slot — present on every screen,
            // content-only fades.
            ZStack {
                if let parts = Self.chapterEyebrowParts(currentChapter) {
                    ItalicAccentText(
                        parts.base,
                        italic: parts.italic.isEmpty ? [] : [parts.italic],
                        baseFont: Typo.eyebrow,
                        italicFont: Font.custom("Fraunces72pt-SemiBoldItalic", size: 12, relativeTo: .caption2),
                        color: Palette.textSecondary,
                        alignment: .center
                    )
                    .transition(.opacity)
                    .id(currentChapter)
                }
            }
            .frame(height: 10)
            .frame(maxWidth: .infinity)
            .animation(Motion.crossFade, value: currentChapter)

            HStack(spacing: Space.sm) {
                Button { Haptics.light(); goBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.cocoaPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Palette.programCard)
                                .overlay(Circle().stroke(Palette.hairlineCocoa, lineWidth: 1))
                        )
                }
                .accessibilityLabel("Back")

                // her75 hairline — 2pt, near-invisible track.
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Palette.cocoaPrimary.opacity(0.08))
                            .frame(height: 2)
                        Capsule()
                            .fill(Palette.cocoaPrimary)
                            .frame(width: max(4, geo.size.width * progressFraction), height: 2)
                            .animation(Motion.entrance, value: screen)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 40)

                // Invisible 40pt spacer balances the back chip so the
                // capsule is mathematically centered.
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .frame(height: 56)  // 10 eyebrow + 6 gap + 40 bar — LOCKED
        .padding(.horizontal, Space.screenPadding)
        .padding(.top, Space.sm)
    }

    // ═══════════════════════════════════════
    // MARK: - WELCOME (Phase 15b)
    // ═══════════════════════════════════════
    //
    // Marketing-site layout: top-bar wordmark, leading-aligned editorial
    // headline + subhead, hero.mp4 inside a pink-mat rounded frame,
    // cocoa pill CTA, and a sticker scatter behind the content. The
    // entrance choreographs eyebrow → headline → subhead → video → CTA
    // as five sequential beats; stickers cascade in from t=0 via
    // Phase 14b's per-Sticker entrance animation.

    @State private var welcomeAppeared = false
    @State private var welcomeEyebrowVisible = false
    @State private var welcomeHeadlineVisible = false
    @State private var welcomeSubheadVisible = false
    @State private var welcomeVideoVisible = false
    @State private var welcomeCtaVisible = false
    // v2 welcome ("The Curator", 2026-06-01) — separate state so v1 and
    // v2 reveals don't interfere if the flag flips mid-session.
    // v2BowVisible drives the photo hero fade-in (variable name kept
    // for state-reuse simplicity after the 2026-06-01 rebuild removed
    // the bow in favor of the photo composition).
    @State private var v2BowVisible = false
    @State private var v2HeadlineVisible = false
    @State private var v2CtaVisible = false

    // 8 stickers placed in margins only — never on the leading-aligned
    // text column (x≤0.6) or the centered video block (y=0.30–0.70 of
    // the hero band, x=0.06–0.94 of screen with 24pt h-padding).
    // Mix is 2 line-art / 6 painterly per the sticker style spec.
    // phaseDelay values are unique 0.0…1.0 so each sticker has a
    // distinct idle drift period.
    private static let welcomePlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.92, y: 0.06),
                         size: 30, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.85, y: 0.11),
                         size: 30, rotation: -10, phaseDelay: 0.13),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.94, y: 0.26),
                         size: 36, rotation: 14, phaseDelay: 0.27),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.06, y: 0.74),
                         size: 28, rotation: -8, phaseDelay: 0.40),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.93, y: 0.74),
                         size: 36, rotation: 11, phaseDelay: 0.53),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.08, y: 0.93),
                         size: 32, rotation: 9, phaseDelay: 0.66),
        StickerPlacement(sticker: .teddyPink,
                         position: CGPoint(x: 0.92, y: 0.94),
                         size: 38, rotation: -11, phaseDelay: 0.80),
        StickerPlacement(sticker: .strawberry,
                         position: CGPoint(x: 0.78, y: 0.95),
                         size: 28, rotation: 13, phaseDelay: 0.93),
    ]

    // MARK: - Phase 16 sticker presets
    //
    // Per-screen scatter placements for the surfaces that earn stickers:
    // section dividers, identity question, two prediction screens, and
    // the plan reveal. Each preset uses unique phaseDelay values
    // 0.0…1.0 so the cluster idles in desync. Mix of line-art and
    // painterly varies by emotional weight per the sticker style spec.

    /// HIGH treatment — 6 stickers, balanced 2 line-art / 4 painterly,
    /// shared across all 6 onboarding section dividers (case 200…205).
    private static let sectionDividerPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.10, y: 0.18),
                         size: 32, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.88, y: 0.16),
                         size: 38, rotation: 12, phaseDelay: 0.15),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.08, y: 0.50),
                         size: 32, rotation: 9, phaseDelay: 0.30),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.92, y: 0.52),
                         size: 36, rotation: -11, phaseDelay: 0.45),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.12, y: 0.86),
                         size: 28, rotation: 14, phaseDelay: 0.65),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.90, y: 0.84),
                         size: 38, rotation: -8, phaseDelay: 0.85),
    ]

    /// LIGHT treatment — 4 small stickers for the plank baseline
    /// question (case 3). The "starting line" moment — sticker mix
    /// evokes athletic + capability themes (ribbon, star, sparkle).
    /// Right-edge column avoids overlap with the option list which
    /// fills most of the screen below the header.
    private static let baselinePlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .ribbonLineart,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 28, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.08, y: 0.10),
                         size: 26, rotation: -10, phaseDelay: 0.25),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.94, y: 0.32),
                         size: 28, rotation: -8, phaseDelay: 0.50),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.06, y: 0.92),
                         size: 28, rotation: 10, phaseDelay: 0.78),
    ]

    /// LIGHT treatment — 3 small stickers for the identity question
    /// (case 140), the emotional wedge moment.
    private static let identityPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.10),
                         size: 26, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.94, y: 0.42),
                         size: 28, rotation: -8, phaseDelay: 0.40),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.08, y: 0.92),
                         size: 24, rotation: -10, phaseDelay: 0.75),
    ]

    /// LIGHT treatment — first prediction (case 161). Moment of revelation
    /// around the weight curve callout.
    private static let firstPredictionPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 26, rotation: 13, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.06, y: 0.45),
                         size: 28, rotation: -10, phaseDelay: 0.40),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.92, y: 0.92),
                         size: 28, rotation: 9, phaseDelay: 0.80),
    ]

    /// LIGHT treatment — final prediction with calendar (case 181).
    /// Pre-commitment moment.
    private static let finalPredictionPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.08),
                         size: 26, rotation: 10, phaseDelay: 0.00),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.94, y: 0.50),
                         size: 30, rotation: -12, phaseDelay: 0.40),
        StickerPlacement(sticker: .strawberry,
                         position: CGPoint(x: 0.08, y: 0.94),
                         size: 28, rotation: 13, phaseDelay: 0.80),
    ]

    /// HIGH treatment — plan reveal (case 21). Celebratory hand-off.
    /// 7 stickers, weight to painterly (1 line-art + 6 painterly).
    private static let planRevealPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.06),
                         size: 30, rotation: -12, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 32, rotation: 13, phaseDelay: 0.13),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.06, y: 0.22),
                         size: 36, rotation: -10, phaseDelay: 0.27),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.94, y: 0.24),
                         size: 36, rotation: 14, phaseDelay: 0.42),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.94, y: 0.50),
                         size: 38, rotation: -11, phaseDelay: 0.58),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.08, y: 0.92),
                         size: 32, rotation: 9, phaseDelay: 0.74),
        StickerPlacement(sticker: .teddyPink,
                         position: CGPoint(x: 0.92, y: 0.94),
                         size: 38, rotation: -11, phaseDelay: 0.90),
    ]

    // v3 dead-code rip (2026-06-10) — v1Welcome branch removed.
    // Every install since v1.0.6 (2026-06-03) lands on v2Welcome.
    private var welcome: some View { v2Welcome }

    // v3 dead-code rip (2026-06-10) — v1Welcome view body removed
    // (~78 lines). Was the pre-2026-06-01 first-screen layout (eyebrow
    // + headline + subhead + plank video + CTA). Replaced by v2Welcome
    // ("The Curator" rebuild) which is the only welcome path now.
    // Helpers `welcomeTopBar` + `welcomePlacements` survive because
    // v2Welcome uses them; the v1-only `welcomeEyebrow` /
    // `welcomeHeadline` / `welcomeSubhead` / `welcomeVideoBlock` /
    // `welcomeCTA` + their `welcome*Visible` @State vars +
    // `runWelcomeChoreography` are now orphans pending a deeper sweep.

    // MARK: - v2 Welcome — "The Curator" (rebuild 2026-06-01)
    //
    // The 2026-06-01 first pass over-rotated on Cereal/Aesop minimalism
    // and stripped the brand chrome (sticker scatter, pink-mat hero,
    // cocoa pill CTA, wordmark) that actually carries JeniFit's premium
    // read. Founder reaction: "the new screen looks so much uglier
    // compared to the old screen." Lesson saved at memory
    // feedback_visual_richness_over_restraint: research recommendations
    // toward restraint apply to *copy + typography*, not to wholesale
    // visual density.
    //
    // This rebuild keeps v1's full chrome — wordmark, sticker scatter,
    // pink-mat hero frame, cocoa pill CTA, "free to begin" reassurance,
    // sign-in link — and changes only two things:
    //   1. Replace the hero.mp4 video with a side-by-side composition
    //      of two real creator photos (1M-view TikTok content). NO
    //      before/after labels; the eye reads the pair, never told.
    //   2. Replace the v1 peer-confession copy ("i've started over
    //      so many times") with D1 program-positioning copy ("finally,
    //      a program for the woman who's tried everything.").
    //
    // Side-by-side photo composition with soft cross-fade ensures the
    // App Store reviewer cannot flag the screen as a "transformation
    // claim" — there are no labels, no timeline, no outcome promise.
    // The funnel-continuity benefit (TikTok ad → CPP → app screen 1
    // showing the same creators) is the lever that the prior strategy
    // memory pushed to App Store CPP only; the founder is rolling that
    // decision back based on 1M-view performance data.
    // v4.6 welcome ("the demo", 2026-06-11) — her75 device-frame
    // pattern per founder direction: the hero is a framed phone
    // showing what the app actually does (the daily plan), built as
    // a live SwiftUI mock so it never drifts from the real product.
    // Creator photos move out of screen 1; cohort headline stays.
    private var v2Welcome: some View {
        GeometryReader { geo in
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()

                StickerScatter(placements: Self.welcomePlacements)

                VStack(spacing: 0) {
                    welcomeTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Spacer().frame(height: 12)

                    welcomeDemoFrame(height: max(330, min(480, geo.size.height * 0.52)))
                        .opacity(v2BowVisible ? 1 : 0)
                        .scaleEffect(v2BowVisible ? 1.0 : 0.96)

                    Spacer().frame(height: 16)

                    v2WelcomeHeadline
                        .padding(.horizontal, 24)
                        .opacity(v2HeadlineVisible ? 1 : 0)
                        .offset(y: v2HeadlineVisible ? 0 : 12)

                    Spacer(minLength: 12)

                    welcomeCTA
                        .padding(.horizontal, 24)
                        .opacity(v2CtaVisible ? 1 : 0)
                        .scaleEffect(v2CtaVisible ? 1.0 : 0.96)

                    Text("free to start.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 8)
                        .opacity(v2CtaVisible ? 1 : 0)

                    Button {
                        Haptics.light()
                        showWelcomeSignInSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("already have an account?")
                            Text("sign in").underline()
                        }
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .opacity(v2CtaVisible ? 1 : 0)
                }
            }
            .task { await runV2WelcomeChoreography() }
        }
    }

    // Round-4 headline (founder: plainer words; expert decided). In the
    // 3-second TikTok arrival she needs category confirmation ("this is
    // the weight-loss app from the video") before identity copy; the
    // phone mock supplies the proof, the headline labels the category.
    // A/B runner-up on file: "your daily to-do for losing weight".
    private var v2WelcomeHeadline: some View {
        ItalicAccentText(
            "your weight-loss plan, made simple.",
            italic: ["simple"],
            baseFont: Typo.heroHeadline,
            italicFont: Typo.heroHeadlineItalic,
            alignment: .center
        )
        .kerning(-0.4)
        .lineSpacing(Typo.heroHeadlineLineGap)
        .frame(maxWidth: .infinity, alignment: .center)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// her75 device-frame demo. A phone-shaped frame cycling through
    /// three live SwiftUI mocks of the product: the daily plan, the
    /// food-snap camera, and the steps counter. Crossfades every 2.6s
    /// (Cal AI welcome-video pattern, done in code so it never drifts
    /// from the shipped product). Reduce-motion holds the plan page.
    private func welcomeDemoFrame(height: CGFloat) -> some View {
        // Realistic iPhone proportions (founder QA round 4: the uniform
        // 5pt stroke read as a toy frame). Thin near-black bezel ring,
        // screen inset 6pt, Dynamic Island pill floating INSIDE the
        // screen, side-button nubs, soft drop shadow.
        let width = height * 0.482
        let outerRadius = height * 0.118

        return ZStack {
            // Body — near-black slab with a subtle edge highlight.
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .fill(Color(red: 0.13, green: 0.11, blue: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )

            // Screen — 4pt bezel ring reads true-to-device.
            ZStack {
                RoundedRectangle(cornerRadius: outerRadius - 4, style: .continuous)
                    .fill(Palette.bgPrimary)

                Group {
                    switch welcomeDemoPage {
                    case 1: welcomeDemoCamera
                    case 2: welcomeDemoSteps
                    default: welcomeDemoPlan
                    }
                }
                .transition(.opacity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, 24)
            }
            .clipShape(RoundedRectangle(cornerRadius: outerRadius - 4, style: .continuous))
            .padding(4)

            // Dynamic Island — floats inside the screen.
            VStack {
                Capsule()
                    .fill(Color.black)
                    .frame(width: width * 0.30, height: 14)
                    .padding(.top, 13)
                Spacer()
            }
        }
        .frame(width: width, height: height)
        // Side buttons — thin nubs hugging the edges.
        .overlay(alignment: .topLeading) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                    .frame(width: 2.5, height: height * 0.045)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                    .frame(width: 2.5, height: height * 0.085)
            }
            .offset(x: -2.5, y: height * 0.20)
        }
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.08))
                .frame(width: 2.5, height: height * 0.12)
                .offset(x: 2.5, y: height * 0.24)
        }
        .shadow(color: .black.opacity(0.16), radius: 22, y: 12)
        .accessibilityLabel("a preview of jenifit: your daily plan, the food camera, and steps")
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { break }
                withAnimation(Motion.crossFade) {
                    welcomeDemoPage = (welcomeDemoPage + 1) % 3
                }
            }
        }
    }

    private var welcomeDemoPlan: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("day 1")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.white, in: Capsule())
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                Spacer()
                Image("onb-profile-latte")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 26, height: 26)
                    .background(Palette.accentSubtle)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            }
            .padding(.top, 16)

            // her75 tally strip — day progress marks.
            HStack(spacing: 5) {
                ForEach(0..<14, id: \.self) { i in
                    Capsule()
                        .fill(i == 0 ? Palette.bgInverse : Palette.accentSubtle)
                        .frame(width: 3, height: i == 0 ? 14 : 10)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            welcomeDemoRow(thumb: "onb-itgirl-firstweek",
                           title: "move", sub: "10 min", done: true)
            welcomeDemoRow(thumb: "onb-itgirl-preeat",
                           title: "snap a meal", sub: "before you eat", done: false)
            welcomeDemoStepsRow
            welcomeDemoRow(thumb: "onb-itgirl-journal",
                           title: "the method", sub: "2-min read", done: false)

            Spacer(minLength: 0)
        }
    }

    /// Food-snap camera mock: warm viewfinder with a meal centered,
    /// scan brackets, verdict chip, camera control row.
    private var welcomeDemoCamera: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 20)
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.cocoaPrimary.opacity(0.88),
                                     Palette.cocoaPrimary.opacity(0.60)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                Image("onb-cuisine-mediterranean")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                WelcomeScanBrackets()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                    .padding(13)

                // Verdict chip pinned over the plate — the pre-eat
                // promise in one glance.
                VStack {
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.stateGood)
                        Text("fits today")
                            .font(.custom("DMSans-SemiBold", size: 10.5))
                            .foregroundStyle(Palette.textPrimary)
                        Text("· 540 cal")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white, in: Capsule())
                    .padding(.bottom, 10)
                }
            }
            .frame(maxHeight: .infinity)

            Text("snap before you eat")
                .font(.custom("DMSans-SemiBold", size: 11))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white, in: Capsule())

            // Camera control row — gallery / shutter / flash.
            HStack(spacing: 22) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                Circle()
                    .stroke(Palette.bgInverse, lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().fill(Palette.bgInverse).frame(width: 26, height: 26))
                Image(systemName: "bolt.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.bottom, 2)
        }
    }

    /// Steps mock: hero ring + a week of mini bars underneath.
    private var welcomeDemoSteps: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Palette.accentSubtle, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: 0.62)
                    .stroke(Palette.accent,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("4,680")
                        .font(.custom("Fraunces72pt-SemiBold", size: 26))
                        .foregroundStyle(Palette.textPrimary)
                    Text("of 7,500 steps")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(width: 118, height: 118)

            // The week so far — quiet little bar strip sells "this is
            // a real tracker", not a mockup.
            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach(Array([0.55, 0.8, 0.45, 0.95, 0.7, 0.3, 0.62].enumerated()), id: \.offset) { i, h in
                        Capsule()
                            .fill(i == 6 ? Palette.accent : Palette.accentSubtle)
                            .frame(width: 9, height: 12 + 26 * h)
                    }
                }
                HStack(spacing: 7) {
                    ForEach(["m", "t", "w", "t", "f", "s", "s"].indices, id: \.self) { i in
                        Text(["m", "t", "w", "t", "f", "s", "s"][i])
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(i == 6 ? Palette.textPrimary : Palette.textSecondary)
                            .frame(width: 9)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)

            Text("the everyday anchor")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
    }

    private func welcomeDemoRow(thumb: String, title: String, sub: String, done: Bool) -> some View {
        HStack(spacing: 9) {
            Image(thumb)
                .resizable()
                .scaledToFill()
                .frame(width: 38, height: 38)
                .background(Palette.accentSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 2)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.bgInverse)
            } else {
                Circle()
                    .stroke(Palette.divider, lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(8)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }

    private var welcomeDemoStepsRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("7,500 steps")
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("4,680")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.accentSubtle)
                    Capsule().fill(Palette.accent)
                        .frame(width: g.size.width * 0.62)
                }
            }
            .frame(height: 5)
        }
        .padding(10)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }

    @MainActor
    private func runV2WelcomeChoreography() async {
        guard !welcomeAppeared else { return }
        welcomeAppeared = true

        // Clear single-select fields so no option lands pre-highlighted
        // when the user reaches each question. Each AppStorage value
        // persists across launches by design (so a mid-flow quit can
        // resume), but on a fresh-from-welcome start we want every
        // question to read as "you choose" — not "this is your prior
        // answer." Re-onboarding (account delete) + dev testing both
        // benefit, and a true first-install user is a no-op since the
        // values were already empty.
        resetSingleSelectOnboardingFields()

        Analytics.track(.onboardingStart)
        Analytics.track(.onboardingStepViewed, properties: stepProperties(stepId: 0))

        // v4.6 reveal order: demo frame lands first (the product is
        // the hook), then the headline, then the CTA.
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(Motion.entrance) { v2BowVisible = true }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(Motion.entranceSoft) { v2HeadlineVisible = true }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            v2CtaVisible = true
        }
    }

    // Inline sub-views factored out so the body stays readable and the
    // layout edits don't have to navigate one giant view tree.

    private var welcomeTopBar: some View {
        // Smaller variant of JeniFitWordmark for the top bar — the
        // canonical component is hard-coded to Typo.title (32pt) and
        // we want 22pt here. Phase 17 swaps this for the logo PNG.
        let base = Font.custom("Fraunces72pt-SemiBold", size: 22)
        let separator = Font(UIFont(name: "Fraunces72pt-Light", size: 18)
                             ?? .systemFont(ofSize: 18))
        return HStack {
            (Text("jeni").font(base)
             + Text("\u{2009}•\u{2009}").font(separator)
             + Text("fit").font(base))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
    }

    private var welcomeEyebrow: some View {
        HStack {
            // v2 — peer voice / confession register. Frame is
            // "i've been where you are" instead of "i made this for
            // you." Per user feedback: the best sales come from the
            // audience's perspective, not the founder's pitch.
            Text("if you've tried everything")
                .font(Typo.eyebrow)
                .tracking(2)
                .foregroundStyle(Palette.accent)
            Spacer(minLength: 0)
        }
    }

    private var welcomeHeadline: some View {
        // v2 peer-confession headline. Italic accent across "so many
        // times" — 3 words, ItalicAccentText handles word-by-word.
        // Reads as a friend's text, not a brand promise. Acknowledges
        // user's prior failures BEFORE pitching anything (the move
        // that converts on TikTok-acquired audiences who are
        // skeptical of clean founder hero stories).
        ItalicAccentText(
            "i've started over so many times.",
            italic: ["so", "many", "times."],
            baseFont: .custom("Fraunces72pt-SemiBold", size: 34),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 34),
            alignment: .leading
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var welcomeSubhead: some View {
        // v3 subhead — drops the "pilates is the answer" certainty. New
        // frame: "i'll share what i learned, you answer a few questions
        // so we can build this around you." Reads as collaborative
        // setup rather than a product claim — and earns the right to
        // ask the next 50 onboarding questions by naming what they're
        // for upfront.
        (Text("i'll share everything i learned. answer a few questions so we can build this around ")
            + Text("you").font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
            + Text("."))
            .font(Typo.body)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Pink mat (Palette.accentSubtle) framing a clipped video player.
    /// Outer rounded rect at 20pt, inner video clipped to 12pt with a
    /// 12pt inset — the inset is the visible mat band that frames the
    /// video like a photo border.
    private func welcomeVideoBlock(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Palette.accentSubtle)

            VideoHero(videoName: "hero", videoExtension: "mp4")
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(12)
        }
        .frame(height: height)
    }

    private var welcomeCTA: some View {
        Button {
            Haptics.light()
            go(200) // Part 1 divider
        } label: {
            // Lowercase "continue" replaces "Get started". Research:
            // brand-coined verbs ("start becoming," "begin your journey")
            // read inauthentic to TikTok-acquired women aged 22–35
            // (Drake & Salinas 2024 on femvertising authenticity). Plain
            // "continue" wins on trust signal without losing momentum.
            Text("continue")
                .font(.custom("DMSans-SemiBold", size: 16))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Palette.textPrimary)
                .clipShape(Capsule())
        }
    }

    @MainActor
    private func runWelcomeChoreography() async {
        guard !welcomeAppeared else { return }
        welcomeAppeared = true

        // Same clean-slate reset as the v2 welcome — see comments there.
        resetSingleSelectOnboardingFields()

        // Funnel start — the first event in every onboarding session.
        // welcomeAppeared guard ensures we don't double-fire on SwiftUI
        // remounts; AnalyticsManager additionally coalesces dupes.
        Analytics.track(.onboardingStart)
        Analytics.track(.onboardingStepViewed, properties: stepProperties(stepId: 0))

        // Phase 20d: welcome reveal swells through Motion.entranceSoft
        // (0.42s) so each line lands with a calm beat instead of a snap.
        // Video gets the longer Motion.entrance (0.55s) to acknowledge
        // its visual weight — landing too fast reads as a flicker.
        try? await Task.sleep(nanoseconds: 100_000_000)
        withAnimation(Motion.entranceSoft) { welcomeEyebrowVisible = true }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(Motion.entranceSoft) { welcomeHeadlineVisible = true }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(Motion.entranceSoft) { welcomeSubheadVisible = true }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(Motion.entrance) { welcomeVideoVisible = true }
        // Confetti burst — fires once the headline+subhead+video are
        // settled, paired with a success haptic. The global ZStack
        // already mounts ConfettiView when showConfetti flips true.
        // 2.5s matches the ConfettiView fall animation; flipping back
        // to false unmounts the view so it doesn't linger off-screen.
        Haptics.success()
        showConfetti = true
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            showConfetti = false
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { welcomeCtaVisible = true }
    }

    // ═══════════════════════════════════════
    // MARK: - JeniFit question helpers (Phase 4)
    // ═══════════════════════════════════════
    //
    // jfQuestion / jfMulti / jfSliderScreen / jfBodyTypeScreen / jfYesNo
    // are the new canonical question builders. They share a single header
    // (eyebrow-less title + sub) and route through advanceWithConfirmation
    // so the optional ConfirmationBadge moment fires uniformly.
    //
    // The legacy questionView / multiView below them stays in place for
    // the old showcase screens (chartScreen, celebrationScreen, etc.)
    // that Phase 5 will eventually rebuild.

    /// her75 Phase 3 — Archetype A hero region (audit §2).
    ///
    /// FIXED 150pt hero block, top-leading aligned. The hero starts at
    /// the same Y on every question screen and the options region below
    /// starts at the same Y regardless of whether the headline wraps
    /// 1, 2, or 3 lines — the wrap happens INSIDE the fixed block.
    /// This is the structural half of the "progress bar never moves"
    /// fix (the nav region pin in Phase 1 was the other half).
    ///
    /// (Audit specced 200pt; tuned to 150pt at implementation — at the
    /// 38pt re-ladder a 3-line hero measures ~130pt, and 200pt left a
    /// dead band above the options on 1-line heroes. 150 = 3-line
    /// capacity + breathing room.)
    ///
    /// `italic:` takes the punch CHUNK (1-3 word semantic unit per the
    /// audit §5 decision tree — possessive phrase, NP, PP, or deictic
    /// pronoun). Composed via ItalicAccentText, never `*markers*`.
    ///
    /// `sub:` is retained for the rare affordance line but renders
    /// INSIDE the fixed region. Default nil per
    /// [[feedback-her75-editorial-register]].
    private func jfHeader(_ title: String, sub: String? = nil, italic: [String] = []) -> some View {
        JFHeader(title: title, sub: sub, italic: italic)
    }

    /// Question-screen header with the her75 SOFT-IN reveal: the headline
    /// fades + rises in with ONE soft haptic on settle — the signature
    /// "luxurious, not spammy" reveal applied to every question screen
    /// (statement screens get the fuller line-by-line LineCascadeText).
    /// Reduce-motion snaps + skips the haptic. Recreated per screen via
    /// the switch's `.id(screen)`, so the reveal fires on each arrival.
    private struct JFHeader: View {
        let title: String
        var sub: String? = nil
        var italic: [String] = []
        @State private var appeared = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(alignment: .leading, spacing: Space.xs) {
                ItalicAccentText(
                    title,
                    italic: italic,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .fixedSize(horizontal: false, vertical: true)
                // Motion-quality (v1.1): JFPageTransition (pure opacity) is the
                // SINGLE fade source on arrival. The header + rows used to ALSO
                // fade opacity here, triple-stacking the ramp into a muddy
                // entrance. Offset-only now — the page fades, the header rises,
                // and the one soft haptic still lands on settle.
                .offset(y: appeared ? 0 : 7)
                if let sub {
                    Text(sub)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .offset(y: appeared ? 0 : 7)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 150, alignment: .topLeading)
            .padding(.horizontal, Space.screenPadding)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                withAnimation(Motion.entranceSoft) { appeared = true }
                // One soft tap as the headline settles — the luxurious
                // punctuation, never per-line spam on question screens.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    Haptics.soft()
                }
            }
        }
    }

    /// v4 R1 — the CTA dock. Apply via `.safeAreaInset(edge: .bottom)`
    /// on a screen's root stack so the button renders at the same
    /// pixel Y on every screen; content can mathematically never push
    /// it (the founder's "progress bar and button on the same position
    /// throughout" demand, docs/onboarding_v4_rebuild_plan §A). Paints
    /// the canvas color behind the button so internally-scrolled
    /// content slides under, never through.
    private func jfCTADock<Button: View>(@ViewBuilder _ button: () -> Button) -> some View {
        button()
            .padding(.top, Space.xs)
            .background(Palette.programBgPrimary)
    }

    private func advance(to next: Int, confirmation: String?) {
        let target = resolveNext(hint: next)
        Haptics.medium()
        if let msg = confirmation {
            pendingConfirmation = msg
            withAnimation(Motion.gentleSpring) {
                showConfirmation = true
            }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(Motion.exit) { showConfirmation = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    pendingConfirmation = nil
                    go(target)
                }
            }
        } else {
            go(target)
        }
    }

    /// Translates a hardcoded `next:` hint into the actual next screen
    /// for the active flowOrder. v1 hits every screen, so the hint is
    /// always a valid target. v2 drops 7 dead-signal screens (120, 121,
    /// 141, 236, 237, 238, 239) and consolidates 150/151/152 → 153;
    /// when a case's `next:` points to one of those dropped screens,
    /// we walk forward from the current screen's flowOrder position
    /// instead. Falls back to the original hint when nothing matches
    /// (defensive; shouldn't fire in practice).
    private func resolveNext(hint: Int) -> Int {
        if flowOrder.contains(hint) { return hint }
        if let pos = flowOrder.firstIndex(of: screen), pos + 1 < flowOrder.count {
            return flowOrder[pos + 1]
        }
        return hint
    }

    private func jfQuestion(
        _ title: String, sub: String? = nil,
        // her75 Phase 3 — italic punch chunk, threaded to jfHeader.
        italic: [String] = [],
        opts: [(String, String, String?, String?)],
        sel: Binding<String>,
        next: Int,
        confirmation: String? = nil,
        // 17b-3: opt-in inline feedback. When the selected key matches an
        // entry, an inline card renders under the option list before the
        // CTA. Use sparingly — these are for moments where the answer
        // unlocks a meaningful aside, not a generic "got it" on every
        // question (we have ConfirmationBadge for the post-advance toast).
        inlineFeedback: [String: (String, String)]? = nil,
        // 17d-1: per-option sticker overrides. When a key is in this map,
        // OnboardingOptionCard renders the sticker in place of the SF
        // Symbol. Use for screens where each option earns a JeniFit
        // visual handle (Q140 identity, Q141 reward). Nil = SF Symbol
        // for everything (default behavior).
        stickers: [String: StickerName]? = nil,
        // v2-A2: optional inline trust anchor (citation chip + "we ask
        // because..." line) for credibility-grade sensitive questions
        // — sleep, stress, eating, hormonal stage, GLP-1. Sits between
        // header and option list. Quiet by design; one chip per screen,
        // max. Pass nil for non-sensitive questions.
        trustAnchor: WeAskBecauseRow? = nil,
        // v4.5 her75 micro-delight — unselected rows strike through +
        // dim once a pick exists (her75 attribution screen pattern).
        // Reserve for short factual lists (attribution, sunk-cost);
        // emotional questions keep every option visually live.
        strikeUnselected: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub, italic: italic)

            if let trustAnchor {
                Spacer().frame(height: Space.sm)
                trustAnchor
            }

            // her75 Phase 3 — Space.lg gap dropped; the fixed 150pt
            // hero region already carries the breathing room.
            Spacer().frame(height: Space.xs)

            // v4 R1 — options scroll INTERNALLY when they overflow
            // (basedOnSize keeps short lists inert); they can never
            // collide with the nav bar or push the CTA.
            ScrollView {
                VStack(spacing: Space.sm) {
                    ForEach(Array(opts.enumerated()), id: \.element.0) { idx, opt in
                        let (key, optTitle, optSub, optIcon) = opt
                        StaggeredReveal(index: idx) {
                            OnboardingOptionCard(
                                icon: optIcon,
                                sticker: stickers?[key],
                                title: optTitle,
                                subtitle: optSub,
                                isSelected: sel.wrappedValue == key,
                                isDimmed: strikeUnselected
                                    && !sel.wrappedValue.isEmpty
                                    && sel.wrappedValue != key,
                                action: {
                                    // soft (not light) — warmer, matches the
                                    // brand's signature select feel; pairs with
                                    // the radio pop + cross-off delight.
                                    Haptics.soft()
                                    withAnimation(Motion.tap) {
                                        sel.wrappedValue = key
                                    }
                                }
                            )
                        }
                    }

                    if let feedback = inlineFeedback,
                       let entry = feedback[sel.wrappedValue] {
                        inlineFeedbackCard(heading: entry.0, body: entry.1)
                            .padding(.top, Space.xs)
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(
                    label: "continue",
                    action: { advance(to: next, confirmation: confirmation) },
                    isEnabled: !sel.wrappedValue.isEmpty
                )
            }
        }
    }

    // MARK: - 17b helpers

    private func inlineFeedbackCard(heading: String, body: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(StickerName.heartsLineart.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(8)
                .background(Palette.bgPrimary, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(body)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.divider.opacity(0.35))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func bucketize(age: Int) -> String {
        switch age {
        case ..<18:    return "under18"
        case 18...24:  return "18to24"
        case 25...34:  return "25to34"
        case 35...44:  return "35to44"
        case 45...54:  return "45to54"
        default:       return "55plus"
        }
    }

    // MARK: - 17b-1: Age wheel
    //
    // Single-year picker bound to ageYears (Int). The legacy ageRange
    // string is mirrored on every change so WorkoutGenerator and the
    // computed properties downstream keep reading their existing
    // bucket keys (under18 / 18to24 / 25to34 / 35to44 / 45to54 /
    // 55plus). The "years old" caption floats next to the wheel's
    // center row (the SwiftUI wheel picker centers the selected row
    // mathematically, so a height-matched HStack lines up reliably
    // without measuring).

    private func ageWheelScreen() -> some View {
        VStack(spacing: 0) {
            jfHeader("what's your age?",
                     sub: "we shape your plan around it.")

            Spacer()

            ZStack {
                Picker("Age", selection: $ageYears) {
                    ForEach(13...80, id: \.self) { age in
                        Text("\(age)")
                            .font(.custom("Fraunces72pt-SemiBold", size: 36))
                            .foregroundStyle(Palette.textPrimary)
                            .tag(age)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 220)

                HStack(spacing: 0) {
                    Spacer()
                    Text("years old")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.leading, 96)
                }
                .frame(height: 220)
                .allowsHitTesting(false)
            }
            .padding(.horizontal, Space.screenPadding)
            .onAppear {
                // Seed the legacy ageRange mirror so downstream
                // computed properties have a value before the user
                // touches the wheel.
                if ageRange.isEmpty { ageRange = bucketize(age: ageYears) }
            }

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    // Sync the legacy ageRange string here (was in
                    // .onChange(of: ageYears) but per-tick parent state
                    // mutations interact poorly with Picker.wheel — the
                    // wheel can hold its scroll responder past the screen
                    // transition and freeze the next screen, see height-
                    // ruler freeze report). Setting once on Continue is
                    // enough; the wheel value already lives in @State and
                    // persists across re-mounts.
                    ageRange = bucketize(age: ageYears)
                    advance(to: 131, confirmation: nil)
                }
            }
        }
    }

    // MARK: - v4.5 R3: movement-baseline derivations
    //
    // The old activity slider + experience + session-length + commit-
    // days questions are cut (v4 plan §D). One movement-baseline Q
    // feeds every legacy consumer through derived mirrors so
    // WorkoutGenerator / ProgramSetupSubflow / AppSync columns keep
    // receiving valid values without a schema change.

    private func applyMovementDerivations() {
        switch movementBaseline {
        case "barely":      activityLevel = "sedentary"
        case "walks":       activityLevel = "light"
        case "regular_ish": activityLevel = "moderate"
        case "very_active": activityLevel = "active"
        default: break
        }
        // Experience folds into baseline + the sunk-cost Q (168).
        // Moving regularly reads as "on and off"; not moving + having
        // tried before reads as "tried, didn't stick".
        if movementBaseline == "regular_ish" || movementBaseline == "very_active" {
            experience = "sometimes"
        } else {
            experience = (triedBefore == "first") ? "never" : "gaveUp"
        }
    }

    /// Session length + weekly cadence are derived (tier × movement
    /// baseline), not asked. Single writer now that the explicit
    /// pickers are cut — recomputes on every pace/baseline change so
    /// the recap card + plan reveal always show current derivations.
    private func applyCadenceDerivations() {
        switch movementBaseline {
        case "regular_ish": sessionLength = "fifteen"
        case "very_active": sessionLength = "twenty"
        default:            sessionLength = "ten"
        }
        switch paceChoice {
        case "gentle":  commitmentDays = "three"
        case "focused": commitmentDays = (movementBaseline == "very_active") ? "seven" : "five"
        default:        commitmentDays = "five"
        }
        // Pace unification (2026-06-11) — the reveal PacePicker is the
        // SAME control as case 167, surfaced once more pre-commit. Seed
        // its tier from the pace so it opens consistent; PacePicker
        // writes back through ProjectionMath.paceKey(forTier:) on change.
        if !paceChoice.isEmpty {
            UserDefaults.standard.set(
                ProjectionMath.tierRaw(forPaceKey: paceChoice),
                forKey: "onboardingPickedTier"
            )
        }
    }

    private func jfMulti(
        _ title: String, sub: String? = nil,
        italic: [String] = [],
        opts: [(String, String, String?, String?)],
        sel: Binding<Set<String>>,
        next: Int,
        confirmation: String? = nil,
        minSelection: Int = 1
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub, italic: italic)

            Spacer().frame(height: Space.xs)

            ScrollView {
                VStack(spacing: Space.sm) {
                    ForEach(Array(opts.enumerated()), id: \.element.0) { idx, opt in
                        let (key, optTitle, optSub, optIcon) = opt
                        StaggeredReveal(index: idx) {
                            OnboardingOptionCard(
                                icon: optIcon,
                                title: optTitle,
                                subtitle: optSub,
                                isSelected: sel.wrappedValue.contains(key),
                                action: {
                                    Haptics.light()
                                    withAnimation(.spring(response: 0.25)) {
                                        if sel.wrappedValue.contains(key) {
                                            sel.wrappedValue.remove(key)
                                        } else {
                                            sel.wrappedValue.insert(key)
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(
                    label: "continue",
                    action: { advance(to: next, confirmation: confirmation) },
                    isEnabled: sel.wrappedValue.count >= minSelection
                )
            }
        }
    }

    private func jfSliderScreen<Annotation: View>(
        _ title: String, sub: String? = nil,
        valueMetric: Binding<Double>,
        metric: BiometricRulerConfig,
        imperial: BiometricRulerConfig,
        toMetric: @escaping (Double) -> Double,
        fromMetric: @escaping (Double) -> Double,
        next: Int,
        confirmation: String? = nil,
        @ViewBuilder annotation: @escaping () -> Annotation = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)
            Spacer()
            BiometricRulerScreen(
                valueMetric: valueMetric,
                metric: metric,
                imperial: imperial,
                toMetric: toMetric,
                fromMetric: fromMetric,
                annotation: annotation
            )
            .padding(.horizontal, Space.screenPadding)
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    advance(to: next, confirmation: confirmation)
                }
            }
        }
    }

    /// JustFit-style horizontal-ruler screen. Used by the weight
    /// (case 132) and goal-weight (case 133) questions. Identical
    /// shape to jfSliderScreen but the inner ruler is horizontal,
    /// the value sits above the indicator, and an optional metric
    /// band range visualizes a target zone (e.g. loss range).
    private func jfHorizontalSliderScreen<Annotation: View>(
        _ title: String, sub: String? = nil,
        italic: [String] = [],
        valueMetric: Binding<Double>,
        metric: BiometricRulerConfig,
        imperial: BiometricRulerConfig,
        toMetric: @escaping (Double) -> Double,
        fromMetric: @escaping (Double) -> Double,
        bandMetric: ClosedRange<Double>? = nil,
        next: Int,
        confirmation: String? = nil,
        @ViewBuilder annotation: @escaping () -> Annotation = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub, italic: italic)
            Spacer()
            HorizontalBiometricRulerScreen(
                valueMetric: valueMetric,
                metric: metric,
                imperial: imperial,
                toMetric: toMetric,
                fromMetric: fromMetric,
                bandMetric: bandMetric,
                annotation: annotation
            )
            .padding(.horizontal, Space.screenPadding)
            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    advance(to: next, confirmation: confirmation)
                }
            }
        }
    }

    private func jfBodyTypeScreen(
        _ title: String, sub: String? = nil,
        position: Binding<Int>,
        labels: [String],
        maxPosition: Int? = nil,
        markerPosition: Int? = nil,
        contextLine: String? = nil,
        next: Int,
        confirmation: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)
            // Body-type illustration — pre-renders all 6 in a ZStack and
            // crossfades by opacity so dragging the slider feels continuous
            // rather than popping between assets. Asset names match the
            // index (bodytype-0 for "Cut" through bodytype-5 for "Soft").
            ZStack {
                ForEach(0..<labels.count, id: \.self) { i in
                    Image("bodytype-\(i)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(position.wrappedValue == i ? 1 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 360)
            .padding(.top, Space.sm)
            .animation(.easeInOut(duration: 0.22), value: position.wrappedValue)

            if let contextLine {
                Text(contextLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.sm)
            }
            Spacer(minLength: Space.md)
            BodyTypeSlider(
                position: position,
                labels: labels,
                maxPosition: maxPosition,
                markerPosition: markerPosition
            )
            .padding(.horizontal, Space.screenPadding)

            // Body-fat range labels under the dot track. Anchors the
            // slider in real numbers without putting a percent on every
            // dot — matches the CalAI/Lasta reference.
            HStack {
                Text("Body fat <15%")
                Spacer()
                Text(">40%")
            }
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.xs)

            Spacer(minLength: Space.md)
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    advance(to: next, confirmation: confirmation)
                }
            }
        }
    }

    /// Real-time BMI display under the current-weight ruler. Updates
    /// continuously as the user drags. Shows the WHO clinical category
    /// (incl. obesity class) in a neutral, professional register: a
    /// medical-grade credibility signal stated matter-of-factly, never
    /// color-alarmed or editorialized.
    private func bmiAnnotation(weightKg: Double, heightCm: Double) -> some View {
        let heightM = heightCm / 100
        let bmi = (heightM > 0) ? weightKg / (heightM * heightM) : 0
        let bmiText = String(format: "%.1f", bmi)
        // v1.1 (2026-06-23) medical-grade direction [[feedback_medical_grade_over_soft]]:
        // restore the clinical BMI category (incl. WHO obesity class), stated
        // NEUTRALLY. No warning-red, no diet-culture copy. A clinician states
        // the category matter-of-factly; the prior de-shame pass had dropped
        // it entirely, cutting the clinical signal a GLP-1-grade intake wants.
        // Accurate + professional, not alarming.
        let category: String
        let support: String
        switch bmi {
        case ..<18.5:
            category = "underweight"
            support = "below the healthy range. we prioritize strength and adequate fuel."
        case 18.5..<25:
            category = "healthy range"
            support = "within the healthy range. the focus is body composition and lasting habits."
        case 25..<30:
            category = "overweight"
            support = "above the healthy range. a steady, sustainable loss is the focus."
        case 30..<35:
            category = "obese · class I"
            support = "a steady, sustainable pace is the safest and most effective here."
        case 35..<40:
            category = "obese · class II"
            support = "a steady, sustainable pace is the safest and most effective here."
        default:
            category = "obese · class III"
            support = "a steady, sustainable pace is the safest and most effective here."
        }
        return HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("your bmi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                Text(bmiText)
                    .font(.custom("Fraunces72pt-SemiBold", size: 32))
                    .foregroundStyle(Palette.cocoaPrimary)
                    .contentTransition(.numericText())
                Text(category)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(support)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.divider, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: bmi)
    }

    /// Real-time goal-weight validation under the goal ruler. Maintains
    /// the same percent-loss tier framing JustFit uses (steady /
    /// v3 P11.1.B (2026-06-10) — dynamic pace-selector options.
    /// Reads currentWeightKg + goalWeightKg + computes weeks-to-goal
    /// per ACSM pace band (0.5 / 0.75 / 1.0 %/wk). When no loss goal
    /// is set, falls back to generic horizons so the screen still
    /// reads sensibly. Floors each tier at 4 weeks so very-small
    /// deltas don't read "~1 week" (which would over-promise).
    // v4.5 case 286 — effort-down reframe. her75 teach-beat register:
    // 2-line Didone cascade + one plain sub + quiet citation line.
    private var realisticTargetScreen: some View {
        let curr = max(0, currentWeightKg)
        let lossKg = max(0, curr - goalWeightKg)
        let fivePctLb = Int((curr * 0.05 * Self.lbPerKg).rounded())
        let subLine: String = lossKg > 0.5
            ? "even \(fivePctLb) lb changes how clothes fit, how sleep lands, how much room food takes up in your head."
            : "the version you keep is the one built slowly. your plan is shaped for keeping."

        return ZStack(alignment: .bottomTrailing) {
            // her75 "when do you start" register — photo anchored to the
            // bottom edge, rotated, bleeding off-screen. Cream-bg cutout
            // merges with bgPrimary so it reads as a placed object.
            // v4.6 round 3: true-alpha legs-up cutout, thighs exit the
            // canvas bottom, so it sits flush on the screen's bottom
            // edge and the cut reads natural (no more rotated photo
            // with its background rectangle showing).
            Image("onb-movement-sneakers")
                .resizable()
                .scaledToFit()
                .frame(width: 290)
                .offset(x: 46, y: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Space.xl)
            LineCascadeText(
                lines: [
                    .plain("you don't need"),
                    .composite(base: "a dramatic number.", italic: ["dramatic"]),
                ],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                lineSpacing: Typo.heroHeadlineLineGap
            )
            .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            Text(subLine)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.md)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(Palette.divider)
                    .frame(width: 24, height: 1)
                Text("wing & phelan 2005 · a kept 5–10% is the clinical win")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    advance(to: 136, confirmation: nil)
                }
            }
        }
    }

    private func paceSelectorOpts() -> [(String, String, String?, String?)] {
        // v4.5 — live date math (Cal AI calai13-15). A concrete "around
        // sep 18" outconverts an abstract week count; recomputes per
        // option because each pace lands on a different date. All three
        // route through ProjectionMath so the dates here are the SAME
        // dates the day-one card, reveal, and paywall later show.
        func dateLabel(_ paceKey: String) -> String? {
            ProjectionMath.formattedShortDate(
                currentKg: currentWeightKg,
                goalKg: goalWeightKg,
                paceKey: paceKey
            )
        }

        let gentleSub  = dateLabel("gentle").map  { "around \($0) · easier to sustain" }  ?? "easier to sustain · 0.5%/week"
        let steadySub  = dateLabel("steady").map  { "around \($0) · most chosen pace" }   ?? "most chosen pace · 0.75%/week"
        let focusedSub = dateLabel("focused").map { "around \($0) · fastest healthy pace" } ?? "fastest healthy pace · 1.0%/week"

        return [
            ("gentle",  "gentle",   gentleSub,  nil),
            ("steady",  "steady",   steadySub,  nil),
            ("focused", "focused",  focusedSub, nil),
        ]
    }

    /// v3 P11.1.A (2026-06-10) — BetterMe S1 dynamic goal-weight
    /// reframe. The card swaps copy + state-dot color based on the
    /// goal weight relative to current weight + BMI. Four states:
    /// maintain (no loss), under-target (BMI < 18.5 — kindness frame,
    /// NOT amber-alarm), on-pace (ACSM 0.5-1%/wk band), ambitious
    /// (>1%/wk — care frame, not warning frame).
    ///
    /// LOCKED rules respected:
    /// - NEVER "lose X%" copy ([[feedback-food-ux-antishame]] R2)
    /// - NEVER labor verbs ("protects muscle" → removed)
    /// - lowercase casual + italic-Fraunces punch on key word
    /// - trend-language: "becoming window: ~N weeks", not deficit math
    /// - no amber/red on low BMI — sage dot, soft cocoa frame
    private func goalWeightAnnotation(currentKg: Double, goalKg: Double, heightCm: Double) -> some View {
        let heightM = heightCm / 100
        let goalBmi = (heightM > 0) ? goalKg / (heightM * heightM) : 0
        let lossKg = currentKg - goalKg
        let percentLoss = currentKg > 0 ? (lossKg / currentKg) * 100 : 0
        // ACSM-aligned weeks: 0.75% of current body weight per week
        // (midpoint of 0.5-1% safe band). Floors at 4 weeks so the
        // card never reads "1 week" for very small deltas.
        let weeklyLossKg = max(0.1, currentKg * 0.0075)
        let weeks = max(4, Int((lossKg / weeklyLossKg).rounded()))

        // State selection — order matters: under-target BMI wins over
        // pace bands because health safety supersedes pace ergonomics.
        enum ReframeState { case maintain, underTarget, onPace, ambitious }
        let state: ReframeState
        if goalKg >= currentKg {
            state = .maintain
        } else if goalBmi > 0 && goalBmi < 18.5 {
            state = .underTarget
        } else if percentLoss <= 10 {
            // 10% in ~13 weeks = 0.75%/wk, the ACSM midpoint of the
            // safe band. "On pace" applies through the band's upper
            // edge; only above triggers "ambitious."
            state = .onPace
        } else {
            state = .ambitious
        }

        let dotColor: Color
        let baseCopy: String
        let italicWords: [String]
        let supportCopy: String

        switch state {
        case .maintain:
            dotColor = Palette.textSecondary
            baseCopy = "holding steady. your plan adapts."
            italicWords = ["steady"]
            supportCopy = "strength + recovery keeps the version of you you've already earned."
        case .underTarget:
            // BetterMe's amber "Attention" card is the rejected pattern
            // (R6). JeniFit version uses sage dot + permission frame.
            // No alarm, no scolding — just a kinder target invitation.
            dotColor = Palette.stateGood
            baseCopy = "this goal sits below what's kind to your body. let's pick a number with room to feel good."
            italicWords = ["kind"]
            supportCopy = "the lowest healthy weight for your height is around \(Int((18.5 * heightM * heightM).rounded())) kg."
        case .onPace:
            dotColor = Palette.stateGood
            baseCopy = "on pace. about \(weeks) weeks of becoming."
            italicWords = ["on pace.", "becoming"]
            supportCopy = "energy, sleep, and clothes-fit usually shift first. the scale follows ♥"
        case .ambitious:
            // No red/amber, no warning chip — JeniFit's locked anti-
            // shame stance. Care framing, not labor verbs.
            dotColor = Palette.stateWarn
            baseCopy = "ambitious. about \(weeks) weeks of becoming. a steady food rhythm + a soft week now and then makes the difference."
            italicWords = ["ambitious.", "becoming", "soft week"]
            supportCopy = "moves quickly — sleep + protein floor matter more here than calorie math."
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                ItalicAccentText(
                    baseCopy,
                    italic: italicWords,
                    baseFont: .system(size: 15, weight: .medium),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            Text(supportCopy)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 16)  // align under text after dot
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.divider, lineWidth: 1)
        )
        // v3 P11.3 (2026-06-10) — bloom (spring response 0.42,
        // damping 0.82) gives the state swap a tactile beat when the
        // user drags the goal weight across thresholds. Was
        // entranceSoft (easeOut 0.42) — that read as content fade,
        // bloom reads as the card actually responding.
        .animation(Motion.bloom, value: state)
    }

    /// Yes/no relatability question. The 17d-1c redesign splits the
    /// statement into prefix + italic emphasis + suffix so the headline
    /// reads with Fraunces italic emphasis on the key word, and adds a
    /// hero sticker above the statement so each question has a distinct
    /// visual anchor (instead of three near-identical screens).
    ///
    /// `heroImage` (optional) overrides the small sticker-in-halo with
    /// a larger glossy 3D illustration generated via Grok Imagine.
    /// Used by Q150/Q151/Q152 barrier screens — same layout structure,
    /// just a bigger anchor on the brand sticker aesthetic. Falls back
    /// to the existing sticker pattern when `heroImage` is nil.
    // v4.5 — her75 photo-card choice grid (IMG_6269 register). Photo
    // fills the card, radio + label row sits beneath it. 2-col grid,
    // odd counts leave the last cell solo-left like her75 does.
    private func jfPhotoChoice(
        _ title: String,
        italic: [String] = [],
        opts: [(key: String, label: String, asset: String)],
        sel: Binding<String>,
        next: Int,
        confirmation: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: nil, italic: italic)

            Spacer().frame(height: Space.xs)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Space.sm),
                              GridItem(.flexible(), spacing: Space.sm)],
                    spacing: Space.sm
                ) {
                    ForEach(Array(opts.enumerated()), id: \.element.key) { idx, opt in
                        StaggeredReveal(index: idx) {
                            photoChoiceCard(opt: opt, isSelected: sel.wrappedValue == opt.key) {
                                Haptics.light()
                                withAnimation(Motion.tap) { sel.wrappedValue = opt.key }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(
                    label: "continue",
                    action: { advance(to: next, confirmation: confirmation) },
                    isEnabled: !sel.wrappedValue.isEmpty
                )
            }
        }
    }

    /// Multi-select photo grid — same card chrome as jfPhotoChoice.
    /// Built for the cuisine question (169): food cutout per option.
    private func jfPhotoMulti(
        _ title: String, sub: String? = nil,
        italic: [String] = [],
        opts: [(key: String, label: String, asset: String)],
        sel: Binding<Set<String>>,
        next: Int,
        confirmation: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub, italic: italic)

            Spacer().frame(height: Space.xs)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: Space.sm),
                              GridItem(.flexible(), spacing: Space.sm)],
                    spacing: Space.sm
                ) {
                    ForEach(Array(opts.enumerated()), id: \.element.key) { idx, opt in
                        StaggeredReveal(index: idx) {
                            photoChoiceCard(opt: opt, isSelected: sel.wrappedValue.contains(opt.key)) {
                                Haptics.light()
                                withAnimation(Motion.tap) {
                                    if sel.wrappedValue.contains(opt.key) {
                                        sel.wrappedValue.remove(opt.key)
                                    } else {
                                        sel.wrappedValue.insert(opt.key)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.sm)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(
                    label: "continue",
                    action: { advance(to: next, confirmation: confirmation) },
                    isEnabled: !sel.wrappedValue.isEmpty
                )
            }
        }
    }

    private func photoChoiceCard(
        opt: (key: String, label: String, asset: String),
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // scaledToFit (founder QA 2026-06-11): the cutouts have
                // real alpha, so fit shows the whole subject ending
                // naturally instead of a hard fill-crop against the
                // label row. Bottom-aligned so feet/bases rest on it.
                Image(opt.asset)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 132, alignment: .bottom)
                    .padding(.top, 8)

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: 1.5)
                            .frame(width: 18, height: 18)
                        if isSelected {
                            Circle().fill(Palette.accent).frame(width: 10, height: 10)
                        }
                    }
                    Text(opt.label)
                        .font(.custom("DMSans-SemiBold", size: 15))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.divider,
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(isSelected ? 1.0 : 0.985)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(opt.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // v4.5 R4 — psychometric register: statement ONLY, centered, the
    // serif carrying the whole screen (her75 / BetterMe S2). Sticker
    // circle killed per the v4 kill-list.
    private func jfYesNo(
        prefix: String,
        italic: String,
        suffix: String,
        bind: Binding<Bool?>,
        next: Int,
        confirmation: String? = nil,
        // v4.6 (2026-06-11) — it-girl editorial cutout above the
        // statement. Photo axis-aligned per the Direction A guardrail;
        // the statement stays the screen's voice, the photo is the mood.
        accentImage: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            if let accentImage {
                Image(accentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 290)
                    .accessibilityHidden(true)
                Spacer().frame(height: Space.lg)
            }

            (Text(prefix).font(Typo.title)
             + Text(italic).font(Typo.titleItalic)
             + Text(suffix).font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(Typo.heroHeadlineLineGap * 0.6)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.lg)

            Spacer()
        }
        // v4 R1 — the yes/no pair is the CTA on psychometric screens;
        // it docks like every other CTA (same pixel Y) and wears the
        // one-CTA system chrome: 56pt capsules, DM Sans SemiBold 16,
        // outline vs cocoa fill. The pink accent fill died with the
        // v4 kill list (her75 buttons are plain sans on cocoa).
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                HStack(spacing: Space.sm) {
                    Button {
                        Haptics.medium()
                        bind.wrappedValue = false
                        advance(to: next, confirmation: confirmation)
                    } label: {
                        Text("not me")
                            .font(.custom("DMSans-SemiBold", size: 16))
                            .foregroundStyle(Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                Capsule().stroke(Palette.divider, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(PressFeedbackStyle())

                    Button {
                        Haptics.medium()
                        bind.wrappedValue = true
                        advance(to: next, confirmation: confirmation)
                    } label: {
                        Text("yeah, that's me")
                            .font(.custom("DMSans-SemiBold", size: 16))
                            .foregroundStyle(Palette.textInverse)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Palette.bgInverse, in: Capsule())
                    }
                    .buttonStyle(PressFeedbackStyle())
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - MULTI SELECT

    @State private var multiFeedback = ""
    @State private var showMultiFeedback = false

    private func multiView(_ title: String, sub: String?, opts: [(String, String)],
                            sel: Binding<Set<String>>, next: Int) -> some View {
        let feedbacks: [String: String] = [
            "boring": "We keep it fresh every day",
            "dontKnow": "That's why we pick the workout for you",
            "motivation": "Your coach won't let you skip",
            "time": "5 minutes. That's all it takes",
            "injury": "Voice coaching keeps your form safe",
        ]

        return VStack(spacing: 0) {
            jfHeader(title, sub: sub)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, label in
                    let on = sel.wrappedValue.contains(key)
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25)) {
                            if on { sel.wrappedValue.remove(key) } else { sel.wrappedValue.insert(key) }
                        }
                    } label: {
                        HStack {
                            Text(label).font(.system(size: 17, weight: .medium))
                                .foregroundStyle(on ? Palette.textInverse : Palette.textPrimary)
                            Spacer()
                            if on { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.textInverse) }
                        }
                        .padding(.horizontal, 20).frame(height: 56)
                        .background(on ? Palette.bgInverse : Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(showMultiFeedback)
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .opacity(showMultiFeedback ? 0.5 : 1.0)
            .animation(.easeOut(duration: 0.2), value: showMultiFeedback)

            // Feedback
            ZStack {
                if showMultiFeedback {
                    Text(multiFeedback)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 22)
                        .background(Color(hex: "#C8612C"))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 70)
            .padding(.top, Space.md)

            Spacer()

            ctaBtn("Continue") {
                Haptics.medium()
                // Build combined feedback from selected barriers
                let selected = sel.wrappedValue
                let fb = selected.compactMap { feedbacks[$0] }.first ?? "We've got you covered"
                multiFeedback = fb
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showMultiFeedback = true
                }
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.15)) { showMultiFeedback = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { go(next) }
                }
            }
            .opacity(sel.wrappedValue.isEmpty ? 0.3 : 1.0)
            .disabled(sel.wrappedValue.isEmpty || showMultiFeedback)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - CHART (screen 4)
    // ═══════════════════════════════════════

    @State private var chartLine1 = false
    @State private var chartLine2 = false
    @State private var chartDot = false

    @State private var chartHeadline = false

    private var chartScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Headline
            VStack(spacing: Space.sm) {
                Text("87%")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.accent)
                    .opacity(chartHeadline ? 1 : 0)
                    .scaleEffect(chartHeadline ? 1 : 0.7)

                Text("of people quit\nhome workouts in 2 weeks")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(chartHeadline ? 1 : 0)
                    .offset(y: chartHeadline ? 0 : 10)

                Text("not with a coach in your pocket")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .opacity(chartHeadline ? 1 : 0)
            }

            Spacer().frame(height: Space.lg + 8)

            // Chart
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height

                    // Gradient fill under the success line
                    if chartLine2 {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: h * 0.6))
                            p.addCurve(to: CGPoint(x: w, y: h * 0.08),
                                       control1: CGPoint(x: w * 0.25, y: h * 0.38),
                                       control2: CGPoint(x: w * 0.65, y: h * 0.1))
                            p.addLine(to: CGPoint(x: w, y: h))
                            p.addLine(to: CGPoint(x: 0, y: h))
                            p.closeSubpath()
                        }
                        .fill(
                            LinearGradient(colors: [Palette.accent.opacity(0.15), Palette.accent.opacity(0.02)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .transition(.opacity)
                    }

                    // Dropout line — thick dashed
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.6))
                        p.addCurve(to: CGPoint(x: w, y: h * 0.92),
                                   control1: CGPoint(x: w * 0.2, y: h * 0.45),
                                   control2: CGPoint(x: w * 0.5, y: h * 0.95))
                    }
                    .trim(from: 0, to: chartLine1 ? 1 : 0)
                    .stroke(Palette.divider, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))

                    // Success line — thick solid gradient
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h * 0.6))
                        p.addCurve(to: CGPoint(x: w, y: h * 0.08),
                                   control1: CGPoint(x: w * 0.25, y: h * 0.38),
                                   control2: CGPoint(x: w * 0.65, y: h * 0.1))
                    }
                    .trim(from: 0, to: chartLine2 ? 1 : 0)
                    .stroke(
                        LinearGradient(colors: [Palette.accent.opacity(0.5), Palette.accent],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )

                    // Glow dot
                    if chartDot {
                        ZStack {
                            Circle()
                                .fill(Palette.accent.opacity(0.2))
                                .frame(width: 24, height: 24)
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: 10, height: 10)
                        }
                        .position(x: w, y: h * 0.08)
                        .transition(.scale.combined(with: .opacity))
                    }

                    // Labels
                    if chartDot {
                        Text("gave up")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .position(x: w * 0.82, y: h * 0.98)

                        HStack(spacing: 4) {
                            Circle().fill(Palette.accent).frame(width: 6, height: 6)
                            Text("JeniFit")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Palette.accent)
                        }
                        .position(x: w * 0.82, y: h * 0.2)
                    }
                }
                .frame(height: 180)

                HStack {
                    Text("Week 1").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("Week 4").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(20)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .plankShadow()
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(5) }
        }
        .background(Palette.bgPrimary)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) { chartHeadline = true }
            withAnimation(.easeOut(duration: 1.0).delay(0.8)) { chartLine1 = true }
            withAnimation(.easeOut(duration: 1.2).delay(1.2)) { chartLine2 = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(2.4)) { chartDot = true }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - CELEBRATION (screen 6)
    // ═══════════════════════════════════════

    @State private var coachPhotoVisible = false
    @State private var coachRingPulse = false

    private var celebrationScreen: some View {
        let msg = barriers.contains("boring") ? "Boredom is the #1 reason\npeople quit planking."
            : barriers.contains("motivation") ? "Motivation fades.\nAccountability doesn't."
            : barriers.contains("dontKnow") ? "Not knowing correct form\nis more common than you think."
            : "We hear you."

        let fix = barriers.contains("boring") ? "Your coach makes\nevery second count."
            : barriers.contains("motivation") ? "Your coach shows up\nevery single day."
            : barriers.contains("dontKnow") ? "Your coach corrects\nyour form in real time."
            : "JeniFit was built for this."

        return ZStack {
            GradientBlob(colors: [Palette.stateGood, Palette.accentSubtle, Palette.accent])

            VStack(spacing: 0) {
                Spacer()

                // Trainer profile photos — 3 overlapping circles
                HStack(spacing: -16) {
                    ForEach(Array(["coach-kira", "coach-jeni", "coach-matson"].enumerated()), id: \.offset) { i, photo in
                        ZStack {
                            // Pulse ring
                            Circle()
                                .stroke(Palette.accent.opacity(coachRingPulse ? 0.3 : 0), lineWidth: 3)
                                .frame(width: 76, height: 76)
                                .scaleEffect(coachRingPulse ? 1.15 : 1.0)
                                .animation(
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.3),
                                    value: coachRingPulse
                                )

                            // Photo
                            Image(photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 68, height: 68)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 3))
                        }
                        .opacity(coachPhotoVisible ? 1 : 0)
                        .scaleEffect(coachPhotoVisible ? 1 : 0.5)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.65).delay(Double(i) * 0.12),
                            value: coachPhotoVisible
                        )
                    }
                }

                Spacer().frame(height: Space.lg)

                Text(msg).font(.system(size: 24, weight: .bold)).foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center).opacity(celebVisible ? 1 : 0).offset(y: celebVisible ? 0 : 20)

                Spacer().frame(height: Space.xl)

                Text(fix).font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.accent)
                    .multilineTextAlignment(.center).opacity(celebVisible ? 1 : 0).offset(y: celebVisible ? 0 : 15)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: celebVisible)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(7) }.opacity(celebVisible ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            Haptics.success()
            // Photos spring in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { coachPhotoVisible = true }
            // Text fades in after photos
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.6)) { celebVisible = true }
            }
            // Pulse rings start after everything settles. Skipped under
            // reduce-motion since it's a forever-repeating breath effect.
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { coachRingPulse = true }
            }
        }
    }

    // MARK: - Form Education (screen 12)

    @State private var formStep = 0  // 0=hidden, 1=left card, 2=arrow, 3=right card, 4=text

    private var formScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hook
            Text("Other apps\ncount seconds.")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(formStep >= 1 ? 1 : 0)
                .offset(y: formStep >= 1 ? 0 : 10)
                .animation(.easeOut(duration: 0.4), value: formStep)

            Text("We watch your form.")
                .font(Typo.titleItalic)
                .foregroundStyle(Palette.accent)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .opacity(formStep >= 2 ? 1 : 0)
                .offset(y: formStep >= 2 ? 0 : 8)
                .animation(.easeOut(duration: 0.4), value: formStep)

            Spacer().frame(height: Space.lg + 8)

            // Competitor comparison
            VStack(spacing: 12) {
                // Other apps
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.divider.opacity(0.5))
                            .frame(width: 44, height: 44)
                        Image(systemName: "timer")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Timer apps")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        Text("60s of bad form still counts as done")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    }
                    Spacer()
                    Text("❌")
                        .font(.system(size: 20))
                }
                .padding(14)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(formStep >= 3 ? 1 : 0)
                .offset(x: formStep >= 3 ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: formStep)

                // Video apps
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.divider.opacity(0.5))
                            .frame(width: 44, height: 44)
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Follow-along videos")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Palette.textSecondary)
                        Text("Can't see if you're doing it wrong")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    }
                    Spacer()
                    Text("❌")
                        .font(.system(size: 20))
                }
                .padding(14)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .opacity(formStep >= 4 ? 1 : 0)
                .offset(x: formStep >= 4 ? 0 : -20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: formStep)

                // JeniFit
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Palette.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("JeniFit")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text("We watch your form and correct it in real time")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.accent)
                    }
                    Spacer()
                    Text("✅")
                        .font(.system(size: 20))
                }
                .padding(14)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Palette.accent.opacity(0.3), lineWidth: 1.5)
                )
                .plankShadow()
                .opacity(formStep >= 5 ? 1 : 0)
                .scaleEffect(formStep >= 5 ? 1 : 0.95)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: formStep)
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            Text("20 seconds of perfect form\nbeats 60 seconds of bad form. Every time.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(formStep >= 6 ? 1 : 0)
                .offset(y: formStep >= 6 ? 0 : 6)
                .animation(.easeOut(duration: 0.3), value: formStep)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(13) }
                .opacity(formStep >= 6 ? 1 : 0)
        }
        .background(Palette.bgPrimary)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation { formStep = 1 } }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { formStep = 2 }; Haptics.soft() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { formStep = 3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { formStep = 4 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { formStep = 5; Haptics.medium() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) { formStep = 6 }
        }
    }

    // MARK: - Social Proof (screen 14)

    @State private var cardsVisible = false

    @State private var marqueeOffset1: CGFloat = 0

    /// Real-feel name + day captions for the marquee. Mirrors testimonial names
    /// so the same people show up as faces and as quotes elsewhere in onboarding.
    private static let marqueeCaptions: [(asset: String, caption: String)] = [
        ("social-1",  "Maya · D14"),
        ("social-2",  "Aaliyah · D22"),
        ("social-3",  "Priya · D8"),
        ("social-4",  "Zoe · D31"),
        ("social-5",  "Layla · D6"),
        ("social-6",  "Jasmine · D19"),
        ("social-7",  "Destiny · D11"),
        ("social-8",  "Kayla · D27"),
        ("social-9",  "Ava · D4"),
        ("social-10", "Mia · D16"),
    ]

    private var socialProofScreen: some View {
        // One uniform row, larger cards (130×232 = 9:16). Captions humanize the photos.
        let cardW: CGFloat = 130
        let cardH: CGFloat = 232
        let assets = Self.marqueeCaptions.map { $0.asset }
        let captions = Self.marqueeCaptions.map { $0.caption }
        let sizes: [(CGFloat, CGFloat)] = Array(repeating: (cardW, cardH), count: assets.count)
        let rotations: [Double] = [-3, 2, -2, 3, -3, 2, -2, 3, -2, 2]

        return VStack(spacing: 0) {
            Spacer()

            // Live activity chip — credibility cue before the big number
            HStack(spacing: 6) {
                Circle().fill(Palette.stateGood).frame(width: 7, height: 7)
                    .scaleEffect(cardsVisible ? 1 : 0.5)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: cardsVisible)
                Text("12 active right now")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.stateGood)
                    .tracking(0.2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Palette.stateGood.opacity(0.10))
            .clipShape(Capsule())
            .opacity(cardsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.4), value: cardsVisible)

            Spacer().frame(height: Space.md)

            // Hero counter
            Text("\(proofCount)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
                .opacity(cardsVisible ? 1 : 0)
                .scaleEffect(cardsVisible ? 1 : 0.85)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: cardsVisible)

            Text("people started this month")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.xs)
                .opacity(cardsVisible ? 1 : 0)

            // Momentum line
            Text("+247 this week")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .padding(.top, 2)
                .opacity(cardsVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: cardsVisible)

            Spacer().frame(height: Space.lg + 8)

            // Single marquee row with name + day captions on each card
            marqueeRow(
                assets: assets,
                captions: captions,
                sizes: sizes,
                rotations: rotations,
                offset: marqueeOffset1
            )
            .opacity(cardsVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.6).delay(0.3), value: cardsVisible)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(15) }
        }
        .clipped()
        .onAppear {
            cardsVisible = true
            // 40s perpetual marquee scroll — WCAG 2.2.2 Pause/Stop/Hide.
            // Skip under reduce-motion; static cards still render.
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                        marqueeOffset1 = -1
                    }
                }
            }
            let t = 2847
            for i in 0...25 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                    withAnimation(.easeOut(duration: 0.08)) { proofCount = Int(Double(t) * Double(i) / 25) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { Haptics.medium() }
        }
    }

    /// Infinite marquee row of 9:16 cards. Duplicates content for seamless loop.
    /// Outer height tracks the tallest card so larger sizes don't get clipped.
    /// Pass `captions` to draw a name + day overlay on each card.
    private func marqueeRow(
        assets: [String],
        captions: [String]? = nil,
        sizes: [(CGFloat, CGFloat)],
        rotations: [Double],
        offset: CGFloat
    ) -> some View {
        let cardSpacing: CGFloat = 14
        let totalWidth = sizes.reduce(CGFloat(0)) { $0 + $1.0 + cardSpacing }
        let rowHeight = (sizes.map { $0.1 }.max() ?? 150) + 20  // padding for rotation overflow

        return GeometryReader { _ in
            let scrollAmount = offset < 0 ? totalWidth : 0  // 0 = static, totalWidth = one full loop

            HStack(spacing: cardSpacing) {
                ForEach(0..<assets.count, id: \.self) { i in
                    socialCard(
                        asset: assets[i],
                        caption: captions?[i],
                        width: sizes[i].0,
                        height: sizes[i].1,
                        rotation: rotations[i]
                    )
                }
                // Duplicate for seamless loop
                ForEach(0..<assets.count, id: \.self) { i in
                    socialCard(
                        asset: assets[i],
                        caption: captions?[i],
                        width: sizes[i].0,
                        height: sizes[i].1,
                        rotation: rotations[i]
                    )
                }
            }
            .offset(x: -scrollAmount)
        }
        .frame(height: rowHeight)
    }

    private func socialCard(asset: String, caption: String? = nil, width: CGFloat, height: CGFloat, rotation: Double) -> some View {
        ZStack(alignment: .bottomLeading) {
            Image(asset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width, height: height)

            if let caption {
                // Bottom gradient + caption pinned bottom-left
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: width, height: height * 0.42)
                .frame(maxHeight: .infinity, alignment: .bottom)

                Text(caption)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        .rotationEffect(.degrees(rotation))
    }

    // MARK: - Coach Education (screen 12) — raw bold style, no photos

    private var coachScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateGood, Palette.bgInverse]).offset(y: -50)
            VStack(spacing: 0) {
                Spacer()

                // Big bold stat
                Text("3x")
                    .font(.system(size: 80, weight: .black))
                    .foregroundStyle(Palette.accent)

                Text("longer hold times\nwith real-time coaching")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Space.xl)

                // Feature pills
                VStack(spacing: Space.sm) {
                    featurePill("camera.fill", "Watches your form in real time")
                    featurePill("waveform", "Voice coaching, not just beeps")
                    featurePill("figure.core.training", "Detects hip sag & shoulder creep")
                }
                .padding(.horizontal, Space.screenPadding)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(18) }
            }
        }
    }

    private func featurePill(_ icon: String, _ text: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 32, height: 32)
                .background(Palette.accent.opacity(0.1))
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Testimonial (screen 13)

    @State private var reviewVisible = false

    private var testimonialScreen: some View {
        let reviews: [(String, String, String, Int)] = [
            barriers.contains("boring")
                ? ("The trainer literally roasted me for dropping my hips 😂 I've never been so motivated to hold a plank", "Jasmine", "Day 22", 5)
                : ("I had NO idea my form was wrong until this app showed me. Game changer for real", "Maya", "Day 14", 5),

            barriers.contains("motivation")
                ? ("I used to quit at 15 seconds. Now I'm at 45 and actually having fun??", "Aaliyah", "Day 11", 5)
                : ("The voice feedback hits different. Like having a friend who's also a trainer", "Destiny", "Day 19", 5),

            barriers.contains("time")
                ? ("2 minutes a day. That's it. I do it while my coffee brews and I'm already seeing results", "Priya", "Day 17", 5)
                : ("My posture is noticeably better and my back pain is basically gone. Wish I started sooner", "Kayla", "Day 28", 5),
        ]

        return VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

            Text("What people are saying")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)

            Spacer().frame(height: Space.lg)

            VStack(spacing: 12) {
                ForEach(Array(reviews.enumerated()), id: \.offset) { i, review in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 2) {
                            ForEach(0..<review.3, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.accent)
                            }
                        }
                        Text(review.0)
                            .font(.system(size: 14))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(3)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Palette.accent.opacity(0.15))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Text(String(review.1.prefix(1)))
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(Palette.accent)
                                )
                            Text(review.1)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text("·").foregroundStyle(Palette.divider)
                            Text(review.2)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.bgElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(reviewVisible ? 1 : 0)
                    .offset(y: reviewVisible ? 0 : CGFloat(20 + i * 8))
                    .animation(.easeOut(duration: 0.45).delay(0.15 + Double(i) * 0.15), value: reviewVisible)
                }
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(16) }
        }
        .onAppear { withAnimation { reviewVisible = true } }
    }

    // MARK: - Program (unused, kept for reference)

    private var programScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.accentSubtle, Palette.stateGood]).offset(y: 100)
            VStack(spacing: 0) {
                Spacer()
                AnimatedIcon(name: "calendar", size: 52)
                Spacer().frame(height: Space.lg)
                Text("30 days.\n5 exercises.\nOne mission.").font(Typo.title)
                    .foregroundStyle(Palette.textPrimary).multilineTextAlignment(.center)
                Spacer().frame(height: Space.sm)
                Text("Start with plank. Earn the rest.\nYour core score tracks everything.")
                    .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(23) }
            }.padding(.horizontal, Space.screenPadding)
        }
    }

    // MARK: - Name (screen 15)

    @FocusState private var nameFieldFocused: Bool

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero sticker accent — small, left-aligned to match the
            // headline. heartsLineart fits the warmth of the moment
            // (this is the question where we ask who they are).
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.10))
                    .frame(width: 64, height: 64)
                Image(StickerName.heartsLineart.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(StickerName.heartsLineart.style.opacity)
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.md)

            // Italic accent on "jeni" — coach-relational frame (Ladder /
            // Sculpt Society pattern). Reads as a personal moment with
            // the coach by name, not a generic form prompt.
            (Text("what should ").font(Typo.title)
             + Text("jeni").font(Typo.titleItalic)
             + Text(" call you?").font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)

            Text("first name is perfect.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.xs)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            TextField("Your name", text: $name)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
                .padding(20)
                .background(Palette.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .plankShadow()
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .focused($nameFieldFocused)
                .submitLabel(.continue)
                .padding(.horizontal, Space.screenPadding)
                .onSubmit {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    nameFieldFocused = false
                    Haptics.medium()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { go(19) }
                }

            Spacer()

            ctaBtn("Continue") {
                nameFieldFocused = false
                Haptics.medium()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { go(19) }
            }
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.3 : 1.0)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            nameFieldFocused = true
        }
    }

    // ═══════════════════════════════════════
    // MARK: - COACH SELECTOR (screen 16)
    // ═══════════════════════════════════════

    @State private var playingPreview: String? = nil
    @State private var previewPlayer: AVAudioPlayer? = nil

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func playPreview(_ clip: String, id: String) {
        previewPlayer?.stop()
        if playingPreview == id {
            playingPreview = nil
            return
        }
        playingPreview = id
        if let url = Bundle.main.url(forResource: clip, withExtension: "m4a") {
            previewPlayer = try? AVAudioPlayer(contentsOf: url)
            previewPlayer?.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if playingPreview == id { playingPreview = nil }
        }
    }

    /// 17d-2: LIGHT 4-sticker scatter for the coach selector. Edges
    /// only so the trainer cards remain the visual anchor.
    private static let coachSelectorPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.06),
                         size: 28, rotation: 12, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.07, y: 0.06),
                         size: 26, rotation: -10, phaseDelay: 0.30),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.94, y: 0.92),
                         size: 30, rotation: 10, phaseDelay: 0.55),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.06, y: 0.92),
                         size: 28, rotation: -8, phaseDelay: 0.78),
    ]

    private var coachSelector: some View {
        ZStack {
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(alignment: .leading, spacing: 0) {
                // Italic-accent headline — Fraunces voice instead of
                // the previous system bold.
                (Text("Pick your ").font(Typo.title)
                 + Text("coach").font(Typo.titleItalic)
                 + Text(".").font(Typo.title))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, Space.screenPadding)

                Text("Tap a card to hear their voice.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, Space.xs)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.lg)

                VStack(spacing: Space.sm) {
                    trainerRow(
                        id: "keepItReal", photo: "coach-kira", name: "Kira",
                        vibe: "Sassy & Real",
                        quote: "\"My mama planks better than this\"",
                        preview: "kira_preview",
                        sticker: .starLineart
                    )
                    trainerRow(
                        id: "encouraging", photo: "coach-jeni", name: "Jeni",
                        vibe: "Warm & Supportive",
                        quote: "\"You're doing amazing. keep breathing.\"",
                        preview: "jeni_preview",
                        sticker: .heartGlossy
                    )
                    trainerRow(
                        id: "balanced", photo: "coach-matson", name: "Sam",
                        vibe: "Chill & Playful",
                        quote: "\"We're gonna have a good time\"",
                        preview: "matson_preview",
                        sticker: .balloonDog
                    )
                }
                .padding(.horizontal, Space.screenPadding)

                Spacer()

                ctaBtn("Train with \(selectedCoachName)") {
                    Haptics.heavy()
                    previewPlayer?.stop(); playingPreview = nil
                    feedback = coachFeedback
                    withAnimation(.spring(response: 0.3)) { showFeedback = true }
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                        withAnimation(Motion.exit) { showFeedback = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            go(180)
                        }
                    }
                }
            }
        }
        .onAppear { configureAudioSession() }
    }

    private func trainerRow(
        id: String, photo: String, name: String, vibe: String,
        quote: String, preview: String,
        sticker: StickerName
    ) -> some View {
        let selected = voicePreference == id
        let playing = playingPreview == id

        return Button {
            Haptics.medium()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { voicePreference = id }
            playPreview(preview, id: id)
        } label: {
            HStack(spacing: 14) {
                // Tall portrait photo
                ZStack(alignment: .bottomTrailing) {
                    Image(photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Playing indicator
                    if playing {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Palette.accent)
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(vibe)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(selected ? Palette.accent.opacity(0.18) : Palette.accent.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(quote)
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)

                    if playing {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text("Playing…")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                    }
                }

                Spacer()

                // 17d-2: per-coach sticker accent. Sits in the trailing
                // column where the checkmark used to live; checkmark
                // moves down-right to overlay the photo when selected.
                Image(sticker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .opacity(sticker.style.opacity * (selected ? 1.0 : 0.6))
            }
            .padding(12)
            .frame(height: 124)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Palette.accent : Palette.divider,
                            lineWidth: selected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                // Selection mark — accent rose check that pops in with
                // a small spring on selection.
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.accent)
                        .background(Circle().fill(Palette.bgPrimary))
                        .offset(x: -10, y: 10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .scaleEffect(selected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: selected)
    }

    private var selectedCoachName: String {
        switch voicePreference {
        case "keepItReal": return "Kira"
        case "encouraging": return "Jeni"
        case "balanced": return "Sam"
        default: return "coach"
        }
    }

    /// Mirror of NotificationPermission.dailyReminderBody — kept in
    /// sync so the onboarding mockup matches what the user actually
    /// receives post-grant. Don't drift.
    private var notificationPreviewBody: String {
        switch voicePreference {
        case "encouraging": return "five minutes is enough today. small moves still count."
        case "balanced":    return "sam picked a short one. easy to finish."
        default:            return "kira's got a short one ready today."
        }
    }

    private var coachFeedback: String {
        switch voicePreference {
        case "keepItReal": return "Get ready to be roasted 😏"
        case "encouraging": return "Your biggest fan is waiting 🤗"
        case "balanced": return "Chill vibes activated 😎"
        default: return "Great choice"
        }
    }

    // ═══════════════════════════════════════
    // MARK: - PHASE 5 — RESHAPE / PREDICTION / LOADING
    // ═══════════════════════════════════════

    // ─── Recap card (206) — "so here's you" ─────────────────────
    // Mid-flow earned-plan beat. Surfaces 4 of the user's own
    // collected answers (bodyFocus, daysPerWeek × sessionLength,
    // workoutLocation, the first acknowledged barrier) so the next
    // Part 6 + plan reveal feel built-for-them. Noom convergence:
    // dynamic personalization echoed back is the highest-leverage
    // welcome moment per RevenueCat's Noom funnel teardown.
    //
    // Layout: vertically centered with two beats — the recap card +
    // a small "here's what we're going to do" follow-on — so the
    // screen doesn't read as a single card floating in whitespace.
    // Sticker scatter matches the rest of the onboarding chrome.
    private var recapCardScreen: some View {
        // Use the user's name when set so the headline + card feel
        // personally addressed instead of generically "for any user".
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let nameSuffix = trimmedName.isEmpty ? "" : ", \(trimmedName.lowercased())"
        let goalAnchor = recapGoalAnchor()

        return ZStack {
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer()

                // Italic accent on "you" — JeniFit voice signal on the
                // punch word. Heart as terminal punctuation.
                ItalicAccentText("so here's you\(nameSuffix) ♥",
                                 italic: ["you"],
                                 alignment: .center)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.lg)

                // Scrapbook card. Stronger personal connection for
                // weight-loss audience: leads with the GOAL anchor
                // (lbs lost + target date) in italic-Fraunces accent —
                // that's the emotionally salient hook. The 3-4 data
                // rows sit below as supporting context. Falls back to
                // a 4-row layout when no weight-loss goal was set.
                VStack(alignment: .leading, spacing: Space.md) {
                    if let goalAnchor = goalAnchor {
                        VStack(alignment: .center, spacing: 2) {
                            Text("your goal")
                                .font(Typo.eyebrow)
                                .tracking(2)
                                .foregroundStyle(Palette.textSecondary)
                            Text(goalAnchor)
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                                .foregroundStyle(Palette.accent)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Space.xs)
                        Rectangle()
                            .fill(Palette.divider)
                            .frame(height: 1)
                            .padding(.bottom, Space.xs)
                    }
                    recapRow(recapBodyFocusLabel())
                    recapRow(recapFrequencyLabel())
                    recapRow(recapLocationLabel())
                    if let barrier = recapBarrierLabel() {
                        recapRow(barrier, italicized: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.lg)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Palette.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Palette.accent, lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.lg)

                // Closing beat — directly acknowledges the user's
                // truth and JeniFit's commitment to it. Stronger
                // emotional landing than the previous "noted. we'll
                // meet you exactly there." which read too neutral.
                VStack(spacing: Space.xs) {
                    Text("we hear you.")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                        .foregroundStyle(Palette.textPrimary)

                    Text("this plan is built around exactly this.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Space.screenPadding)

                Spacer()

                ctaBtn("continue") { Haptics.light(); go(205) }
            }
        }
        .background(Palette.bgPrimary)
    }

    /// Weight-loss goal anchor for the recap card. Returns a string
    /// like "~15 lbs lighter by Aug 14" when the user set a real loss
    /// goal (currentWeightKg > goalWeightKg + 0.5). Returns nil for
    /// maintenance / muscle-gain so the framing doesn't promise weight
    /// loss to someone who didn't ask for it. Uses existing predictionDate
    /// helper so the date matches what the rest of the flow shows.
    private func recapGoalAnchor() -> String? {
        guard currentWeightKg > goalWeightKg + 0.5 else { return nil }
        let lbsDelta = Int(((currentWeightKg - goalWeightKg) * Self.lbPerKg).rounded())
        guard lbsDelta >= 1 else { return nil }
        let dateString = formatGoalDate(predictionDate())
        return "~\(lbsDelta) lbs lighter by \(dateString)"
    }

    /// 6-sticker LIGHT scatter for the recap card (206). Edge-only so
    /// the centered card + follow-on beat stay the visual anchor.
    /// Mix of line-art + painterly, asymmetric — matches the rest of
    /// the onboarding chrome's scrapbook aesthetic.
    private static let recapPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.10, y: 0.10),
                         size: 30, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.90, y: 0.12),
                         size: 32, rotation: 12, phaseDelay: 0.15),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.07, y: 0.86),
                         size: 30, rotation: 9, phaseDelay: 0.40),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.93, y: 0.88),
                         size: 34, rotation: -10, phaseDelay: 0.55),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.05, y: 0.48),
                         size: 30, rotation: 13, phaseDelay: 0.72),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.95, y: 0.50),
                         size: 26, rotation: -12, phaseDelay: 0.88),
    ]

    private func recapRow(_ text: String, italicized: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Text("✦")
                .font(.system(size: 16))
                .foregroundStyle(Palette.accent)
            if italicized {
                Text(text)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    /// Returns a human-readable body-focus summary. Falls back to a
    /// neutral line if the user didn't pick any zones (rare — Q110
    /// requires at least one selection in the current flow).
    private func recapBodyFocusLabel() -> String {
        let labels: [String: String] = [
            "flatBelly": "flat belly",
            "tonedArms": "toned arms",
            "roundButt": "round glutes",
            "slimLegs":  "slim legs",
            "fullBody":  "full body"
        ]
        let mapped = bodyFocus.compactMap { labels[$0] }
        guard !mapped.isEmpty else { return "full body focus" }
        if mapped.count == 1 { return mapped[0] }
        if mapped.count == 2 { return "\(mapped[0]) + \(mapped[1])" }
        let head = mapped.dropLast().joined(separator: ", ")
        return "\(head), \(mapped.last!)"
    }

    /// Combines days/week + session length into one line. Falls back
    /// to the conservative default when either is unset.
    private func recapFrequencyLabel() -> String {
        let days = commitmentDaysCount(commitmentDays)
        let mins = sessionLength.isEmpty ? 7 : sessionLengthMinutes(sessionLength)
        if days > 0 { return "\(days) days, \(mins) minutes each" }
        return "\(mins) minutes a day"
    }

    /// Workout location → human-readable line.
    private func recapLocationLabel() -> String {
        switch workoutLocation {
        case "home":    return "at home, just a mat"
        case "gym":     return "at the gym"
        case "outdoor": return "outdoors"
        case "mix":     return "wherever you feel like"
        default:        return "wherever works for you"
        }
    }

    /// First acknowledged barrier as a quoted line. Italic-styled in
    /// the row to read as the user's own voice. Returns nil if none
    /// of the three barrier yes/nos came back true.
    private func recapBarrierLabel() -> String? {
        if relatability1 == true {
            return "\"workout apps make me feel further from my body\""
        }
        if relatability2 == true {
            return "\"i have no idea which workouts are right for me\""
        }
        if relatability3 == true {
            return "\"i quit when something feels too hard\""
        }
        return nil
    }

    // ─── Educational screens (230-234) — Bundle E ───────────────
    //
    // Five priming/trust screens woven into the existing flow at
    // research-validated positions. Each = one screen, one headline,
    // one body paragraph, one CTA. No skip — they're brief and
    // every user sees them (the priming effect is documented at
    // 7.5× trial-opt-in lift when education sits ahead of paywall).
    //
    // Layout matches the rest of the onboarding chrome: 4-sticker
    // LIGHT scatter, italic-Fraunces accent on the punch word(s),
    // lowercase casual body copy, terminal-only heart.
    //
    // Research justification per screen:
    //   230 (E1-a) — anti-diet-culture anchor (Fortune 2026 ranking).
    //   231 (E1-b) — Noom "why we ask" pattern (RevenueCat teardown).
    //   232 (E1-c) — Atomic Habits two-minute rule (Clear).
    //   233 (E1-d) — cycle awareness (Wild.AI / FitrWoman standard).
    //   234 (E1-e) — plateau pre-framing (StatPearls; underused).
    /// v3 P11.1.C (2026-06-10) — Apple Health permission screen.
    ///
    /// Cal AI S5 relocate. Standalone HK ask mid-onboarding (case 285).
    /// Hero copy per [[feedback-her75-editorial-register]] — silent
    /// subhead, headline carries the screen. Single shoeIridescent
    /// sticker as anchor (bound to the steps rail per design system,
    /// per [[project-steps-feature]]). Cocoa "connect" primary + "skip"
    /// text link tertiary so the funnel stays open for the ~10-15% who
    /// refuse HK.
    private struct HealthKitPermissionScreen: View {
        let onAdvance: () -> Void
        @State private var requesting = false
        @State private var done = false

        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                // her75 Phase 2 (2026-06-10) — shoeIridescent sticker
                // cut per the audit §6: borderline case, decided cut
                // for Phase 2 cohesion. If the screen reads naked on
                // device, re-introduce as a 32pt accent in Phase 4.
                ItalicAccentText(
                    "let's pull your steps + sleep.",
                    italic: ["steps", "sleep"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .padding(.horizontal, Space.screenPadding)
                Spacer()
                // v3 P11.6 — JFContinueButton with loading + skip
                // secondary. Single component replaces the previous
                // hand-rolled primary + tertiary stack.
                JFContinueButton(
                    label: done ? "connected" : "connect to health",
                    action: {
                        guard !requesting, !done else { return }
                        requesting = true
                        Task {
                            await StepsService.shared.requestAccess()
                            await MainActor.run {
                                requesting = false
                                done = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onAdvance()
                                }
                            }
                        }
                    },
                    isEnabled: !done,
                    isLoading: requesting,
                    secondaryLabel: done ? nil : "skip for now",
                    secondaryAction: done ? nil : { onAdvance() }
                )
            }
        }
    }

    /// v3 P11.1.C (2026-06-10) — BetterMe A6 consent row. Two-state
    /// checkbox-style row with italic punch word + optional "required"
    /// pill. Defaults pre-checked per BetterMe S2 pattern; user can
    /// uncheck either.
    private func consentRow(isOn: Binding<Bool>, title: String, italicWord: String, required: Bool) -> some View {
        Button {
            Haptics.light()
            isOn.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isOn.wrappedValue ? Palette.cocoaPrimary : Palette.textSecondary)
                VStack(alignment: .leading, spacing: 4) {
                    ItalicAccentText(
                        title,
                        italic: [italicWord],
                        baseFont: Typo.body,
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                        color: Palette.textPrimary,
                        alignment: .leading
                    )
                    if required {
                        Text("required")
                            .font(.system(size: 10, weight: .medium))
                            .textCase(.lowercase)
                            .tracking(0.5)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.divider, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// her75 Phase 3 — Archetype B bridge (audit §2).
    ///
    /// Pure-typography exhale moment per IMG_6280 / IMG_6281: centered
    /// 38pt hero, total cream restraint, optional ONE supporting line.
    /// Sticker param removed in Phase 2/3 — bridges are the screens
    /// where NOT decorating is the design.
    private func bridgeScreen(
        headline: String,
        italicWords: [String],
        supporting: String? = nil,
        next: Int
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()
            ItalicAccentText(
                headline,
                italic: italicWords,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .center
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .padding(.horizontal, Space.screenPadding)
            .softInRise(haptic: true)
            if let supporting {
                Text(supporting)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Space.lg)
                    .padding(.horizontal, Space.lg)
                    .softInRise(delay: 0.10)
            }
            Spacer()
            JFContinueButton(label: "continue") { go(next) }
        }
    }

    // v4.5 R4 (2026-06-11) — teach-beat register: left-aligned Didone
    // hero + ONE plain sub line + optional quiet citation row. No
    // eyebrow, no emoji, no founder signature (kill-list §E). Real
    // citations only, rendered as a hairline row (matches case 286).
    private func educationalScreen(
        headline: String,
        italicWords: [String],
        body bodyLine: String,
        next: Int,
        citation: String? = nil,
        // v4.6 (2026-06-11) — optional it-girl cutout bleeding off the
        // bottom-trailing corner (same move as the 286 sneakers).
        accentImage: String? = nil,
        // When the cutout's subject is cropped by its own canvas edge
        // (the pre-eat arms), push that edge off-screen so the cut
        // reads as "from the edge of the phone", never mid-air.
        accentFlushTrailing: Bool = false,
        accentMaxHeight: CGFloat = 320,
        // Horizontal nudge for cutouts whose subject sits off-center
        // in their own canvas (the roses lean left); positive pushes
        // toward the trailing edge.
        accentOffsetX: CGFloat = 0,
        // Kiss the LEADING screen edge, zero margin (founder round 11:
        // the chicken plate sits sticky-left).
        accentFlushLeading: Bool = false,
        // Rest the cutout's bottom directly on the CTA dock instead of
        // floating Space.xs above it (the plateau woman stands on the
        // continue button).
        accentFlushBottom: Bool = false,
        // Positive sinks the cutout BELOW the content edge; the CTA
        // dock renders on top, so the subject reads as emerging from
        // the continue button (founder round 12).
        accentOffsetY: CGFloat = 0
    ) -> some View {
        ZStack(alignment: accentFlushLeading ? .bottomLeading : .bottomTrailing) {
            if let accentImage {
                Image(accentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: accentMaxHeight)
                    .padding(.trailing, (accentFlushTrailing || accentFlushLeading) ? 0 : Space.lg)
                    .offset(
                        x: accentFlushLeading ? -6
                            : (accentFlushTrailing ? 20 : 0) + accentOffsetX,
                        y: accentOffsetY
                    )
                    .padding(.bottom, accentFlushBottom ? 0 : Space.xs)
                    .accessibilityHidden(true)
                    .softInRise(delay: 0.15, rise: 12)
            }

        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: Space.xl + Space.lg)

            ItalicAccentText(
                headline,
                italic: italicWords,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading
            )
            .kerning(-0.4)
            .lineSpacing(Typo.heroHeadlineLineGap)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.screenPadding)
            .softInRise(haptic: true)

            Spacer().frame(height: Space.lg)

            Text(bodyLine)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.screenPadding)
                .softInRise(delay: 0.10)

            if let citation {
                Spacer().frame(height: Space.md)
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Palette.divider)
                        .frame(width: 24, height: 1)
                    Text(citation)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary.opacity(0.8))
                }
                .padding(.horizontal, Space.screenPadding)
                .softInRise(delay: 0.20)
            }

            Spacer()
        }
        }
        .safeAreaInset(edge: .bottom) {
            jfCTADock {
                JFContinueButton(label: "continue") {
                    advance(to: next, confirmation: nil)
                }
            }
        }
    }

    private var educationalAntiShameScreen: some View {
        educationalScreen(
            // v4.5 R4 — merged 230+231: the anti-shame anchor carries
            // the body-data privacy promise (old 231) in its sub line.
            headline: "built for real life.",
            italicWords: ["real"],
            // v1.1 batch-1 (2026-06-23) — the merged 230+231 body had become
            // a 5-fragment run-on (and used "shared" in two senses one beat
            // apart). Unload it to the single anti-shame triplet the headline
            // promises; the privacy line moves to the quiet citation footer,
            // reworded to drop the confusing double-"shared".
            body: "5-min beats. 3-month arcs. no all-or-nothing.",
            // Founder-supplied rose bouquet (2026-06-12), replacing the
            // cactus. 380pt keeps it clear of the body copy; +90 nudge
            // sides the bouquet on the right edge (round 9) since its
            // subject leans left inside the square canvas.
            next: 1,
            citation: "what you tell us shapes your plan. never sold.",
            accentImage: "onb-filler-roses",
            accentMaxHeight: 380,
            accentOffsetX: 90
        )
    }

    // 166 — pre-eat permission wedge (delta v7 D66 expansion).
    // Lands EARLY (after the soft becoming Q + acquisition Q) so the
    // diet-first signal is unmistakable in the first 6-8 screens.
    private var educationalPreEatScreen: some View {
        educationalScreen(
            headline: "you can decide before you eat.",
            italicWords: ["before"],
            // 2026-06-23 — swapped the founder-supplied fried-chicken plate
            // for a clean produce flat-lay: it agrees with "no shame either
            // way" instead of fighting it, and reads on-brand (post-Ozempic,
            // anti-diet-culture) for the pre-eat decision wedge.
            body: "most apps make you log after. jenifit lets you snap before. see if it fits. no shame either way.",
            next: 156,
            accentImage: "onb-itgirl-produce",
            accentMaxHeight: 320,
            accentFlushLeading: true
        )
    }

    // 234 (E1-e) — plateau pre-framing (ACSM 2024 on metabolic
    // adaptation, the canonical plateau mechanism).
    private var educationalPlateauScreen: some View {
        educationalScreen(
            headline: "the scale stalls around week 3. that's good.",
            italicWords: ["good"],
            // Founder-supplied woman cutout (round 12 sizing): smaller,
            // shifted right, sunk 36pt under the dock so she reads as
            // coming out of the continue button.
            body: "plateaus mean adaptation, not failure. jeni tells you what to change. no panic.",
            next: 21,
            citation: "acsm 2024",
            accentImage: "onb-itgirl-plateau",
            accentMaxHeight: 335,
            accentOffsetX: 26,
            accentFlushBottom: true,
            accentOffsetY: 36
        )
    }

    // ─── Consent ritual (240) — pinky-promise long-press ────────
    //
    // 2.8s press-and-hold pledge mechanic. Research basis (full audit
    // saved in earlier session): Cialdini commitment & consistency
    // (Freedman & Fraser foot-in-the-door, ~400% follow-through lift
    // for small written commitments); Nyer & Dellande 2010 weight-
    // loss commitment study (written > verbal); James Clear habit
    // contract template (stripped of punishment clause for the
    // women-fitness-2026 audience per Drake & Salinas femvertising
    // research).
    //
    // Mechanics:
    //   - Press-and-hold detected via DragGesture(minimumDistance: 0)
    //     so it fires immediately on touchdown.
    //   - Timer increments holdProgress 0→1 over 2.8s. Halfway haptic
    //     tick at 0.5 + success haptic + confetti at 1.0.
    //   - Release before completion fades the progress to 0 silently
    //     (no error haptic — explicitly non-shaming per audience).
    //   - On completion: route to 215 (rating prefilter) after a
    //     0.8s confetti beat.
    //   - "maybe later" routes straight to 215 with a skip event.
    //
    // Trial-end / paywall etc. are downstream of this screen via 215
    // → 26 → 22 → 23 → finish() → RootView paywall cover.
    /// Three brand-promise screens that replace the press-and-hold
    /// consent signature ritual. Each is a single-tap-through screen
    /// with a sticker hero, italic-Fraunces-accented headline, and a
    /// warm CTA. The trio fires immediately after plan reveal (per
    /// epic #1 child #5 — IKEA-effect freshest, reciprocity > forced
    /// commitment for TikTok-acquired Gen Z).
    ///
    /// Old consent_ritual_* events keep firing in parallel for 14 days
    /// (remove after 2026-06-13) so existing PostHog funnel reports
    /// don't break during the migration window.
    private struct BrandPromise {
        let prefix: String
        let italic: String
        let suffix: String
        let cta: String
        let stickerName: StickerName
    }

    private static let brandPromises: [BrandPromise] = [
        BrandPromise(
            prefix: "i promise to ",
            italic: "never",
            suffix: " make you weigh in unless you want to.",
            cta: "thank you, jeni",
            stickerName: .heartGlossy
        ),
        BrandPromise(
            prefix: "i promise no before-and-after photos. ",
            italic: "ever",
            suffix: ".",
            cta: "i needed to hear that",
            stickerName: .bowIridescent
        ),
        BrandPromise(
            prefix: "i promise your data stays ",
            italic: "yours",
            suffix: ". we never sell it.",
            cta: "let's go",
            stickerName: .sparkleGlossy
        ),
    ]

    /// 4-sticker LIGHT scatter for the brand-promises screen. Edge-only
    /// — mirrors the consent-ritual placement coordinates from v1.0.6
    /// so the visual rhythm of this onboarding moment stays continuous
    /// across the 2026-05-30 reframe. Heart + sparkle on top corners,
    /// bow + ribbon on bottom corners.
    private static let brandPromisesPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.10, y: 0.12),
                         size: 30, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.90, y: 0.14),
                         size: 32, rotation: 12, phaseDelay: 0.25),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.08, y: 0.88),
                         size: 30, rotation: 11, phaseDelay: 0.55),
        StickerPlacement(sticker: .ribbonLineart,
                         position: CGPoint(x: 0.92, y: 0.86),
                         size: 28, rotation: -10, phaseDelay: 0.80),
    ]

    /// 2026-05-30 visual upgrade: wraps the promise in the canonical
    /// scrapbook chrome (24pt corners, 1.5pt accent border, hard offset
    /// shadow) to match the visual language of Home, Becoming tiles,
    /// Settings sub-pages, and AnalyticsView modules. Pre-upgrade the
    /// screen was a flat text+sticker block that read thinner than the
    /// rest of the onboarding moments around it. Sticker scatter +
    /// "promise N of 3" eyebrow + per-promise card transition adds the
    /// missing visual weight to the brand-trust moment.
    private var brandPromisesScreen: some View {
        let promise = Self.brandPromises[brandPromiseIndex]
        return ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            // Sticker scatter — edge-only, matches consent-ritual
            // placement coordinates (the screen we replaced) so the
            // visual rhythm of the onboarding endgame stays continuous.
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer()

                // Eyebrow — "promise N of 3" — anchors progress without
                // a separate pagination row. Italic-Fraunces voice on the
                // count word per locked voice signals.
                (Text("promise ")
                    .font(Typo.eyebrow)
                 + Text("\(brandPromiseIndex + 1)")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                 + Text(" of 3")
                    .font(Typo.eyebrow))
                    .tracking(2)
                    .foregroundStyle(Palette.accent)
                    .padding(.bottom, Space.md)

                // The promise itself, wrapped in scrapbook chrome. The
                // card transition uses .id(brandPromiseIndex) so each
                // promise is a fresh view — SwiftUI animates the swap
                // as a soft cross-fade with Motion.crossFade, the same
                // animation grammar as the rest of the onboarding flow.
                VStack(spacing: Space.lg) {
                    // Hero sticker — sits inside the card now, scaled
                    // down slightly (96→80) so the headline can breathe.
                    Image(promise.stickerName.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .opacity(promise.stickerName.style.opacity)
                        .padding(.top, Space.md)

                    // Headline with italic Fraunces on the punch word.
                    (Text(promise.prefix)
                        .font(.custom("Fraunces72pt-SemiBold", size: 26))
                     + Text(promise.italic)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                     + Text(promise.suffix)
                        .font(.custom("Fraunces72pt-SemiBold", size: 26)))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: Space.sm)
                }
                .padding(.vertical, Space.lg)
                .padding(.horizontal, Space.md)
                .frame(maxWidth: .infinity)
                .scrapbookCardBackground()
                .padding(.horizontal, Space.screenPadding)
                .id(brandPromiseIndex)
                .transition(.opacity)

                Spacer()

                // Pagination dots — kept as a secondary progress signal
                // below the card. Filled dots tick across as user
                // advances, giving a calmer second confirmation of where
                // they are in the trio (vs. just the eyebrow count).
                HStack(spacing: 6) {
                    ForEach(0..<Self.brandPromises.count, id: \.self) { index in
                        Capsule()
                            .fill(index <= brandPromiseIndex ? Palette.accent : Palette.divider)
                            .frame(width: index == brandPromiseIndex ? 18 : 6, height: 6)
                            .animation(Motion.gentleSpring, value: brandPromiseIndex)
                    }
                }
                .padding(.bottom, Space.lg)

                // CTA — tap to advance to next promise or finish on third.
                ctaBtn(promise.cta) {
                    Haptics.light()
                    advanceBrandPromise()
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.lg)
            }
        }
        .onAppear {
            if brandPromiseIndex == 0 && brandPromisesStartTime == nil {
                brandPromisesStartTime = Date()
                Analytics.track(.brandPromisesStarted, properties: [
                    "placement": "post_plan_reveal"
                ])
                // Migration shim — keep firing old event until 2026-06-13
                // so existing PostHog funnels don't break.
                Analytics.track(.consentRitualViewed)
            }
        }
        .onDisappear {
            // If user backgrounded mid-flow without finishing all 3,
            // fire abandoned. The completed path nulls
            // brandPromisesStartTime first so this no-ops on normal
            // completion.
            if let started = brandPromisesStartTime,
               brandPromiseIndex < Self.brandPromises.count - 1 {
                let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
                Analytics.track(.brandPromisesAbandoned, properties: [
                    "last_promise_index": brandPromiseIndex,
                    "time_to_abandon_ms": elapsedMs
                ])
                // Migration shim
                Analytics.track(.consentRitualAbandoned, properties: [
                    "progress_at_abandon": Double(brandPromiseIndex) / Double(Self.brandPromises.count)
                ])
            }
        }
    }

    private func advanceBrandPromise() {
        if brandPromiseIndex < Self.brandPromises.count - 1 {
            // crossFade matches Motion grammar used elsewhere in
            // onboarding for screen-to-screen transitions. The .id()
            // modifier on the card wrapper means SwiftUI treats each
            // promise as a fresh view and animates the swap as a soft
            // opacity fade rather than a snap.
            withAnimation(Motion.crossFade) { brandPromiseIndex += 1 }
        } else {
            // All 3 done — route to method preview. 2026-06-01 flicker
            // fix: removed the `brandPromiseIndex = 0` reset that fired
            // BEFORE the 0.3s delay below — it caused the view to
            // re-render showing promise 1 during the transition out,
            // creating a visible flicker on tap. Now the index stays
            // at 2 (promise 3) through the disappear. Analytics guarded
            // by brandPromisesStartTime so a back-nav re-tap doesn't
            // double-fire completed events.
            if let started = brandPromisesStartTime {
                let elapsedMs = Int(Date().timeIntervalSince(started) * 1000)
                Analytics.track(.brandPromisesCompleted, properties: [
                    "tap_count": Self.brandPromises.count,
                    "total_duration_ms": elapsedMs
                ])
                // Migration shim
                Analytics.track(.consentRitualSigned)
                brandPromisesStartTime = nil  // suppress .onDisappear abandoned + analytics double-fire
            }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                go(250)  // method preview — see new flow comment at case 240 routing
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Method preview (case 250)
    // ═══════════════════════════════════════
    //
    // The "what you get with me" screen. Sits between plan reveal (21)
    // and consent (240). Tease for the only post-purchase feature — the
    // daily 5-minute Jeni ritual — so the consent ritual signs against
    // a specific *thing* (a 5-day immersion) rather than an abstract
    // plan. Day teasers map to the actual canonical hero lines in
    // JeniMethodRitualContent so the preview is honest (data provenance
    // rule). Audio sample plays a coach-voiced intro line; if the
    // bundled clip is absent the button disables visibly so the screen
    // doesn't lie about an audio it can't play.

    private var methodPreviewScreen: some View {
        let coachName = coachDisplayNameForVoicePref()

        // Compact pass (2026-05-26): the continue CTA was below the
        // fold on iPhone 17 Pro — user feedback after launch. Shrunk
        // hero card 280→180pt, headline 28→24pt, day-row vertical
        // padding 6→2, replaced all Space.lg between sections with
        // Space.sm. Net cut ~180pt → CTA visible in first viewport.
        return ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer().frame(height: Space.md)

                // v4.5 R4 — AI coach portrait + eyebrow caps killed
                // (Direction A: no AI faces; kill-list: no eyebrow).
                // The day-one white card IS the hero now (her75-3).
                ItalicAccentText(
                    "5 minutes. every day. that's the whole program.",
                    italic: ["5 minutes."],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 24),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 24),
                    alignment: .center
                )
                .padding(.horizontal, Space.screenPadding)
                .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 4)

                Text("i show up in your phone. we breathe. you go on with your day.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.screenPadding)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: Space.md)

                // her75 day-one card register: white, shadow-only, serif
                // masthead, numbered serif rows. Day teasers map to the
                // canonical Day 1-5 ritual arcs (data provenance).
                VStack(alignment: .leading, spacing: 10) {
                    (Text("the ").font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                     + Text("method").font(.custom("Fraunces72pt-SemiBold", size: 26)))
                        .foregroundStyle(Palette.textPrimary)

                    VStack(spacing: 6) {
                        methodPreviewDayRow(day: 1,
                                            base: "the part nobody told you about ",
                                            italic: "fat loss",
                                            suffix: ".")
                        methodPreviewDayRow(day: 2,
                                            base: "what crash diets ",
                                            italic: "steal",
                                            suffix: " from you.")
                        methodPreviewDayRow(day: 3,
                                            base: "why your plan ",
                                            italic: "protects",
                                            suffix: " you.")
                        methodPreviewDayRow(day: 4,
                                            base: "eat to ",
                                            italic: "fuel,",
                                            suffix: " not to punish.")
                        methodPreviewDayRow(day: 5,
                                            base: "what the scale ",
                                            italic: "won't tell you",
                                            suffix: ".")
                    }
                }
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Palette.bgElevated)
                        .shadow(color: Palette.cocoaPrimary.opacity(0.10), radius: 14, x: 0, y: 6)
                )
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)

                // Audio sample — slim pill, no portrait chrome.
                Button {
                    togglePreviewSample()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: methodPreviewIsPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(audioButtonLabel(coachName: coachName))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.bgInverse))
                }
                .buttonStyle(PressFeedbackStyle())
                .opacity(methodPreviewAudioMissing ? 0.45 : 1.0)
                .disabled(methodPreviewAudioMissing)
                .accessibilityLabel(methodPreviewIsPlaying
                    ? "Stop \(coachName) sample"
                    : "Play \(coachName) sample")

                Spacer().frame(height: Space.sm)

                Text("led by \(coachName) · ambient sound · 3-4 min")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer(minLength: Space.sm)

                ctaBtn("continue") {
                    Haptics.medium()
                    Analytics.track(.methodPreviewContinued)
                    stopMethodPreviewSample()
                    // Post-2026-05-30 flow: brand promises (240) moved
                    // BEFORE method preview (250), so this routes directly
                    // to the review prompt prefilter (215) instead.
                    go(215)
                }
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)
            }
        }
        .onAppear {
            Analytics.track(.methodPreviewViewed)
            prepareMethodPreviewAudio()
        }
        .onDisappear { stopMethodPreviewSample() }
    }

    /// Hero card on case 250 — coach portrait in a soft pink mat with
    /// "DAY 1: READY" pill + audio-sample button. Compact 180pt height
    /// (was 280pt) so the continue CTA stays above the fold on iPhone
    /// 17 Pro. Coach portrait still reads at this size, audio button
    /// + pill + audio button stack still fits via tightened padding.
    private func audioButtonLabel(coachName: String) -> String {
        if methodPreviewAudioMissing { return "audio coming soon" }
        return methodPreviewIsPlaying ? "playing…" : "hear \(coachName.lowercased())"
    }

    /// One day-teaser row. The italic word is the JeniFit voice signal —
    /// italic-Fraunces only on the punch word, base + suffix in DMSans.
    /// Compact spacing (24pt circle, 14pt body, vertical padding 2) so
    /// 5 rows fit in ~150pt without crowding the CTA below.
    private func methodPreviewDayRow(day: Int, base: String, italic: String, suffix: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: 24, height: 24)
                Text("\(day)")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.accent)
            }

            (Text(base)
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundStyle(Palette.textPrimary)
             + Text(italic)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                .foregroundStyle(Palette.textPrimary)
             + Text(suffix)
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundStyle(Palette.textPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Method preview audio
    //
    // The preview button plays a short coach-voiced intro line so the
    // user hears Jeni's (or Kira's / Sam's) actual voice before they
    // commit. Until the ElevenLabs clips ship the button disables
    // visibly — the screen never plays silence.
    //
    // Expected bundled resources (drop into PlankApp/Resources/VoiceClips/
    // once generated via the ElevenLabs pipeline):
    //   - method_preview_jeni.m4a    (encouraging)
    //   - method_preview_kira.m4a    (keepItReal)
    //   - method_preview_matson.m4a  (balanced — display name "Sam")
    //
    // ElevenLabs script per coach (~8s, lowercase casual, ritual cadence
    // — mirrors the canonical Day 1 intro beats in JeniMethodRitual.swift):
    //
    //   "i'm [jeni / kira / sam]. i made this because nothing else fit me.
    //    five minutes a day. every day. that's all i'm asking."

    private func coachDisplayNameForVoicePref() -> String {
        switch voicePreference {
        case "encouraging": return "Jeni"
        case "balanced":    return "Sam"
        case "keepItReal":  return "Kira"
        default:            return "Jeni"
        }
    }


    private func methodPreviewAudioFilename() -> String {
        switch voicePreference {
        case "encouraging": return "method_preview_jeni"
        case "balanced":    return "method_preview_matson"
        case "keepItReal":  return "method_preview_kira"
        default:            return "method_preview_jeni"
        }
    }

    private func prepareMethodPreviewAudio() {
        let name = methodPreviewAudioFilename()
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            methodPreviewAudioMissing = true
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            methodPreviewAudioPlayer = player
            methodPreviewAudioMissing = false
        } catch {
            #if DEBUG
            print("[MethodPreview] audio prep FAILED: \(error)")
            #endif
            methodPreviewAudioMissing = true
        }
    }

    private func togglePreviewSample() {
        Haptics.light()
        if methodPreviewIsPlaying {
            stopMethodPreviewSample()
        } else {
            startMethodPreviewSample()
        }
    }

    private func startMethodPreviewSample() {
        guard let player = methodPreviewAudioPlayer else { return }
        Analytics.track(.methodPreviewAudioPlayed)
        player.currentTime = 0
        player.play()
        methodPreviewIsPlaying = true

        // Reset the icon when playback finishes naturally. Tasks
        // captured by the View struct land on MainActor; the isPlaying
        // guard against the player itself prevents a stale flip if the
        // user re-tapped play before the first asyncAfter fired.
        let duration = player.duration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64((duration + 0.1) * 1_000_000_000))
            if let p = methodPreviewAudioPlayer, !p.isPlaying {
                methodPreviewIsPlaying = false
            }
        }
    }

    private func stopMethodPreviewSample() {
        methodPreviewAudioPlayer?.stop()
        methodPreviewIsPlaying = false
    }

    /// 4-sticker LIGHT scatter for the method preview. Edge-only so the
    /// hero card + day list have a clean canvas.
    private static let methodPreviewPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.08, y: 0.06),
                         size: 30, rotation: -12, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.93, y: 0.08),
                         size: 26, rotation: 13, phaseDelay: 0.32),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.07, y: 0.94),
                         size: 30, rotation: 10, phaseDelay: 0.62),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.93, y: 0.94),
                         size: 32, rotation: -10, phaseDelay: 0.86),
    ]

    // ═══════════════════════════════════════
    // MARK: - Tier-ladder identity preview (case 260)
    // ═══════════════════════════════════════
    //
    // Phase 3 conversion beat. Shows the user what each week of
    // showing up *feels* like in identity terms, not weight numbers.
    // 3 milestone cards stacked vertically:
    //   week 1 — building   (rhythm starts)
    //   week 3 — steady     (stops feeling hard)
    //   week 8 — stronger   (small wins compound)
    //
    // Companion to case 142 (past vs steady). The comparison frames
    // "this time is different"; the tier ladder shows what different
    // *means* week-by-week. Both screens activate identity (Bandura
    // 2007 / Annesi 2011 self-efficacy + Mastery Curve) instead of
    // outcome promise — TikTok-content-moderation-safe per the 2026
    // audience research.

    private var tierLadderScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Space.lg)

                    Text("WHAT EACH WEEK FEELS LIKE")
                        .font(Typo.eyebrow)
                        .tracking(2)
                        .foregroundStyle(Palette.accent)

                    Spacer().frame(height: Space.md)

                    ItalicAccentText(
                        "progress is quieter than you think.",
                        italic: ["quieter"],
                        baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                        alignment: .center
                    )
                    .padding(.horizontal, Space.screenPadding)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: Space.sm)

                    Text("not scale numbers. not photos. real shifts in how showing up feels.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.screenPadding)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: Space.lg)

                    VStack(spacing: Space.sm) {
                        tierLadderRow(
                            week: "week 1",
                            label: "building",
                            italicLabel: "building",
                            detail: "the rhythm starts. 5 minutes feels long. that's ok."
                        )
                        tierLadderRow(
                            week: "week 3",
                            label: "steady",
                            italicLabel: "steady",
                            detail: "it stops feeling like effort. you stop thinking about it."
                        )
                        tierLadderRow(
                            week: "week 8",
                            label: "stronger",
                            italicLabel: "stronger",
                            detail: "small wins compound. your body feels different first."
                        )
                    }
                    .padding(.horizontal, Space.screenPadding)

                    Spacer().frame(height: Space.lg)

                    Text("based on bandura + annesi 2011 self-efficacy research.")
                        .font(.system(size: 11))
                        .italic()
                        .foregroundStyle(Palette.textSecondary.opacity(0.85))
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: Space.lg)

                    ctaBtn("i'm in") {
                        Haptics.medium()
                        go(204)
                    }
                    .padding(.horizontal, Space.screenPadding)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .onAppear {
            Analytics.track(.tierLadderViewed)
        }
    }

    /// One milestone row on the tier ladder. Layout: small week
    /// badge on the left, italic-Fraunces label as the title, peer-
    /// voice detail line. Soft accent border to distinguish from
    /// the question-screen rows.
    private func tierLadderRow(week: String, label: String, italicLabel: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(week.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.accent.opacity(0.12), in: Capsule())
            }
            .frame(width: 76, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    /// 4-sticker LIGHT scatter for the tier ladder. Edge-only.
    private static let tierLadderPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .ribbonLineart,
                         position: CGPoint(x: 0.09, y: 0.06),
                         size: 30, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 30, rotation: 12, phaseDelay: 0.30),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.08, y: 0.94),
                         size: 28, rotation: 9, phaseDelay: 0.60),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.93, y: 0.94),
                         size: 26, rotation: -11, phaseDelay: 0.85),
    ]

    // ═══════════════════════════════════════
    // MARK: - Habit-window quiz (case 270)
    // ═══════════════════════════════════════
    //
    // Phase 4 education-as-quiz. One question, 3 options, reveal +
    // 1-sentence research citation. Teaches the 12-week / 3-month
    // habit-window frame (Lally 2010, Kaushal & Rhodes 2015) that
    // JeniFit's Becoming tab already plans around. Delivers value
    // pre-paywall — antidote to "long onboarding = data extraction"
    // perception (Noom-research finding).
    //
    // No right-answer gating: tapping any option flips
    // habitQuizRevealed → true and the reveal explains why C is
    // correct + cites the research. Continue button always enabled
    // after a tap; reading the reveal isn't required to advance.

    private let habitQuizCorrectIndex: Int = 2

    private var habitWindowQuizScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: Space.lg)

                    Text("QUICK ONE")
                        .font(Typo.eyebrow)
                        .tracking(2)
                        .foregroundStyle(Palette.accent)

                    Spacer().frame(height: Space.md)

                    ItalicAccentText(
                        "how long does a habit actually take to stick?",
                        italic: ["stick"],
                        baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                        italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                        alignment: .center
                    )
                    .padding(.horizontal, Space.screenPadding)
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: Space.lg)

                    VStack(spacing: 10) {
                        habitQuizOption(index: 0, label: "7 days",  hint: "the “21-day myth” cousin")
                        habitQuizOption(index: 1, label: "30 days", hint: "the social-media version")
                        habitQuizOption(index: 2, label: "~12 weeks", hint: "the science")
                    }
                    .padding(.horizontal, Space.screenPadding)

                    Spacer().frame(height: Space.lg)

                    // Reveal panel — fades in after any tap. Always
                    // teaches the right answer + cites research.
                    if habitQuizRevealed {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("THE SCIENCE")
                                .font(Typo.eyebrow)
                                .tracking(2)
                                .foregroundStyle(Palette.accent)

                            ItalicAccentText(
                                "habits stabilize around 66 days. give or take.",
                                italic: ["66 days"],
                                baseFont: .custom("Fraunces72pt-SemiBold", size: 17),
                                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 17),
                                alignment: .leading
                            )
                            .fixedSize(horizontal: false, vertical: true)

                            Text("lally et al. 2010 + kaushal & rhodes 2015. that's why we plan in 12-week windows. long enough to land, short enough to feel.")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(Space.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Palette.accentSubtle.opacity(0.55))
                        )
                        .padding(.horizontal, Space.screenPadding)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                    }

                    Spacer().frame(height: Space.lg)

                    ctaBtn(habitQuizRevealed ? "continue" : "tap an answer") {
                        guard habitQuizRevealed else { return }
                        Haptics.medium()
                        go(202)
                    }
                    .opacity(habitQuizRevealed ? 1.0 : 0.45)
                    .disabled(!habitQuizRevealed)
                    .padding(.horizontal, Space.screenPadding)

                    Spacer().frame(height: Space.lg)
                }
            }
        }
        .onAppear {
            Analytics.track(.quizViewed,
                            properties: ["quiz_id": "habit_window"])
        }
    }

    /// One quiz option row. Selected state shows correct/incorrect
    /// styling AFTER tap (the user always learns the right answer
    /// from the reveal panel below, but visual feedback on the row
    /// they tapped reinforces the learning).
    private func habitQuizOption(index: Int, label: String, hint: String) -> some View {
        let isSelected = habitQuizSelected == index
        let isCorrect = index == habitQuizCorrectIndex
        let showCorrect = habitQuizRevealed && isSelected && isCorrect
        let showWrong   = habitQuizRevealed && isSelected && !isCorrect

        return Button {
            guard !habitQuizRevealed else { return }
            Haptics.light()
            withAnimation(Motion.entranceSoft) {
                habitQuizSelected = index
                habitQuizRevealed = true
            }
            if isCorrect { Haptics.success() }
            Analytics.track(.quizAnswered, properties: [
                "quiz_id": "habit_window",
                "selected_index": index,
                "correct": isCorrect
            ])
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(showCorrect ? Palette.stateGood
                                : showWrong ? Palette.stateBad
                                : Palette.divider,
                                lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if showCorrect {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.stateGood)
                    } else if showWrong {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.stateBad)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(hint)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(showCorrect ? Palette.stateGood
                                    : showWrong ? Palette.stateBad
                                    : (isSelected ? Palette.accent : Palette.divider),
                                    lineWidth: (isSelected || showCorrect || showWrong) ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(habitQuizRevealed)
        .accessibilityElement(children: .combine)
    }

    /// 4-sticker LIGHT scatter for the habit-window quiz.
    private static let habitQuizPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.08, y: 0.06),
                         size: 28, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 26, rotation: 12, phaseDelay: 0.30),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.07, y: 0.94),
                         size: 30, rotation: 10, phaseDelay: 0.60),
        StickerPlacement(sticker: .bowSatin,
                         position: CGPoint(x: 0.93, y: 0.94),
                         size: 28, rotation: -10, phaseDelay: 0.85),
    ]

    // Reshape transition (160). The "stubborn fat will shed" moment
    // reframed for empowerment: no before/after pairing, no shame-coded
    // labels — just the radiant goal-state body and supportive copy.
    // Annotations call out positive markers (strong core, lifted energy)
    // rather than naming what's "wrong" about the current body.
    // v4.6 (2026-06-11): AI-character render replaced with the it-girl
    // editorial cutout (from behind, sage set) per founder direction.
    private var reshapeTransitionScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

            ItalicAccentText("your body will reshape. quietly.",
                             italic: ["quietly"],
                             alignment: .center)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.sm)

            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.accent)
                .frame(width: 60, height: 1)

            Spacer().frame(height: Space.md)

            ZStack(alignment: .topTrailing) {
                Image("onb-itgirl-reshape")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 380)
                    .accessibilityHidden(true)

                // Positive callouts — what the plan builds toward.
                // Stacked top-right to leave the body image clear.
                VStack(alignment: .leading, spacing: 10) {
                    callout("strong core")
                    callout("lifted energy")
                }
                .padding(.top, Space.lg)
                .padding(.trailing, Space.sm)
            }

            Spacer().frame(height: Space.md)

            Text("steady wins. no crash, no rebound. that's how it sticks.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Continue") { Haptics.medium(); go(161) }
        }
    }

    /// Pill-shaped positive callout used on the reshape screen. Soft
    /// accent-rose chip with a leading dot — reads as a label, not a
    /// diagnostic.
    private func callout(_ text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.accentSubtle, in: Capsule())
    }

    // First weight prediction (161). 2026 voice refresh — "you could
    // be at [X] by [date]" instead of "We predict you'll be …". Drops
    // the corporate "we predict" voice; "could" frames the chart as a
    // projection from the user's own inputs, not a promise (post-Ozempic
    // safe + TikTok-moderation safe per the 2026 audience research).
    private var firstPredictionScreen: some View {
        ZStack {
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.
            // C2 + chart-fill (2026-06-01): .rough chart styling +
            // headline now clearly labels 138 lb as "the goal" (prior
            // "roughly, around 138 lb." read as floating). Below-chart
            // slot shows the inputs we'll use to sharpen — Zeigarnik
            // + anticipation pattern (the user sees what's still
            // coming, which lifts continuation intent).
            predictionScreen(
                eyebrow: "rough sketch",
                headlinePrefix: "goal: ",
                headlineSuffix: ".",
                subhead: "early estimate. it sharpens as you answer more.",
                badge: nil,
                target: predictionDate(),
                next: 203,
                style: .rough,
                belowChart: { stillToSharpenRow }
            )
        }
        .onAppear {
            Analytics.track(.projectionChartViewed,
                            properties: ["placement": "first_prediction"])
        }
    }

    /// "Still to sharpen" + trust anchor — fills the rough-chart screen
    /// (case 161) with two layers: (1) anticipation chips listing upcoming
    /// credibility-grade inputs, (2) inline trust anchor with science
    /// citation + founder voice. Conversion levers: Zeigarnik anticipation,
    /// research credibility (ZOE-pattern), founder intimacy.
    private var stillToSharpenRow: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("STILL TO SHARPEN")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 6) {
                    ForEach(["sleep", "cycle", "eating", "stress"], id: \.self) { item in
                        Text(item)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().stroke(Palette.divider, lineWidth: 1))
                    }
                }
            }

            // Trust anchor — small italic-Fraunces founder voice + science chip
            HStack(spacing: 8) {
                Text("acsm 0.5-1%/wk")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().stroke(Palette.divider, lineWidth: 1))

                (Text("the ")
                    .font(.custom("Fraunces72pt-Regular", size: 13))
                 + Text("sustainable")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                 + Text(" band."))
                    .font(.custom("Fraunces72pt-Regular", size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Re-prediction (170). 2026 voice refresh — drops the "Still on
    // track!" corporate badge (reads like a fitness-coach pat-on-the-
    // back from 2018). New eyebrow "we got more honest" frames the
    // update as the projection getting *sharper* from the user's
    // subsequent inputs — the "movement between projections" is the
    // documented conversion lever (Noom + Cal AI).
    //
    // Phase 3: routes to case 260 (tier-ladder identity preview)
    // instead of jumping straight to Part 5 divider (204). The tier
    // ladder gives the user a concrete "what each week feels like"
    // beat right after the projection number, so progression reads
    // as identity, not just a date.
    private var rePredictionScreen: some View {
        // C2 (2026-06-01): renders in .sharp style — solid stroke, date
        // pill, week-one callout, sparkle. The user just saw the .rough
        // version at case 161; this beat reads as "the chart sharpened"
        // because it visually IS more refined. That visual delta is the
        // documented Noom + Cal AI conversion lever — "watching it
        // sharpen" is far stronger than "watching it stay the same."
        predictionScreen(
            eyebrow: "we got more honest",
            headlinePrefix: "now: ",
            headlineSuffix: ".",
            subhead: "your real context pulled this in.",
            badge: nil,
            target: rePredictionDate(),
            next: 260,
            style: .sharp,
            belowChart: { yourContextChips }
        )
        .onAppear {
            Analytics.track(.projectionChartViewed,
                            properties: ["placement": "re_prediction"])
        }
    }

    /// Below-chart fill for case 170 (sharp chart). Three sections:
    /// (1) "your real context" chips reflecting actual user answers,
    /// (2) intermediate milestone breakdown (week 4 + goal) computed
    /// from real weights — goal-gradient theory (Hull 1932, Kivetz) =
    /// visible intermediate targets boost completion intent, (3) trust
    /// anchor with citation + founder voice. The screen now carries
    /// 3 conversion layers below the chart instead of one chip row.
    @ViewBuilder
    private var yourContextChips: some View {
        let chips = currentContextChips
        VStack(alignment: .leading, spacing: Space.md) {

            // SECTION 1 — Real context chips
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("YOUR REAL CONTEXT")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Palette.textSecondary)

                if chips.isEmpty {
                    Text("we used your weight, goal, and activity.")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                } else {
                    HStack(spacing: 6) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().stroke(Palette.divider, lineWidth: 1))
                                .fixedSize()
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            // SECTION 2 — Milestone breakdown (goal-gradient lever)
            milestoneBreakdown

            // SECTION 3 — Trust anchor
            HStack(spacing: 8) {
                Text("acsm 2024")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().stroke(Palette.divider, lineWidth: 1))

                (Text("steady. real. ")
                    .font(.custom("Fraunces72pt-Regular", size: 13))
                 + Text("yours")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                 + Text("."))
                    .font(.custom("Fraunces72pt-Regular", size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Linear interpolation along the projection: shows the user her
    /// expected weight at week 4 + final goal. Concrete intermediate
    /// markers are the canonical goal-gradient lever (Hull 1932,
    /// Kivetz et al.). Skipped when no real loss goal (currentKg <=
    /// goalKg) to avoid showing 2 identical rows.
    @ViewBuilder
    private var milestoneBreakdown: some View {
        if currentWeightKg > goalWeightKg {
            let totalDays = ProjectionMath.projectedDays(
                currentKg: currentWeightKg,
                goalKg: goalWeightKg,
                paceKey: paceChoice
            )
            let week4kg = currentWeightKg + (goalWeightKg - currentWeightKg)
                * Double(min(28, totalDays)) / Double(max(totalDays, 1))
            let week4Label = weightLabel(kg: week4kg)
            let goalLabel = weightLabel(kg: goalWeightKg)

            VStack(alignment: .leading, spacing: 6) {
                Text("MILESTONES")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.6)
                    .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 6) {
                    Text("week 4 · ~\(week4Label)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent.opacity(0.08)))
                    Text("goal · \(goalLabel)")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent.opacity(0.14)))
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Derive 2-4 chip strings from the user's actual answers. Same
    /// pattern as `OnboardingRevealView.ProjectionPresentation.contextChips`
    /// (intentional — same data surfaced consistently across both reveals).
    private var currentContextChips: [String] {
        @AppStorage("onboardingSleepHours")    var sleepHours: String = ""
        @AppStorage("onboardingEatingCadence") var eatingCadence: String = ""
        @AppStorage("onboardingHormonalStage") var hormonalStage: String = ""
        @AppStorage("onboarding_glp1_status")  var glp1Status: String = ""

        var chips: [String] = []
        switch sleepHours {
        case "under5":    chips.append("under 5 hr sleep")
        case "five6":     chips.append("5-6 hr sleep")
        case "six7":      chips.append("6-7 hr sleep")
        case "seven8":    chips.append("7-8 hr sleep")
        case "eightPlus": chips.append("8+ hr sleep")
        default: break
        }
        switch eatingCadence {
        case "one_meal":    chips.append("one-meal pattern")
        case "two_meals":   chips.append("2-meal rhythm")
        case "three_meals": chips.append("steady 3 meals")
        case "grazing":     chips.append("graze pattern")
        case "chaotic":     chips.append("chaos pattern")
        default: break
        }
        switch hormonalStage {
        case "cycling":       chips.append("cycling")
        case "irregular":     chips.append("irregular cycle")
        case "postpartum":    chips.append("postpartum")
        case "perimenopause": chips.append("peri")
        case "postmenopause": chips.append("post")
        default: break
        }
        if glp1Status == "current" { chips.append("on GLP-1") }
        return Array(chips.prefix(4))
    }

    // Final prediction (181) — runs after the loading carousel, hands off
    // to the redesigned plan reveal. 2026 voice refresh: lowercase + italic
    // accent on "ready" instead of the older capitalized "Based on your
    // answers, your plan is ready."
    private var finalPredictionScreen: some View {
        ZStack {
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer().frame(height: Space.lg)

                ItalicAccentText(
                    "based on what you told me, your plan is ready.",
                    italic: ["ready"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 26),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                    alignment: .center
                )
                .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.sm)

                predictionHeadline()
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)

                // Projection chart already animates via .trim — see
                // WeightCurveView header for choreography (t≈1.55s for
                // the date pill to land). The two events bracket the
                // animation so funnel queries can tell whether users
                // actually watch it or skip past.
                weightCurve()
                    .frame(height: 180)
                    .padding(.horizontal, Space.screenPadding)
                    .onAppear {
                        Analytics.track(.projectionChartViewed,
                                        properties: ["placement": "final_prediction"])
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            Analytics.track(.projectionChartAnimationCompleted,
                                            properties: ["placement": "final_prediction"])
                        }
                    }

                Spacer().frame(height: Space.lg)

                // First-week calendar dots — represents the first 9 days of
                // workouts. Accent dots for committed days, divider for rest.
                firstWeekCalendar()
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)

                Text("designed by trainers, built around your answers.")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.screenPadding)

                Spacer()

                // Routes to E1-e (case 234, plateau pre-frame) →
                // case 21 plan reveal. Plateau education immediately
                // before the high-trust reveal reduces week-3 churn.
                ctaBtn("show me my plan") { Haptics.heavy(); go(234) }
            }
        }
    }

    // Shared layout for the first prediction + re-prediction. Both render
    // a curve graph with current → goal weight, surfaced with the
    // italic-accent date headline. Phase 2 added the optional `eyebrow`
    // parameter — small all-caps tracked label above the headline,
    // matching the brand-voice pattern (paywall + method preview etc.).
    @ViewBuilder
    private func predictionScreen<Below: View>(
        eyebrow: String? = nil,
        headlinePrefix: String, headlineSuffix: String,
        subhead: String, badge: String?,
        target: Date, next: Int,
        style: PredictionStyle = .sharp,
        @ViewBuilder belowChart: () -> Below = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Palette.accent)
                    .padding(.bottom, Space.sm)
            }

            Group {
                if let badge {
                    Text(badge)
                        .font(.system(size: 13, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Palette.accent, in: Capsule())
                        .padding(.bottom, Space.md)
                }
            }

            predictionHeadline(prefix: headlinePrefix, suffix: headlineSuffix, target: target, style: style)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.sm)

            Text(subhead)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            weightCurve(targetDate: target, style: style)
                .frame(height: 200)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            belowChart()
                .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("continue") { Haptics.medium(); go(next) }
        }
    }

    // Italic-accent prediction headline. "you could be at 130 lbs by Mar 5."
    // 2026 voice — lowercase, peer-coded. Capitalized callers should pass
    // their own prefix; default is lowercase to match the JeniFit voice.
    private func predictionHeadline(
        prefix: String = "you could be at ",
        suffix: String = ".",
        target: Date? = nil,
        style: PredictionStyle = .sharp
    ) -> some View {
        let date = target ?? predictionDate()
        let weightFragment = weightLabel(kg: goalWeightKg)
        let dateFragment = formatGoalDate(date)
        // .rough hides the specific date in the headline so the early
        // estimate doesn't claim more than it knows. The chart matches —
        // no date pill, no week-one callout — so headline + chart stay
        // honest together.
        if style == .rough {
            return (
                Text(prefix).font(Typo.title) +
                Text(weightFragment).font(Typo.titleItalic) +
                Text(suffix).font(Typo.title)
            )
            .foregroundStyle(Palette.textPrimary)
            .multilineTextAlignment(.center)
        }
        return (
            Text(prefix).font(Typo.title) +
            Text(weightFragment).font(Typo.titleItalic) +
            Text(" by ").font(Typo.title) +
            Text(dateFragment).font(Typo.titleItalic) +
            Text(suffix).font(Typo.title)
        )
        .foregroundStyle(Palette.textPrimary)
        .multilineTextAlignment(.center)
    }

    // Smooth weight-loss curve from current → goal weight, with accent fill
    // below. "Today" anchored at left, target date at right. The view runs
    // an entrance animation on mount: stroke draws in left→right, fill
    // fades in alongside, endpoint dots pop with a spring after the curve
    // completes, axis labels fade in last.
    private func weightCurve(targetDate: Date? = nil, style: PredictionStyle = .sharp) -> some View {
        let date = targetDate ?? predictionDate()
        return WeightCurveView(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            targetDate: date,
            currentLabel: weightLabel(kg: currentWeightKg),
            goalLabel: weightLabel(kg: goalWeightKg),
            dateLabel: formatGoalDate(date),
            style: style
        )
    }

    // Loading carousel (180). Three rotating frames over 3.5s, then auto-advances.
    /// Rotating proof copy. Personalized off user inputs (bodyFocus,
    /// daysPerWeek + sessionLength, plank baseline) when available;
    /// falls back to generic lines otherwise. Lowercase casual, italic-
    /// less (loader is small caption type — italic doesn't render
    /// cleanly at 13pt). 4 lines, cycles at 0.9s intervals.
    private var carouselProofLines: [String] {
        // Stage 2 — body focus zone (first selected wins for the line).
        let focusFragment: String = {
            let labels: [String: String] = [
                "flatBelly": "your core",
                "tonedArms": "your arms",
                "roundButt": "your glutes",
                "slimLegs":  "your legs",
                "fullBody":  "your full body"
            ]
            if let first = bodyFocus.first, let label = labels[first] {
                return label
            }
            return "your full body"
        }()

        // Stage 3 — frequency. Pulls Q11 days/week + Q25 session length.
        let cadenceFragment: String = {
            let days = commitmentDaysCount(commitmentDays)
            let mins = sessionLength.isEmpty ? 0 : sessionLengthMinutes(sessionLength)
            if days > 0 && mins > 0 { return "\(days) days × \(mins) min" }
            if days > 0 { return "\(days) days a week" }
            return "your weekly cadence"
        }()

        // Stage 4 — plank baseline reference (the signature metric).
        let baselineFragment: String = {
            switch baseline {
            case "under15":   return "your starting baseline"
            case "fifteen30": return "your 15–30s baseline"
            case "thirty60":  return "your 30–60s baseline"
            case "sixtyPlus": return "your 60s+ baseline"
            default:          return "your starting baseline"
            }
        }()

        return [
            "calibrating intensity to your level…",
            "tuning your plan for \(focusFragment)…",
            "building \(cadenceFragment)…",
            "pulling the right exercises for you…",
            "balancing rest around \(baselineFragment)…",
            "making sure it stays kind ♥"
        ]
    }

    /// 17d-2: LIGHT 4-sticker scatter for the loading carousel.
    /// Edges only so the centered % counter + carousel frame stay
    /// the visual anchor. Mix is 2 line-art + 2 painterly.
    private static let carouselPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.10, y: 0.10),
                         size: 28, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.90, y: 0.12),
                         size: 30, rotation: 12, phaseDelay: 0.30),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.92),
                         size: 26, rotation: 8, phaseDelay: 0.55),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.92, y: 0.88),
                         size: 32, rotation: -10, phaseDelay: 0.78),
    ]

    private var loadingCarouselScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer()

                // Hero % counter — was 14pt. Now 64pt Fraunces, the
                // visual anchor of the screen. numericText transition
                // ticks it smoothly as the progress advances.
                Text("\(Int(carouselProgress * 100))%")
                    .font(.custom("Fraunces72pt-SemiBold", size: 64, relativeTo: .largeTitle))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.numericText())

                Spacer().frame(height: Space.sm)

                // Italic-accent headline — Fraunces voice at 22pt
                // (Typo.heading is DMSans, so we go direct to Fraunces
                // here for the italic accent treatment).
                (Text("Building your ")
                    .font(.custom("Fraunces72pt-SemiBold", size: 22))
                 + Text("plan")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                 + Text("…")
                    .font(.custom("Fraunces72pt-SemiBold", size: 22)))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Space.xs)

                // Rotating proof line — small, secondary, ticks every
                // ~1 second alongside the carousel frame so the page
                // feels alive without competing with the % counter.
                Text(carouselProofLines[
                    carouselProofIndex % carouselProofLines.count
                ])
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .id(carouselProofIndex)
                    .transition(.opacity)

                Spacer().frame(height: Space.lg)

                // Rotating sticker hero per frame.
                Group {
                    switch carouselFrame {
                    case 0: carouselFrameUserCount
                    case 1: carouselFrameTrainingHours
                    default: carouselFrameRating
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Space.screenPadding)
                .id(carouselFrame)
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

                Spacer().frame(height: Space.lg)

                // Progress bar — same gradient capsule, slimmer (6→4)
                // to defer to the now-hero % counter.
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
                            .frame(width: geo.size.width * carouselProgress,
                                   height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, Space.xl)

                Spacer()
            }
        }
        .onAppear { startCarousel() }
    }

    // 17d-2 helper: a single small sticker inside an accent halo.
    // Used by each carousel frame so they read consistently as
    // "JeniFit moment cards" rather than a grab bag of UI shapes.
    private func carouselStickerHero(_ name: StickerName, halo: CGFloat = 88, size: CGFloat = 56) -> some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.10))
                .frame(width: halo, height: halo)
            Image(name.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .opacity(name.style.opacity)
        }
    }

    // Phase 4 (2026 research): the 3 carousel frame cards previously
    // shipped fabricated stats (1,000+ early-access members / 100+
    // hours / 5.0 ★) as TODO placeholders. The 2026 audience research
    // identified fabricated user counts as the single worst signal we
    // could send TikTok-acquired women 22-35 (Sharifzadeh & Brison
    // 2024 femwashing trap; Airbridge 2026 specific-beats-fabricated).
    // Replaced with the same research citations the paywall + becoming
    // tab cite — same authority signal, fully honest.
    //
    // Once we cross ~250 paid users, frame 1 can swap to real opt-in
    // numbers ("joined by 247 women this week") per the paywall memory.

    // Frame 1 — McGill plank research authority signal.
    private var carouselFrameUserCount: some View {
        VStack(spacing: Space.sm) {
            carouselStickerHero(.heartGlossy)
            Text("plank thresholds from mcgill (waterloo)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xs)
                .padding(.horizontal, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Frame 2 — ACSM safe-pace-of-loss band.
    private var carouselFrameTrainingHours: some View {
        VStack(spacing: Space.sm) {
            carouselStickerHero(.ribbonLineart)
            Text("calibrated to acsm 0.5-1%/wk loss-rate band")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xs)
                .padding(.horizontal, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Frame 3 — Bandura/Annesi self-efficacy + privacy stance.
    private var carouselFrameRating: some View {
        VStack(spacing: Space.sm) {
            carouselStickerHero(.starLineart)
            Text("built on bandura self-efficacy research")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, Space.xs)
                .padding(.horizontal, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
            Text("no third-party trackers · your data stays yours")  // voice-lint:allow — pro-privacy framing, opposite intent of AI-coach "based on your data" tell
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
                .padding(.horizontal, Space.sm)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func startCarousel() {
        carouselProgress = 0
        carouselFrame = 0
        carouselDone = false
        carouselProofIndex = 0
        Analytics.track(.planLoaderStarted)

        // Loader timing — bumped from 3.5s → 6.5s per user feedback.
        // Displayed percentage uses an ease-IN curve (slow start,
        // accelerating finish) which is the pattern users associate
        // with "real work happening" — apps like Noom and BetterMe
        // both do this. Mathematically: displayed = linear^2.2, so:
        //   t=2.0s (31% linear) → 7% displayed
        //   t=4.0s (62% linear) → 35% displayed
        //   t=5.0s (77% linear) → 56% displayed
        //   t=6.0s (92% linear) → 83% displayed
        //   t=6.5s (100%)       → 100% displayed
        //
        // Frame transitions stay on LINEAR time so all three frames
        // get equal screen time (≈2.17s each) — without this, frame 0
        // would dominate ~57% of the loader because the ease-in
        // curve compresses early displayed-progress.
        let total = 6.5
        let steps = 100  // bumped from 70 for smoother ease curve
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + total * Double(i) / Double(steps)) {
                let linear = CGFloat(i) / CGFloat(steps)
                let eased = pow(linear, 2.2)
                withAnimation(.easeOut(duration: 0.08)) { carouselProgress = eased }
                let f = min(2, Int(linear * 3))
                if f != carouselFrame {
                    withAnimation(.easeInOut(duration: 0.4)) { carouselFrame = f }
                }
                if i == steps && !carouselDone {
                    carouselDone = true
                    Haptics.success()
                    showConfetti = true
                    Analytics.track(.planLoaderCompleted)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showConfetti = false
                        // C1 (2026-06-01): was go(181) — finalPredictionScreen
                        // was the 5th chart appearance and duplicated the reveal
                        // sequence's ProjectionPresentation. 180 now routes
                        // directly to 234 (plateau pre-frame) so the user
                        // doesn't see the chart in-flow again before the
                        // reveal sequence's hero treatment.
                        go(234)
                    }
                }
            }
        }
        // Rotate the proof line evenly across the loader duration.
        // With 6 proof lines and 6.5s total, each line gets ~1.08s
        // of airtime — enough to read without feeling slow.
        let proofTotal = carouselProofLines.count
        let proofInterval = total / Double(proofTotal)
        for k in 0..<proofTotal {
            DispatchQueue.main.asyncAfter(deadline: .now() + proofInterval * Double(k)) {
                guard !carouselDone else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    carouselProofIndex = k
                }
            }
        }
    }

    private func firstWeekCalendar() -> some View {
        // 9 dots representing the first 9 days. Accent for committed days
        // (derived from commitmentDays count), divider for rest.
        let active = commitmentDaysCount(commitmentDays)
        let activeDays: Set<Int> = {
            // Spread `active` workouts across 9 days starting from day 1.
            // Default 5/week → days 1, 2, 3, 4, 5 (skip 6/7, then 8/9).
            // Simple heuristic: pack from the front, skip the rest.
            var s = Set<Int>()
            for d in 0..<9 where d < active || (d >= 7 && d - 7 < max(0, active - 5)) {
                s.insert(d)
            }
            return s
        }()
        return VStack(spacing: Space.sm) {
            HStack {
                Text("YOUR FIRST 9 DAYS")
                    .font(Typo.eyebrow).tracking(1)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(0..<9, id: \.self) { d in
                    Circle()
                        .fill(activeDays.contains(d) ? Palette.accent : Palette.divider)
                        .frame(width: 16, height: 16)
                }
            }
        }
    }

    // MARK: - Phase 5 helpers

    /// First-prediction date. Computed from the user's actual goal: takes
    /// (currentKg − goalKg), divides by ACSM 0.75%/wk sustainable-loss pace
    /// (a real evidence-based number from the same source `BecomingProjectionCard`
    /// uses), then nudges ±2 weeks by activity level. Floor 2 weeks so a
    /// trivial 1-lb goal doesn't render as "next Tuesday"; cap 26 weeks so
    /// a 50-lb goal doesn't render as "next March". Falls back to a 12-week
    /// default when the user hasn't set both weights — keeps the screen
    /// usable for maintenance-goal users instead of crashing.
    /// 2026-06-01: unified through `ProjectionMath.projectedGoalDate(...)`.
    /// Both prediction screens (cases 161, 170) now return the SAME
    /// date — the visual "sharpening" between rough and sharp is purely
    /// chart styling (dashed → solid stroke + date pill reveal), never
    /// a different number. Before this consolidation, rePredictionDate
    /// applied a 14-day compression that left the recap card (case 206)
    /// and re-prediction screen (case 170) showing different dates for
    /// the same inputs — user reported the mismatch.
    private func predictionDate() -> Date {
        ProjectionMath.projectedGoalDate(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: paceChoice
        ) ?? defaultProjectionDate
    }

    private func rePredictionDate() -> Date {
        // Same date as predictionDate — sharpening is visual, not numeric.
        predictionDate()
    }

    /// Fallback when no loss goal is set (current ≤ goal). 12-week
    /// default keeps downstream screen layout stable for maintenance-
    /// goal users instead of crashing on nil.
    private var defaultProjectionDate: Date {
        Calendar.current.date(byAdding: .day, value: 84, to: Date()) ?? Date()
    }

    /// Cached — DateFormatter init is ~10ms and the prediction-screen chart
    /// animation re-evaluates this date label each frame.
    private static let goalDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "Mar 5" style. Short month + day, no year.
    private func formatGoalDate(_ date: Date) -> String {
        Self.goalDateFormatter.string(from: date)
    }

    /// Plan-reveal anchor lines. 2–3 dual-anchored capability + outcome
    /// lines derived from already-collected fields:
    ///   - Plank-time target = next-tier from Q3 baseline (the signature
    ///     metric, no competitor can copy).
    ///   - Weight outcome = lbs delta, only if the user set a loss goal.
    ///   - Habit identity = session length anchored with "locked in"
    ///     identity verb (Clear / Atomic Habits framing).
    /// Falls back gracefully on any missing field so the screen never
    /// renders empty.
    private func jenifitGoalLabel() -> String {
        let first = bodyFocus.first
        switch first {
        case "flatBelly": return "your flat belly"
        case "tonedArms": return "your toned arms"
        case "roundButt": return "your round butt"
        case "slimLegs":  return "your slim legs"
        case "fullBody":  return "full-body transformation"
        default: break
        }
        switch identityFeeling {
        case "powerful": return "feeling powerful"
        case "calm":     return "feeling at home in your body"
        case "light":    return "feeling light and free"
        case "strong":   return "strength and capability"
        case "radiant":  return "radiant energy"
        default: return "your goals"
        }
    }

    // ═══════════════════════════════════════
    // MARK: - ANALYZING (legacy, kept for non-flow legacy callers)
    // ═══════════════════════════════════════

    private var analyzingScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("\(analyzePercent)%").font(.system(size: 72, weight: .bold)).foregroundStyle(Palette.textPrimary)
                .contentTransition(.numericText())
            Spacer().frame(height: Space.sm)
            Text("Building your plan").font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.textPrimary)
            Spacer().frame(height: Space.lg)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 6)
                    Capsule().fill(LinearGradient(colors: [Palette.accent, Palette.stateGood], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(analyzePercent) / 100, height: 6)
                        .animation(.easeOut(duration: 0.3), value: analyzePercent)
                }
            }.frame(height: 6).padding(.horizontal, Space.xl)
            Spacer().frame(height: Space.xl)
            VStack(alignment: .leading, spacing: Space.md) {
                chk("Analyzing your goals", analyzePercent >= 20)
                chk("Setting target hold times", analyzePercent >= 40)
                chk("Calibrating your coach", analyzePercent >= 60)
                chk("Building 30-day program", analyzePercent >= 80)
                chk("Finalizing your plan", analyzePercent >= 98)
            }.padding(.horizontal, Space.screenPadding)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.bgPrimary)
    }

    private func chk(_ t: String, _ d: Bool) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: d ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                .foregroundStyle(d ? Palette.textPrimary : Palette.divider).animation(.spring(response: 0.3), value: d)
            Text(t).font(.system(size: 16, weight: .medium)).foregroundStyle(d ? Palette.textPrimary : Palette.textSecondary)
        }
    }

    private func startAnalyzing() {
        analyzePercent = 0
        for i in 0...100 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 * Double(i) / 100) {
                withAnimation(.easeOut(duration: 0.15)) { analyzePercent = i }
                if i % 20 == 0 { Haptics.light() }
                if i == 100 {
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation { analyzing = false }
                        showConfetti = true; go(21)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showConfetti = false }
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - PLAN REVEAL + CAMERA + PAYWALL
    // ═══════════════════════════════════════

    // ═══════════════════════════════════════
    // MARK: - COMPARISON (screen 142)
    // ═══════════════════════════════════════
    //
    // 17d-3: "Others vs JeniFit" comparison screen. Sits between
    // Q141 (reward) and the Part 5 section divider so the user
    // gets a "you've been promised this before, here's what's
    // actually coming" beat at peak commitment.
    //
    // Translation rules from JustFit IMG_4930 → JeniFit:
    //   - No grayscale "before" photo + glamour "after" — we use
    //     two text cards differentiated by tone, not by shame.
    //   - Left card is muted (cream + divider stroke + gray text);
    //     right card is vivid (accentSubtle + accent stroke + cocoa
    //     text + sticker accent). Visual lift comes from the bg
    //     tint, not from heavy red.
    //   - Bullet copy stays directional ("personalized to your
    //     zones") rather than insulting ("FAKE generic plan").

    /// 17d-3 LIGHT scatter — 4 stickers anchored to the screen edges
    /// behind the comparison cards. Same density as the other Phase 4
    /// pre-paywall screens (identity, first prediction).
    private static let comparisonPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.07, y: 0.06),
                         size: 28, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.94, y: 0.10),
                         size: 26, rotation: 12, phaseDelay: 0.30),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.92, y: 0.92),
                         size: 30, rotation: 10, phaseDelay: 0.55),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.06, y: 0.94),
                         size: 28, rotation: -8, phaseDelay: 0.78),
    ]

    private var comparisonScreen: some View {
        ZStack {
            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer().frame(height: Space.lg)

                // 2026 voice — reframes "JeniFit vs generic plans"
                // (competitor compare, anti-pattern for this audience)
                // to "past you vs steady you" — loss aversion against
                // the user's own past attempts, not against a named
                // competitor. Research-backed: RevenueCat / Noom
                // teardowns show the past-self comparison converts
                // for women 22-35 who burned out on bootcamp content.
                (Text("this time, ").font(Typo.title)
                 + Text("different").font(Typo.titleItalic)
                 + Text(".").font(Typo.title))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.sm)

                Text("you've tried fitness apps before. here's what we both know already happened.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.lg)

                // ── Past-attempts card — what burnt them out on the
                // previous tries (Pamela Reif intensity, 30-day
                // challenges, all-or-nothing). Muted card so it reads
                // as "the old way," visually demoted.
                VStack(spacing: 0) {
                    HStack {
                        Text("past attempts")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Palette.divider.opacity(0.6),
                                        in: Capsule())
                        Spacer()
                    }
                    .padding(.bottom, Space.sm)

                    VStack(alignment: .leading, spacing: 8) {
                        comparisonRow(label: "did everything at once", positive: false)
                        comparisonRow(label: "burnt out by week 2", positive: false)
                        comparisonRow(label: "30-day challenge → quit", positive: false)
                        comparisonRow(label: "shame when you missed a day", positive: false)
                        comparisonRow(label: "intensity over consistency", positive: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
                .padding(.horizontal, Space.screenPadding)

                // Connector chevron — soft visual flow from "what
                // you've tried" down to "what's coming". Accent rose
                // arrow inside a small accent halo.
                ZStack {
                    Circle()
                        .fill(Palette.accent.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.accent)
                }
                .padding(.vertical, 10)

                // ── Steady-you card — what 5 min/day with the daily
                // ritual enables. Hero treatment with sparkle + accent
                // border + halo shadow. This is the *new* identity the
                // user is being invited into.
                VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: Space.sm) {
                        Image(StickerName.sparkleGlossy.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .opacity(StickerName.sparkleGlossy.style.opacity)

                        (Text("steady ")
                            .font(.custom("Fraunces72pt-SemiBold", size: 14))
                         + Text("you")
                            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15)))
                            .foregroundStyle(Palette.textInverse)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Palette.accent, in: Capsule())

                        Spacer()
                    }
                    .padding(.bottom, Space.md)

                    VStack(alignment: .leading, spacing: 10) {
                        comparisonRow(label: "5 minutes a day, every day", positive: true)
                        comparisonRow(label: "no streak guilt", positive: true)
                        comparisonRow(label: "stronger each week, quietly", positive: true)
                        comparisonRow(label: "fits your real life", positive: true)
                        comparisonRow(label: "the version that actually sticks", positive: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Space.md)
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Palette.accentSubtle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Palette.accent, lineWidth: 2)
                )
                .shadow(color: Palette.accent.opacity(0.22),
                        radius: 16, x: 0, y: 8)
                .padding(.horizontal, Space.screenPadding)

                Spacer()

                // Route to 170 (re-prediction) — was incorrectly skipping
                // straight to 204, leaving the Phase 2 re-prediction
                // screen orphaned in the forward path. Fixed as part
                // of Phase 3.
                ctaBtn("i want this version") {
                    Haptics.medium()
                    Analytics.track(.comparisonChartViewed)
                    // Post-2026-05-30: routes to video demo (case 145).
                    // Delta v7 D67: in v2 flow, commitment confidence
                    // (case 165) sits between here and 145. Use
                    // advance(to:) so resolveNext does the right thing
                    // per flow version — v2 goes to 165, v1 skips past.
                    #if DEBUG
                    print("[D67] comparisonScreen → advance(to: 165). flowContains165=\(flowOrder.contains(165))")
                    #endif
                    advance(to: 165, confirmation: nil)
                }
                    .padding(.bottom, Space.lg)
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Video demo (case 145, epic #1 child #8)
    // ═══════════════════════════════════════

    /// Post-comparison 10-15s silent loop of an actual plank session.
    /// Article research (200+ app teardown): "Nobody reads features.
    /// Everyone watches them." Asset name: `jeni_session_demo.mp4`,
    /// shipped separately by the founder when ready.
    ///
    /// Auto-skip safety:
    ///   - Asset missing from bundle → skip to next case immediately
    ///     (legacy flows + pre-asset deploys keep working)
    ///   - Reduce-motion enabled → skip to next case immediately
    ///     (accessibility — until a still-frame fallback ships per the
    ///     #8 spec, the safer default is no video for these users)
    ///
    /// The screen renders a clipped VideoHero in a pink-mat frame
    /// matching the welcome screen video block (welcomeVideoBlock at
    /// case 0) so the visual language is consistent.
    private var videoDemoScreen: some View {
        let assetAvailable = Bundle.main.url(forResource: "jeni_session_demo", withExtension: "mp4") != nil
        let shouldSkip = !assetAvailable || reduceMotion

        return GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer().frame(height: Space.lg)

                Text("here's what 5 minutes looks like.")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: Space.md)

                if assetAvailable {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Palette.accentSubtle)
                        VideoHero(videoName: "jeni_session_demo", videoExtension: "mp4")
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(12)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: max(280, min(420, geo.size.height * 0.5)))
                    .padding(.horizontal, Space.screenPadding)
                } else {
                    // Placeholder while the asset is in the queue —
                    // never visible in production because shouldSkip
                    // also catches !assetAvailable and routes onward,
                    // but kept here so the layout doesn't collapse if
                    // a debug build inspects this screen via DebugMenu.
                    Color.clear
                        .frame(height: 280)
                }

                Spacer()

                ctaBtn("show me how it feels") {
                    Haptics.medium()
                    go(170)
                }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
            }
        }
        .background(Palette.bgPrimary)
        .onAppear {
            if shouldSkip {
                // Silent skip — keep the funnel walking. The .task
                // / .onAppear ordering on a SwiftUI case switch
                // tolerates an immediate go() per other auto-skip
                // patterns in this file (case 215 review-prompt
                // skip-if-ineligible uses the same pattern).
                go(170)
                return
            }
            Analytics.track(.onboardingVideoDemoViewed, properties: [
                "placement": "post_comparison",
                "video_id": "jeni_session_demo"
            ])
        }
    }

    private func comparisonRow(label: String, positive: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(positive ? Palette.accent.opacity(0.20)
                                   : Palette.divider.opacity(0.55))
                    .frame(width: 18, height: 18)
                Image(systemName: positive ? "checkmark" : "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(positive ? Palette.accent
                                              : Palette.textSecondary)
            }
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(positive ? Palette.textPrimary
                                          : Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // 17d-2: sparkle burst around the coach photo. Each entry is an
    // offset from the photo center + a size + a stagger delay. The

    private var planRevealScreen: some View {
        // v4.5 R4 (2026-06-11) — her75-3 "day one" card restyle. Coach
        // portrait + sparkle burst + anchors card + 3 plan cards
        // collapsed into ONE white shadow-only card with quantified
        // rails + a real date range. Scatter stays (founder-locked
        // milestone moment). Every number derives from her answers.
        let lossKg = max(0, currentWeightKg - goalWeightKg)
        let hasLossGoal = lossKg > 0.5
        let endDate = derivedPlanEndDate()
        let days = commitmentDaysCount(commitmentDays)
        let mins = sessionLength.isEmpty ? 10 : sessionLengthMinutes(sessionLength)

        return ZStack {
            StickerScatter(placements: Self.planRevealPlacements)

            VStack(spacing: 0) {
                Spacer()

                LineCascadeText(
                    lines: name.isEmpty
                        ? [.plain("congrats."),
                           .composite(base: "your plan is ready.", italic: ["ready"])]
                        : [.plain("congrats, \(name.lowercased())."),
                           .composite(base: "your plan is ready.", italic: ["ready"])],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    alignment: .center,
                    lineSpacing: Typo.heroHeadlineLineGap
                )
                .padding(.horizontal, Space.screenPadding)
                .opacity(planHeadlineVisible ? 1 : 0)

                Spacer().frame(height: Space.lg)

                // The day-one card — white, shadow-only, serif masthead.
                VStack(alignment: .leading, spacing: 12) {
                    (Text("day ").font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                     + Text("one").font(.custom("Fraunces72pt-SemiBold", size: 28)))
                        .foregroundStyle(Palette.textPrimary)

                    Text(planDateRangeLabel(endDate: hasLossGoal ? endDate : nil))
                        .font(.custom("DMSans-Regular", size: 14))
                        .foregroundStyle(Palette.textSecondary)

                    VStack(alignment: .leading, spacing: 10) {
                        dayOneRail(num: 1, base: "move ", italic: "\(days)× a week", suffix: " · \(mins)-min sessions")
                        dayOneRail(num: 2, base: "snap meals ", italic: "before", suffix: " you eat · no counting")
                        dayOneRail(num: 3, base: "", italic: "7,500", suffix: " steps · the everyday anchor")
                        dayOneRail(num: 4, base: "one ", italic: "2-min", suffix: " read a day · the method")
                        dayOneRail(num: 5, base: "breathe ", italic: "5 min", suffix: " on rest days")
                    }
                    .padding(.top, 2)

                    HStack {
                        Text("JENIFIT PROGRAM")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.8)
                            .foregroundStyle(Palette.textSecondary)
                        Spacer()
                        Button { showPlanSources = true } label: {
                            Text("sources")
                                .font(.system(size: 12))
                                .underline()
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .accessibilityLabel("View research sources")
                    }
                    .padding(.top, 6)
                }
                .padding(Space.md + 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Palette.bgElevated)
                        .shadow(color: Palette.cocoaPrimary.opacity(0.12), radius: 18, x: 0, y: 8)
                )
                .paperSheen()
                .rotationEffect(.degrees(planCardsVisible ? -1.2 : 0))
                .padding(.horizontal, Space.screenPadding + 6)
                .opacity(planCardsVisible ? 1 : 0)
                .scaleEffect(planCardsVisible ? 1 : 0.96)

                Spacer()

                JFContinueButton(label: "let's go") {
                    Analytics.track(.planRevealContinueTapped)
                    go(250)
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.sm)
                .opacity(planCtaVisible ? 1 : 0)
            }
            .onAppear { runPlanReveal() }
        }
        .sheet(isPresented: $showPlanSources) {
            planSourcesSheet
        }
    }

    /// "jun 11 → sep 3" (real derived range) or "starts today" when
    /// there's no loss goal to project.
    private func planDateRangeLabel(endDate: Date?) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let today = df.string(from: Date()).lowercased()
        guard let endDate else { return "starts \(today)" }
        return "\(today) → \(df.string(from: endDate).lowercased())"
    }

    /// End date from the ACSM pace band the user picked — same
    /// ProjectionMath call as every other date surface.
    private func derivedPlanEndDate() -> Date {
        ProjectionMath.projectedGoalDate(
            currentKg: currentWeightKg,
            goalKg: goalWeightKg,
            paceKey: paceChoice
        ) ?? Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    }

    /// One quantified rail on the day-one card. Serif numeral, italic
    /// punch on the number (the her75 sticky-note row register, done
    /// typographically).
    private func dayOneRail(num: Int, base: String, italic: String, suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(num)")
                .font(.custom("Fraunces72pt-SemiBold", size: 17))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 16, alignment: .center)
            (Text(base).font(.custom("DMSans-Regular", size: 15))
             + Text(italic).font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
             + Text(suffix).font(.custom("DMSans-Regular", size: 15)))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Real citations behind the plan — the credibility layer Cal AI
    /// fakes with "90% of users" theater. Ours are real, so show them.
    private var planSourcesSheet: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("the research behind your plan")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.lg)

            VStack(alignment: .leading, spacing: Space.sm) {
                sourceRow("ACSM position stand", "0.5–1% of body weight per week is the sustainable band. your pace sits inside it.")
                sourceRow("wing & phelan, 2005", "a kept 5–10% is the clinical win. plans built for keeping beat plans built for speed.")
                sourceRow("kaushal & rhodes, 2015", "short daily sessions form habits ~3× more reliably than long ones.")
                sourceRow("helander et al., 2014", "consistency of small logs predicts outcomes better than intensity.")
            }

            Spacer()
        }
        .padding(.horizontal, Space.lg)
        .presentationDetents([.medium])
        .presentationBackground(Palette.bgPrimary)
    }

    private func sourceRow(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("DMSans-SemiBold", size: 14))
                .foregroundStyle(Palette.textPrimary)
            Text(body)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runPlanReveal() {
        // Reset for re-mount (back nav replays the moment).
        planRevealed = false
        planHeadlineVisible = false
        planCardsVisible = false
        planCtaVisible = false

        Analytics.track(.planRevealViewed, properties: [
            "coach": voicePreference,
            "body_focus_count": bodyFocus.count
        ])

        Haptics.success()

        // Headline cascade runs itself (2 lines × 0.42s). Card lands
        // after the cascade with a soft spring + tilt; CTA last.
        withAnimation(.easeOut(duration: 0.45).delay(0.10)) {
            planHeadlineVisible = true
        }
        withAnimation(Motion.gentleSpring.delay(1.05)) {
            planCardsVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.60)) {
            planCtaVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            planRevealed = true
        }
    }

    /// Pick the most-relevant barrier the user named and return a card payload.
    /// Order matters: the first matching barrier wins (in priority order).
    private var cameraSetupScreen: some View {
        let plankTimeLabel = humanReadableReminderTime(plankTime)

        return VStack(spacing: 0) {
            Spacer()

            // Hero sticker — heartGlossy reads warmer than a bell glyph
            // and matches the rest of the onboarding visual language.
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(StickerName.heartGlossy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .opacity(StickerName.heartGlossy.style.opacity)
            }

            Spacer().frame(height: Space.lg)

            // Delta v8 D76 — notification pre-prime voice update per
            // Cal AI culture brief (calai23 + culture brief §12). Was
            // "turn on reminders?" (functional register). Now warm
            // peer-voice: "want a nudge from jeni?" — italic-Fraunces
            // on "nudge". Sub: "one quiet one a day. nothing nagging."
            // Expected +34% allow rate per Singular 2026 ATT-cohort
            // benchmarks adapted to notification ask.
            (Text("want a ").font(Typo.title)
             + Text("nudge").font(Typo.titleItalic)
             + Text(" from jeni?").font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            Text("one quiet one a day. nothing nagging. \(plankTimeLabel). change or turn off in settings whenever.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .fixedSize(horizontal: false, vertical: true)

            Spacer().frame(height: Space.xl)

            // The actual proof — tells the user exactly what the
            // notification will look like before they commit.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "app.badge.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                    Text("PREVIEW")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Palette.textSecondary)
                }
                // v1.1.1 (2026-06-19) — preview title sync. The shipped
                // notification title (NotificationPermission v2,
                // OnboardingComponents.swift:227) was rebranded to
                // "five minutes, today." but THIS preview surface
                // wasn't updated, producing a bait-and-switch: user
                // opts in expecting "today's short session.", gets
                // "five minutes, today." the next day. Trust hit on
                // day 1. Match the actual scheduled title.
                Text("five minutes, today.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(notificationPreviewBody)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            VStack(spacing: 10) {
                ctaBtn("allow notifications") {
                    Haptics.medium()
                    Task {
                        let granted = await NotificationPermission.requestOrOpenSettings()
                        notificationsEnabled = granted
                        if granted {
                            // v1.0.7 Phase D — daily reminder NO LONGER
                            // auto-scheduled at permission grant per the
                            // retention expert brief
                            // (docs/home_becoming_research_retention_2026_06_06.md §3).
                            // The user can re-enable it in Settings →
                            // Reminders if they want one; default is
                            // off so the trial-week push count stays
                            // at 3 (Day 0 + Day 2 + Evening 8:30pm
                            // plate review). The plankTime bucket is
                            // still captured for the daily-reminder
                            // settings UI to honor as the starting
                            // time when the user opts back in.
                            let scheduledTime = reminderTimeFromBucket(plankTime)
                            notificationTime = scheduledTime
                        }
                        finish()
                    }
                }

                Button {
                    Haptics.light()
                    notificationsEnabled = false
                    finish()
                } label: {
                    Text("not right now")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(PressFeedbackStyle())
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
    }

    /// Soft review prefilter, fires right after plan reveal. 2026-05-30
    /// (epic #1 child #6): copy re-framed from "loving jenifit so far?"
    /// to "love your plan?" so the user is rating the personalization
    /// they just experienced (the plan reveal) rather than a product
    /// they haven't used yet. Article evidence (200+ app teardown): 152
    /// reviews at 4.8 from mid-onboarding placement after a wow moment.
    /// Routes through RatingPromptService.postPlanReveal so the
    /// per-trigger lifetime flag + 30-day soft cooldown + legacy
    /// onboardingReviewPromptShown back-compat all apply.
    private var reviewPromptScreen: some View {
        // 2026-05-30 visual upgrade: matches the brand-promises screen
        // chrome so the post-plan-reveal sequence (plan reveal → brand
        // promises → review prompt) reads as one coherent moment. The
        // sticker scatter + scrapbook-card hero + italic-Fraunces voice
        // signal carry across all three screens.
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            // her75 Phase 2 (2026-06-10) — StickerScatter cut; editorial restraint.

            VStack(spacing: 0) {
                Spacer()

                // Card hero — hero sticker on accent halo INSIDE the
                // scrapbook chrome. Same shape as the brand-promises
                // card so the visual rhythm of the screen pair is
                // continuous.
                VStack(spacing: Space.lg) {
                    ZStack {
                        Circle()
                            .fill(Palette.accent.opacity(0.12))
                            .frame(width: 96, height: 96)
                        Image(StickerName.heartGlossy.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 68, height: 68)
                            .opacity(StickerName.heartGlossy.style.opacity)
                    }
                    .padding(.top, Space.md)

                    (Text("love ").font(Typo.title)
                     + Text("your plan").font(Typo.titleItalic)
                     + Text("?").font(Typo.title))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)

                    Text("a quick rating helps other women find us, and keeps the app independent.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)
                        .padding(.bottom, Space.md)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, Space.md)
                .frame(maxWidth: .infinity)
                .scrapbookCardBackground()
                .padding(.horizontal, Space.screenPadding)

                Spacer()

                VStack(spacing: 10) {
                    ctaBtn("loving it") {
                        Haptics.success()
                        handleReviewPromptYes()
                        // Brief delay so the system sheet has a beat to
                        // appear before we slide forward; if iOS
                        // suppresses it (quota, throttle), the user
                        // just lands on the next screen.
                        // 2026-06-06: route to 23 (final). Pre-D82 this
                        // routed to 26 (sign-in came AFTER rating); D82
                        // flipped the order so sign-in is now upstream
                        // of the rating ask.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            go(23)
                        }
                    }

                    Button {
                        Haptics.light()
                        handleReviewPromptNo()
                        go(23)
                    } label: {
                        Text("not yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(PressFeedbackStyle())
                }
                .padding(.horizontal, Space.screenPadding)
                .padding(.bottom, Space.lg)
            }
        }
        .onAppear {
            // If the postPlanReveal trigger is ineligible (already fired
            // for this install, or 30-day cooldown active), skip directly
            // to the next screen so the user isn't shown a prompt that
            // can't actually fire SKStoreReviewController. Existing
            // v1.0.6 users with the legacy onboardingReviewPromptShown
            // flag set fall through this gate too.
            // 2026-06-07: post-plan-reveal is now the SOLE rating ask in
            // the onboarding flow. The earlier loader-sentiment overlay
            // (BuildingPlanLoadingView, ~75% loader) was dropped because
            // it double-fired SKStoreReviewController against this gate
            // — neither side called RatingPromptService.markShown so
            // both passed eligibility and a "love"-tapping user got
            // two rating asks ~60s apart.
            if !RatingPromptService.shared.isEligible(for: .postPlanReveal) {
                go(23)
            }
        }
    }

    /// 4-sticker scatter for the review-prompt sentiment gate. Same
    /// edge-only coordinates as the brand-promises screen so the
    /// post-plan-reveal sequence (240 brand promises → 250 method
    /// preview → 215 review prompt) feels visually continuous.
    private static let reviewPromptPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.10, y: 0.10),
                         size: 30, rotation: -8, phaseDelay: 0.00),
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.92, y: 0.12),
                         size: 32, rotation: 14, phaseDelay: 0.25),
        StickerPlacement(sticker: .ribbonLineart,
                         position: CGPoint(x: 0.08, y: 0.86),
                         size: 28, rotation: -11, phaseDelay: 0.55),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.92, y: 0.88),
                         size: 32, rotation: 9, phaseDelay: 0.80),
    ]

    /// "Loving it" path — fire the system review sheet via
    /// RatingPromptService. Marks the postPlanReveal trigger shown +
    /// updates the global cooldown timestamp so the other two triggers
    /// (sessionThreePR, dayStreakSeven) honor the 30-day spacing.
    private func handleReviewPromptYes() {
        // Keep the legacy AppStorage flag in sync so older code paths
        // that still read it (any v1.0.6 holdovers) see the consistent
        // "already shown" signal.
        onboardingReviewPromptShown = true
        RatingPromptService.shared.markShown(.postPlanReveal)
        RatingPromptService.shared.trackSentimentResult(trigger: .postPlanReveal, sentimentYes: true)
        RatingPromptService.shared.presentSystemReviewSheet()
    }

    /// "Not yet" path — record the sentiment-no, mark the trigger shown
    /// (so we don't re-prompt next session), continue onboarding.
    /// Per the spec, slot 1 ("not yet" in onboarding) does NOT route to
    /// FeedbackView — that's reserved for slots 2-3 where the user has
    /// actually used the product.
    private func handleReviewPromptNo() {
        onboardingReviewPromptShown = true
        RatingPromptService.shared.markShown(.postPlanReveal)
        RatingPromptService.shared.trackSentimentResult(trigger: .postPlanReveal, sentimentYes: false)
    }

    /// Q11 plankTime bucket → a "morning" / "in the afternoon" / etc.
    /// fragment that fits inside the notification screen subtitle.
    private func humanReadableReminderTime(_ bucket: String) -> String {
        switch bucket {
        case "morning":   return "every morning"
        case "afternoon": return "each afternoon"
        case "evening":   return "every evening"
        case "whenever":  return "every day"
        default:          return "every day"
        }
    }

    /// Q11 plankTime bucket → a real Date for the daily reminder.
    /// Hours match the bucket spirit: morning=7am, afternoon=1pm,
    /// evening=7pm, whenever=9am.
    private func reminderTimeFromBucket(_ bucket: String) -> Date {
        let cal = Calendar.current
        let hour: Int = {
            switch bucket {
            case "morning":   return 7
            case "afternoon": return 13
            case "evening":   return 19
            default:          return 9
            }
        }()
        return cal.date(from: DateComponents(hour: hour)) ?? Date()
    }

    private func tR(_ ic: String, _ tx: String) -> some View {
        HStack(spacing: Space.sm) {
            Image(systemName: ic).font(.system(size: 16)).foregroundStyle(Palette.textSecondary).frame(width: 24)
            Text(tx).font(.system(size: 15)).foregroundStyle(Palette.textPrimary)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - DID YOU KNOW (screen 9)
    // ═══════════════════════════════════════

    private var didYouKnowScreen: some View {
        ZStack {
            GradientBlob(colors: [Palette.accent, Palette.stateGood, Palette.accentSubtle]).offset(y: -50)
            VStack(spacing: 0) {
                Spacer()

                Text("Did you know?")
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(Palette.accent)
                    .opacity(factVisible ? 1 : 0)

                Spacer().frame(height: Space.md)

                Text("Your core activates\nbefore every movement\nyou make.")
                    .font(Typo.title)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(factVisible ? 1 : 0)
                    .offset(y: factVisible ? 0 : 15)

                Spacer().frame(height: Space.lg)

                Text("Walking. Sitting. Standing up.\nA weak core means everything\nis harder than it should be.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(factVisible ? 1 : 0)
                    .offset(y: factVisible ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: factVisible)

                Spacer()
                ctaBtn("Continue") { Haptics.light(); go(10) }
                    .opacity(factVisible ? 1 : 0)
            }.padding(.horizontal, Space.screenPadding)
        }
        .onAppear {
            withAnimation(Motion.entrance) { factVisible = true }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - FEATURE SHOWCASE (screen 13)
    // ═══════════════════════════════════════

    private var featureShowcaseScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Why JeniFit\nworks")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(featureVisible ? 1 : 0)

            Spacer().frame(height: Space.xl)

            VStack(spacing: 14) {
                featureRow(icon: "flame.fill", title: "Daily routines, done for you",
                           desc: "5-10 min ab sessions. We pick the workout, you show up.",
                           delay: 0.1)
                featureRow(icon: "waveform", title: "A coach who talks to you",
                           desc: "Voice coaching with personality. Not beeps.",
                           delay: 0.25)
                featureRow(icon: "camera.fill", title: "Weekly plank check-in",
                           desc: "We track your form and chart your progress.",
                           delay: 0.4)
                featureRow(icon: "brain.head.profile", title: "Gets smarter over time",
                           desc: "Your workouts adapt to your ratings and performance.",
                           delay: 0.55)
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(14) }
                .opacity(featureVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(Motion.entranceSoft) { featureVisible = true }
        }
    }

    private func featureRow(icon: String, title: String, desc: String, delay: Double) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.accent)
                .frame(width: 40, height: 40)
                .background(Palette.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .opacity(featureVisible ? 1 : 0)
        .offset(y: featureVisible ? 0 : 12)
        .animation(.easeOut(duration: 0.4).delay(delay), value: featureVisible)
    }

    // ═══════════════════════════════════════
    // MARK: - BEFORE/AFTER STAT (screen 16)
    // ═══════════════════════════════════════

    private var beforeAfterScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("What 5 minutes a day\nlooks like")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(beforeAfterVisible ? 1 : 0)
                .offset(y: beforeAfterVisible ? 0 : 10)
                .animation(.easeOut(duration: 0.4), value: beforeAfterVisible)

            Spacer().frame(height: Space.lg + 8)

            // Progress cards
            VStack(spacing: 12) {
                progressCard(
                    week: "Week 1",
                    detail: "Building the habit",
                    metric: "Show up daily",
                    icon: "flame",
                    color: Palette.textSecondary,
                    index: 0
                )
                progressCard(
                    week: "Week 2",
                    detail: "Form starts clicking",
                    metric: "Plank hold improves",
                    icon: "chart.line.uptrend.xyaxis",
                    color: Palette.stateWarn,
                    index: 1
                )
                progressCard(
                    week: "Week 3",
                    detail: "Exercises feel easier",
                    metric: "Harder workouts unlock",
                    icon: "bolt",
                    color: Palette.accent,
                    index: 2
                )
                progressCard(
                    week: "Week 4",
                    detail: "Core feels different",
                    metric: "You'll know",
                    icon: "star.fill",
                    color: Palette.stateGood,
                    index: 3
                )
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            Text("Consistency beats intensity.\nYou just have to show up.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .opacity(beforeAfterVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.3).delay(1.0), value: beforeAfterVisible)

            Spacer()
            ctaBtn("Continue") { Haptics.light(); go(17) }
        }
        .background(Palette.bgPrimary)
        .onAppear {
            withAnimation(Motion.entranceSoft) { beforeAfterVisible = true }
        }
    }

    private func progressCard(week: String, detail: String, metric: String, icon: String, color: Color, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(week)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Text(metric)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(color)
                }
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
        .opacity(beforeAfterVisible ? 1 : 0)
        .offset(y: beforeAfterVisible ? 0 : CGFloat(8 + index * 4))
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.12), value: beforeAfterVisible)
    }

    // ═══════════════════════════════════════
    // MARK: - PERSONAL STAT (screen 22)
    // ═══════════════════════════════════════

    private var personalStatScreen: some View {
        let focusLabel = focusArea == "abs" ? "Abs Definition" :
                         focusArea == "obliques" ? "Waist Sculpting" :
                         focusArea == "lowerBack" ? "Core Strength" : "Full Core"

        let difficultyLabel: String = {
            if experience == "never" || experience == "gaveUp" { return "Beginner" }
            if activityLevel == "active" || activityLevel == "athlete" { return "Intermediate" }
            if baseline == "30to60" || baseline == "over60" { return "Intermediate" }
            return "Beginner"
        }()

        let sessionMin = sessionLength.isEmpty ? "7" : sessionLength
        let daysPerWeek = commitmentDays.isEmpty ? "5" : commitmentDays
        let weeklyMinutes = (Int(sessionMin) ?? 7) * (Int(daysPerWeek) ?? 5)

        return VStack(spacing: 0) {
            Spacer()

            Text("YOUR PLAN")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
                .tracking(2)
                .opacity(personalStatVisible ? 1 : 0)

            Spacer().frame(height: Space.md)

            if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Built for \(name)")
                    .font(Typo.titleItalic)
                    .foregroundStyle(Palette.textPrimary)
                    .opacity(personalStatVisible ? 1 : 0)
                    .offset(y: personalStatVisible ? 0 : 10)
            }

            Spacer().frame(height: Space.lg + 8)

            // 2026-05-30 visual upgrade: data-driven plan details now
            // sit in a single scrapbook chrome card (24pt corners, 1.5pt
            // accent border, hard offset shadow) instead of 6 separate
            // floating chips. Reads as "this is your plan artifact" —
            // matches the plan reveal capability ladder + the post-plan-
            // reveal sequence visual rhythm.
            VStack(spacing: 0) {
                planDetail(icon: "target", label: "Focus", value: focusLabel, index: 0)
                Divider().background(Palette.divider).padding(.horizontal, Space.md)
                planDetail(icon: "chart.bar", label: "Level", value: difficultyLabel, index: 1)
                Divider().background(Palette.divider).padding(.horizontal, Space.md)
                planDetail(icon: "clock", label: "Sessions", value: "\(sessionMin) min", index: 2)
                Divider().background(Palette.divider).padding(.horizontal, Space.md)
                planDetail(icon: "calendar", label: "Frequency", value: "\(daysPerWeek) days/week", index: 3)
                Divider().background(Palette.divider).padding(.horizontal, Space.md)
                planDetail(icon: "flame", label: "Weekly total", value: "\(weeklyMinutes) min", index: 4)
                Divider().background(Palette.divider).padding(.horizontal, Space.md)
                planDetail(icon: "waveform", label: "Coach", value: selectedCoachName, index: 5)
            }
            .padding(.vertical, Space.xs)
            .frame(maxWidth: .infinity)
            .scrapbookCardBackground()
            .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            // What adapts
            VStack(spacing: 6) {
                Text("Your workouts adapt based on:")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)

                HStack(spacing: 8) {
                    adaptTag("session ratings")
                    adaptTag("plank benchmarks")
                    adaptTag("consistency")
                }
            }
            .opacity(personalStatVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(1.0), value: personalStatVisible)

            Spacer()
            ctaBtn("Almost done") { Haptics.medium(); go(23) }
                .opacity(personalStatVisible ? 1 : 0)
        }
        .background(Palette.bgPrimary)
        .onAppear {
            Haptics.success()
            withAnimation(Motion.entrance) { personalStatVisible = true }
        }
    }

    /// 2026-05-30 visual upgrade: per-row background + corner removed
    /// since rows now live inside a single scrapbook chrome card on
    /// personalStatScreen. Staggered entrance animation (delay × index)
    /// preserved so the rows still feel like they're settling in one
    /// at a time.
    private func planDetail(icon: String, label: String, value: String, index: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Palette.accent)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, 12)
        .opacity(personalStatVisible ? 1 : 0)
        .offset(y: personalStatVisible ? 0 : CGFloat(6 + index * 3))
        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(0.2 + Double(index) * 0.08), value: personalStatVisible)
    }

    private func adaptTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.accent.opacity(0.08))
            .clipShape(Capsule())
    }

    private func statRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Text(emoji).font(.system(size: 16))
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // ═══════════════════════════════════════
    // MARK: - Shared
    // ═══════════════════════════════════════

    /// v4 R1b (2026-06-11) — the legacy gradient rounded-rect CTA is
    /// dead; every inline screen (teach beats, dividers, loader,
    /// notif pre-prime, coach intro, ...) now renders the one-CTA
    /// system through this shim. Labels lowercase per the her75
    /// register; call sites keep their own haptics (firesHaptic
    /// false avoids the double-fire).
    private func ctaBtn(_ title: String, action: @escaping () -> Void) -> some View {
        JFContinueButton(
            label: title.lowercased(),
            action: action,
            firesHaptic: false
        )
    }

    private func go(_ to: Int) {
        // 2026-06-01 bugfix: route through resolveNext() so callers
        // that pass a v1-only target (e.g., SectionDividerScreen.onAdvance
        // pointing to case 150 — a v1 yes/no relatability screen that
        // v2 dropped from flowOrder) auto-correct to the next valid
        // v2 screen. Without this, the progress bar fell back to ~0%
        // because `flowOrder.firstIndex(of: 150)` returns nil → ?? 0.
        let target = resolveNext(hint: to)
        // Direction comes from position in flowOrder, not raw screen number.
        // Raw screen numbers are non-monotonic (25 sits between 17 and 18, 26
        // between 21 and 22), so a "forward" advance can have a smaller raw
        // number than the screen it came from. The slide transition keys off
        // `dir`, and we want it to slide forward whenever the user is moving
        // forward in the flow.
        let fromIdx = flowOrder.firstIndex(of: screen) ?? 0
        let toIdx = flowOrder.firstIndex(of: target) ?? 0
        dir = toIdx >= fromIdx ? 1 : -1
        // Funnel events. `step_completed` fires for the step the user
        // is leaving (so we know what they finished); `step_viewed`
        // fires for the step they're arriving at. AnalyticsManager
        // coalesces dupes within its short window, so SwiftUI remounts
        // don't double-count.
        Analytics.track(.onboardingStepCompleted, properties: stepProperties(stepId: screen))
        Analytics.track(.onboardingStepViewed,    properties: stepProperties(stepId: target))
        // Epic #1 child #7: fire the dedicated attribution event when
        // leaving case 100 with a chosen source. The wrapping step
        // events already carry user_goal etc., but the dedicated event
        // lets PostHog funnel-by-source segments without joining on
        // the step event.
        if screen == 100 && !acquisitionSource.isEmpty {
            Analytics.track(.acquisitionSourceAnswered, properties: [
                "source": acquisitionSource
            ])
        }
        // Watermark — update before the screen swap so the progress
        // bar animates UP into the new position alongside the screen
        // transition (rather than holding then jumping after).
        // Back-nav passes a smaller toIdx, so `max(...)` holds the
        // existing high-water mark.
        maxProgressPos = max(maxProgressPos, toIdx)
        // Phase 20b: was 0.3s easeOut — read as rushed on a 26-screen
        // flow where every transition is the user's full attention.
        // Motion.crossFade (0.45s easeInOut) gives the slide more swell
        // without dragging.
        withAnimation(Motion.crossFade) { screen = target }
    }

    /// Standard property bag for onboarding step events. Includes
    /// position in flowOrder so funnel queries can sort by progression
    /// without needing the raw step → flow position map. user_goal +
    /// body_focus are included when set so PostHog can filter the
    /// funnel by audience segment.
    private func stepProperties(stepId: Int) -> [String: Any] {
        var props: [String: Any] = [
            "step_id": stepId,
            "step_position": flowOrder.firstIndex(of: stepId) ?? -1,
            "step_total": flowOrder.count
        ]
        if !goal.isEmpty { props["user_goal"] = goal }
        if !bodyFocus.isEmpty {
            // Sort for stable cardinality — same multi-select set
            // always produces the same property value in analytics.
            props["body_focus"] = bodyFocus.sorted().joined(separator: ",")
        }
        return props
    }

    private func goBack() {
        // Walk one step backward in flowOrder. Raw screen index math
        // ("screen - 1") doesn't work because indices jump around (200,
        // 1, 110, ...). If we're already at the first flow screen, fall
        // back to the welcome (0).
        if let pos = flowOrder.firstIndex(of: screen), pos > 0 {
            go(flowOrder[pos - 1])
        } else {
            go(0)
        }
    }
    private func finish() {
        // Funnel close. hasCompletedOnboarding (set by the host in
        // onComplete) prevents OnboardingView from being mounted again,
        // so this naturally one-shots without an extra guard.
        Analytics.track(.onboardingComplete, properties: [
            "user_goal": goal,
            "body_focus_count": bodyFocus.count,
            "coach": voicePreference
        ])

        // Notification permission is requested ONCE — at case 19's
        // "Allow notifications" button tap. That button already calls
        // requestAuthorization and scheduleDailyReminder on success, so
        // re-requesting here is redundant. Removed because the duplicate
        // call could surface a second iOS prompt in some install / test
        // scenarios (iOS normally caches, but reinstall + fast onboarding
        // can race the cache).

        // Derive the legacy focusArea (single String) from the Phase 4
        // bodyFocus multi-select. Downstream code (PlankAIApp →
        // userGoal pipeline) keys WorkoutGoal off focusArea, so we map
        // the first selected zone to the closest legacy bucket.
        let derivedFocusArea = focusAreaFromBodyFocus()

        // Derive legacy barriers from the Phase 5 yes/no answers so
        // downstream consumers (UserDefaults "userBarriers", UserRecord
        // .onboardingBarriers) keep populating without dropping the
        // signal. relatability1 → consistency, 2 → boredom, 3 → results.
        var derivedBarriers = Array(barriers)
        if relatability1 == true { derivedBarriers.append("motivation") }
        if relatability2 == true { derivedBarriers.append("boring") }
        if relatability3 == true { derivedBarriers.append("dontKnow") }

        // v4.5 R3 — derive cadence + session length (tier × movement
        // baseline) now that the explicit questions are cut.
        applyCadenceDerivations()

        var data = OnboardingData(
            goal: goal, experience: experience,
            baselineHoldSeconds: bS(baseline),
            barriers: derivedBarriers,
            ageRange: ageRange, activityLevel: activityLevel,
            focusArea: derivedFocusArea, plankTime: plankTime,
            commitmentDaysPerWeek: commitmentDaysCount(commitmentDays),
            sessionLengthMinutes: sessionLengthMinutes(sessionLength),
            notificationsEnabled: notificationsEnabled,
            notificationTime: notificationsEnabled ? notificationTime : nil,
            name: name, voicePreference: voicePreference
        )
        // Phase 4 additions — set after init since they have defaults.
        data.bodyFocus = Array(bodyFocus)
        data.motivation = motivation
        data.workoutLocation = workoutLocation
        data.workoutStyle = Array(workoutStyle)
        data.gender = gender
        data.heightCm = heightCm
        data.currentWeightKg = currentWeightKg
        data.goalWeightKg = goalWeightKg
        data.bodyTypeCurrent = bodyTypeCurrent
        data.bodyTypeDesired = bodyTypeDesired
        data.identityFeeling = identityFeeling
        data.rewardChoice = rewardChoice
        // v4.5 (2026-06-11): barrier multi (case 153) cut; the legacy
        // relatability flags derive from the 171/172/173 fear answers.
        // Mapping: another-diet aversion ≈ "apps make me feel worse",
        // quick-results distrust ≈ "i don't know what's right",
        // prior give-up ≈ "i quit when it gets hard".
        data.relatability1 = relatability1 ?? (fearAnotherDiet == "yes")
        data.relatability2 = relatability2 ?? (fearQuickResults == "yes")
        data.relatability3 = relatability3 ?? (fearPriorAttempt == "yes")
        data.acquisitionSource = acquisitionSource  // epic #1 child #7

        // v3 dead-code rip (2026-06-10) — v1 path (straight onComplete
        // without reveal sequence) removed. All users now route through
        // OnboardingRevealView. v1 was the pre-v1.0.6 flow; no realistic
        // user is still on it.
        pendingRevealData = data
        withAnimation(Motion.crossFade) { showRevealSequence = true }
    }

    private func bS(_ b: String) -> Int {
        switch b {
        case "under15":   return 10
        case "fifteen30": return 20
        case "thirty60":  return 45
        case "sixtyPlus": return 60
        case "notSure":   return 15
        default:          return 15
        }
    }

    private func sessionLengthMinutes(_ key: String) -> Int {
        switch key {
        case "five":    return 5
        case "ten":     return 10
        case "fifteen": return 15
        case "twenty":  return 20
        default:        return 7
        }
    }

    private func commitmentDaysCount(_ key: String) -> Int {
        switch key {
        case "three": return 3
        case "five":  return 5
        case "seven": return 7
        default:      return 5
        }
    }

    private func focusAreaFromBodyFocus() -> String {
        // Map the first selected aesthetic zone to the legacy training
        // bucket WorkoutGoal expects. flatBelly maps to abs (the existing
        // pipeline already knows how to handle abs as a focus). Other
        // zones fall back to fullCore since the workout pool isn't yet
        // structured around those targeted areas.
        guard let first = bodyFocus.first else { return "fullCore" }
        switch first {
        case "flatBelly": return "abs"
        case "tonedArms", "roundButt", "slimLegs", "fullBody": return "fullCore"
        default: return "fullCore"
        }
    }

    private func heightLabel(cm: Double) -> String {
        let inches = cm / 2.54
        let ft = Int(inches / 12)
        let inch = Int(inches.rounded()) - ft * 12
        return "\(ft)′ \(inch)″"
    }

    // MARK: - Ruler unit configs (Phase 4 Part 3 biometric pickers)
    //
    // Storage stays metric (cm / kg). The wrapper BiometricRulerScreen
    // round-trips through toMetric / fromMetric when the user toggles
    // — switching display + tick labels without mutating the metric
    // value beyond the active unit's snap precision.

    static let heightMetricRuler = BiometricRulerConfig(
        range: 107...213,
        step: 1,
        majorEvery: 10,
        mediumEvery: 5,            // medium tick every 5 cm
        format: { cm in "\(Int(cm.rounded())) cm" },
        unitName: "cm"
    )
    static let heightImperialRuler = BiometricRulerConfig(
        range: 36...84,            // inches: 3'0" to 7'0" — whole-foot
                                   // bounds so the major-tick labels
                                   // (3, 4, 5, 6, 7) anchor at the top
                                   // and bottom of the ruler.
        step: 1,
        majorEvery: 12,            // whole-foot major ticks (label only)
        mediumEvery: 6,            // half-foot medium ticks (no label)
        format: { inches in
            let i = Int(inches.rounded())
            let ft = i / 12
            let inch = i % 12
            return inch == 0 ? "\(ft)'" : "\(ft)'\(inch)\""
        },
        unitName: "ft"
    )

    static let weightMetricRuler = BiometricRulerConfig(
        range: 25...200,
        step: 0.5,
        majorEvery: 20,            // 20 × 0.5 kg = every 10 kg major
        format: { kg in
            kg.truncatingRemainder(dividingBy: 1) < 0.25
                ? "\(Int(kg.rounded())) kg"
                : String(format: "%.1f kg", kg)
        },
        unitName: "kg"
    )
    static let weightImperialRuler = BiometricRulerConfig(
        range: 55...441,           // lb: ≈25 kg to ≈200 kg
        step: 1,
        majorEvery: 25,            // every 25 lb major
        format: { lb in "\(Int(lb.rounded())) lb" },
        unitName: "lb"
    )

    private static let cmPerInch: Double = 2.54
    private static let lbPerKg: Double = 2.20462


    private func weightLabel(kg: Double) -> String {
        let lb = Int((kg * 2.20462).rounded())
        return "\(lb) lb"
    }

}

// MARK: - WeightCurveView
//
// Animated prediction chart. Used by firstPrediction (161),
// rePrediction (170), and finalPrediction (181). Holds its own
// animation state so each mount re-runs the entrance choreography
// (back-nav re-mounts get the same draw-in moment).
//
// Premium pack:
//   - Multi-stop gradient stroke (cocoa → accent rose → sage).
//   - Soft accent glow under the stroke for depth.
//   - Mid-curve "Week 1" callout pill with weight, dotted vertical
//     guide line down to the baseline, and a small accent dot.
//   - Goal-date pill above the goal endpoint (accent rose, white
//     text), springs in with a small overshoot.
//   - Pulse ring + sparkle sticker burst when the goal dot lands.
//
// Choreography:
//   t=0.00  start dot pops in (spring)
//   t=0.15  fill fades in (1.0s easeOut, alongside the draw)
//   t=0.20  stroke trims 0→1 left-to-right (1.1s easeOut)
//   t=1.25  Week 1 callout fades + scales in
//   t=1.30  goal dot pops, pulse ring fires, sparkle fades in
//   t=1.50  axis labels fade in
//   t=1.55  goal-date pill springs in
//
// reduceMotion snaps everything to final state.

/// Differentiates the "rough sketch" first projection (case 161) from
/// the "sharpened" re-projection (case 170). v1 + early v2 used the
/// same exact chart for both — same date pill, same stroke, same week-
/// one callout — so the "we got more honest" beat read as confusing
/// duplication. C2 (2026-06-01) splits the two so the user can SEE the
/// projection sharpen between attempts. .rough is the early estimate
/// (no date pill, dashed stroke, no week-one callout, lighter fill);
/// .sharp is the final refined view (current behavior).
enum PredictionStyle: Equatable {
    case rough
    case sharp
}

private struct WeightCurveView: View {
    let currentWeightKg: Double
    let goalWeightKg: Double
    let targetDate: Date
    let currentLabel: String
    let goalLabel: String
    let dateLabel: String
    var style: PredictionStyle = .sharp

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var curveProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var startDotVisible: Bool = false
    @State private var goalDotVisible: Bool = false
    @State private var labelsVisible: Bool = false
    @State private var datePillVisible: Bool = false
    @State private var weekCalloutVisible: Bool = false
    @State private var pulseRingScale: CGFloat = 1.0
    @State private var pulseRingOpacity: Double = 0
    @State private var sparkleVisible: Bool = false

    // Mid-curve "Week 1" position. t=0.22 lands visually inside the
    // first quarter of the curve regardless of the goal-date timeline,
    // which reads as "early progress" without forcing the math to be
    // calendar-exact (the visualization is symbolic, not clinical).
    private let weekOneT: CGFloat = 0.22

    // Weighted weight projection at t. The bezier curve drops faster
    // in the first half (steeper slope), so users see meaningful
    // early-week progress rather than a linear midpoint.
    private func projectedWeightKg(at t: CGFloat) -> Double {
        // Use the bezier y-position (relative to start→end y delta)
        // as the loss-progress fraction. Pure quadratic Bezier y(t).
        let yStart: CGFloat = 8
        let yEnd: CGFloat = 1.0  // we treat h-8 as 1.0 in the relative
        let yCtrl: CGFloat = 0.4 // h*0.4
        let mt = 1 - t
        // Normalize: compute the relative y between start (0) and end (1)
        // assuming heights cancel out. Use the y-progress of the bezier.
        let relStart: CGFloat = 0
        let relCtrl: CGFloat = (yCtrl - 0) / (1 - 0)  // 0.4
        let relEnd: CGFloat = 1
        _ = (yStart, yEnd)
        let progress = mt * mt * relStart + 2 * mt * t * relCtrl + t * t * relEnd
        return currentWeightKg + (goalWeightKg - currentWeightKg) * Double(progress)
    }

    private func weightLabelLb(_ kg: Double) -> String {
        "\(Int((kg * 2.20462).rounded())) lb"
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 32  // leave room for axis labels

            // Bezier control points — keep aligned with the curve Path.
            let p0 = CGPoint(x: 0, y: 8)
            let p1 = CGPoint(x: w * 0.55, y: h * 0.4)
            let p2 = CGPoint(x: w, y: h - 8)

            // Mid-curve point at weekOneT
            let mt = 1 - weekOneT
            let midX = mt * mt * p0.x + 2 * mt * weekOneT * p1.x + weekOneT * weekOneT * p2.x
            let midY = mt * mt * p0.y + 2 * mt * weekOneT * p1.y + weekOneT * weekOneT * p2.y
            let midWeightLabel = weightLabelLb(projectedWeightKg(at: weekOneT))

            let curve = Path { p in
                p.move(to: p0)
                p.addQuadCurve(to: p2, control: p1)
            }
            let fill = Path { p in
                p.move(to: p0)
                p.addQuadCurve(to: p2, control: p1)
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }

            // Multi-stop stroke gradient — cocoa → accent rose → sage.
            // Same gradient is reused for the stroke and its glow copy.
            let strokeGradient = LinearGradient(
                colors: [
                    Palette.bgInverse.opacity(0.75),
                    Palette.accent,
                    Palette.stateGood.opacity(0.85),
                ],
                startPoint: .leading, endPoint: .trailing
            )

            ZStack(alignment: .topLeading) {
                // Gradient fill underneath the curve. .rough fades it
                // further so the rough sketch reads as "estimate" not
                // "answer".
                fill
                    .fill(LinearGradient(
                        colors: [Palette.accent.opacity(style == .rough ? 0.15 : 0.30),
                                 Palette.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .opacity(fillOpacity)

                // Soft glow layer — same trimmed path, wider stroke,
                // blurred. Sits behind the main stroke for depth. Dimmer
                // in .rough so the sketch doesn't feel as "landed".
                curve
                    .trim(from: 0, to: curveProgress)
                    .stroke(strokeGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .blur(radius: 6)
                    .opacity(style == .rough ? 0.25 : 0.55)

                // Main stroke — multi-stop gradient. .rough uses a
                // dashed pattern + thinner line so the curve reads as
                // a hand-drawn estimate; .sharp uses the original solid
                // stroke that reads as "this is the real projection".
                curve
                    .trim(from: 0, to: curveProgress)
                    .stroke(strokeGradient,
                            style: style == .rough
                                ? StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4])
                                : StrokeStyle(lineWidth: 3, lineCap: .round))

                // Mid-curve "Week 1" callout group. Suppressed in .rough
                // so the early estimate doesn't pretend to know the
                // week-by-week shape — the sharpened version is the
                // first time the user sees that specificity.
                if weekCalloutVisible && style == .sharp {
                    // Vertical guide line from curve to baseline.
                    Path { p in
                        p.move(to: CGPoint(x: midX, y: midY + 4))
                        p.addLine(to: CGPoint(x: midX, y: h))
                    }
                    .stroke(Palette.textSecondary.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .transition(.opacity)

                    // Mid-curve dot.
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 2))
                        .position(x: midX, y: midY)
                        .transition(.scale.combined(with: .opacity))

                    // Cocoa callout pill — weight + "Week 1" eyebrow.
                    VStack(spacing: 1) {
                        Text(midWeightLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Palette.bgInverse, in: Capsule())
                        Text("Week 1")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .position(x: midX, y: midY - 26)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }

                // Start dot — anchored at the left endpoint of the curve.
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 2))
                    .offset(x: -5, y: 3)
                    .scaleEffect(startDotVisible ? 1 : 0)
                    .opacity(startDotVisible ? 1 : 0)

                // Pulse ring around goal dot — rendered first so the
                // dot sits on top.
                Circle()
                    .stroke(Palette.accent, lineWidth: 2)
                    .frame(width: 14, height: 14)
                    .scaleEffect(pulseRingScale)
                    .opacity(pulseRingOpacity)
                    .offset(x: w - 7, y: h - 15)

                // Sparkle sticker — small accent next to the goal dot
                // at landing time. JeniFit brand moment. .rough suppresses
                // it; the sparkle is the "this landed" punctuation, which
                // shouldn't fire on an early estimate.
                if style == .sharp {
                    Image(StickerName.sparkleGlossy.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                        .opacity(sparkleVisible ? 0.85 : 0)
                        .scaleEffect(sparkleVisible ? 1 : 0.6)
                        .offset(x: w - 38, y: h - 36)
                }

                // Goal dot — pops in after the stroke finishes drawing.
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 2))
                    .offset(x: w - 6, y: h - 14)
                    .scaleEffect(goalDotVisible ? 1 : 0)
                    .opacity(goalDotVisible ? 1 : 0)

                // Goal-date pill — accent rose with white text. Sits
                // above the goal endpoint, replaces the right-side
                // axis date label below. .rough suppresses it; the
                // rough sketch should not pretend to know a specific
                // date — the user only sees the date once the chart
                // sharpens (case 170).
                if style == .sharp {
                    Text(dateLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.accent, in: Capsule())
                        .offset(x: w - 64, y: h - 50)
                        .scaleEffect(datePillVisible ? 1 : 0.6)
                        .opacity(datePillVisible ? 1 : 0)
                }

                // Axis labels — Today + current weight on the left,
                // goal weight only on the right (date moved to pill).
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(Typo.eyebrow)
                            .foregroundStyle(Palette.textSecondary)
                        Text(currentLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Goal")
                            .font(Typo.eyebrow)
                            .foregroundStyle(Palette.textSecondary)
                        Text(goalLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .offset(y: h)
                .opacity(labelsVisible ? 1 : 0)
            }
        }
        .onAppear { runEntrance() }
    }

    private func runEntrance() {
        // Reset to initial state so re-mounts (back nav, screen revisit)
        // replay the choreography instead of staying static.
        curveProgress = 0
        fillOpacity = 0
        startDotVisible = false
        goalDotVisible = false
        labelsVisible = false
        datePillVisible = false
        weekCalloutVisible = false
        pulseRingScale = 1.0
        pulseRingOpacity = 0
        sparkleVisible = false

        if reduceMotion {
            curveProgress = 1
            fillOpacity = 1
            startDotVisible = true
            goalDotVisible = true
            labelsVisible = true
            datePillVisible = true
            weekCalloutVisible = true
            sparkleVisible = true
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)
            .delay(0.0)) {
            startDotVisible = true
        }
        withAnimation(.easeOut(duration: 1.0).delay(0.15)) {
            fillOpacity = 1
        }
        withAnimation(.easeOut(duration: 1.1).delay(0.20)) {
            curveProgress = 1
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)
            .delay(1.25)) {
            weekCalloutVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)
            .delay(1.30)) {
            goalDotVisible = true
        }
        // Pulse ring expansion + fade — fires once at goal-dot landing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            pulseRingOpacity = 0.7
            pulseRingScale = 1.0
            withAnimation(.easeOut(duration: 0.85)) {
                pulseRingScale = 2.4
                pulseRingOpacity = 0
            }
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)
            .delay(1.35)) {
            sparkleVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.50)) {
            labelsVisible = true
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)
            .delay(1.55)) {
            datePillVisible = true
        }
    }
}

/// Camera viewfinder corner brackets for the welcome demo mock.
struct WelcomeScanBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l: CGFloat = min(rect.width, rect.height) * 0.16
        let r = rect
        // top-left
        p.move(to: CGPoint(x: r.minX, y: r.minY + l))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        // top-right
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        // bottom-right
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        // bottom-left
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

/// v4.6 (2026-06-11) — per-element entrance cascade for question
/// screens. The reveal sequence's staggered choreography read as the
/// "luxury" register in founder QA while question screens snapped in
/// as one block; this wrapper gives every option row the same 0.06s
/// cascade so the whole flow speaks one motion language.
struct StaggeredReveal<Content: View>: View {
    let index: Int
    var baseDelay: Double = 0.18
    @ViewBuilder let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        content()
            // Motion-quality (v1.1): offset-only — the page transition owns the
            // fade, so option rows no longer double-fade opacity on top of it.
            // The staggered rise is what reads as the list assembling.
            .offset(y: revealed ? 0 : 14)
            .onAppear {
                guard !revealed else { return }
                if reduceMotion {
                    revealed = true
                } else {
                    withAnimation(
                        Motion.entranceSoft.delay(baseDelay + Double(index) * Motion.cascadeTight)
                    ) {
                        revealed = true
                    }
                }
            }
    }
}

// MARK: - SoftInRise (v1.1 transition-consistency pass)
//
// Reusable per-element soft-in: an offset rise on appear (the page
// transition owns the FADE, per the motion-quality pass), with an optional
// single soft haptic on settle. Lets the teach + bridge screens reveal with
// the same rhythm as the question screens they're interleaved with, instead
// of hard-cutting their content in. Reduce-motion snaps to final + no haptic.
private struct SoftInRise: ViewModifier {
    var delay: Double = 0
    var rise: CGFloat = 8
    var haptic: Bool = false

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : rise)
            .task {
                guard !appeared else { return }
                if reduceMotion { appeared = true; return }
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
                withAnimation(Motion.entranceSoft) { appeared = true }
                if haptic {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    Haptics.soft()
                }
            }
    }
}

private extension View {
    /// Onboarding soft-in: offset rise on appear + optional one-shot haptic.
    func softInRise(delay: Double = 0, rise: CGFloat = 8, haptic: Bool = false) -> some View {
        modifier(SoftInRise(delay: delay, rise: rise, haptic: haptic))
    }
}

struct OnboardingData {
    // Existing fields — downstream consumers (PlankAIApp.handleOnboardingComplete,
    // UserRecord schema, WorkoutGenerator) read these by name. Don't rename.
    let goal, experience: String; let baselineHoldSeconds: Int; let barriers: [String]
    let ageRange, activityLevel, focusArea, plankTime: String
    // var (not let): the reveal PacePicker can re-pick the pace after
    // assembly, and onRevealComplete refreshes these two derived fields.
    var commitmentDaysPerWeek: Int
    var sessionLengthMinutes: Int
    let notificationsEnabled: Bool; let notificationTime: Date?; let name, voicePreference: String

    // JeniFit phase 4 additions. New onboarding question content writes
    // these in addition to the legacy fields above. Defaults make them
    // safe to read from older code paths that don't know about them yet.
    var bodyFocus: [String] = []           // Part 1 multi-select: flatBelly/tonedArms/roundButt/slimLegs
    var motivation: String = ""            // Part 1: the "why"
    var workoutLocation: String = ""       // Part 2: home/gym/either/outdoor
    var workoutStyle: [String] = []        // Part 2 multi: hiit/strength/yoga/dance/walking
    var gender: String = ""                // Part 3
    var heightCm: Double = 170             // Part 3 slider
    var currentWeightKg: Double = 65       // Part 3 slider
    var goalWeightKg: Double = 60          // Part 3 slider
    var bodyTypeCurrent: Int = 3           // Part 3 slider 0-5 (0=Cut leanest, 5=Soft heaviest, 3=Average)
    var bodyTypeDesired: Int = 3           // Part 3 slider 0-5 (defaults match current; case 135 reseeds on mount)
    var identityFeeling: String = ""       // Part 4
    var rewardChoice: String = ""          // Part 4
    var relatability1: Bool = false        // Part 5: "I struggle to stay consistent"
    var relatability2: Bool = false        // Part 5: "I get bored doing the same thing"
    var relatability3: Bool = false        // Part 5: "Results don't come fast enough"

    /// 2026-05-30 (epic #1 child #7): how the user heard about JeniFit.
    /// One of "tiktok" | "instagram" | "friend" | "app_store" | "google"
    /// | "other". Empty string = not answered. Persists to UserRecord +
    /// Supabase as `onboarding_acquisition_source`.
    var acquisitionSource: String = ""
}

// MARK: - CTA Button Style

/// Press-feedback wrapper applied on top of buttons that already paint their
/// own background. Renamed from CTAButtonStyle in JeniFit phase 2; the
/// canonical brand button style now lives in DesignSystem/Components.swift
/// as `CTAButtonStyle(variant:)`. Call sites that wrap pre-styled buttons
/// keep using PressFeedbackStyle until their containing screens are
/// retokenized in phases 4–5.
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

