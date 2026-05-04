import SwiftUI
import AVFoundation

// MARK: - Onboarding Flow
// Interleaved: 2-3 questions → education/celebration → repeat
// Every question requires Continue. Instant feedback on answers.
// Gradient blobs + animated SF Symbols + photo slots for stock images.

struct OnboardingView: View {
    @State private var screen: Int
    @State private var dir = 1
    @State private var visible = false

    init(onComplete: @escaping (OnboardingData) -> Void) {
        self.onComplete = onComplete
        self._screen = State(wrappedValue: -1)
    }
    @State private var feedback = ""
    @State private var showFeedback = false
    @State private var showConfetti = false
    @State private var showWelcomeSignInSheet = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Data — legacy
    @State private var goal = ""
    @State private var experience = ""
    @State private var baseline = ""
    @State private var barriers: Set<String> = []
    @State private var ageRange = ""
    @State private var activityLevel = ""
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
    @State private var workoutStyle: Set<String> = ["hiit"]
    @State private var gender = ""
    @State private var heightCm: Double = 170
    @State private var currentWeightKg: Double = 65
    @State private var goalWeightKg: Double = 60
    @State private var bodyTypeCurrent: Int = 2
    @State private var bodyTypeDesired: Int = 1
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
    @State private var chartAnimated = false
    @State private var proofCount = 0
    @State private var celebVisible = false

    // Education screen animations
    @State private var factVisible = false
    @State private var featureVisible = false
    @State private var beforeAfterVisible = false
    @State private var personalStatVisible = false

