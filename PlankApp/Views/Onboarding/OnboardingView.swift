import SwiftUI
import AVFoundation
import AVKit
import StoreKit

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
        self._screen = State(wrappedValue: 0)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Data — legacy
    @State private var goal = ""
    @State private var experience = ""
    @State private var baseline = ""
    @State private var barriers: Set<String> = []
    @State private var ageRange = ""
    @State private var activityLevel = ""
    // 17b: ageYears + activityLevelIndex are the new wheel/slider
    // sources of truth. ageRange + activityLevel string mirrors are
    // updated via .onChange so downstream code paths
    // (WorkoutGenerator, AppSync, computed properties at 3153/3167/3674)
    // keep reading the legacy string keys unchanged.
    @State private var ageYears: Int = 25
    @State private var activityLevelIndex: Int = 2
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
    @State private var planCoachVisible = false
    @State private var planHeadlineVisible = false
    @State private var planSubheadVisible = false
    @State private var planPresetVisible = false
    @State private var planSparkleBurstActive = false
    @State private var planSparkleBurstVisible = false
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

    // ── Consent ritual (case 240) state ────────────────────────
    @State private var consentHoldProgress: CGFloat = 0
    @State private var consentHoldActive: Bool = false
    @State private var consentHoldCompleted: Bool = false
    @State private var consentHoldTimer: Timer?
    @State private var consentHapticHalfwayFired: Bool = false

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
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if screen >= 1 && !analyzing && screen != 20 {
                    navBar.transition(.opacity)
                }
                Spacer().frame(height: screen < 1 ? 0 : Space.sm)


                currentScreen
                    .id(screen)
                    // Editorial fade between onboarding screens. Was a
                    // directional slide which read as app-cliche; the
                    // straight opacity fade reads premium and avoids
                    // the visual whiplash on rapid forward/back nav.
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
        case 200: SectionDividerScreen(
            partNumber: 1, title: "Your story",
            supporting: "Three quick reads on what brought you here.",
            dwellSeconds: 1.6,
            // Routes to the anti-shame educational anchor (E1-a, case
            // 230) before the first question. Sets brand promise.
            onAdvance: { go(230) },
            stickerPlacements: Self.sectionDividerPlacements
        )
        case 201: SectionDividerScreen(
            partNumber: 2, title: "How you move now",
            supporting: "We'll match your plan to where you are today.",
            dwellSeconds: 1.6,
            onAdvance: { go(2) },
            stickerPlacements: Self.sectionDividerPlacements
        )
        case 202: SectionDividerScreen(
            partNumber: 3, title: "About you",
            supporting: "A few numbers so the math behind your plan is honest.",
            dwellSeconds: 1.6,
            // Routes to body-question primer (E1-b, case 231) before
            // the gender Q — Noom "why we ask" pattern reduces drop.
            onAdvance: { go(231) },
            stickerPlacements: Self.sectionDividerPlacements
        )
        case 203: SectionDividerScreen(
            partNumber: 4, title: "How you want to feel",
            supporting: "The version of you that's waiting on the other side.",
            dwellSeconds: 1.6,
            onAdvance: { go(140) },
            stickerPlacements: Self.sectionDividerPlacements
        )
        case 204: SectionDividerScreen(
            partNumber: 5, title: "What stops you",
            supporting: "Three honest questions. Tap whichever lands.",
            dwellSeconds: 1.6,
            onAdvance: { go(150) },
            stickerPlacements: Self.sectionDividerPlacements
        )
        case 205: SectionDividerScreen(
            partNumber: 6, title: "Ready to start",
            supporting: "Last few. Then your plan goes live.",
            dwellSeconds: 1.6,
            onAdvance: { go(3) },
            stickerPlacements: Self.sectionDividerPlacements
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
        case 230: educationalAntiShameScreen     // after Part 1 divider
        case 231: educationalBodyPrimerScreen    // before gender
        case 232: educationalFiveMinScreen       // before session length
        case 233: educationalCycleScreen         // after identity feeling
        case 234: educationalPlateauScreen       // before plan reveal

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
            sel: $monthSignals, next: 141
        )

        // ─── N2 — "what's worked before — and what hasn't?" ──────
        // Bridge between Q2 (current training) and Q8 (activity).
        // Net-new question, also @State only — no DB change. The
        // "what's worked before" Q is the most consistent question
        // across Noom / BetterMe / Lasta that JeniFit doesn't ask.
        case 236: jfMulti(
            "what's worked before — and what hasn't?",
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
        case 1: jfQuestion(
            "what are we becoming?",
            sub: "we'll build the entire plan around this answer.",
            opts: [
                ("loseWeight",  "Lose weight",              "Lean down, feel lighter",      "arrow.down.circle"),
                ("fullBody",    "Full body transformation", "Tone all over, head to toe",   "sparkle"),
                ("toneCore",    "Tone my core",             "Define abs and obliques",      "figure.core.training"),
                ("growGlutes",  "Grow glutes",              "Sculpt and lift",              "figure.strengthtraining.functional"),
                ("slimLegs",    "Slim and define legs",     "Lean, long lines",             "figure.walk"),
            ],
            sel: $goal, next: 110
        )

        case 110: jfMulti(
            "tap where you want to feel it.",
            sub: "pick as many as you want.",
            opts: [
                ("flatBelly", "Flat belly",          nil, "figure.core.training"),
                ("tonedArms", "Toned arms",          nil, "dumbbell.fill"),
                ("roundButt", "Round butt",          nil, "figure.strengthtraining.functional"),
                ("slimLegs",  "Slim legs",           nil, "figure.walk"),
                ("fullBody",  "Full body slimming",  nil, "figure.mixed.cardio"),
            ],
            sel: $bodyFocus, next: 111,
            confirmation: "Locked in. Your routines target these zones."
        )

        case 111: jfQuestion(
            "what's the real reason — be honest.",
            sub: "no judgment. it helps us pick the right tone.",
            opts: [
                ("getShaped",  "Get shaped",          "Build the body I want",     "figure.strengthtraining.traditional"),
                ("lookBetter", "Look better",         "Confidence in any outfit",  "sparkle"),
                ("summer",     "Prepare for summer",  "Beach-ready, glow-ready",   "sun.max"),
                ("confidence", "Feel more confident", "Stronger inside and out",   "heart.circle"),
                ("selfLove",   "Find self-love",      "Make peace with my body",   "heart.fill"),
            ],
            sel: $motivation, next: 201
        )

        // ─── Part 2 — How you move now ──────────────────────────
        case 2: jfQuestion(
            "honestly, how's it going right now?",
            sub: "no shame on any answer. the plan calibrates from this.",
            opts: [
                ("never",     "I don't really train",               nil,                         "moon.zzz"),
                ("gaveUp",    "I've tried, couldn't stick with it", nil,                         "arrow.uturn.backward"),
                ("sometimes", "Here and there",                     nil,                         "calendar"),
                ("regular",   "Regularly",                          "Multiple times a week",     "checkmark.circle.fill"),
            ],
            // Routes to N2 (case 236, "what's worked before") so the
            // experience context lands before activity level.
            sel: $experience, next: 236,
            inlineFeedback: [
                "gaveUp": ("We've been there.", "Most people quit by week two. Your plan is built around staying."),
                "regular": ("Got you.", "We'll keep it challenging without grinding you out."),
            ]
        )

        case 8: activityLevelScreen()

        case 120: jfQuestion(
            "Where will you train?",
            sub: "We tune the moves so they fit your space.",
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

        case 25: jfQuestion(
            "how much time can you actually give?",
            sub: "the smallest answer is also the smartest one for beginners.",
            opts: [
                ("five",    "5 minutes",  "Quick reset",           "5.circle"),
                ("ten",     "10 minutes", "Solid daily routine",   "10.circle"),
                ("fifteen", "15 minutes", "Full session",          "15.circle"),
                ("twenty",  "20 minutes", "Deep work",             "20.circle"),
            ],
            sel: $sessionLength, next: 17
        )

        case 17: jfQuestion(
            "let's pick something you'll actually show up for.",
            sub: "five days is the sweet spot. three is honest. seven is rare.",
            opts: [
                ("three", "3 days", "Easing in",    "3.circle"),
                ("five",  "5 days", "Recommended",  "5.circle"),
                ("seven", "7 days", "All in",       "7.circle"),
            ],
            // Routes to case 270 (habit-window quiz) before Part 3
            // divider. Phase 4: education-as-quiz teaches the 12-week
            // habit frame before the body Q cluster lands.
            sel: $commitmentDays, next: 270,
            confirmation: "got it. your plan starts here."
        )

        // ─── Part 3 — About you (biometrics) ────────────────────
        case 130: jfQuestion(
            "What's your gender?",
            sub: "We adjust your plan based on this.",
            opts: [
                ("female",    "Female",            nil, "person.fill"),
                ("male",      "Male",              nil, "person.fill"),
                ("nonbinary", "Non-binary",        nil, "person.crop.circle"),
                ("private",   "Prefer not to say", nil, "person.crop.circle.badge.questionmark"),
            ],
            sel: $gender, next: 7
        )

        case 7: ageWheelScreen()

        case 131: jfSliderScreen(
            "How tall are you?",
            sub: "We use this to calibrate intensity.",
            valueMetric: $heightCm,
            metric: Self.heightMetricRuler,
            imperial: Self.heightImperialRuler,
            toMetric: { inches in inches * Self.cmPerInch },
            fromMetric: { cm in (cm / Self.cmPerInch).rounded() },
            next: 132
        )

        case 132: jfHorizontalSliderScreen(
            "what's your current weight?",
            sub: "we round to the kilo. just for your plan.",
            valueMetric: $currentWeightKg,
            metric: Self.weightMetricRuler,
            imperial: Self.weightImperialRuler,
            toMetric: { lb in lb / Self.lbPerKg },
            fromMetric: { kg in (kg * Self.lbPerKg).rounded() },
            next: 133,
            // Affirmation beat — sensitive numeric input. Research:
            // Noom-pattern validation after weight entry reduces drop.
            // Gen-Z casual lowercase to match the audience voice.
            confirmation: "okay. that's the hard one. ♥",
            annotation: {
                bmiAnnotation(weightKg: currentWeightKg, heightCm: heightCm)
            }
        )

        case 133: jfHorizontalSliderScreen(
            "And your goal weight?",
            sub: "Sets your target. You can change this later.",
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
            confirmation: "thank you for sharing. that's the hardest field on this form.",
            annotation: {
                goalWeightAnnotation(currentKg: currentWeightKg, goalKg: goalWeightKg)
            }
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
        case 140:
            ZStack {
                StickerScatter(placements: Self.identityPlacements)
                jfQuestion(
                    "Which one feels most like the new you?",
                    sub: "Pick the version that's pulling you forward.",
                    opts: [
                        ("powerful", "Powerful", "Confident, undeniable",   nil),
                        ("calm",     "Calm",     "At home in my body",      nil),
                        ("light",    "Light",    "Free, unburdened",        nil),
                        ("strong",   "Strong",   "Capable, grounded",       nil),
                        ("radiant",  "Radiant",  "Glowing from inside out", nil),
                    ],
                    // Routes to E1-d (case 233, cycle awareness) →
                    // N1 (235, "this month signals") → 141 reward Q.
                    sel: $identityFeeling, next: 233,
                    // Reciprocity beat — Phase 2 refresh. Lowercase peer
                    // voice replaces the older capitalized corporate
                    // affirmation; brevity reads as warmer than the
                    // earlier "your plan is built around getting you
                    // there" coach-statement.
                    confirmation: "got it. we'll build around that.",
                    stickers: [
                        "powerful": .starLineart,
                        "calm":     .flower3D,
                        "light":    .balloonDog,
                        "strong":   .ribbonLineart,
                        "radiant":  .sparkleGlossy,
                    ]
                )
            }

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

        // ─── Part 5 — What stops you ────────────────────────────
        case 150: jfYesNo(
            prefix: "Workout apps make me feel further from my body, not ",
            italic: "closer",
            suffix: ".",
            sticker: .flower3D,
            heroImage: "edu-barrier-body",
            bind: $relatability1, next: 151
        )
        case 151: jfYesNo(
            prefix: "I have no idea which workouts are ",
            italic: "right",
            suffix: " for me.",
            sticker: .starLineart,
            heroImage: "edu-barrier-guidance",
            bind: $relatability2, next: 152
        )
        case 152: jfYesNo(
            prefix: "I quit when something feels ",
            italic: "too hard",
            suffix: " or boring.",
            sticker: .heartsLineart,
            heroImage: "edu-barrier-stick",
            bind: $relatability3, next: 206,
            // Reciprocity beat — closes the barriers sequence. Phase 2
            // refresh aligns with the RevenueCat reciprocity finding +
            // matches the peer-voice cadence of cases 133 and 140.
            // Underlying Rhodes & de Bruijn 2013 still applies (naming
            // the barrier closes ~50% of intention-behavior gap).
            confirmation: "reading you. these aren't excuses."
        )

        // ─── Part 6 — Ready to start ────────────────────────────
        case 3:
            ZStack {
                StickerScatter(placements: Self.baselinePlacements)
                jfQuestion(
                    "how long can you hold a plank?",
                    sub: "your starting benchmark. \"no idea\" is also an answer.",
                    opts: [
                        ("under15",   "Under 15s",  "Just starting",       "stopwatch"),
                        ("fifteen30", "15-30s",     "Building a base",     "stopwatch.fill"),
                        ("thirty60",  "30-60s",     "Solid foundation",    "timer"),
                        ("sixtyPlus", "60+ seconds","Strong already",      "flame.fill"),
                        ("notSure",   "Not sure",   "We'll figure it out", "questionmark.circle"),
                    ],
                    sel: $baseline, next: 11
                )
            }

        case 11: jfQuestion(
            "When should we send your daily reminder?",
            sub: "You'll get one notification at this time, every day.",
            opts: [
                ("morning",   "Morning",   "Around 7 AM",   "sunrise.fill"),
                ("afternoon", "Afternoon", "Around 1 PM",   "sun.max.fill"),
                ("evening",   "Evening",   "Around 7 PM",   "moon.stars.fill"),
                ("whenever",  "Whenever",  "Around 9 AM",   "shuffle"),
            ],
            sel: $plankTime, next: 18,
            inlineFeedback: [
                "morning": ("Solid pick.", "Mornings stick best — you'll be done before the day pulls at you."),
            ]
        )

        case 18: nameInput
        case 19: coachSelector

        // ─── Phase 5 — prediction / loading / plan reveal ─────
        case 160: reshapeTransitionScreen
        case 161: firstPredictionScreen
        case 170: rePredictionScreen
        case 180: loadingCarouselScreen
        case 181: finalPredictionScreen

        // ─── Post-question pipeline ─────
        case 20: EmptyView() // legacy analyzing overlay marker — superseded by 180
        case 21: planRevealScreen
        case 22: personalStatScreen
        case 23: cameraSetupScreen
        case 215: reviewPromptScreen

        // ─── Method preview (250) — "what you get with me" ──────────
        // Sits between plan reveal (21) and consent (240). Previews the
        // daily 5-min ritual (the only post-purchase feature). Honest
        // teaser of the 5-day arc + Jeni audio sample so the consent
        // ritual signs against something concrete, not abstract.
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

        // ─── Consent ritual (240) — playful pinky-promise pledge ────
        // Press-and-hold 2.8s long-press signature. Cialdini commitment
        // & consistency principle in app form — small voluntary
        // commitment lifts follow-through. Placed between method preview
        // (250) and rating prefilter (215) — IKEA-effect maximum: user
        // has just received a personalized plan + seen the daily ritual.
        case 240: consentRitualScreen
        case 26: SignInPromptView { Haptics.medium(); go(22) }

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
    private static let flowOrder: [Int] = [
        // Part 1 — anti-shame anchor (230) right after the divider
        // sets the brand promise before any sensitive Q.
        200, 230, 1, 110, 111,
        // Part 2 — N2 (236, "what's worked before") after Q2 so the
        // experience context lands before activity level. E1-c (232,
        // five-min science) before session length pre-empts doubt.
        201, 2, 236, 8, 120, 121, 232, 25, 17,
        // Phase 4 — education-as-quiz beat (12-week habit window).
        // Teaches the JeniFit 3-month evidence frame before the body
        // Q cluster lands; value delivered pre-paywall, antidote to
        // "extraction without value" perception (Noom-research finding).
        270,
        // Part 3 — E1-b (231, body-Q primer) immediately before
        // gender reduces drop on the highest-skip questions.
        202, 231, 130, 7, 131, 132, 133, 134, 135,
        // Phase 5 — reshape transition + first prediction (commit-escalation)
        160, 161,
        // Part 4 — E1-d (233, cycle awareness) after identity Q, then
        // N1 (235, "this month") routes into reward Q.
        203, 140, 233, 235, 141, 142,
        // Phase 5 — re-prediction recap
        170,
        // Phase 3 — tier-ladder identity preview (week 1 / 3 / 8).
        // Shows progression as identity, not weight numbers.
        260,
        // Part 5
        204, 150, 151, 152,
        // Mid-flow recap — "so here's you" — surfaces 4 of the user's
        // own answers so the Part 6 + plan reveal feel earned.
        206,
        // Part 6
        205, 3, 11, 18, 19,
        // Phase 5 — loading carousel + final prediction → plateau
        // pre-frame (E1-e, 234) → plan reveal → method preview (250,
        // "what you get with me" — daily ritual tease, only post-purchase
        // feature) → consent ritual (240, pinky-promise long-press
        // signature) → rating prefilter → sign-in → personal stat →
        // camera setup.
        //
        // Phase 3 (2026 conversion pass): tier-ladder identity preview
        // (260) inserted between re-prediction (170) and Part 5 divider
        // (204) — shows the user what each week of the program FEELS
        // like in identity terms (building / steady / stronger), not
        // weight numbers. Companion to the comparison frame at case
        // 142.
        180, 181, 234, 21, 250, 240, 215, 26, 22, 23,
    ]

    private var progressFraction: CGFloat {
        let pos = Self.flowOrder.firstIndex(of: screen) ?? 0
        return CGFloat(pos + 1) / CGFloat(Self.flowOrder.count)
    }

    private var navBar: some View {
        HStack(spacing: Space.sm) {
            Button { Haptics.light(); goBack() } label: {
                Image(systemName: "arrow.left").font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Palette.textPrimary).frame(width: 40, height: 40)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 4)
                    Capsule().fill(Palette.textPrimary)
                        .frame(width: max(8, geo.size.width * progressFraction), height: 4)
                        // easeOut, not spring — spring can overshoot on a small
                        // forward delta (e.g., 69% → 73%) and look like a regression.
                        // Slightly slower than the page-swap so the bar reads as
                        // catching up to the screen, not racing it.
                        .animation(Motion.entrance, value: screen)
                }
            }.frame(height: 4)
            Color.clear.frame(width: 40, height: 40)
        }.padding(.horizontal, Space.screenPadding)
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

    private var welcome: some View {
        GeometryReader { geo in
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()

                StickerScatter(placements: Self.welcomePlacements)

                VStack(spacing: 0) {
                    welcomeTopBar
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    Spacer().frame(height: 32)

                    welcomeEyebrow
                        .padding(.horizontal, 24)
                        .opacity(welcomeEyebrowVisible ? 1 : 0)
                        .offset(y: welcomeEyebrowVisible ? 0 : 8)

                    Spacer().frame(height: 12)

                    welcomeHeadline
                        .padding(.horizontal, 24)
                        .opacity(welcomeHeadlineVisible ? 1 : 0)
                        .offset(y: welcomeHeadlineVisible ? 0 : 12)

                    Spacer().frame(height: 16)

                    welcomeSubhead
                        .padding(.horizontal, 24)
                        .opacity(welcomeSubheadVisible ? 1 : 0)
                        .offset(y: welcomeSubheadVisible ? 0 : 12)

                    Spacer().frame(height: 20)

                    // Plank video block — restored after the polaroid
                    // experiment. Keeps Variant D's founder-voice copy
                    // above (eyebrow + headline + subhead) but lets
                    // the video carry the visual weight. Cap shrunk
                    // from 240–380 to 200–320 so the welcome stack
                    // still fits with the shorter Variant D headline.
                    welcomeVideoBlock(height: max(200, min(320, geo.size.height * 0.36)))
                        .padding(.horizontal, 24)
                        .opacity(welcomeVideoVisible ? 1 : 0)
                        .scaleEffect(welcomeVideoVisible ? 1.0 : 0.96)

                    Spacer(minLength: 12)

                    welcomeCTA
                        .padding(.horizontal, 24)
                        .opacity(welcomeCtaVisible ? 1 : 0)
                        .scaleEffect(welcomeCtaVisible ? 1.0 : 0.96)

                    Text("free to begin.")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 8)
                        .opacity(welcomeCtaVisible ? 1 : 0)

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
                    .opacity(welcomeCtaVisible ? 1 : 0)
                }
            }
            .task { await runWelcomeChoreography() }
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
            + Text("you").font(.custom("Fraunces72pt-RegularItalic", size: 17))
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

    private func jfHeader(_ title: String, sub: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(title)
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let sub {
                Text(sub)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.screenPadding)
    }

    private func advance(to next: Int, confirmation: String?) {
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
                    go(next)
                }
            }
        } else {
            go(next)
        }
    }

    private func jfQuestion(
        _ title: String, sub: String? = nil,
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
        stickers: [String: StickerName]? = nil
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, optTitle, optSub, optIcon in
                    OnboardingOptionCard(
                        icon: optIcon,
                        sticker: stickers?[key],
                        title: optTitle,
                        subtitle: optSub,
                        isSelected: sel.wrappedValue == key,
                        action: {
                            Haptics.light()
                            withAnimation(Motion.tap) {
                                sel.wrappedValue = key
                            }
                        }
                    )
                }

                if let feedback = inlineFeedback,
                   let entry = feedback[sel.wrappedValue] {
                    inlineFeedbackCard(heading: entry.0, body: entry.1)
                        .padding(.top, Space.xs)
                }
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            Button("Continue") {
                advance(to: next, confirmation: confirmation)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
            .opacity(sel.wrappedValue.isEmpty ? 0.35 : 1.0)
            .disabled(sel.wrappedValue.isEmpty)
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
            jfHeader("What's your age?",
                     sub: "We adjust your plan based on this.")

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

            Button("Continue") {
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
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
    }

    // MARK: - 17b-2: Activity level slider
    //
    // Replaces the 5-row jfQuestion list with a halo-and-slider view:
    // a sticker inside an accent ring swaps per index, a big title +
    // description block updates beneath it, and a 5-position slider
    // drives the value. Same activityLevel keys as before so all
    // downstream consumers stay unchanged.

    private static let activityLevelKeys = [
        "sedentary", "light", "moderate", "active", "athlete"
    ]
    private static let activityLevelTitles = [
        "MOSTLY RESTING", "LIGHT", "STEADY", "VERY ACTIVE", "ATHLETE LEVEL"
    ]
    private static let activityLevelSubtitles = [
        "Mostly sitting — that's where I'm at right now.",
        "Short walks, errands, the occasional movement break.",
        "On my feet most of the day.",
        "Physical job or daily walks already in the routine.",
        "Training is a daily thing for me.",
    ]
    private static let activityLevelStickers: [StickerName] = [
        .teddyPlaid, .tulipBouquet, .heartGlossy, .sparkleGlossy, .starLineart
    ]

    private func activityLevelScreen() -> some View {
        let idx = max(0, min(Self.activityLevelKeys.count - 1, activityLevelIndex))
        let sticker = Self.activityLevelStickers[idx]

        return VStack(spacing: 0) {
            jfHeader("Choose your activity level",
                     sub: "Outside of workouts. Walking, standing, errands.")

            Spacer()

            ZStack {
                Circle()
                    .stroke(Palette.accent.opacity(0.55), lineWidth: 2)
                    .frame(width: 180, height: 180)

                Image(sticker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .opacity(sticker.style.opacity)
                    .id(idx)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.22), value: idx)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.xs) {
                Text(Self.activityLevelTitles[idx])
                    .font(.custom("Fraunces72pt-SemiBold", size: 22))
                    .tracking(1.5)
                    .foregroundStyle(Palette.textPrimary)
                    .contentTransition(.opacity)

                Text(Self.activityLevelSubtitles[idx])
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(.easeOut(duration: 0.18), value: idx)

            Spacer().frame(height: Space.lg)

            ActivityLevelSliderTrack(
                index: $activityLevelIndex,
                count: Self.activityLevelKeys.count
            )
            .frame(height: 50)
            .padding(.horizontal, Space.lg)

            HStack {
                Text("Not active")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("Highly active")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, Space.lg)

            Spacer()

            Button("Continue") {
                // Sync the legacy activityLevel string here rather
                // than per-tick onChange, mirroring the age wheel
                // pattern (avoids parent re-renders during slider
                // drag that can interact poorly with downstream
                // screens that need a clean mount).
                let clampedIdx = max(0, min(Self.activityLevelKeys.count - 1,
                                            activityLevelIndex))
                activityLevel = Self.activityLevelKeys[clampedIdx]
                advance(to: 120, confirmation: nil)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
        .onAppear {
            if activityLevel.isEmpty {
                activityLevel = Self.activityLevelKeys[idx]
            }
        }
    }

    private func jfMulti(
        _ title: String, sub: String? = nil,
        opts: [(String, String, String?, String?)],
        sel: Binding<Set<String>>,
        next: Int,
        confirmation: String? = nil,
        minSelection: Int = 1
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, optTitle, optSub, optIcon in
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
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            Button("Continue") {
                advance(to: next, confirmation: confirmation)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
            .opacity(sel.wrappedValue.count < minSelection ? 0.35 : 1.0)
            .disabled(sel.wrappedValue.count < minSelection)
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
            Button("Continue") {
                advance(to: next, confirmation: confirmation)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
    }

    /// JustFit-style horizontal-ruler screen. Used by the weight
    /// (case 132) and goal-weight (case 133) questions. Identical
    /// shape to jfSliderScreen but the inner ruler is horizontal,
    /// the value sits above the indicator, and an optional metric
    /// band range visualizes a target zone (e.g. loss range).
    private func jfHorizontalSliderScreen<Annotation: View>(
        _ title: String, sub: String? = nil,
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
            jfHeader(title, sub: sub)
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
            Button("Continue") {
                advance(to: next, confirmation: confirmation)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
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
            Button("Continue") {
                advance(to: next, confirmation: confirmation)
            }
            .buttonStyle(.ctaPrimary)
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.lg)
        }
    }

    /// Real-time BMI display under the current-weight ruler. Updates
    /// continuously as the user drags. Color-coded category text:
    /// sage green for Normal, warm orange for everything else. Reads
    /// as a credibility signal (we know how this works) rather than a
    /// judgment — the labels stay clinical, no editorializing.
    private func bmiAnnotation(weightKg: Double, heightCm: Double) -> some View {
        let heightM = heightCm / 100
        let bmi = (heightM > 0) ? weightKg / (heightM * heightM) : 0
        let bmiText = String(format: "%.1f", bmi)
        let label: String
        let color: Color
        let support: String
        switch bmi {
        case ..<18.5:
            label = "Underweight"
            color = Palette.stateWarn
            support = "Strength training and steady fueling will round out your build."
        case 18.5..<25:
            label = "Normal weight"
            color = Palette.stateGood
            support = "You're in a healthy range — let's lock in habits that last."
        case 25..<30:
            label = "Overweight"
            color = Palette.stateWarn
            support = "A little more movement unlocks a stronger, lighter you."
        default:
            label = "Obese"
            color = Palette.stateWarn
            support = "Steady wins — your plan moves at a pace your body thanks you for."
        }
        return HStack(alignment: .top, spacing: Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your BMI:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(bmiText)
                    .font(.custom("Fraunces72pt-SemiBold", size: 32))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(color)
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
    /// reasonable / ambitious / aggressive) but JeniFit-flavored copy.
    /// 0.75 kg/week is the clinical median for sustainable loss; weeks
    /// estimate is the rounded division of total loss by that rate.
    private func goalWeightAnnotation(currentKg: Double, goalKg: Double) -> some View {
        let lossKg = currentKg - goalKg
        let percentLoss = currentKg > 0 ? (lossKg / currentKg) * 100 : 0
        let weeks = max(1, Int((lossKg / 0.75).rounded()))
        let percentInt = max(0, Int(percentLoss.rounded()))

        let header: String
        let color: Color
        let mainBefore: String
        let mainAccent: String
        let mainAfter: String
        let support: String

        if goalKg >= currentKg {
            header = "Maintain mode:"
            color = Palette.textSecondary
            mainBefore = "Holding steady"
            mainAccent = ""
            mainAfter = " — your plan adapts."
            support = "Strength + recovery work keeps the version of you that you've earned."
        } else if percentLoss <= 15 {
            header = "Reasonable goal:"
            color = Palette.stateGood
            mainBefore = "You'll lose "
            mainAccent = "\(percentInt)%"
            mainAfter = " of your weight."
            support = "Research links 10%+ loss to meaningful gains across health markers."
        } else if percentLoss <= 25 {
            header = "Ambitious goal:"
            color = Palette.stateWarn
            mainBefore = "About "
            mainAccent = "\(weeks) weeks"
            mainAfter = " of consistent work."
            support = "Steady weekly progress beats spikes — we'll keep the plan honest."
        } else {
            header = "Significant goal:"
            color = Palette.stateWarn
            mainBefore = "Focus on "
            mainAccent = "sustainable"
            mainAfter = " progress."
            support = "Aiming for ~0.5 kg/week protects muscle and reduces rebound."
        }

        let mainLine: Text = (
            Text(mainBefore)
                .foregroundStyle(Palette.textPrimary)
            + Text(mainAccent)
                .foregroundStyle(Palette.accent)
                .fontWeight(.bold)
            + Text(mainAfter)
                .foregroundStyle(Palette.textPrimary)
        )

        return VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            mainLine
                .font(.system(size: 16, weight: .semibold))
            Text(support)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Palette.divider, lineWidth: 1)
        )
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
    private func jfYesNo(
        prefix: String,
        italic: String,
        suffix: String,
        sticker: StickerName,
        heroImage: String? = nil,
        bind: Binding<Bool?>,
        next: Int,
        confirmation: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero — either the large generated illustration (when
            // `heroImage` is provided) or the small sticker-in-halo
            // fallback. The illustration renders at 180pt on a soft
            // accentSubtle (#F5D5D8) rounded backdrop so transparency
            // edge cases blend into the pink rather than the cream bg.
            Group {
                if let heroImage = heroImage {
                    Image(heroImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .padding(Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Palette.accentSubtle)
                        )
                } else {
                    ZStack {
                        Circle()
                            .fill(Palette.accent.opacity(0.10))
                            .frame(width: 92, height: 92)
                        Image(sticker.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .opacity(sticker.style.opacity)
                    }
                }
            }
            .padding(.bottom, Space.lg)

            (Text(prefix).font(Typo.title)
             + Text(italic).font(Typo.titleItalic)
             + Text(suffix).font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.lg)

            Spacer()

            HStack(spacing: Space.md) {
                Button {
                    Haptics.medium()
                    bind.wrappedValue = false
                    advance(to: next, confirmation: confirmation)
                } label: {
                    Text("Not me")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Palette.bgElevated,
                                    in: RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Palette.divider, lineWidth: 1)
                        )
                }
                .buttonStyle(PressFeedbackStyle())

                Button {
                    Haptics.medium()
                    bind.wrappedValue = true
                    advance(to: next, confirmation: confirmation)
                } label: {
                    Text("Yeah, that's me")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Palette.accent,
                                    in: RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(PressFeedbackStyle())
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.bottom, Space.xl)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - QUESTION (legacy — feedback on Continue)
    // ═══════════════════════════════════════

    @State private var inlineFeedback = ""
    @State private var showInlineFeedback = false

    private func questionView(_ title: String, sub: String?, opts: [(String, String)],
                              sel: Binding<String>, feedbacks: [String: String], next: Int) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)

            Spacer().frame(height: Space.lg)

            // Options (disabled during feedback)
            VStack(spacing: Space.sm) {
                ForEach(opts, id: \.0) { key, label in
                    let on = sel.wrappedValue == key
                    Button {
                        Haptics.light()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { sel.wrappedValue = key }
                    } label: {
                        Text(label)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(on ? Palette.textInverse : Palette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20).frame(height: 56)
                            .background(on ? Palette.bgInverse : Palette.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .scaleEffect(on ? 1.02 : 1.0)
                    .animation(.spring(response: 0.25), value: on)
                    .disabled(showInlineFeedback)
                }
            }
            .padding(.horizontal, Space.screenPadding)
            .opacity(showInlineFeedback ? 0.5 : 1.0)
            .animation(.easeOut(duration: 0.2), value: showInlineFeedback)

            // Feedback area (fixed height, between options and button)
            ZStack {
                if showInlineFeedback {
                    Text(inlineFeedback)
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

            // Continue button
            ctaBtn("Continue") {
                Haptics.medium()
                if let fb = feedbacks[sel.wrappedValue] {
                    inlineFeedback = fb
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showInlineFeedback = true
                    }
                    Haptics.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut(duration: 0.15)) { showInlineFeedback = false }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if next == -1 { withAnimation { analyzing = true }; startAnalyzing() }
                            else { go(next) }
                        }
                    }
                } else {
                    if next == -1 { withAnimation { analyzing = true }; startAnalyzing() }
                    else { go(next) }
                }
            }
            .opacity(sel.wrappedValue.isEmpty ? 0.3 : 1.0)
            .disabled(sel.wrappedValue.isEmpty || showInlineFeedback)
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
                    featurePill("waveform", "Voice coaching — not just beeps")
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
            StickerScatter(placements: Self.coachSelectorPlacements)

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
                        quote: "\"You're doing amazing — keep breathing.\"",
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
        case "encouraging": return "Your workout is ready. Your coach is waiting."
        case "balanced":    return "Your workout is ready. Sam's got something for you."
        default:            return "Your workout is ready. Don't make Kira wait."
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
            StickerScatter(placements: Self.recapPlacements)

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
        let mins = sessionLength.isEmpty ? 7 : (Int(sessionLength) ?? 7)
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
    private func educationalScreen(
        heroImage: String? = nil,
        eyebrow: String? = nil,
        headline: String,
        italicWords: [String],
        body: String,
        next: Int
    ) -> some View {
        ZStack {
            StickerScatter(placements: Self.educationalPlacements)

            VStack(spacing: 0) {
                Spacer()

                // Optional hero illustration. Flat editorial style
                // generated via Grok Imagine. Sits above the eyebrow
                // as the visual anchor. Backed by a soft accentSubtle
                // (#F5D5D8) rounded rectangle so any residual
                // transparency artifacts blend into the pink instead
                // of showing against the cream app bg.
                if let heroImage = heroImage {
                    Image(heroImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .padding(Space.md)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Palette.accentSubtle)
                        )
                        .padding(.horizontal, Space.lg)
                    Spacer().frame(height: Space.lg)
                }

                if let eyebrow = eyebrow {
                    Text(eyebrow)
                        .font(Typo.eyebrow)
                        .tracking(2)
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, Space.screenPadding)
                    Spacer().frame(height: Space.md)
                }

                ItalicAccentText(headline,
                                 italic: italicWords,
                                 alignment: .center)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.lg)

                Text(body)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.screenPadding)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                ctaBtn("continue") { Haptics.light(); go(next) }
            }
        }
        .background(Palette.bgPrimary)
    }

    /// LIGHT 4-sticker scatter for educational screens. Edge-only so
    /// the centered headline + body stay the visual anchor. Mix of
    /// line-art + painterly. Matches the onboarding chrome.
    private static let educationalPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.12),
                         size: 28, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.92, y: 0.14),
                         size: 30, rotation: 12, phaseDelay: 0.20),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.10, y: 0.88),
                         size: 30, rotation: 9, phaseDelay: 0.50),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.92, y: 0.86),
                         size: 32, rotation: -10, phaseDelay: 0.75),
    ]

    // 230 (E1-a) — brand-promise anchor + coach intro. Sets the
    // long-game expectation before any sensitive Q. Routes → case 1.
    // Renamed from anti-shame framing — same placement, positive
    // version. Five-minutes-a-day commitment is the brand throughline.
    private var educationalAntiShameScreen: some View {
        educationalScreen(
            heroImage: "edu-coach-intro",
            eyebrow: "first things first",
            headline: "you've got jeni now.",
            italicWords: ["jeni"],
            body: "she keeps it short, honest, and yours. five minutes a day. she'll bring the rest. ♥",
            next: 1
        )
    }

    // 231 (E1-b) — body-question priming. Reduces drop on the most-
    // skipped questions (gender, weight, body shape). Placed before
    // case 130 (gender). Routes → case 130.
    private var educationalBodyPrimerScreen: some View {
        educationalScreen(
            heroImage: "edu-body-primer",
            eyebrow: "heads up",
            headline: "the next few are about your body.",
            italicWords: ["your body"],
            body: "just to calibrate session difficulty and your progress chart. these stay between you and jeni.",
            next: 130
        )
    }

    // 232 (E1-c) — five-minute science. Pre-empts the "is 5 min
    // enough?" doubt before case 25 (session length). Routes → 25.
    private var educationalFiveMinScreen: some View {
        educationalScreen(
            heroImage: "edu-five-minutes",
            eyebrow: "real talk",
            headline: "five minutes is the science answer.",
            italicWords: ["five"],
            body: "beginners who start at 5 stick around 3× longer than those who start at 30. it's not about working harder. it's about showing up tomorrow.",
            next: 25
        )
    }

    // 233 (E1-d) — cycle awareness. Trust signal for women 22-35.
    // Doesn't collect data; just acknowledges. Placed after case 140
    // (identity feeling). Routes → N1 (case 235) which asks about
    // this month's signals, then continues to case 141 (reward).
    private var educationalCycleScreen: some View {
        educationalScreen(
            heroImage: "edu-cycle",
            eyebrow: "one more thing",
            headline: "you're not the same person on day 7 as day 21.",
            italicWords: ["day 7", "day 21"],
            body: "hormones shift across your cycle. some weeks you'll feel unstoppable. some you'll need a softer day. jeni adjusts. you don't have to push through.",
            next: 235
        )
    }

    // 234 (E1-e) — plateau pre-framing. Reduces week-3 churn. Placed
    // between case 181 (final prediction) and case 21 (plan reveal).
    private var educationalPlateauScreen: some View {
        educationalScreen(
            heroImage: "edu-plateau",
            eyebrow: "before you start",
            headline: "the scale will stall around week 3. that's good.",
            italicWords: ["good"],
            body: "plateaus mean your body is adapting — it's a physiological win, not a fail. jeni tells you what to change when it happens. no panic. no quitting.",
            next: 21
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
    private var consentRitualScreen: some View {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let nameForSignature = trimmedName.isEmpty ? "me" : trimmedName.lowercased()
        let signatureLetterCount = max(0, min(nameForSignature.count,
            Int(round(CGFloat(nameForSignature.count) * consentHoldProgress))))
        let signaturePrefix = String(nameForSignature.prefix(signatureLetterCount))

        return ZStack {
            StickerScatter(placements: Self.consentPlacements)

            VStack(spacing: 0) {
                Spacer()

                // Eyebrow
                Text("one more thing.")
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Palette.accent)

                Spacer().frame(height: Space.md)

                // Pledge — playful gen-Z casual, italic accent on
                // "pinky promise" punch phrase.
                ItalicAccentText(
                    "pinky promise i'll show up. even on the bad days.",
                    italic: ["pinky", "promise"],
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                    alignment: .center
                )
                .padding(.horizontal, Space.screenPadding)
                .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: Space.sm)

                Text("five minutes. that's it. ♥")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: Space.xl)

                // Signature card — receives the press-and-hold.
                // Border stroke fills clockwise as progress advances.
                consentSignatureCard(prefix: signaturePrefix,
                                     fullName: nameForSignature)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.md)

                Text("press & hold to sign")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)

                Spacer()

                // Skip — neutral copy, never punitive. Matches the
                // research note that 22–35 women penalize commitment-
                // shame frames (Drake & Salinas 2024).
                Button {
                    Haptics.light()
                    cancelConsentHold()
                    Analytics.track(.consentRitualSkipped)
                    go(215)
                } label: {
                    Text("maybe later")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 12)
                }
                .buttonStyle(PressFeedbackStyle())
                .padding(.bottom, Space.lg)
            }
        }
        .background(Palette.bgPrimary)
        .onAppear {
            Analytics.track(.consentRitualViewed)
        }
        .onDisappear {
            // Defensive cleanup — if the user nav'd away mid-hold,
            // kill the timer so it doesn't fire after the screen.
            consentHoldTimer?.invalidate()
            consentHoldTimer = nil
        }
    }

    /// The press-and-hold signature card. Animated border-stroke
    /// progresses 0→1 over 2.8s; name letters fill in italic Fraunces
    /// as the hold deepens. Released early: silent fade-out.
    private func consentSignatureCard(prefix: String, fullName: String) -> some View {
        // Disambiguate the displayed name: full ghost in textSecondary
        // at 30% opacity, filled prefix in textPrimary italic.
        let ghostSuffix = String(fullName.dropFirst(prefix.count))

        return VStack(spacing: 4) {
            // Signature line — visible name fills letter-by-letter
            HStack(spacing: 0) {
                Text(prefix)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                Text(ghostSuffix)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                    .foregroundStyle(Palette.textSecondary.opacity(0.25))
            }

            // Hairline under the signature — adds polaroid-signature feel
            Rectangle()
                .fill(Palette.textSecondary.opacity(0.3))
                .frame(height: 1)
                .padding(.horizontal, Space.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.lg)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Palette.bgElevated)
                .overlay(
                    // Progress border — trims clockwise as the user holds
                    RoundedRectangle(cornerRadius: 24)
                        .trim(from: 0, to: consentHoldProgress)
                        .stroke(Palette.accent, lineWidth: 2)
                )
                .overlay(
                    // Idle border — sits under the trimmed accent so
                    // the card has a visible edge even before hold.
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !consentHoldActive && !consentHoldCompleted {
                        startConsentHold()
                    }
                }
                .onEnded { _ in
                    if !consentHoldCompleted {
                        cancelConsentHold()
                    }
                }
        )
    }

    private func startConsentHold() {
        guard !consentHoldCompleted else { return }
        consentHoldActive = true
        consentHapticHalfwayFired = false
        Haptics.light()
        let durationSec: CGFloat = 2.8
        let tickSec: TimeInterval = 0.05
        consentHoldTimer?.invalidate()
        consentHoldTimer = Timer.scheduledTimer(withTimeInterval: tickSec, repeats: true) { timer in
            DispatchQueue.main.async {
                let increment = CGFloat(tickSec) / durationSec
                withAnimation(.linear(duration: tickSec)) {
                    consentHoldProgress = min(consentHoldProgress + increment, 1.0)
                }
                // Halfway haptic tick — fires once.
                if !consentHapticHalfwayFired && consentHoldProgress >= 0.5 {
                    consentHapticHalfwayFired = true
                    Haptics.light()
                }
                if consentHoldProgress >= 1.0 {
                    timer.invalidate()
                    completeConsentHold()
                }
            }
        }
    }

    private func cancelConsentHold() {
        consentHoldTimer?.invalidate()
        consentHoldTimer = nil
        consentHoldActive = false
        if !consentHoldCompleted {
            // Track abandon only when there was meaningful progress —
            // otherwise it's just a stray tap, not an abandonment.
            if consentHoldProgress > 0.15 {
                Analytics.track(.consentRitualAbandoned,
                                properties: ["progress_at_abandon": consentHoldProgress])
            }
            // Silent fade-out, no error haptic. Per audience research:
            // no shame frames.
            withAnimation(.easeOut(duration: 0.45)) {
                consentHoldProgress = 0
            }
        }
    }

    private func completeConsentHold() {
        consentHoldCompleted = true
        consentHoldActive = false
        Haptics.success()
        showConfetti = true
        Analytics.track(.consentRitualSigned)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            showConfetti = false
            go(215)
        }
    }

    /// 4-sticker LIGHT scatter for the consent screen. Edge-only.
    private static let consentPlacements: [StickerPlacement] = [
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
        let coachAsset = coachPortraitAssetForVoicePref()

        // Compact pass (2026-05-26): the continue CTA was below the
        // fold on iPhone 17 Pro — user feedback after launch. Shrunk
        // hero card 280→180pt, headline 28→24pt, day-row vertical
        // padding 6→2, replaced all Space.lg between sections with
        // Space.sm. Net cut ~180pt → CTA visible in first viewport.
        return ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            StickerScatter(placements: Self.methodPreviewPlacements)

            VStack(spacing: 0) {
                Spacer().frame(height: Space.md)

                Text("WHAT YOU GET WITH ME")
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Palette.accent)

                Spacer().frame(height: Space.sm)

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

                Spacer().frame(height: Space.sm)

                methodPreviewHeroCard(coachAsset: coachAsset, coachName: coachName)
                    .padding(.horizontal, Space.screenPadding)

                Spacer().frame(height: Space.sm)

                // 5 day teasers — pulled from canonical Day 1-5
                // ritual hero arcs so the preview matches what
                // ships post-purchase.
                VStack(spacing: 4) {
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
                .padding(.horizontal, Space.screenPadding)

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
                    go(240)
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
    private func methodPreviewHeroCard(coachAsset: String, coachName: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.accentSubtle)
                .frame(height: 180)

            Image(coachAsset)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("DAY 1: READY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Palette.bgPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Palette.textPrimary.opacity(0.88), in: Capsule())
                    Spacer()
                }

                Button {
                    togglePreviewSample()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: methodPreviewIsPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(audioButtonLabel(coachName: coachName))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Palette.bgPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.textPrimary))
                }
                .buttonStyle(PressFeedbackStyle())
                .opacity(methodPreviewAudioMissing ? 0.45 : 1.0)
                .disabled(methodPreviewAudioMissing)
                .accessibilityLabel(methodPreviewIsPlaying
                    ? "Stop \(coachName) sample"
                    : "Play \(coachName) sample")
            }
            .padding(12)
        }
        .frame(height: 180)
    }

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

    private func coachPortraitAssetForVoicePref() -> String {
        switch voicePreference {
        case "encouraging": return "coach-jeni"
        case "balanced":    return "coach-matson"
        case "keepItReal":  return "coach-kira"
        default:            return "coach-jeni"
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
            StickerScatter(placements: Self.tierLadderPlacements)

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
            StickerScatter(placements: Self.habitQuizPlacements)

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
                                "habits stabilize around 66 days — give or take.",
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
                Image("bodytype-goal")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 380)

                // Positive callouts — what the plan builds toward.
                // Stacked top-right to leave the body image clear and
                // avoid covering the face/silhouette outline.
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
            StickerScatter(placements: Self.firstPredictionPlacements)
            predictionScreen(
                eyebrow: "we got the numbers",
                headlinePrefix: "you could be at ",
                headlineSuffix: ".",
                subhead: "early estimate from what you've told me so far. it'll get sharper as we go.",
                badge: nil,
                target: predictionDate(),
                next: 203
            )
        }
        .onAppear {
            Analytics.track(.projectionChartViewed,
                            properties: ["placement": "first_prediction"])
        }
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
        predictionScreen(
            eyebrow: "we got more honest",
            headlinePrefix: "updated. you could be at ",
            headlineSuffix: ".",
            subhead: "your barriers + your baseline pulled this in. every answer sharpens it.",
            badge: nil,
            target: rePredictionDate(),
            next: 260
        )
        .onAppear {
            Analytics.track(.projectionChartViewed,
                            properties: ["placement": "re_prediction"])
        }
    }

    // Final prediction (181) — runs after the loading carousel, hands off
    // to the redesigned plan reveal. 2026 voice refresh: lowercase + italic
    // accent on "ready" instead of the older capitalized "Based on your
    // answers, your plan is ready."
    private var finalPredictionScreen: some View {
        ZStack {
            StickerScatter(placements: Self.finalPredictionPlacements)

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
    private func predictionScreen(
        eyebrow: String? = nil,
        headlinePrefix: String, headlineSuffix: String,
        subhead: String, badge: String?,
        target: Date, next: Int
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

            predictionHeadline(prefix: headlinePrefix, suffix: headlineSuffix, target: target)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.sm)

            Text(subhead)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            weightCurve(targetDate: target)
                .frame(height: 200)
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
        target: Date? = nil
    ) -> some View {
        let date = target ?? predictionDate()
        let weightFragment = weightLabel(kg: goalWeightKg)
        let dateFragment = formatGoalDate(date)
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
    private func weightCurve(targetDate: Date? = nil) -> some View {
        let date = targetDate ?? predictionDate()
        return WeightCurveView(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            targetDate: date,
            currentLabel: weightLabel(kg: currentWeightKg),
            goalLabel: weightLabel(kg: goalWeightKg),
            dateLabel: formatGoalDate(date)
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
            return "your body focus"
        }()

        // Stage 3 — frequency. Pulls Q11 days/week + Q25 session length.
        let cadenceFragment: String = {
            let days = commitmentDaysCount(commitmentDays)
            let mins = sessionLength.isEmpty ? 0 : (Int(sessionLength) ?? 0)
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
            StickerScatter(placements: Self.carouselPlacements)

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
                        go(181)
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

    /// First-prediction date. Default: today + 12 weeks. Adjusted ±2 weeks
    /// by activity level (athlete sooner, sedentary later).
    private func predictionDate() -> Date {
        let cal = Calendar.current
        var days = 84  // 12 weeks
        switch activityLevel {
        case "athlete":  days -= 14
        case "sedentary": days += 14
        default: break
        }
        return cal.date(byAdding: .day, value: days, to: Date()) ?? Date()
    }

    /// Re-prediction is 2 weeks earlier than the first — represents the
    /// "answers improved the projection" feedback. Compresses with more
    /// commitment days too, capped so it doesn't go absurd.
    private func rePredictionDate() -> Date {
        let cal = Calendar.current
        var days = 84 - 14  // 10 weeks baseline
        switch activityLevel {
        case "athlete":  days -= 14
        case "sedentary": days += 7
        default: break
        }
        if commitmentDays == "seven" { days -= 7 }
        return cal.date(byAdding: .day, value: max(28, days), to: Date()) ?? Date()
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
    private func planRevealAnchors() -> [String] {
        var lines: [String] = []

        // 1. Plank capability ladder. baseline → next-tier target.
        let plankTarget: String = {
            switch baseline {
            case "under15":   return "a 30-second plank"
            case "fifteen30": return "a 60-second plank"
            case "thirty60":  return "a 90-second plank"
            case "sixtyPlus": return "a 2-minute plank"
            default:          return "a stronger core"
            }
        }()
        lines.append(plankTarget)

        // 2. Weight outcome — only if the user set a real loss goal.
        // currentWeightKg > goalWeightKg means they're aiming to lose.
        // Maintenance / muscle-gain skips this line so the framing
        // doesn't promise weight loss to someone who didn't ask for it.
        if currentWeightKg > goalWeightKg + 0.5 {
            let lbsDelta = Int(((currentWeightKg - goalWeightKg) * Self.lbPerKg).rounded())
            if lbsDelta >= 1 {
                lines.append("~\(lbsDelta) lbs lighter")
            }
        }

        // 3. Habit identity anchor. Pulls session length when set.
        let mins = sessionLength.isEmpty ? 5 : (Int(sessionLength) ?? 5)
        lines.append("\(mins)-minute habit, locked in")

        return lines
    }

    /// JeniFit goal phrasing derived from bodyFocus (Phase 4 multi-select).
    /// Body-part keys lead with "your" so "Built for [label]." reads
    /// natural and personal. Compound-noun keys (fullBody) skip "your".
    /// Falls back to identityFeeling, then a generic "your goals."
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
            StickerScatter(placements: Self.comparisonPlacements)

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
                    go(170)
                }
                    .padding(.bottom, Space.lg)
            }
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
    // burst plays once when planSparkleBurstActive flips to true.
    private static let planSparkleBurst: [(CGSize, CGFloat, StickerName, Double)] = [
        (CGSize(width: -64, height: -28),  20, .sparkleGlossy, 0.00),
        (CGSize(width:  62, height: -34),  22, .starLineart,   0.06),
        (CGSize(width: -76, height:  18),  18, .heartsLineart, 0.12),
        (CGSize(width:  72, height:  22),  22, .sparkleGlossy, 0.18),
        (CGSize(width:   0, height: -56),  18, .starLineart,   0.24),
    ]

    private var planRevealScreen: some View {
        let coachName = voicePreference == "encouraging" ? "Jeni" : voicePreference == "balanced" ? "Sam" : "Kira"
        let coachPhoto = voicePreference == "encouraging" ? "coach-jeni" : voicePreference == "balanced" ? "coach-matson" : "coach-kira"

        return ZStack {
            StickerScatter(placements: Self.planRevealPlacements)

            VStack(spacing: 0) {
            Spacer()

            // Coach photo + sparkle burst halo. The burst plays once,
            // synced to the coach photo entrance. Sparkles scale + fade
            // in, then fade out as the headline takes focus.
            ZStack {
                ForEach(Self.planSparkleBurst.indices, id: \.self) { i in
                    let entry = Self.planSparkleBurst[i]
                    Image(entry.2.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: entry.1, height: entry.1)
                        .opacity(planSparkleBurstVisible ? 0.85 : 0)
                        .scaleEffect(planSparkleBurstActive ? 1 : 0.4)
                        .offset(planSparkleBurstActive ? entry.0 : .zero)
                }
                // Soft accent halo behind the photo for depth.
                // Sizes shrunk (110→88, 72→58) to reclaim vertical
                // space on the plan reveal — user feedback that the
                // progress bar was being pushed too high.
                Circle()
                    .fill(Palette.accent.opacity(0.08))
                    .frame(width: 88, height: 88)
                    .scaleEffect(planCoachVisible ? 1 : 0.5)
                    .opacity(planCoachVisible ? 1 : 0)

                Image(coachPhoto)
                    .resizable().scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Palette.accent, lineWidth: 2.5))
                    .opacity(planCoachVisible ? 1 : 0)
                    .scaleEffect(planCoachVisible ? 1 : 0.8)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: planCoachVisible)

            Spacer().frame(height: Space.md)

            // Italic accent on "set" — Fraunces voice for the headline
            // moment. Personalized with the user's name when available.
            Group {
                if name.isEmpty {
                    (Text("You're all ").font(Typo.title)
                     + Text("set").font(Typo.titleItalic)
                     + Text(".").font(Typo.title))
                } else {
                    (Text("You're all ").font(Typo.title)
                     + Text("set").font(Typo.titleItalic)
                     + Text(", \(name).").font(Typo.title))
                }
            }
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(planHeadlineVisible ? 1 : 0)
                .offset(y: planHeadlineVisible ? 0 : 12)

            Spacer().frame(height: Space.sm)

            // Capability ladder — dual-anchor (capability + outcome)
            // using already-collected fields. Replaces single-body-part
            // "Built for X" headline with a 3-month frame that matches
            // the TikTok creator window + Lally/Kaushal habit research.
            // Three anchors:
            //   1. Plank time goal — concrete capability, JeniFit's
            //      signature metric, no other app can copy this.
            //   2. Weight outcome — only shown if the user set a goal
            //      delta (currentWeight > goalWeight).
            //   3. Habit identity — five-minute frame + "locked in"
            //      identity verb (Clear / Atomic Habits framing).
            VStack(alignment: .leading, spacing: 6) {
                Text("in 3 months ♥")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    .foregroundStyle(Palette.accent)
                    .padding(.bottom, 2)

                ForEach(planRevealAnchors(), id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Text("✦")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.accent)
                        Text(line)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.screenPadding)
            .opacity(planSubheadVisible ? 1 : 0)

            Spacer().frame(height: Space.sm)

            // "[coachName] has your first session ready." line removed —
            // redundant after the 3 capability anchors above which
            // already say "plan is ready." Reclaims ~24pt of vertical
            // space; combined with the smaller coach halo + dropped
            // plan card below, restores the progress bar to its
            // normal top position.

            Spacer().frame(height: Space.md)

            // Plan summary cards — dropped from 4 to 3. "Live form
            // check / We watch your form weekly" was the most
            // forward-looking / abstract benefit (user hasn't tried
            // it yet, harder to picture); the other three are
            // immediately concrete. JeniFit copy — no AI language.
            VStack(spacing: 10) {
                planCard(icon: "calendar", title: "Daily routines", detail: "5–10 min sessions designed for you", color: Palette.accent, index: 0)
                planCard(icon: "waveform", title: "Voice coaching", detail: "\(coachName) guides every move", color: Palette.stateGood, index: 1)
                planCard(icon: "sparkles", title: "Adaptive plan", detail: "Gets smarter as you go", color: Palette.stateWarn, index: 2)
            }
            .padding(.horizontal, Space.screenPadding)
            .opacity(planCardsVisible ? 1 : 0)

            Spacer()

            // CTA — "let's go ♥" replaces "Almost done". Lowercase
            // momentum-coded, heart as terminal voice signature.
            ctaBtn("let's go ♥") {
                Haptics.medium()
                Analytics.track(.planRevealContinueTapped)
                // Routes to method preview (case 250) — pre-paywall
                // ritual tease — then on to consent ritual (240), rating
                // prefilter (215), sign-in, personalStat, finish. The
                // direct go(240) here previously skipped case 250
                // entirely (PostHog 2026-05-26: zero step_id=250 events
                // for 30d post-launch). Fix.
                go(250)
            }
                .opacity(planCtaVisible ? 1 : 0)
            }
            .onAppear { runPlanReveal() }
        }
    }

    private func runPlanReveal() {
        // Reset for re-mount (back nav into the screen replays the
        // moment instead of leaving stale state behind).
        planRevealed = false
        planCoachVisible = false
        planHeadlineVisible = false
        planSubheadVisible = false
        planPresetVisible = false
        planSparkleBurstActive = false
        planSparkleBurstVisible = false
        planCardsVisible = false
        planCtaVisible = false

        // High-trust moment immediately preceding the paywall. Tracked
        // on every mount; AnalyticsManager coalesces back-nav re-fires.
        Analytics.track(.planRevealViewed, properties: [
            "coach": voicePreference,
            "body_focus_count": bodyFocus.count
        ])

        Haptics.success()

        // t=0.10 coach photo + halo spring in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)
            .delay(0.10)) {
            planCoachVisible = true
        }
        // t=0.15 sparkle burst — fade in + fan out, hold ~1.4s, then
        // fade out so the sparkles cede focus to the headline.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                planSparkleBurstActive = true
            }
            withAnimation(.easeOut(duration: 0.35)) {
                planSparkleBurstVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.6)) {
                planSparkleBurstVisible = false
            }
        }
        // t=0.55 headline italic accent slides up + fades in
        withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
            planHeadlineVisible = true
        }
        // t=0.85 subhead fades in
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
            planSubheadVisible = true
        }
        // t=1.10 first-preset preview fades in
        withAnimation(.easeOut(duration: 0.4).delay(1.10)) {
            planPresetVisible = true
        }
        // t=1.30 plan cards fade in (planCard's own staggered
        // entrance kicks off from index 0..3 inside planCard).
        withAnimation(.easeOut(duration: 0.5).delay(1.30)) {
            planCardsVisible = true
        }
        // t=1.65 CTA fades in last
        withAnimation(.easeOut(duration: 0.4).delay(1.65)) {
            planCtaVisible = true
        }
        // t=2.0 mark planRevealed for any other code paths that
        // still observe the legacy flag.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            planRevealed = true
        }
    }

    /// Pick the most-relevant barrier the user named and return a card payload.
    /// Order matters: the first matching barrier wins (in priority order).
    private func barrierPlanCard() -> (icon: String, title: String, detail: String)? {
        let priority: [(String, String, String, String)] = [
            ("dontKnow",   "viewfinder",          "Form, locked in",       "Coach corrects you in real time"),
            ("injury",     "shield.lefthalf.filled", "Safe progressions",  "Every move matched to your level"),
            ("boring",     "shuffle",             "Never the same workout", "Variety baked in, every session"),
            ("motivation", "calendar",            "Shows up every day",    "Streak + coach keep you accountable"),
            ("time",       "bolt.fill",           "Fits the busy days",    "5-minute sessions are real workouts"),
        ]
        for (key, icon, title, detail) in priority where barriers.contains(key) {
            return (icon, title, detail)
        }
        return nil
    }

    private func planCard(icon: String, title: String, detail: String, color: Color, index: Int) -> some View {
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
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .plankShadow()
        .opacity(planRevealed ? 1 : 0)
        .offset(y: planRevealed ? 0 : CGFloat(8 + index * 4))
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.1), value: planRevealed)
    }

    /// Notification permission ask. Replaces the legacy camera setup
    /// screen as the final onboarding moment. The system prompt fires
    /// when the user taps "Allow notifications" — iOS only ever shows
    /// it once per install, so we frame the in-app screen as the soft
    /// pitch and let the OS dialog do the granting. On grant: schedule
    /// a daily reminder at the plankTime they picked in Q11. Either
    /// way (allow or skip), finish() ends onboarding.
    ///
    /// Onboarding ends here — the post-onboarding paywall is handled
    /// outside the flow by RootView's fullScreenCover gating on
    /// PaymentService.hasProAccess.
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

            (Text("turn on ").font(Typo.title)
             + Text("reminders").font(Typo.titleItalic)
             + Text("?").font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            Text("one notification \(plankTimeLabel). that's it. change the time or turn it off in settings whenever.")
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
                // Notification preview — must match what
                // NotificationPermission.scheduleDailyReminder actually
                // sets as content.title ("today's short session."). The
                // old preview said "Time to work" which mismatched the
                // shipped notification title since the lowercase voice
                // refresh in NotificationPermission.swift.
                Text("today's short session.")
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
                        let granted = await NotificationPermission.request()
                        notificationsEnabled = granted
                        if granted {
                            // Map the Q11 plankTime bucket to a real
                            // Date so the daily reminder fires at the
                            // hour the user picked.
                            let scheduledTime = reminderTimeFromBucket(plankTime)
                            notificationTime = scheduledTime
                            NotificationPermission.scheduleDailyReminder(at: scheduledTime)
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

    /// Soft review prefilter, fires right after plan reveal. "Loving it" routes
    /// through SKStoreReviewController so only positive-sentiment users see
    /// the App Store rating sheet — protects the rating from users who tap
    /// 1-star out of pre-paywall friction. iOS gates requestReview() to 3
    /// per 365 days; the AppStorage flag adds an install-level guard so
    /// re-entry into onboarding (rare but possible via sign-out) doesn't
    /// re-fire and burn a slot.
    private var reviewPromptScreen: some View {
        VStack(spacing: 0) {
            Spacer()

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

            (Text("loving ").font(Typo.title)
             + Text("jenifit").font(Typo.titleItalic)
             + Text(" so far?").font(Typo.title))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.sm)

            Text("a quick rating helps other women find us, and keeps the app independent.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                ctaBtn("loving it") {
                    Haptics.success()
                    requestAppStoreReview()
                    // Brief delay so the system sheet has a beat to appear
                    // before we slide forward; if iOS suppresses it (quota,
                    // throttle), the user just lands on the next screen.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        go(26)
                    }
                }

                Button {
                    Haptics.light()
                    onboardingReviewPromptShown = true
                    go(26)
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

    /// Trigger the App Store rating sheet via SKStoreReviewController.
    /// Walks UIScene to find an active foreground windowScene — required
    /// since iOS 14. No-ops if the install-level flag is already set; iOS
    /// itself enforces the 3-per-365-days quota and can silently suppress.
    private func requestAppStoreReview() {
        guard !onboardingReviewPromptShown else { return }
        onboardingReviewPromptShown = true
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
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

            // Data-driven plan details
            VStack(spacing: 10) {
                planDetail(icon: "target", label: "Focus", value: focusLabel, index: 0)
                planDetail(icon: "chart.bar", label: "Level", value: difficultyLabel, index: 1)
                planDetail(icon: "clock", label: "Sessions", value: "\(sessionMin) min", index: 2)
                planDetail(icon: "calendar", label: "Frequency", value: "\(daysPerWeek) days/week", index: 3)
                planDetail(icon: "flame", label: "Weekly total", value: "\(weeklyMinutes) min", index: 4)
                planDetail(icon: "waveform", label: "Coach", value: selectedCoachName, index: 5)
            }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func ctaBtn(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Palette.textInverse)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(
                    LinearGradient(
                        colors: [Palette.bgInverse, Palette.bgInverse.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(PressFeedbackStyle())
        .padding(.horizontal, Space.screenPadding).padding(.bottom, Space.lg)
    }

    private func go(_ to: Int) {
        // Direction comes from position in flowOrder, not raw screen number.
        // Raw screen numbers are non-monotonic (25 sits between 17 and 18, 26
        // between 21 and 22), so a "forward" advance can have a smaller raw
        // number than the screen it came from. The slide transition keys off
        // `dir`, and we want it to slide forward whenever the user is moving
        // forward in the flow.
        let fromIdx = Self.flowOrder.firstIndex(of: screen) ?? 0
        let toIdx = Self.flowOrder.firstIndex(of: to) ?? 0
        dir = toIdx >= fromIdx ? 1 : -1
        // Funnel events. `step_completed` fires for the step the user
        // is leaving (so we know what they finished); `step_viewed`
        // fires for the step they're arriving at. AnalyticsManager
        // coalesces dupes within its short window, so SwiftUI remounts
        // don't double-count.
        Analytics.track(.onboardingStepCompleted, properties: stepProperties(stepId: screen))
        Analytics.track(.onboardingStepViewed,    properties: stepProperties(stepId: to))
        // Phase 20b: was 0.3s easeOut — read as rushed on a 26-screen
        // flow where every transition is the user's full attention.
        // Motion.crossFade (0.45s easeInOut) gives the slide more swell
        // without dragging.
        withAnimation(Motion.crossFade) { screen = to }
    }

    /// Standard property bag for onboarding step events. Includes
    /// position in flowOrder so funnel queries can sort by progression
    /// without needing the raw step → flow position map. user_goal +
    /// body_focus are included when set so PostHog can filter the
    /// funnel by audience segment.
    private func stepProperties(stepId: Int) -> [String: Any] {
        var props: [String: Any] = [
            "step_id": stepId,
            "step_position": Self.flowOrder.firstIndex(of: stepId) ?? -1,
            "step_total": Self.flowOrder.count
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
        if let pos = Self.flowOrder.firstIndex(of: screen), pos > 0 {
            go(Self.flowOrder[pos - 1])
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
        data.relatability1 = relatability1 ?? false
        data.relatability2 = relatability2 ?? false
        data.relatability3 = relatability3 ?? false

        onComplete(data)
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

private struct WeightCurveView: View {
    let currentWeightKg: Double
    let goalWeightKg: Double
    let targetDate: Date
    let currentLabel: String
    let goalLabel: String
    let dateLabel: String

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
                // Gradient fill underneath the curve.
                fill
                    .fill(LinearGradient(
                        colors: [Palette.accent.opacity(0.30),
                                 Palette.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .opacity(fillOpacity)

                // Soft glow layer — same trimmed path, wider stroke,
                // blurred. Sits behind the main stroke for depth.
                curve
                    .trim(from: 0, to: curveProgress)
                    .stroke(strokeGradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .blur(radius: 6)
                    .opacity(0.55)

                // Main stroke — multi-stop gradient.
                curve
                    .trim(from: 0, to: curveProgress)
                    .stroke(strokeGradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Mid-curve guide — dotted vertical from the bezier
                // point down to the baseline. Renders below the dot
                // and the callout so they sit cleanly on top.
                if weekCalloutVisible {
                    Path { p in
                        p.move(to: CGPoint(x: midX, y: midY + 4))
                        p.addLine(to: CGPoint(x: midX, y: h))
                    }
                    .stroke(Palette.textSecondary.opacity(0.45),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .transition(.opacity)
                }

                // Mid-curve dot.
                if weekCalloutVisible {
                    Circle()
                        .fill(Palette.accent)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Palette.bgPrimary, lineWidth: 2))
                        .position(x: midX, y: midY)
                        .transition(.scale.combined(with: .opacity))
                }

                // Mid-curve callout pill — cocoa background, white
                // weight text, "Week 1" eyebrow underneath.
                if weekCalloutVisible {
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
                // at landing time. JeniFit brand moment.
                Image(StickerName.sparkleGlossy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .opacity(sparkleVisible ? 0.85 : 0)
                    .scaleEffect(sparkleVisible ? 1 : 0.6)
                    .offset(x: w - 38, y: h - 36)

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
                // axis date label below.
                Text(dateLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Palette.accent, in: Capsule())
                    .offset(x: w - 64, y: h - 50)
                    .scaleEffect(datePillVisible ? 1 : 0.6)
                    .opacity(datePillVisible ? 1 : 0)

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

// MARK: - ActivityLevelSliderTrack
//
// 17b-2: 5-position discrete slider for the activity-level question.
// Track + dots styling mirrors BodyTypeSlider (so both biometric
// sliders read as the same primitive) but the dot count and gestures
// are scoped to this question — no labels-above row, no marker, no
// effective-max cap.

private struct ActivityLevelSliderTrack: View {
    @Binding var index: Int
    let count: Int

    private let dotSize: CGFloat = 14
    private let selectedDotSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let denom = max(1, count - 1)
            let dotX: (Int) -> CGFloat = { i in
                geo.size.width * CGFloat(i) / CGFloat(denom)
            }
            let mid = geo.size.height / 2

            ZStack {
                Rectangle()
                    .fill(Palette.divider)
                    .frame(height: 2)
                    .position(x: geo.size.width / 2, y: mid)

                Rectangle()
                    .fill(Palette.accent.opacity(0.45))
                    .frame(width: dotX(max(0, min(count - 1, index))),
                           height: 2)
                    .position(x: dotX(max(0, min(count - 1, index))) / 2,
                              y: mid)

                ForEach(0..<count, id: \.self) { i in
                    let selected = i == index
                    ZStack {
                        if selected {
                            Circle()
                                .fill(Palette.bgInverse)
                                .frame(width: selectedDotSize,
                                       height: selectedDotSize)
                            Circle()
                                .stroke(Palette.accent, lineWidth: 2)
                                .frame(width: selectedDotSize,
                                       height: selectedDotSize)
                        } else {
                            Circle()
                                .fill(Palette.accent)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                    .position(x: dotX(i), y: mid)
                    .onTapGesture {
                        Haptics.light()
                        index = i
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let x = max(0, min(geo.size.width, gesture.location.x))
                        let raw = (x / geo.size.width) * CGFloat(denom)
                        let nearest = max(0, min(count - 1, Int(raw.rounded())))
                        if nearest != index {
                            Haptics.soft()
                            index = nearest
                        }
                    }
            )
        }
    }
}

struct OnboardingData {
    // Existing fields — downstream consumers (PlankAIApp.handleOnboardingComplete,
    // UserRecord schema, WorkoutGenerator) read these by name. Don't rename.
    let goal, experience: String; let baselineHoldSeconds: Int; let barriers: [String]
    let ageRange, activityLevel, focusArea, plankTime: String; let commitmentDaysPerWeek: Int
    let sessionLengthMinutes: Int
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