    // Phase 5 — prediction / loading / plan reveal animations
    @State private var predictionVisible = false
    @State private var carouselProgress: CGFloat = 0
    @State private var carouselFrame: Int = 0
    @State private var carouselDone = false

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
                    .transition(.asymmetric(
                        insertion: .move(edge: dir > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: dir > 0 ? .leading : .trailing).combined(with: .opacity)
                    ))
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
                    ConfirmationBadge(message: msg)
                        .padding(.bottom, Space.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(18)
            }

        }
        .sheet(isPresented: $showWelcomeSignInSheet) {
            NavigationStack {
                SignInPromptView(mode: .signIn) {
                    // After Apple/email/cancel closes the prompt: if the user
                    // is now signed in (non-anonymous), they're recovering an
                    // existing account — skip the rest of onboarding and
                    // hand off to MainTabView. AppSync.onAuthChanged will
                    // hydrate UserRecord/SessionLog/DayProgress from the cloud.
                    showWelcomeSignInSheet = false
                    if !AuthService.shared.isAnonymous {
                        hasCompletedOnboarding = true
                    }
                }
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
                    }
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        feedback = msg
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showFeedback = true }
        Haptics.soft()
    }

    private func hideToast() {
        withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
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
        case -1: splashScreen
        case 0: welcome

        // ─── Section dividers ───────────────────────────────────
        case 200: SectionDividerScreen(
            partNumber: 1, title: "Your story",
            supporting: "Three quick reads on what brought you here.",
            dwellSeconds: 1.6,
            onAdvance: { go(1) }
        )
        case 201: SectionDividerScreen(
            partNumber: 2, title: "How you move now",
            supporting: "We'll match your plan to where you are today.",
            dwellSeconds: 1.6,
            onAdvance: { go(2) }
        )
        case 202: SectionDividerScreen(
            partNumber: 3, title: "About you",
            supporting: "A few numbers so the math behind your plan is honest.",
            dwellSeconds: 1.6,
            onAdvance: { go(130) }
        )
        case 203: SectionDividerScreen(
            partNumber: 4, title: "How you want to feel",
            supporting: "The version of you that's waiting on the other side.",
            dwellSeconds: 1.6,
            onAdvance: { go(140) }
        )
        case 204: SectionDividerScreen(
            partNumber: 5, title: "What stops you",
            supporting: "Three honest questions. Tap whichever lands.",
            dwellSeconds: 1.6,
            onAdvance: { go(150) }
        )
        case 205: SectionDividerScreen(
            partNumber: 6, title: "Ready to start",
            supporting: "Last few. Then your plan goes live.",
            dwellSeconds: 1.6,
            onAdvance: { go(3) }
        )

        // ─── Part 1 — Your story ────────────────────────────────
        case 1: jfQuestion(
            "What's the goal?",
            sub: "We'll build the entire plan around this answer.",
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
            "Where should we focus?",
            sub: "Pick the zones you want to see change.",
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
            "Why now?",
            sub: "What's pushing you to start today?",
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
            "How much do you train right now?",
            sub: "Be honest. The plan calibrates from this.",
            opts: [
                ("never",     "I don't really train",               nil,                         "moon.zzz"),
                ("gaveUp",    "I've tried, couldn't stick with it", nil,                         "arrow.uturn.backward"),
                ("sometimes", "Here and there",                     nil,                         "calendar"),
                ("regular",   "Regularly",                          "Multiple times a week",     "checkmark.circle.fill"),
            ],
            sel: $experience, next: 8
        )

        case 8: jfQuestion(
            "How active are you day-to-day?",
            sub: "Outside of workouts. Walking, standing, errands.",
            opts: [
                ("sedentary", "Mostly sitting", nil,                                  "house"),
                ("light",     "Light",          "Short walks, occasional movement",   "figure.walk"),
                ("moderate",  "Moderate",       "On my feet most of the day",         "figure.run"),
                ("active",    "Very active",    "Physical job or daily walks",        "bolt.fill"),
                ("athlete",   "Athlete-level",  nil,                                  "trophy.fill"),
            ],
            sel: $activityLevel, next: 120
        )

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
            sel: $workoutStyle, next: 25
        )

        case 25: jfQuestion(
            "How long per session?",
            sub: "Pick the size you'll actually keep open.",
            opts: [
                ("five",    "5 minutes",  "Quick reset",           "5.circle"),
                ("ten",     "10 minutes", "Solid daily routine",   "10.circle"),
                ("fifteen", "15 minutes", "Full session",          "15.circle"),
                ("twenty",  "20 minutes", "Deep work",             "20.circle"),
            ],
            sel: $sessionLength, next: 17
        )

        case 17: jfQuestion(
            "How many days a week?",
            sub: "The five-day plan is what we'd pick for you.",
            opts: [
                ("three", "3 days", "Easing in",    "3.circle"),
                ("five",  "5 days", "Recommended",  "5.circle"),
                ("seven", "7 days", "All in",       "7.circle"),
            ],
            sel: $commitmentDays, next: 202,
            confirmation: "Got it. Your plan starts here."
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

        case 7: jfQuestion(
            "What's your age?",
            sub: "We adjust your plan based on this.",
            opts: [
                ("under18", "Under 18", "Just getting started",        "graduationcap"),
                ("18to24",  "18–24",    "Young adult",                 "sun.max"),
                ("25to34",  "25–34",    "Building habits",             "leaf"),
                ("35to44",  "35–44",    "Strong + steady",             "shield.fill"),
                ("45to54",  "45–54",    "Refined + experienced",       "sparkles"),
                ("55plus",  "55+",      "Forever fit",                 "flame"),
            ],
            sel: $ageRange, next: 131
        )

        case 131: jfSliderScreen(
            "How tall are you?",
            sub: "We use this to calibrate intensity.",
            value: $heightCm, range: 137...213, step: 1,
            format: { v in heightLabel(cm: v) }, next: 132
        )

        case 132: jfSliderScreen(
            "What's your current weight?",
            sub: "Helps us measure your progress accurately.",
            value: $currentWeightKg, range: 30...200, step: 0.5,
            format: { v in weightLabel(kg: v) }, next: 133,
            annotation: {
                bmiAnnotation(weightKg: currentWeightKg, heightCm: heightCm)
            }
        )

        case 133: jfSliderScreen(
            "And your goal weight?",
            sub: "Sets your target. You can change this later.",
            value: $goalWeightKg, range: 30...200, step: 0.5,
            format: { v in weightLabel(kg: v) }, next: 134,
            confirmation: "We'll calibrate progress to this.",
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
            "Where are you now?",
            sub: "Visual reference, not a number on a scale.",
            position: $bodyTypeCurrent,
            labels: ["Soft", "Curvy", "Average", "Athletic", "Lean", "Cut"],
            next: 135
        )

        case 135: jfBodyTypeScreen(
            "Where do you want to be?",
            sub: "What we're moving you toward.",
            position: $bodyTypeDesired,
            labels: ["Soft", "Curvy", "Average", "Athletic", "Lean", "Cut"],
            maxPosition: bodyTypeCurrent,
            markerPosition: bodyTypeCurrent,
            contextLine: "You said you're at: \(["Soft", "Curvy", "Average", "Athletic", "Lean", "Cut"][bodyTypeCurrent])",
            next: 203
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
        case 140: jfQuestion(
            "Which one feels most like the new you?",
            sub: "Pick the version that's pulling you forward.",
            opts: [
                ("powerful", "Powerful", "Confident, undeniable",   "bolt.fill"),
                ("calm",     "Calm",     "At home in my body",      "leaf.fill"),
                ("light",    "Light",    "Free, unburdened",        "wind"),
                ("strong",   "Strong",   "Capable, grounded",       "shield.fill"),
                ("radiant",  "Radiant",  "Glowing from inside out", "sparkles"),
            ],
            sel: $identityFeeling, next: 141,
            confirmation: "That's the goal. Your plan is built around getting you there."
        )

        case 141: jfQuestion(
            "What's the reward when you hit the goal?",
            sub: "The thing you'll do for yourself when this lands.",
            opts: [
                ("clothes",  "New clothes",        "Treat my new look",      "tshirt.fill"),
                ("trip",     "Take a trip",        "Celebrate somewhere",    "airplane"),
                ("photos",   "Photos of myself",   "Document the change",    "camera.fill"),
                ("personal", "Personal day",       "Just for me",            "sun.max.fill"),
                ("treat",    "Treat myself",       "Something I've wanted",  "gift.fill"),
            ],
            sel: $rewardChoice, next: 204,
            confirmation: "We see you. Your reasons are real."
        )

        // ─── Part 5 — What stops you ────────────────────────────
        case 150: jfYesNo(
            "Workout apps make me feel further from my body, not closer.",
            bind: $relatability1, next: 151
        )
        case 151: jfYesNo(
            "I have no idea which workouts are right for me.",
            bind: $relatability2, next: 152
        )
        case 152: jfYesNo(
            "I quit when something feels too hard or boring.",
            bind: $relatability3, next: 205,
            confirmation: "We've all been there. We'll make it easy."
        )

        // ─── Part 6 — Ready to start ────────────────────────────
        case 3: jfQuestion(
            "How long can you hold a plank?",
            sub: "Your starting benchmark. We move it up from here.",
            opts: [
                ("under15",   "Under 15s",  "Just starting",       "stopwatch"),
                ("fifteen30", "15-30s",     "Building a base",     "stopwatch.fill"),
                ("thirty60",  "30-60s",     "Solid foundation",    "timer"),
                ("sixtyPlus", "60+ seconds","Strong already",      "flame.fill"),
                ("notSure",   "Not sure",   "We'll figure it out", "questionmark.circle"),
            ],
            sel: $baseline, next: 11
        )

        case 11: jfQuestion(
            "When do you want your reminder?",
            sub: "We'll nudge you at the same time every day.",
            opts: [
                ("morning",   "Morning",   "Set the tone",          "sunrise.fill"),
                ("afternoon", "Afternoon", "Midday boost",          "sun.max.fill"),
                ("evening",   "Evening",   "Wind down with motion", "moon.stars.fill"),
                ("whenever",  "Whenever",  "Flexible by day",       "shuffle"),
            ],
            sel: $plankTime, next: 18
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
        // Part 1
        200, 1, 110, 111,
        // Part 2
        201, 2, 8, 120, 121, 25, 17,
        // Part 3
        202, 130, 7, 131, 132, 133, 134, 135,
        // Phase 5 — reshape transition + first prediction (commit-escalation)
        160, 161,
        // Part 4
        203, 140, 141,
        // Phase 5 — re-prediction recap
        170,
        // Part 5
        204, 150, 151, 152,
        // Part 6
        205, 3, 11, 18, 19,
        // Phase 5 — loading carousel + final prediction → plan reveal.
        // Onboarding ends at camera setup (23); the post-onboarding
        // paywall lives outside the flow as RootView's fullScreenCover.
        180, 181, 21, 26, 22, 23,
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
                        .animation(.easeOut(duration: 0.35), value: screen)
                }
            }.frame(height: 4)
            Color.clear.frame(width: 40, height: 40)
        }.padding(.horizontal, Space.screenPadding)
    }

    // ═══════════════════════════════════════
    // MARK: - SPLASH (screen -1)
    // ═══════════════════════════════════════

    @State private var splashLogoVisible = false
    @State private var splashLineVisible = false
    @State private var splashPulse = false

    private var splashScreen: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / brand mark
                JeniFitWordmark()
                    .opacity(splashLogoVisible ? 1 : 0)
                    .scaleEffect(splashLogoVisible ? 1 : 0.8)

                Spacer().frame(height: 12)

                // Animated underline
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.accent)
                    .frame(width: splashLineVisible ? 120 : 0, height: 4)
                    .animation(.easeOut(duration: 0.6).delay(0.4), value: splashLineVisible)

                Spacer().frame(height: Space.lg)

                // Subtle loading dots
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Palette.accent.opacity(splashPulse ? 0.8 : 0.2))
                            .frame(width: 6, height: 6)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                                value: splashPulse
                            )
                    }
                }
                .opacity(splashLineVisible ? 1 : 0)

                Spacer()
            }
        }
        .onAppear {
            // Stage 1: logo scales in + vibration
            Haptics.medium()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                splashLogoVisible = true
            }

            // Stage 2: underline draws + dots pulse
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                splashLineVisible = true
                splashPulse = true
            }

            // Stage 3: auto-transition to welcome
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                go(0)
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - WELCOME
    // ═══════════════════════════════════════

    @State private var heroVisible = false

    private var welcome: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: Space.lg)

                // Eyebrow — sets the editorial tone before the headline lands.
                Text("MADE FOR YOUR LEVEL")
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .foregroundStyle(Palette.accent)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 12)

                Spacer().frame(height: Space.md)

                // Headline with Fraunces italic accent on "strongest".
                ItalicAccentText(
                    "Sculpt your strongest body, at home.",
                    italic: ["strongest"],
                    alignment: .center
                )
                .padding(.horizontal, Space.lg)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 16)

                Spacer().frame(height: Space.md)

                // Subhead — names Jeni once. No AI language.
                Text("Personalized routines built around your goals — guided by Jeni, your coach.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .opacity(visible ? 1 : 0)
                    .offset(y: visible ? 0 : 16)

                Spacer().frame(height: Space.lg)

                // Hero block. Diagonal-stripe placeholder sits where the
                // coach photo will eventually live; three small ✦ glyphs
                // float around the edges as the only sparkles in the
                // entire app — restraint is part of the brand.
                ZStack {
                    EditorialPlaceholder(label: "EDITORIAL · COACH PHOTO")
                        .frame(maxWidth: 320)
                        .frame(height: 320)
                        .opacity(heroVisible ? 1 : 0)
                        .offset(y: heroVisible ? 0 : 30)

                    sparkle(size: 14, opacity: 0.9)
                        .offset(x: 140, y: -150)
                    sparkle(size: 10, opacity: 0.7)
                        .offset(x: -150, y: 20)
                    sparkle(size: 12, opacity: 0.85)
                        .offset(x: 130, y: 140)
                }
                .frame(maxWidth: .infinity)

                Spacer()

                Button("Get started") {
                    Haptics.light()
                    go(200) // Part 1 divider
                }
                .buttonStyle(.ctaPrimary)
                .padding(.horizontal, Space.screenPadding)
                .opacity(visible ? 1 : 0)
                .offset(y: visible ? 0 : 24)

                Button {
                    Haptics.light()
                    showWelcomeSignInSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Already have an account?")
                        Text("Sign in").underline()
                    }
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
                .opacity(visible ? 1 : 0)
            }
        }
        .onAppear {
            // Hero placeholder eases up first so the editorial block lands
            // before the surrounding copy resolves.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.5)) { heroVisible = true }
            }
            // Eyebrow + headline + subhead + CTA share one fade so the page
            // feels intentional, not staged.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.55)) { visible = true }
            }
            // Confetti retained as the celebratory landing touch — kept
            // brief so it reads as accent, not party.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showConfetti = false }
            }
        }
    }

    private func sparkle(size: CGFloat, opacity: Double) -> some View {
        Text("✦")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(Palette.accent.opacity(opacity))
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                showConfirmation = true
            }
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.18)) { showConfirmation = false }
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
        confirmation: String? = nil
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
                        isSelected: sel.wrappedValue == key,
                        action: {
                            Haptics.light()
                            sel.wrappedValue = key
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
            .opacity(sel.wrappedValue.isEmpty ? 0.35 : 1.0)
            .disabled(sel.wrappedValue.isEmpty)
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
        value: Binding<Double>,
        range: ClosedRange<Double>, step: Double,
        format: @escaping (Double) -> String,
        unitLabel: String? = nil,
        next: Int,
        confirmation: String? = nil,
        @ViewBuilder annotation: () -> Annotation = { EmptyView() }
    ) -> some View {
        VStack(spacing: 0) {
            jfHeader(title, sub: sub)
            Spacer()
            VStack(spacing: Space.md) {
                BiometricSlider(value: value, range: range, step: step, format: format, unitLabel: unitLabel)
                annotation()
            }
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
            Spacer()
            if let contextLine {
                Text(contextLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.sm)
            }
            BodyTypeSlider(
                position: position,
                labels: labels,
                maxPosition: maxPosition,
                markerPosition: markerPosition
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
        switch bmi {
        case ..<18.5:
            label = "Underweight"
            color = Palette.stateWarn
        case 18.5..<25:
            label = "Normal weight"
            color = Palette.stateGood
        case 25..<30:
            label = "Overweight"
            color = Palette.stateWarn
        default:
            label = "Obese"
            color = Palette.stateWarn
        }
        return VStack(spacing: 4) {
            Text("BMI: \(bmiText)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(color)
        }
        .contentTransition(.numericText())
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

        let text: String
        let color: Color
        if goalKg >= currentKg {
            text = "Maintain mode — your plan adapts."
            color = Palette.textSecondary
        } else if percentLoss <= 5 {
            text = "Reasonable goal: steady progress."
            color = Palette.stateGood
        } else if percentLoss <= 15 {
            text = "Solid goal: ~\(weeks) weeks at a healthy pace."
            color = Palette.stateGood
        } else if percentLoss <= 25 {
            text = "Ambitious goal: ~\(weeks) weeks of consistent work."
            color = Palette.stateWarn
        } else {
            text = "Significant goal: focus on sustainable progress."
            color = Palette.stateWarn
        }

        return Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func jfYesNo(
        _ statement: String,
        bind: Binding<Bool?>,
        next: Int,
        confirmation: String? = nil
    ) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Text(statement)
                .font(Typo.title)
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
                    Text("No")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 64)
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
                    Text("Yes, that's me")
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textInverse)
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .background(Palette.bgInverse,
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
            // Question + subtitle at top
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
                if let sub {
                    Text(sub).font(Typo.body).foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.screenPadding)

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
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(title).font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
                if let sub {
                    Text(sub).font(Typo.body).foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.screenPadding)

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
            chartAnimated = true
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
                            Group {
                                if UIImage(named: photo) != nil {
                                    Image(photo).resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Palette.accentSubtle
                                }
                            }
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
            // Pulse rings start after everything settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { coachRingPulse = true }
        }
    }

    // MARK: - Form Education (screen 12)

    @State private var formStep = 0  // 0=hidden, 1=left card, 2=arrow, 3=right card, 4=text

    private var formScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hook
            Text("Other apps\ncount seconds.")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(formStep >= 1 ? 1 : 0)
                .offset(y: formStep >= 1 ? 0 : 10)
                .animation(.easeOut(duration: 0.4), value: formStep)

            Text("We watch your form.")
                .font(.system(size: 28, weight: .bold))
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                    marqueeOffset1 = -1
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
            Group {
                if UIImage(named: asset) != nil {
                    Image(asset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Palette.accent.opacity(0.15), Palette.accentSubtle.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Palette.divider.opacity(0.3), lineWidth: 1)
                    )
                }
            }
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
                .font(.system(size: 28, weight: .bold))
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
                Text("30 days.\n5 exercises.\nOne mission.").font(.system(size: 28, weight: .bold))
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
            Text("What should your\ntrainer call you?")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)

            Text("First name is perfect.")
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

    private var coachSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pick your coach")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, Space.screenPadding)
            Text("They'll guide every workout. Tap to preview.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary)
                .padding(.top, Space.xs).padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            VStack(spacing: Space.sm) {
                trainerRow(
                    id: "keepItReal", photo: "coach-kira", name: "Kira",
                    vibe: "Sassy & Real",
                    quote: "\"My mama planks better than this\"",
                    preview: "kira_preview"
                )
                trainerRow(
                    id: "encouraging", photo: "coach-jeni", name: "Jeni",
                    vibe: "Warm & Supportive",
                    quote: "\"You're doing amazing — keep breathing.\"",
                    preview: "jeni_preview"
                )
                trainerRow(
                    id: "balanced", photo: "coach-matson", name: "Matson",
                    vibe: "Chill & Playful",
                    quote: "\"We're gonna have a good time\"",
                    preview: "matson_preview"
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
                    withAnimation(.easeOut(duration: 0.2)) { showFeedback = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        go(180)
                    }
                }
            }
        }
        .onAppear { configureAudioSession() }
    }

    private func trainerRow(id: String, photo: String, name: String, vibe: String,
                             quote: String, preview: String) -> some View {
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
                    Group {
                        if UIImage(named: photo) != nil {
                            Image(photo).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: id == "keepItReal" ? [Palette.accent, Palette.stateWarn] :
                                        id == "encouraging" ? [Palette.stateGood, Palette.accentSubtle] :
                                        [Palette.bgInverse, Palette.accent.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
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
                            .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                        Text(vibe)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(selected ? Palette.accent.opacity(0.15) : Palette.accent.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(quote)
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(selected ? Palette.textInverse.opacity(0.6) : Palette.textSecondary)
                        .lineLimit(2)

                    if playing {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                            Text("Playing...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.accent)
                        .transition(.opacity)
                    }
                }

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? Palette.textInverse : Palette.divider)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .frame(height: 124)
            .background(selected ? Palette.bgInverse : Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Palette.accent : Palette.divider, lineWidth: selected ? 2 : 1)
            )
        }
        .scaleEffect(selected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: selected)
    }

    private var selectedCoachName: String {
        switch voicePreference {
        case "keepItReal": return "Kira"
        case "encouraging": return "Jeni"
        case "balanced": return "Matson"
        default: return "coach"
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

    // Reshape transition (160). JustFit's "stubborn fat will shed" moment
    // reframed: no spot-reduction claims, no body-shame language, no
    // placeholder silhouettes. Real photography for v1.1 — clean ship
    // without imagery for v1.0. Single thin accent rule under the
    // headline as the visual anchor.
    private var reshapeTransitionScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            ItalicAccentText("Your plan will reshape your body.",
                             italic: ["reshape"],
                             alignment: .center)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.md)

            RoundedRectangle(cornerRadius: 1)
                .fill(Palette.accent)
                .frame(width: 60, height: 1)

            Spacer().frame(height: 56)

            Text("Healthy weight loss is steady — not extreme.\nWe'll get you there safely.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Continue") { Haptics.medium(); go(161) }
        }
    }

    // First weight prediction (161). "We predict you'll be [goal] by [date]"
    private var firstPredictionScreen: some View {
        predictionScreen(
            headlinePrefix: "We predict you'll be ",
            headlineSuffix: ".",
            subhead: "We're starting to get a clear picture of you.",
            badge: nil,
            target: predictionDate(),
            next: 203
        )
    }

    // Re-prediction (170) — same shape, earlier date, "Still on track!" badge.
    private var rePredictionScreen: some View {
        predictionScreen(
            headlinePrefix: "We predict you'll be ",
            headlineSuffix: ".",
            subhead: "We'll incorporate your goal into your personalized plan.",
            badge: "Still on track!",
            target: rePredictionDate(),
            next: 204
        )
    }

    // Final prediction (181) — runs after the loading carousel, hands off
    // to the redesigned plan reveal.
    private var finalPredictionScreen: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

            Text("Based on your answers, your plan is ready.")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.sm)

            predictionHeadline()
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.md)

            weightCurve()
                .frame(height: 180)
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.lg)

            // First-week calendar dots — represents the first 9 days of
            // workouts. Accent dots for committed days, divider for rest.
            firstWeekCalendar()
                .padding(.horizontal, Space.screenPadding)

            Spacer().frame(height: Space.md)

            Text("Designed by trainers, built around your answers.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Get my plan") { Haptics.heavy(); go(21) }
        }
    }

    // Shared layout for the first prediction + re-prediction. Both render
    // a curve graph with current → goal weight, surfaced with the
    // italic-accent date headline.
    private func predictionScreen(
        headlinePrefix: String, headlineSuffix: String,
        subhead: String, badge: String?,
        target: Date, next: Int
    ) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: Space.lg)

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

            ctaBtn("Continue") { Haptics.medium(); go(next) }
        }
    }

    // Italic-accent prediction headline. "We predict you'll be 130 lbs by Mar 5."
    private func predictionHeadline(
        prefix: String = "You'll be ",
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
    // below. "Today" anchored at left, target date at right.
    private func weightCurve(targetDate: Date? = nil) -> some View {
        let date = targetDate ?? predictionDate()
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height - 32  // leave room for axis labels
            let curve = Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h - 8),
                    control: CGPoint(x: w * 0.55, y: h * 0.4)
                )
            }
            let fill = Path { p in
                p.move(to: CGPoint(x: 0, y: 8))
                p.addQuadCurve(
                    to: CGPoint(x: w, y: h - 8),
                    control: CGPoint(x: w * 0.55, y: h * 0.4)
                )
                p.addLine(to: CGPoint(x: w, y: h))
                p.addLine(to: CGPoint(x: 0, y: h))
                p.closeSubpath()
            }
            ZStack(alignment: .topLeading) {
                fill
                    .fill(LinearGradient(
                        colors: [Palette.accent.opacity(0.28), Palette.accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                curve
                    .stroke(Palette.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Endpoint markers
                Circle().fill(Palette.accent).frame(width: 10, height: 10)
                    .offset(x: -5, y: 3)
                Circle().fill(Palette.accent).frame(width: 10, height: 10)
                    .offset(x: w - 5, y: h - 13)

                // Axis labels
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today").font(Typo.eyebrow).foregroundStyle(Palette.textSecondary)
                        Text(weightLabel(kg: currentWeightKg))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatGoalDate(date)).font(Typo.eyebrow).foregroundStyle(Palette.textSecondary)
                        Text(weightLabel(kg: goalWeightKg))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                }
                .offset(y: h)
            }
        }
    }

    // Loading carousel (180). Three rotating frames over 3.5s, then auto-advances.
    private var loadingCarouselScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Building your plan…")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: Space.lg)

            // Rotating frame content
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

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.divider).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.accent, Palette.accentSubtle],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * carouselProgress, height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, Space.xl)

            Spacer().frame(height: Space.sm)

            Text("\(Int(carouselProgress * 100))%")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)

            Spacer()
        }
        .background(Palette.bgPrimary)
        .onAppear { startCarousel() }
    }

    // Frame 1 — early-access user count. Number is a placeholder.
    // TODO(post-launch): replace with real count from analytics.
    private var carouselFrameUserCount: some View {
        VStack(spacing: Space.sm) {
            Text("1,000+ early-access members")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            // Avatar grid placeholder — 4×3 of accent circles
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { col in
                            Circle()
                                .fill(Palette.accent.opacity(0.18 + Double((row + col) % 3) * 0.12))
                                .frame(width: 36, height: 36)
                        }
                    }
                }
            }
            .padding(.top, Space.sm)
        }
    }

    // Frame 2 — placeholder training hours.
    // TODO(post-launch): replace with real session count.
    private var carouselFrameTrainingHours: some View {
        VStack(spacing: Space.sm) {
            Text("100+ hours of plank coaching")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                ForEach(["figure.core.training", "figure.flexibility", "figure.mind.and.body",
                         "stopwatch.fill", "flame.fill"], id: \.self) { sym in
                    Image(systemName: sym)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 44, height: 44)
                        .background(Palette.accentSubtle, in: Circle())
                }
            }
            .padding(.top, Space.sm)
        }
    }

    // Frame 3 — early reviews.
    // TODO(post-launch): replace with real App Store rating + review count.
    private var carouselFrameRating: some View {
        VStack(spacing: Space.sm) {
            Text("5.0 ★ early reviews")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.accent)
                }
            }
            .padding(.top, Space.sm)
        }
    }

    private func startCarousel() {
        carouselProgress = 0
        carouselFrame = 0
        carouselDone = false
        let total = 3.5
        let steps = 70
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + total * Double(i) / Double(steps)) {
                let p = CGFloat(i) / CGFloat(steps)
                withAnimation(.easeOut(duration: 0.1)) { carouselProgress = p }
                let f = min(2, Int(p * 3))
                if f != carouselFrame {
                    withAnimation(.easeInOut(duration: 0.35)) { carouselFrame = f }
                }
                if i == steps && !carouselDone {
                    carouselDone = true
                    Haptics.success()
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showConfetti = false
                        go(181)
                    }
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

    /// "Mar 5" style. Short month + day, no year.
    private func formatGoalDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
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

    private var planRevealScreen: some View {
        let coachName = voicePreference == "encouraging" ? "Jeni" : voicePreference == "balanced" ? "Matson" : "Kira"
        let coachPhoto = voicePreference == "encouraging" ? "coach-jeni" : voicePreference == "balanced" ? "coach-matson" : "coach-kira"
        let goalLabel = jenifitGoalLabel()

        return VStack(spacing: 0) {
            Spacer()

            // Coach photo
            Image(coachPhoto)
                .resizable().scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(Palette.accent, lineWidth: 2.5))
                .opacity(planRevealed ? 1 : 0)
                .scaleEffect(planRevealed ? 1 : 0.8)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: planRevealed)

            Spacer().frame(height: Space.md)

            Text("You're all set\(name.isEmpty ? "" : ", \(name)").")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .opacity(planRevealed ? 1 : 0)
                .offset(y: planRevealed ? 0 : 12)

            Spacer().frame(height: Space.xs)

            Text("Built for \(goalLabel).")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .opacity(planRevealed ? 1 : 0)

            Spacer().frame(height: Space.xs)

            Text("\(coachName) has your first workout ready.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .opacity(planRevealed ? 1 : 0)

            // First-preset preview — surfaces the actual workout name +
            // tagline so the abstract "ready" promise lands as something
            // concrete the user can picture starting.
            if let firstPreset = WorkoutPreset.presets(
                for: WorkoutGoal(rawValue: focusArea) ?? .fullCore
            ).first, let desc = firstPreset.description {
                Spacer().frame(height: Space.sm)
                VStack(spacing: 2) {
                    Text(firstPreset.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(desc)
                        .font(Typo.caption)
                        .italic()
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .opacity(planRevealed ? 1 : 0)
            }

            Spacer().frame(height: Space.lg + 8)

            // Plan summary cards. JeniFit copy — no AI language; "live form
            // check" not "AI form coaching" (per justfit-audit Section 6.K).
            VStack(spacing: 10) {
                planCard(icon: "calendar", title: "Daily routines", detail: "5–10 min sessions designed for you", color: Palette.accent, index: 0)
                planCard(icon: "waveform", title: "Voice coaching", detail: "\(coachName) guides every move", color: Palette.stateGood, index: 1)
                planCard(icon: "viewfinder", title: "Live form check", detail: "We watch your form weekly", color: Palette.textSecondary, index: 2)
                planCard(icon: "sparkles", title: "Adaptive plan", detail: "Gets smarter as you go", color: Palette.stateWarn, index: 3)
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            ctaBtn("Set up camera") { Haptics.medium(); go(26) }
                .opacity(planRevealed ? 1 : 0)
        }
        .background(Palette.bgPrimary)
        .onAppear {
            Haptics.success()
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { planRevealed = true }
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

    private var cameraSetupScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            AnimatedIcon(name: "iphone.gen3.radiowaves.left.and.right", size: 56)
            Spacer().frame(height: Space.lg)
            Text("Set up your camera").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.textPrimary)
            Spacer().frame(height: Space.sm)
            Text("Prop your phone about 6 feet away\nso your coach can see you.")
                .font(Typo.body).foregroundStyle(Palette.textSecondary).multilineTextAlignment(.center)
            Spacer().frame(height: Space.xl)
            VStack(alignment: .leading, spacing: Space.md) {
                tR("figure.stand", "Full body visible"); tR("light.max", "Good lighting")
                tR("iphone.gen3", "Lean against wall or book")
            }.padding(20).background(Palette.bgElevated).clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Space.screenPadding)
            Spacer()
            // Onboarding ends here — the post-onboarding paywall is
            // handled outside the flow by RootView's fullScreenCover
            // gating on PaymentService.hasProAccess. Going to finish()
            // directly so the user lands on MainTabView (or the paywall
            // cover, depending on entitlement state).
            ctaBtn("Got it") { Haptics.medium(); finish() }
        }.padding(.horizontal, Space.screenPadding)
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
                    .font(.system(size: 28, weight: .bold))
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
            withAnimation(.easeOut(duration: 0.5)) { factVisible = true }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - FEATURE SHOWCASE (screen 13)
    // ═══════════════════════════════════════

    private var featureShowcaseScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("Why JeniFit\nworks")
                .font(.system(size: 28, weight: .bold))
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
            withAnimation(.easeOut(duration: 0.4)) { featureVisible = true }
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

    @State private var statCount = 0

    private var beforeAfterScreen: some View {
        VStack(spacing: 0) {
            Spacer()

            Text("What 5 minutes a day\nlooks like")
                .font(.system(size: 28, weight: .bold))
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
            withAnimation(.easeOut(duration: 0.4)) { beforeAfterVisible = true }
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
                    .font(.system(size: 28, weight: .bold))
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
            ctaBtn("Set up camera") { Haptics.medium(); go(23) }
                .opacity(personalStatVisible ? 1 : 0)
        }
        .background(Palette.bgPrimary)
        .onAppear {
            Haptics.success()
            withAnimation(.easeOut(duration: 0.5)) { personalStatVisible = true }
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
        withAnimation(.easeOut(duration: 0.3)) { screen = to }
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
        // Request notification permission if user opted in
        if notificationsEnabled {
            Task {
                let granted = await NotificationPermission.request()
                if granted { NotificationPermission.scheduleDailyReminder(at: notificationTime) }
            }
        }

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

    private func weightLabel(kg: Double) -> String {
        let lb = Int((kg * 2.20462).rounded())
        return "\(lb) lb"
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
    var bodyTypeCurrent: Int = 2           // Part 3 slider 0-5
    var bodyTypeDesired: Int = 2           // Part 3 slider 0-5
    var identityFeeling: String = ""       // Part 4
    var rewardChoice: String = ""          // Part 4
    var relatability1: Bool = false        // Part 5: "I struggle to stay consistent"
    var relatability2: Bool = false        // Part 5: "I get bored doing the same thing"
    var relatability3: Bool = false        // Part 5: "Results don't come fast enough"
}

// MARK: - CTA Button Style

// MARK: - Wobbly Rect (slightly uneven rounded corners)

struct WobblyRect: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h * 0.005))
        p.addCurve(
            to: CGPoint(x: w * 0.995, y: h * 0.49),
            control1: CGPoint(x: w * 0.77, y: -h * 0.01),
            control2: CGPoint(x: w * 1.005, y: h * 0.21)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.505, y: h * 0.995),
            control1: CGPoint(x: w * 1.0, y: h * 0.78),
            control2: CGPoint(x: w * 0.78, y: h * 1.01)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.005, y: h * 0.51),
            control1: CGPoint(x: w * 0.23, y: h * 1.005),
            control2: CGPoint(x: w * 0.0, y: h * 0.79)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: h * 0.005),
            control1: CGPoint(x: w * 0.005, y: h * 0.22),
            control2: CGPoint(x: w * 0.24, y: -h * 0.005)
        )
        p.closeSubpath()
        return p
    }
}

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

// MARK: - Rough Capsule (hand-drawn feel)

struct RoughCapsule: Shape {
    func path(in rect: CGRect) -> Path {
        // Inset slightly so the rough edges have room
        let r = rect.insetBy(dx: 2, dy: 2)
        let w = r.width, h = r.height
        let ox = r.minX, oy = r.minY

        var path = Path()
        // Start left center
        path.move(to: CGPoint(x: ox + h * 0.4, y: oy + h * 0.5))
        // Left cap (slightly uneven)
        path.addCurve(
            to: CGPoint(x: ox + h * 0.5, y: oy + h * 0.03),
            control1: CGPoint(x: ox - h * 0.02, y: oy + h * 0.15),
            control2: CGPoint(x: ox + h * 0.1, y: oy - h * 0.04)
        )
        // Top edge (slight wave)
        path.addCurve(
            to: CGPoint(x: ox + w - h * 0.5, y: oy + h * 0.06),
            control1: CGPoint(x: ox + w * 0.35, y: oy - h * 0.02),
            control2: CGPoint(x: ox + w * 0.65, y: oy + h * 0.08)
        )
        // Right cap
        path.addCurve(
            to: CGPoint(x: ox + w - h * 0.4, y: oy + h * 0.55),
            control1: CGPoint(x: ox + w - h * 0.08, y: oy - h * 0.02),
            control2: CGPoint(x: ox + w + h * 0.03, y: oy + h * 0.2)
        )
        // Right cap bottom
        path.addCurve(
            to: CGPoint(x: ox + w - h * 0.5, y: oy + h * 0.97),
            control1: CGPoint(x: ox + w + h * 0.02, y: oy + h * 0.85),
            control2: CGPoint(x: ox + w - h * 0.1, y: oy + h * 1.03)
        )
        // Bottom edge (slight wave)
        path.addCurve(
            to: CGPoint(x: ox + h * 0.5, y: oy + h * 0.94),
            control1: CGPoint(x: ox + w * 0.6, y: oy + h * 1.04),
            control2: CGPoint(x: ox + w * 0.35, y: oy + h * 0.92)
        )
        // Left cap close
        path.addCurve(
            to: CGPoint(x: ox + h * 0.4, y: oy + h * 0.5),
            control1: CGPoint(x: ox + h * 0.08, y: oy + h * 1.05),
            control2: CGPoint(x: ox - h * 0.03, y: oy + h * 0.8)
        )
        path.closeSubpath()
        return path
    }
}

