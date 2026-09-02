#if DEBUG
import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import PhotosUI
import WidgetKit

// MARK: - DebugPreviewRoutes (v9 P7 — the mechanical decomposition)
//
// The launch-arg preview harness, moved verbatim out of
// PlankAIApp.body (it had grown to ~370 lines inside the window
// root). Behavior-identical: every --debug-* route renders exactly
// as before; the final else is the real app. DEBUG-only compile.

struct DebugPreviewRoutes: View {
    @ViewBuilder var body: some View {
        if ProcessInfo.processInfo.arguments.contains("--debug-delete-account") {
            // v25 §39 — the deletion sheet, mounted ALONE. `36` built a
            // harness for exactly this reason: walking to it through
            // Settings films the paywall on the way (`30` §12.1). The
            // Apple face is the one that gained a sentence, and it is
            // the one that cannot be reached without an Apple account.
            let method: AuthMethod =
                ProcessInfo.processInfo.arguments.contains("--debug-delete-account-email")
                ? .email : .apple
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()
                DeleteAccountSheet(
                    onConfirm: { nil },
                    onSucceededDismiss: {},
                    onCancel: {},
                    authMethod: method
                )
            }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-weekly-read-p54") {
            // p54 — the weekly read with every pass-54 addition
            // composed into one frame (follow-through, weekend shape,
            // protein delta, strength, tenure teaching).
            WeeklyReadP54Harness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-weekly-receipt") {
            // v2.6 RC — the export artifact itself, at card
            // size on the cream, for founder judgment.
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()
                WeeklyReceiptCard(model: .init(
                    weekRange: "june 27 to july 3",
                    plates: 14,
                    loggedDays: 6,
                    proteinDaysHit: 5,
                    stepsTotal: 41_200,
                    trendLine: "down about 500g",
                    resets: 3,
                    jeniLine: "seven days, all counted"
                ))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-post-routine") {
            // App v2.3 — the workout completion state for the
            // surface ledger (a real 10-min session isn't
            // walkable; this is the deterministic route).
            PostRoutineView(
                exerciseResults: (0..<12).map {
                    ExerciseResultEntry(
                        exerciseId: "qa-\($0)", duration: 30,
                        completedDuration: 30, skipped: false
                    )
                },
                totalDuration: 8 * 60 + 24,
                workoutName: "total reset",
                streakCount: 3,
                isFirstWorkoutToday: true,
                didMeetThreshold: true,
                onRate: { _, _ in },
                onDone: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-home-redesign") {
            // p59 — THE HOME DESIGN PASS's exploration harness: the
            // food block, the plan rows, the dose standing and the
            // masthead, each in materially different treatments with
            // ONE representative mid-day state, so the direction is
            // chosen by looking (the p58 §8 method, widened to the
            // whole page).
            HomeRedesignHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-burst-gallery") {
            // p64 — THE DELIGHT LAYER's bake-off harness: the three
            // burst styles (paper fleck · light ray · petal bloom)
            // and the three tiers, each fired from a mock control so
            // the direction is chosen by LOOKING (§26 of the brief).
            BurstGalleryHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-moment-gallery") {
            // p65 — THE MOMENT SYSTEM's design harness: the full-page
            // celebration at each tier with a real payload, iterated
            // by LOOKING. `--uitest-moment N` (0 spark · 1 crest ·
            // 2 moment) mounts one directly for the walker.
            MomentGalleryHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-band-contenders") {
            // p58 — the Home nutrition visual, re-decided by LOOKING:
            // the shipped band beside two real alternatives (the
            // split donut; the remainder-hero ring), same data.
            BandContendersHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-widget-gallery") {
            // p58 — the Home Screen widget's faces, mounted alone for
            // THE LOOP's captures (the widget renders in another
            // process; this harness renders the SAME view code at
            // widget geometry so every state can be filmed).
            WidgetGalleryHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-v11-gallery") {
            // App v11 — the editorial kit gallery
            // (docs/app_v11/00_REBIRTH.md §4). Double-tap restarts
            // the arrival choreography for THE LOOP's captures.
            JeniKitGallery()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-jenikit") {
            // App v2 — the JeniKit component gallery
            // (docs/app_v2/10_DESIGN_SYSTEM.md — deleted; git history).
            JKGalleryHarness()
        } else if false {
            // --debug-daily-ritual retired with PlanView (v2.6 RC).
            EmptyView()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-method-note") {
            // p54 — `--debug-lesson-close` retired with the lesson
            // reader's ink-bloom overlay (the corpus deletion).
            // v25 E8.1 — the Method note, mounted alone against a
            // hand-built record. The in-app door (`--uitest-open-method`)
            // races the snapshot load and the ledger's once-ever
            // cooldowns, so a surface whose whole point is "only when
            // your record earns it" is the hardest kind to film from the
            // outside. This mounts the view against explicit inputs, the
            // same technique v12 used when synthesized drags could not
            // scroll the simulator.
            MethodNoteDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-move") {
            // v25 E8.1 — JENI MOVE, mounted alone. `--uitest-seed-program`
            // seeds a real step week; StepsService.seedForQA fills the
            // 28-day baseline the sheet compares her to. Pair with
            // `--debug-move-strength` to see the met state.
            MoveDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-screen") {
            // v1.2 (2026-06-25) — medical-grade Phase 1: SCOFF screen.
            SCOFFScreenView(onComplete: { _, _ in })
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-recovery") {
            // v1.2 (2026-06-25) — ED-positive gentle path + resources.
            SafetyRecoveryView(onContinueGently: {})
        } else if ProcessInfo.processInfo.arguments.contains("--debug-program-setup") {
            // v1.2 (2026-06-25) — the real program-setup subflow, to
            // verify the safety gate fires before the program build.
            ProgramSetupSubflow(onComplete: { _ in })
        } else if ProcessInfo.processInfo.arguments.contains("--debug-plan-numbers") {
            // 2026-08-14 — the repair door, mounted alone. Pair with
            // `--debug-plan-numbers-focus
            //   <weight|height|goal|activity|sex|age|pace>`
            // to land on one editor, or with --uitest-persona-nogoal /
            // --uitest-persona-legacy-alias to film the missing and the
            // ambiguous faces.
            JKPlanNumbersSheet(
                focus: {
                    let args = ProcessInfo.processInfo.arguments
                    guard let i = args.firstIndex(of: "--debug-plan-numbers-focus"),
                          i + 1 < args.count
                    else { return nil }
                    return JKPlanNumbersSheet.Fact(rawValue: args[i + 1])
                }(),
                onClose: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-plate-day") {
            // 2026-08-14 (§34) — the plate page's day repair, mounted
            // alone with the picker already open. Its in-app door is a
            // tap on THE DAY row, and simctl cannot tap; mounting it
            // here also makes the film deterministic in one launch
            // rather than depending on Home resolving first.
            PlateDayDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-symptom-sheet") {
            // 2026-08-14 (§36) — the side-effect logger mounted ALONE,
            // on a PAST day, with its day picker open.
            //
            // The first attempt at this frame paired `--debug-symptom-day`
            // (which only opens the picker inside the sheet) with
            // `--uitest-open-side-effects` (a HomeView door) and filmed
            // the PAYWALL, because without an entitlement the app never
            // reaches Home. That is `30` §12.1's law landing again: a
            // film door that cannot reach the surface it names is a
            // fixture that lies about what was inspected. The fix is the
            // door, never the frame.
            SymptomDayDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-regimen-record") {
            // 2026-08-14 (§36) — the regimen home with BOTH record
            // lists populated: `the doses` (now tappable) and `the
            // symptoms` (new). Its in-app door is Home's medication row
            // or Settings › your medication, and simctl cannot tap.
            //
            // The harness seeds its own account through the same
            // seeder + the same stores the lists read, rather than
            // riding a persona — a film door that cannot reach the
            // surface it names is a fixture that lies about what was
            // inspected (`30` §12.1), and this one has to show two
            // sections at once to prove they read as one page.
            RegimenRecordDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-weigh-ins") {
            // 2026-08-14 (§34) — `your weigh-ins`, mounted alone. Its
            // in-app door is becoming › your record, and simctl cannot
            // tap. Pair with `--uitest-seed-program` for a real week of
            // rows, or `--uitest-seed-oneweight` for the single-row
            // face; with no weigh-ins at all it films the empty state.
            WeighInDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-goal-ritual") {
            // 2026-08-13 — the goal-weight editor, mounted alone. Pair
            // with --uitest-persona-customer to see the live distance +
            // horizon line, or --uitest-persona-nogoal for the first-set
            // face. The in-app doors need a tap, and simctl cannot tap.
            JKGoalRitual(
                currentKg: UserDefaults.standard
                    .double(forKey: "onboardingCurrentWeightKg").nilWhenZero,
                existingGoalKg: UserDefaults.standard
                    .double(forKey: "onboardingGoalWeightKg").nilWhenZero,
                heightCm: UserDefaults.standard.double(forKey: "onboardingHeightCm"),
                isFirstTime: UserDefaults.standard
                    .double(forKey: "onboardingGoalWeightKg") <= 0,
                onSave: { _ in },
                onCancel: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-weigh-in") {
            // 2026-08-13 — the daily weigh-in, mounted alone. It is the
            // second most-used action in the product (72 users / 193
            // events / 90 days) and it had no film door, so its AX5
            // behaviour had never been looked at.
            JKWeightRitual(
                startingFromKg: UserDefaults.standard
                    .double(forKey: "onboardingCurrentWeightKg").nilWhenZero ?? 65,
                priorLoggedCount: 3,
                isUpdatingToday: false,
                onSave: { _ in }, onDone: {}, onCancel: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-consent") {
            SafetyConsentView(onAccept: {})
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-pregnancy") {
            SafetyPregnancyView(onComplete: { _ in })
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-checkin") {
            SafetyCheckInView(onFinish: {})
        } else if ProcessInfo.processInfo.arguments.contains("--debug-safety-gate") {
            // T7 + safety-fix (2026-06-29) - the pre-paywall safety gate.
            // Auto-assesses from seeded AppStorage so each branch is one
            // launch + one screenshot. Seed then launch, e.g.:
            //   defaults write com.bk.plankAI onboarding_medication_status -string insulin_or_sulfonylurea
            //     → clinician-first terminal
            //   defaults write com.bk.plankAI safety_scoff_yes -int 3 (+ safety_scoff_core 3)
            //     → recovery terminal
            //   defaults write com.bk.plankAI safety_pregnancy_status -string pregnant
            //     → maintenance terminal (pregnancy variant)
            //   (clean defaults) → "safety passed" proceed marker
            SafetyGateDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-profile-hub") {
            // Settings, mounted alone — the gear does not expose
            // reliably to XCUI, and this surface needs frame review.
            ProfileHubView()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-jeni-memory") {
            // v25 E3 — what jeni remembers, mounted alone (three taps
            // down the settings tree, and it carries the consent law's
            // visible half; it needs frame review every era).
            JeniMemoryDebugHost()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-v8-hold") {
            // v8 close beats, mounted alone so THE LOOP films them in
            // seconds instead of walking the whole consult.
            V8HoldMoment(store: OV5Store(), onSealed: {})
                .background(Palette.bgPrimary.ignoresSafeArea())
        } else if ProcessInfo.processInfo.arguments.contains("--debug-v8-health") {
            V8HealthMoment(onDone: {})
                .background(Palette.bgPrimary.ignoresSafeArea())
        } else if ProcessInfo.processInfo.arguments.contains("--debug-v8-med-list") {
            // PASS 48 — the `medOne` beat, mounted ALONE. The founder's
            // device screenshot showed eight products with two more
            // below the fold and no way to reach them; walking the
            // whole consult to film it costs ~4 minutes and crosses the
            // paywall on the way (`30` §12.1, the same reason `36`
            // built a sheet harness). This is the LONGEST option list
            // in the consult: eight injectables + "something else" +
            // "not sure yet".
            // `--debug-v8-med-list-pills` renders the short (oral)
            // list, which fits — the control that proves the harness
            // is not simply always overflowing.
            // `--debug-v8-med-list-fresh` runs the typing path instead
            // of the settled back-nav path.
            V8MedListDebugHost()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-snap-demo") {
            // PASS 48 — the onboarding food demo, mounted ALONE, so the
            // photo -> scanning -> result sequence can be filmed frame
            // by frame. Add `--debug-snap-demo-glp1` for the cohort
            // chip ("your number now"), which is the face the founder
            // photographed.
            OV5SnapDemoDebugHost()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-hold-promise") {
            // Hold-to-promise (2026-06-30) — renders the commitment
            // ritual close in isolation so the press-and-hold seal can
            // be screenshotted without walking the full onboarding.
            // Add --debug-hold-auto-seal to auto-run the hold + capture
            // the sealed "promised" state.
            HoldPromiseDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-glp1-nutrition") {
            // v1.2 (2026-06-26) — medical-grade Phase 3.3: GLP-1 nutrition
            // education nudges (hydration / fiber / nutrient density). The
            // three rotate daily; wellness framing, no medical advice.
            ZStack {
                Palette.bgPrimary.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("GLP-1 nutrition nudges (Phase 3.3)")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(24)
            }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-trial-day2") {
            TrialDay2Modal(
                expirationDate: Date().addingTimeInterval(28 * 3600),
                onDismiss: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-trial-day3") {
            TrialDay3Modal(
                expirationDate: Date().addingTimeInterval(9 * 3600),
                onDismiss: {}
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-log-weight-sheet") {
            LogWeightSheetPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-share") {
            HandwrittenSharePreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-weekly") {
            HandwrittenWeeklyPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-snap") {
            HandwrittenSnapPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-result-carousel") {
            ResultCarouselPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-snap-camera") {
            SnapCameraDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-describe") {
            // v1.2 snap rebuild — the describe (text) entry mode
            // in isolation, restyled register.
            QuickAddView(
                onLogged: { _ in },
                onScanInstead: {},
                onDismiss: {},
                userId: "debug-journal-user"
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-arrival") {
            // Phase 1a (Task 9, 2026-06-28) - arrival horizon hero.
            // Renders the hero with seeded data (goalDate ~84 days out,
            // 4 actions this week of 5 target) so it can be iterated
            // and screenshot without a full enrolled account.
            ArrivalHeroPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-promise-confirm") {
            // Task 10 (2026-06-28) - promise confirmation screen.
            // Seeds the stored promise and shows PostPurchaseFlowView
            // jumped straight to the promiseConfirmation phase.
            // Use simctl defaults to set custom values:
            //   day1PromiseAction "log breakfast"
            //   day1PromiseAnchor "after coffee"
            PromiseConfirmPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-kept-promise") {
            // Task 10 (2026-06-28) - Day-1 kept-promise card on the Today screen.
            // Seeds day1Promise* AppStorage values + a past promise time so
            // PlanView renders the card immediately. Requires a real program
            // plan to exist (run --uitest-inapp-qa to set one up first).
            KeptPromisePreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-activation-gallery") {
            // Phase 1a (2026-06-28) - activation design foundation
            // gallery. Renders every reusable component (grainfield
            // background, arc sparkline, tick row, lab readout block,
            // earned sticker cluster) in one scroll so the premium
            // register can be iterated + screenshot without a screen.
            ActivationGalleryHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-projection") {
            // Debug harness - jumps straight to the single projection
            // reveal (T5 merged the former assessment's clinician
            // credibility strip into it). Provenance line variant
            // controlled via simctl defaults write:
            //   onboardingSleepHours five6  → short-sleep line
            //   onboarding_glp1_status current → GLP-1 line
            // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-projection`
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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-projection-maintenance") {
            // FIX 3 (2026-06-29) - delta-0 (maintenance) reveal. Equal
            // current + goal weight so the projection step renders its
            // maintenance-framed variant (maintenance-TDEE calorie hero
            // + "your plan, steady" headline, curve gracefully omitted)
            // instead of gutting the reveal. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-projection-maintenance`
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: 70,
                goalWeightKg: 70,
                onRevealComplete: {},
                debugStartAtProjection: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-projection-suppressed") {
            // v1.2 safety (2026-06-29) - proves the safety adaptation is
            // APPLIED, not cosmetic. Seeds safety_numeric_suppression =
            // true (the ED / pregnant gate output) then jumps to the
            // projection with a REAL loss delta (75 -> 65). The reveal
            // must still render its non-numeric "your plan, steady"
            // variant: NO calorie hero, NO goal date, NO loss curve.
            // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-projection-suppressed`
            SuppressedProjectionDebugHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-commitment") {
            // Task 7 (2026-06-28) - commitment ritual screen.
            // Jumps straight to CommitmentRitualPresentation so
            // simctl can screenshot it without running the full
            // building loader. GLP-1 variant via simctl defaults:
            //   onboarding_glp1_status current  → "protect your muscle" replay
            //   onboardingSleepHours five6       → "after i wake up" default anchor
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: 75,
                goalWeightKg: 65,
                onRevealComplete: {},
                debugStartAtCommitment: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-building") {
            // v1.1.3 T6 (2026-06-29) - jumps straight to the trimmed
            // (~8s) building loader so simctl can time + screenshot it
            // without tapping through the disclaimer. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-building`
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: 75,
                goalWeightKg: 65,
                onRevealComplete: {},
                debugStartAtBuilding: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-disclaimer") {
            // Medical disclaimer trust screen (Task 8). Jumps straight
            // to DisclaimerPresentation so it can be screenshot-ed
            // without running the full building loader. The screen is
            // the default production start so this harness is mainly
            // useful for CI screenshots and design review.
            // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-disclaimer`
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: 75,
                goalWeightKg: 65,
                onRevealComplete: {},
                debugStartAtDisclaimer: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-first-week") {
            // Jumps straight to the firstWeek reveal beat (skips
            // the building loader + its ATT modal). Tier reads
            // from the onboardingPickedTier AppStorage key
            // (default medium); `simctl ... defaults write
            // com.bk.plankAI onboardingPickedTier soft|hard` to
            // check the other tiers.
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: nil,
                goalWeightKg: nil,
                onRevealComplete: {},
                debugStartAtFirstWeek: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-rating-ask") {
            // Jumps to the `.ratingAsk` reveal step (which now
            // renders the FEAR-RESOLUTION beat) for screenshotting.
            // The pre-paywall review gate itself is the `.reviewGate`
            // step just before this — preview it standalone with
            // `--debug-rating-gate`.
            // Launch: `xcrun simctl launch booted com.bk.plankAI --debug-rating-ask`
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: nil,
                goalWeightKg: nil,
                onRevealComplete: {},
                debugStartAtRatingAsk: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-nudge") {
            // The founder's redesigned notification opt-in nudge
            // ("want a nudge from jeni?" - iOS notification-mock
            // banner + "tap to feel it" haptic + time pills). It now
            // lives as the reveal's LIVE permissions step
            // (NudgePermissionAsk), reclaimed from the orphaned case
            // 23. Jumps straight there for sim capture + design
            // review. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-nudge`
            OnboardingRevealView(
                bodyFocus: ["flatBelly"],
                sessionLengthKey: "ten",
                voicePreference: "encouraging",
                commitmentDaysKey: "five",
                currentWeightKg: 75,
                goalWeightKg: 65,
                onRevealComplete: {},
                debugStartAtPermissions: true
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-paywall") {
            // 2026-07-07 - keep-wall design preview. Renders
            // PaywallView with DEBUG mock pricing + mock day-one
            // data (no RC packages / no UserRecord needed in-sim)
            // so the full layout - ownership hero, day-one card,
            // three tier rows, receipt-confirm - renders for
            // visual verification. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-paywall`
            // Add `--uitest-pricing-fail` to preview the pricing
            // failure + retry states.
            PaywallView(
                dismissable: true,
                onSubscribed: {},
                onRestore: {},
                onDismiss: {},
                onPurchaseCancelled: { _, _ in }
            )
        } else if ProcessInfo.processInfo.arguments.contains("--debug-winback") {
            // 2026-07-08 - final-exit winback preview. Seeds a
            // loss goal + discount-unlocked so the plan card
            // renders its rich state (goal · date · saved price).
            // Add `--debug-winback-bare` to preview the
            // no-goal/no-discount fallback row. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-winback`
            //
            // 2026-08-10 - the wall no longer presents this sheet (App
            // Store 5.6: chained exit interstitials). The surface is
            // kept, and previewable, for the silent-week re-engagement
            // work earmarked in TODOS.md.
            CancellationWinbackSheet(onStayOpen: {}, onLeave: {})
                .onAppear {
                    let d = UserDefaults.standard
                    let bare = ProcessInfo.processInfo.arguments.contains("--debug-winback-bare")
                    // Clear BOTH the v5 + legacy weight keys (the
                    // card prefers v5), so bare truly shows the
                    // no-goal fallback row.
                    d.set(bare ? "" : "jen", forKey: "userName")
                    d.set(bare ? "" : "jen", forKey: "onb_v5_name")
                    d.set(bare ? 0 : 90.7, forKey: "onboardingCurrentWeightKg")
                    d.set(bare ? 0 : 81.2, forKey: "onboardingGoalWeightKg")
                    d.set(bare ? 0 : 90.7, forKey: "onb_v5_weight_kg")
                    d.set(bare ? 0 : 81.2, forKey: "onb_v5_goal_kg")
                    d.set(bare ? false : true, forKey: "downsellShownOnce")
                }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-stand-down") {
            // 2026-08-10 - the wall's stand-down, the screen the X
            // lands on once the one offer is spent (App Store 5.6).
            // Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-stand-down`
            StandDownView(onSeePlans: {}, onRestore: {})
                .onAppear { UserDefaults.standard.set("jen", forKey: "userName") }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-rating-gate") {
            // 2026-07-08 - the first-win sentiment gate preview.
            // Renders RatingSentimentScreen exactly as it fires
            // after a first workout completion; "not really" opens
            // the feedback path. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-rating-gate`
            RatingGateDebugHost()
        } else {
            RootView()
                .modifier(ResumeBloom())
        }
    }
}
#endif


// MARK: - MoveDebugHarness (v25 E8.1)
//
// The sim reports no HealthKit data, so Move's rows would all be absent
// and the surface unfilmable — the same problem E8 hit with the protein
// close. This seeds a representative week + baseline through the
// service's own QA seam, and optionally a recorded strength session, so
// every state can be looked at rather than reasoned about.

#if DEBUG
private struct MoveDebugHarness: View {
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                MoveSheet(goal: 7_500, weightKg: 74.2)
            } else {
                Color(Palette.bgPrimary).ignoresSafeArea()
            }
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            // Wipe FIRST. UserDefaults survives a relaunch, so without
            // this the harness accumulated sessions across runs and the
            // strength block filmed "3 of 2" — the exact
            // seeder-after-wipe ordering trap E7 recorded for food.
            MoveManualStore.wipe()
            StepsService.shared.seedForQA(
                weekly: [6_240, 9_180, 4_020, 8_640, 7_710, 2_180, 5_460],
                today: 5_460,
                history28: (0..<28).map { 4_000 + ($0 * 431) % 6_000 }
            )
            if args.contains("--debug-move-strength") {
                MoveManualStore.record(
                    kind: .strength, minutes: 45, weightKg: 74.2,
                    at: Date().addingTimeInterval(-2 * 86_400)
                )
                MoveManualStore.record(
                    kind: .strength, minutes: 30, weightKg: 74.2,
                    at: Date().addingTimeInterval(-5 * 86_400)
                )
            } else if args.contains("--debug-move-one-session") {
                MoveManualStore.record(
                    kind: .strength, minutes: 30, weightKg: 74.2,
                    at: Date().addingTimeInterval(-86_400)
                )
            }
            ready = true
        }
    }
}
#endif


// MARK: - WeeklyReadP54Harness (p54)
//
// Mounts the weekly read against an explicit composed model — the
// §36 technique (the in-app door needs a seeded week, a due anchor
// and a cooldown-free ledger, so a surface whose whole point is
// "what mattered THIS week" is the hardest kind to film live).
// `--debug-weekly-read-p54` films the pass-54 additions in one
// frame: the Method follow-through line, the weekend shape, the
// protein delta, the strength pillar and the tenure teaching.

#if DEBUG
struct WeeklyReadP54Harness: View {
    private var minimal: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-weekly-read-min")
    }
    var body: some View {
        if minimal {
            // p54 AX5 bisect: the read with NO signals, NO
            // observations, NO teaching — isolates the width-forcer.
            ReSigningView(
                due: JourneyModel.DueReview(
                    weekIndex: 6,
                    slice: ProgramWeekSlice(weekIndex: 6, days: []),
                    proposal: .holdSteady(reason: "the plan holds."),
                    weekName: "the steady week",
                    story: "quiet.",
                    resolution: .init(
                        kind: .doseDay,
                        windowStartDay: "2026-08-10",
                        dueSince: .now
                    ),
                    model: WeeklyReadModel(
                        windowStartDay: "2026-08-10",
                        anchorKind: .doseDay,
                        heroLine: "a quiet week.",
                        heroItalics: [],
                        signals: [],
                        observations: [],
                        teaching: nil,
                        offer: .v4(.holdSteady(reason: "the plan holds."))
                    )
                ),
                userId: "debug", onSigned: { _ in }, onClose: {}
            )
        } else {
            full
        }
    }

    private var full: some View {
        ReSigningView(
            due: JourneyModel.DueReview(
                weekIndex: 6,
                slice: ProgramWeekSlice(weekIndex: 6, days: []),
                proposal: .holdSteady(reason: "the plan holds."),
                weekName: "the steady week",
                story: "6 days kept \u{00B7} 14 plates logged \u{00B7} weighed in 3 times.",
                resolution: .init(
                    kind: .doseDay,
                    windowStartDay: "2026-08-10",
                    dueSince: .now
                ),
                model: WeeklyReadComposer.compose({
                    var i = WeeklyReadComposer.Inputs(
                        windowStartDay: "2026-08-10",
                        anchorKind: .doseDay,
                        offer: .v4(.holdSteady(reason: "the plan holds."))
                    )
                    i.stepsThisWeek = Array(repeating: 6_400, count: 7)
                    i.stepsTrailing = Array(repeating: 6_100, count: 21)
                    i.plateDays = 6
                    i.plateCount = 14
                    i.proteinDaysMet = 5
                    i.priorProteinDaysMet = 2
                    i.strengthSessions7 = 2
                    i.weekendKcalDelta = 350
                    i.methodFollowUpsMet = 2
                    i.methodFollowUpsSettled = 3
                    i.doseWeek = .takenOnDay
                    i.cycleDay = 2
                    i.cycleLength = 7
                    i.treatmentMonths = 11
                    i.weight = .init(
                        band: "holding_steady",
                        sufficiency: "established",
                        deltaText: "0.2 lb"
                    )
                    return i
                }())
            ),
            userId: "debug",
            onSigned: { _ in },
            onClose: {}
        )
    }
}
#endif

// MARK: - MethodNoteDebugHarness (v25 E8.1)

#if DEBUG
private struct MethodNoteDebugHarness: View {
    var body: some View {
        Group {
            if let resolved = MethodEngine.note(input) {
                MethodNoteView(resolved: resolved, onKept: {}, onClose: {})
            } else {
                Text("no note for this state \u{2014} which is the point")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.bgPrimary)
            }
        }
    }

    private var input: MethodEngine.Input {
        let args = ProcessInfo.processInfo.arguments
        var i = MethodEngine.Input()
        i.plateCountEver = 22
        i.proteinFloorG = 90
        i.proteinEatenTodayG = 60
        i.loggedDayOffsets = Set(0..<7)
        i.weekendDayOffsets = [2, 3]
        i.programDay = 12
        i.hourOfDay = 10
        i.trendIsEstablished = true
        i.weighInCount = 9
        i.emaDelta7dKg = -0.2
        i.daysOfWeightHistory = 40
        i.strengthSessionsLast7 = 2
        i.steps7dMean = 7_000
        i.steps28dMean = 7_200
        i.metProteinFloorBeforeToday = true
        i.recentLoggedDayProteins = [60, 48, 52, 95, 91]   // the pattern
        // p54 — the harness films the US default (the unit fix's
        // whole point: the film sees what she sees).
        i.weightUnitIsLb = true

        if args.contains("--debug-method-scale") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.latestWeightKg = 74.4
            i.previousWeightKg = 73.2
        }
        // v25 E9 — the two GI notes that replaced a prescribed volume.
        if args.contains("--debug-method-fluids") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.recentQueasySymptomWord = "queasy"
        }
        if args.contains("--debug-method-fiber") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.loggedConstipationRecently = true
            i.recentFiberGPerDay = 11
        }
        if args.contains("--debug-method-clinic") {
            i.clinicNotes = MethodClinicSource.resolve(
                MethodClinicSource.Bundle(
                    version: 1,
                    attribution: "dr. okafor \u{00B7} lakeside metabolic",
                    notes: [
                        MethodNote(
                            id: "clinic_protein_v1",
                            trigger: .proteinUnderFloorRepeatedly,
                            noticed: "{days} of your last {window} days came in under {floor} g.",
                            noticedItalic: ["under {floor} g."],
                            because: "we set that number together at your last visit. breakfast is where it usually goes missing, so start there.",
                            evidence: nil,
                            action: .init(label: "add something with protein", door: .describePlate),
                            followUp: .proteinFloorMetToday,
                            cooldownDays: 7,
                            suppressedForm: "your protein has been landing light most days.",
                            authority: .careTeam(attribution: "dr. okafor \u{00B7} lakeside metabolic")
                        )
                    ],
                    suppressedNoteIds: [],
                    expiresAt: nil
                )
            ).notes
        }
        // p54 — the three new states, filmable in isolation.
        if args.contains("--debug-method-salty") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.latestWeightKg = 74.6
            i.previousWeightKg = 74.0
            i.lastWeighInDaysAgo = 0
            i.yesterdaySodiumMg = 3_400
        }
        if args.contains("--debug-method-salty-pattern") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.latestWeightKg = 74.6
            i.previousWeightKg = 74.0
            i.lastWeighInDaysAgo = 0
            i.yesterdaySodiumMg = 3_400
            i.saltyBumpPriorInstances = 2
        }
        if args.contains("--debug-method-menses") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.latestWeightKg = 74.6
            i.previousWeightKg = 74.0
            i.lastWeighInDaysAgo = 0
            i.cycleSeasonIsMenstrual = true
        }
        if args.contains("--debug-method-ended") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.selfMedicationEndedDaysAgo = 3
        }
        if args.contains("--debug-method-interval-late") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.doseCycleDay = 9
            i.doseCycleLength = 10
        }
        if args.contains("--debug-method-suppressed") { i.numericsSuppressed = true }
        return i
    }
}
// MARK: - PlateDayDebugHarness (§34)
private struct PlateDayDebugHarness: View {
    var body: some View {
        let at = Calendar.current.date(
            bySettingHour: 21, minute: 40, second: 0,
            of: Calendar.current.startOfDay(for: .now)
        ) ?? .now
        PlateDetailSheet(
            entry: FoodLogPersister.FoodLogEntry(
                id: "debug-plate-day",
                loggedAt: at,
                title: "salmon and rice",
                kcal: 610, protein: 34, carbs: 62, fat: 21,
                fiber: 4, sugar: 3, sodiumMg: 640,
                items: ["salmon", "jasmine rice", "broccoli"],
                source: "photo",
                itemsDetail: [
                    .init(name: "salmon", portionG: 140, kcal: 280,
                          protein: 34, carbs: 0, fat: 15),
                    .init(name: "jasmine rice", portionG: 150, kcal: 240,
                          protein: 4, carbs: 53, fat: 1),
                    .init(name: "broccoli", portionG: 90, kcal: 90,
                          protein: 3, carbs: 9, fat: 5),
                ]
            ),
            userId: "debug-plate-day",
            onDismiss: {}
        )
    }
}

// MARK: - WeighInDebugHarness (§34)
//
// The debug routes REPLACE the app root, so `PlankAIApp`'s launch task —
// which is where `--uitest-seed-program` writes weigh-ins into SwiftData
// — never runs. The first take of this film showed the empty state for a
// persona with a seeded week, which is a fixture lying about what was
// inspected (`30` §12.1). The harness seeds its own rows, through the
// same store the ledger reads.
private struct WeighInDebugHarness: View {
    @Environment(\.modelContext) private var modelContext
    @State private var ready = false
    private let userId = "debug-weigh-ins"

    var body: some View {
        Group {
            if ready {
                WeighInLedgerSheet(userId: userId, onClose: {})
            } else {
                Color(Palette.bgPrimary).ignoresSafeArea()
            }
        }
        .task {
            let args = ProcessInfo.processInfo.arguments
            // Wipe first — the harness runs on a persistent store and a
            // second launch would otherwise double the record (the
            // seeder-after-wipe ordering trap, recorded three times).
            let owner = userId
            try? modelContext.delete(model: WeightLogRecord.self,
                                     where: #Predicate { $0.userId == owner })
            if !args.contains("--debug-weigh-ins-empty") {
                // A real fortnight: her own numbers, one from Health,
                // the sign-up row at the bottom, and a day carrying two
                // rows (the case a per-day roll-up would have hidden).
                // Hours are explicit: the two rows sharing yesterday
                // must carry DIFFERENT times, or the film cannot show
                // the disambiguation it exists to show.
                let series: [(daysAgo: Int, hour: Int, kg: Double, source: String)] = [
                    (0, 7, 74.2, "manual"),
                    (1, 20, 74.5, "healthkit"),
                    (1, 7, 75.1, "manual"),
                    (3, 7, 74.8, "manual"),
                    (6, 8, 75.2, "manual"),
                    (9, 7, 75.1, "healthkit"),
                    (13, 9, 75.4, "onboarding"),
                ]
                for point in series {
                    let day = Calendar.current.date(
                        byAdding: .day, value: -point.daysAgo, to: .now
                    ) ?? .now
                    let at = Calendar.current.date(
                        bySettingHour: point.hour, minute: 2, second: 0,
                        of: Calendar.current.startOfDay(for: day)
                    ) ?? day
                    let row = WeightLogRecord(
                        userId: owner, weightKg: point.kg,
                        loggedAt: at, source: point.source
                    )
                    row.pendingUpsert = false   // debug data stays local
                    modelContext.insert(row)
                }
                try? modelContext.save()
            }
            ready = true
        }
    }
}

// MARK: - RegimenRecordDebugHarness (v25 §36)
//
// The regimen home, with nine weeks of real doses and six days of real
// symptoms, seeded through `MedicationQASeeder`'s own `history` variant
// and `SideEffectLog` — the same writers the product uses. Films `the
// doses` (tappable as of this session), `the symptoms` (new), and the
// two together, which is the thing that had to be looked at: whether a
// page that already carried four doors, a next-dose line, a symptom
// door and an era chain still reads as one page with a fifth section.
private struct RegimenRecordDebugHarness: View {
    @Environment(\.modelContext) private var modelContext
    @State private var ready = false
    private let userId = "debug-regimen-record"

    var body: some View {
        Group {
            if ready {
                RegimenSheet(userId: userId, onDone: {})
            } else {
                Color(Palette.bgPrimary).ignoresSafeArea()
            }
        }
        .task {
            // Wipe first — the harness runs on a persistent store, and a
            // second launch would otherwise double every row (the
            // seeder-after-wipe ordering trap, recorded three times).
            let owner = userId
            try? modelContext.delete(model: RegimenPlanRecord.self,
                                     where: #Predicate { $0.userId == owner })
            try? modelContext.delete(model: DoseEventRecord.self,
                                     where: #Predicate { $0.userId == owner })
            try? modelContext.delete(model: ObservationRecord.self,
                                     where: #Predicate { $0.userId == owner })
            try? modelContext.save()
            // `--debug-regimen-record-short` seeds ONE dose instead of
            // nine. The page with nine is longer than a screen and
            // `the symptoms` sits below the fold, and simctl cannot
            // scroll (this repo's own record: synthesized drags do not
            // move the iOS 26.2 simulator). A section nobody has filmed
            // is a section nobody has looked at, so the short fixture
            // exists to put BOTH record lists in one frame. It is the
            // same page, with a shorter history — not a different one.
            let short = ProcessInfo.processInfo.arguments
                .contains("--debug-regimen-record-short")
            MedicationQASeeder.seed(
                variant: short ? "injectable" : "history",
                userId: owner, in: modelContext
            )
            if short {
                // The injectable variant seeds a plan and today's open
                // slot but no history, so give it two resolved slots to
                // list — through the real chokepoint.
                let cal = Calendar.current
                for daysAgo in [7, 14] {
                    guard let day = cal.date(
                        byAdding: .day, value: -daysAgo, to: .now
                    ) else { continue }
                    MedicationLog.resolve(
                        .taken(site: daysAgo == 7 ? .leftThigh : .rightAbdomen,
                               note: nil, at: day),
                        slotDayKey: TodayStateService.dayKey(for: day),
                        source: .sheet, userId: owner, in: modelContext
                    )
                }
                for (daysAgo, symptom, severity) in [
                    (1, SideEffectSymptom.nausea, SideEffectSeverity.noticeable),
                    (6, SideEffectSymptom.foodNoise, SideEffectSeverity.aTouch),
                ] {
                    guard let day = cal.date(
                        byAdding: .day, value: -daysAgo, to: .now
                    ) else { continue }
                    _ = SideEffectLog.record(
                        symptom, severity: severity,
                        dayKey: TodayStateService.dayKey(for: day),
                        userId: owner, in: modelContext
                    )
                }
            }
            // One extra day carrying TWO symptoms, because a row that
            // states two facts is the case the single-symptom seed
            // cannot show, and it is the one that decides whether the
            // detail line wraps sanely at AX5.
            let cal = Calendar.current
            if let twoAgo = cal.date(byAdding: .day, value: -2, to: .now) {
                let key = TodayStateService.dayKey(for: twoAgo)
                _ = SideEffectLog.record(.fatigue, severity: .rough,
                                         dayKey: key, userId: owner,
                                         in: modelContext)
                _ = SideEffectLog.record(.hairShedding, severity: .aTouch,
                                         dayKey: key, userId: owner,
                                         in: modelContext)
            }
            try? modelContext.save()
            ready = true
        }
    }
}

// MARK: - SymptomDayDebugHarness (v25 §36)
//
// The logger opened on a day that is NOT today, which is the whole
// capability: the day row states `yesterday`, the chips below it show
// what is on file for THAT day, and every tap writes there.
// `--debug-symptom-day` alongside opens the fourteen-day picker.
private struct SymptomDayDebugHarness: View {
    @Environment(\.modelContext) private var modelContext
    @State private var ready = false
    private let userId = "debug-symptom-sheet"

    var body: some View {
        Group {
            if ready {
                SideEffectSheet(
                    userId: userId,
                    initialDayKey: TodayStateService.dayKey(
                        for: Calendar.current.date(
                            byAdding: .day, value: -1, to: .now
                        ) ?? .now
                    ),
                    onDone: {}
                )
            } else {
                Color(Palette.bgPrimary).ignoresSafeArea()
            }
        }
        .task {
            let owner = userId
            try? modelContext.delete(model: ObservationRecord.self,
                                     where: #Predicate { $0.userId == owner })
            try? modelContext.save()
            let cal = Calendar.current
            // Yesterday carries two, so the frame shows recorded pills
            // (blush, each stating its own severity) sitting under a day
            // row that is NOT today — the state that was unreachable.
            if let yesterday = cal.date(byAdding: .day, value: -1, to: .now) {
                let key = TodayStateService.dayKey(for: yesterday)
                _ = SideEffectLog.record(.nausea, severity: .noticeable,
                                         dayKey: key, userId: owner,
                                         in: modelContext)
                _ = SideEffectLog.record(.fatigue, severity: .aTouch,
                                         dayKey: key, userId: owner,
                                         in: modelContext)
            }
            try? modelContext.save()
            ready = true
        }
    }
}

// MARK: - PASS 48 film harnesses

/// The `medOne` beat on the consult's own paper, with nothing else on
/// screen. The store is built in `.task` for the same reason the v8
/// host builds its own there: a `@State` initial value allocates and
/// discards an `OV5Store` on every parent re-render, and `@Observable`
/// deinit on the 26.2 sim is the documented abort family.
private struct V8MedListDebugHost: View {
    @State private var store: OV5Store? = nil

    private var pills: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-v8-med-list-pills")
    }
    private var fresh: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-v8-med-list-fresh")
    }
    /// `--debug-v8-med-list-beat <id>` mounts any other talk beat on the
    /// same stage. Used to prove the four RULER beats (age · height ·
    /// weight · goal) still take a horizontal drag after PASS 48 put a
    /// scroll container around the column.
    private var beatID: String {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--debug-v8-med-list-beat"),
              i + 1 < args.count else { return "medOne" }
        return args[i + 1]
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            if let store, case .talk(let beat)? = V8Script.node(for: beatID, store: store) {
                V8Stage(
                    beat: beat,
                    store: store,
                    restored: !fresh,
                    onAdvance: { _ in }
                )
            }
        }
        .environment(\.v8OnInk, false)
        .task {
            let s = OV5Store()
            s.glp1Status = "current"
            s.medRoute = pills ? "pills" : "shots"
            s.medProduct = ""
            store = s
        }
    }
}

/// The onboarding food demo alone, so the scan moment can be filmed
/// without walking act ii.
private struct OV5SnapDemoDebugHost: View {
    @State private var store: OV5Store? = nil

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            if let store {
                OV5SnapDemoScreen(store: store, onAdvance: {})
            }
        }
        .task {
            let s = OV5Store()
            if ProcessInfo.processInfo.arguments.contains("--debug-snap-demo-glp1") {
                s.glp1Status = "current"
            }
            store = s
        }
    }
}

private extension Double {
    /// Debug-route helper: 0 means "the key is absent", which is the
    /// state every goal-weight surface now distinguishes from a value.
    var nilWhenZero: Double? { self > 0 ? self : nil }
}

// MARK: - BandContendersHarness (p58)
//
// The founder asked whether one strong visual object — "perhaps a
// split donut/ring or another better solution" — could own Home's
// nutrition state. Not a spec: a question. This harness renders the
// three candidates with ONE representative mid-day state so the
// decision is made by looking, against the product's own laws
// (§9 protein leads; the count-up cohort never reads "over";
// one shape, one sentence — the p57 grammar).

private struct BandContendersHarness: View {
    // One state for all three: 1,660 of 1,473 kcal · protein 96/120 ·
    // carbs 149 g · fat 61 g (149·4 + 61·9 + 96·4 ≈ 1,529 of the
    // 1,660 — alcohol/fiber rounding keeps the remainder honest).
    private let kcalEaten = 1660
    private let kcalTarget = 1473
    private let proteinG = 96.0
    private let proteinFloor = 120.0
    private let carbsG = 149.0
    private let fatG = 61.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                panel("A · the shipped band (protein leads)") { shippedBand }
                panel("B · the split donut (macro shares)") { splitDonut }
                panel("C · the remainder-hero ring (Lose It's pattern)") { remainderHero }
            }
            .padding(24)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    private func panel(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // A — the shipped composition, verbatim proportions.
    private var shippedBand: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("protein")
                .font(.custom("DMSans-SemiBold", size: 13))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            HStack(spacing: 18) {
                ZStack {
                    JeniRing(fraction: proteinG / proteinFloor, size: 116, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("96").font(.custom("JeniHeroSerif-Regular", size: 34)).foregroundStyle(Palette.textPrimary)
                        Text("of 120 g").font(Typo.caption).foregroundStyle(Palette.cocoaTertiary)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("24 g to the floor").font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.textPrimary)
                    Text("protein first").font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textPrimary.opacity(0.55))
                }
            }
            .padding(.top, 6)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5).padding(.top, 20)
            HStack(alignment: .firstTextBaseline) {
                Text("the day").font(Typo.caption).foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text("1,660").font(.custom("JeniHeroSerif-Regular", size: 20)).monospacedDigit()
                Text("of 1,473 kcal · 187 over")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.top, 12)
            Text("carbs 149 g · fat 61 g · fiber 24 g · sugar 45 g · sodium 1,770 mg")
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 10)
        }
    }

    // B — one donut whose segments are macro calorie-shares.
    private var splitDonut: some View {
        let pk = proteinG * 4, ck = carbsG * 4, fk = fatG * 9
        let total = pk + ck + fk
        return HStack(spacing: 18) {
            ZStack {
                donutSegment(0, pk / total, Palette.roseBerry)
                donutSegment(pk / total, (pk + ck) / total, Palette.accent)
                donutSegment((pk + ck) / total, 1, Palette.roseBlush)
                VStack(spacing: 0) {
                    Text("1,660").font(.custom("JeniHeroSerif-Regular", size: 24))
                        .foregroundStyle(Palette.textPrimary)
                    Text("of 1,473").font(Typo.caption).foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .frame(width: 116, height: 116)
            VStack(alignment: .leading, spacing: 6) {
                legendRow(Palette.roseBerry, "protein", "96 g")
                legendRow(Palette.accent, "carbs", "149 g")
                legendRow(Palette.roseBlush, "fat", "61 g")
            }
        }
    }

    private func donutSegment(_ from: Double, _ to: Double, _ color: Color) -> some View {
        Circle().trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: 12))
            .rotationEffect(.degrees(-90))
            .padding(6)
    }

    private func legendRow(_ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.textPrimary)
            Text(value).font(.custom("DMSans-Regular", size: 13))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }

    // C — the remainder as the hero (Lose It's strongest pattern).
    private var remainderHero: some View {
        HStack(spacing: 18) {
            ZStack {
                JeniRing(fraction: Double(kcalEaten) / Double(kcalTarget), size: 116, lineWidth: 10)
                VStack(spacing: 0) {
                    Text("187").font(.custom("JeniHeroSerif-Regular", size: 34)).foregroundStyle(Palette.textPrimary)
                    Text("over").font(Typo.caption).foregroundStyle(Palette.cocoaTertiary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("1,660 of 1,473 kcal").font(.custom("DMSans-Medium", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                Text("protein 96 of 120 g").font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

// MARK: - BurstGalleryHarness (p64)
//
// THE DELIGHT LAYER's film harness: each cell is a mock completed
// control; tapping fires that cell's burst + the spark haptic so
// the composed event (press → state → burst → haptic) can be felt
// and filmed at each tier. The p64 bake-off ran here (fleck vs ray
// vs bloom — fleck shipped, the losers were deleted).
// `--uitest-burst-fire N` fires cell N on launch so the walker can
// film without a coordinate tap.

// p65 — the moment gallery: the ONE celebration surface at each tier,
// with realistic payloads, so the composition is designed by looking.
// `--uitest-moment N` mounts tier N directly (walker-tappable).
private struct MomentGalleryHarness: View {
    @State private var shown: Int? = {
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "--uitest-moment"),
           i + 1 < ProcessInfo.processInfo.arguments.count,
           let n = Int(ProcessInfo.processInfo.arguments[i + 1]), (0..<3).contains(n) {
            return n
        }
        return nil
    }()

    private static let payloads: [FoodModule.PlateMoment] = [
        .init(occasion: "first_plate_today", eyebrow: "on file.",
              headline: "today's first plate.", punch: "first plate",
              fact: "17 of 120 g of protein.", tier: "spark"),
        .init(occasion: "floor_crossing", eyebrow: "on file.",
              headline: "floor covered.", punch: "covered",
              fact: "23 g of protein. that's 122 of 120 g.", tier: "crest"),
        .init(occasion: "first_plate_ever", eyebrow: "on file.",
              headline: "your record starts here.", punch: "starts here",
              fact: "34 of 120 g of protein.", tier: "moment"),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 18) {
                Text("the moment gallery")
                    .font(.custom("JeniHeroSerif-Regular", size: 24))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, 60)
                ForEach(0..<3) { i in
                    Button {
                        shown = i
                    } label: {
                        Text(Self.payloads[i].tier)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Capsule().strokeBorder(
                                Palette.textPrimary.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(JKPress())
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bgPrimary.ignoresSafeArea())

            if let i = shown {
                JeniMomentView(moment: Self.payloads[i]) { shown = nil }
                    .transition(.opacity)
                    .id(i)
            }
        }
        .animation(.easeOut(duration: 0.3), value: shown)
    }
}

private struct BurstGalleryHarness: View {
    @State private var plays: [Int] = Array(repeating: 0, count: 3)

    private let cells: [(String, JeniBurst.Tier)] = [
        ("spark", .spark),
        ("crest", .crest),
        ("moment", .moment),
    ]

    var body: some View {
        VStack(spacing: 26) {
            Text("the burst gallery")
                .font(.custom("JeniHeroSerif-Regular", size: 24))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 40)
            HStack(spacing: 18) {
                ForEach(0..<3) { i in
                    cell(i)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bgPrimary.ignoresSafeArea())
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-burst-fire"),
               args.count > idx + 1, let n = Int(args[idx + 1]),
               (0..<3).contains(n) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    plays[n] += 1
                    JeniHaptic.spark()
                }
            }
        }
    }

    @ViewBuilder private func cell(_ i: Int) -> some View {
        let (label, tier) = cells[i]
        VStack(spacing: 10) {
            Button {
                plays[i] += 1
                JeniHaptic.spark()
            } label: {
                ZStack {
                    Circle()
                        .fill(Palette.textPrimary)
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textInverse)
                }
            }
            .buttonStyle(JKPress())
            .overlay {
                JeniBurst(tier: tier, play: plays[i])
                    .frame(width: 320, height: 320)
            }
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(width: 108, height: 130)
    }
}

// MARK: - WidgetGalleryHarness (p58)
//
// The widget's faces at widget geometry (iPhone 16 class: small
// 170×170, medium 364×170), on a neutral backdrop. The widget's own
// containerBackground doesn't apply outside a widget host, so the
// harness supplies the paper and the system corner mask.

private struct WidgetGalleryHarness: View {
    private func snap(
        eaten: Int = 1240, target: Int? = 1620,
        countUp: Bool = false, suppressed: Bool = false,
        protein: Int = 64, floor: Int? = 90,
        plates: Int = 3, dose: String? = nil
    ) -> JeniWidgetSnapshot {
        JeniWidgetSnapshot(
            dayKey: JeniWidgetSnapshot.dayKey(), generatedAt: .now,
            proteinEatenG: protein, proteinFloorG: floor,
            kcalEaten: eaten, kcalTarget: target, plateCount: plates,
            countUpOnly: countUp, isMaintenance: false,
            numericsSuppressed: suppressed, doseLine: dose
        )
    }

    private func face(
        _ snapshot: JeniWidgetSnapshot?, family: WidgetFamily, caption: String
    ) -> some View {
        VStack(spacing: 6) {
            JeniTodayWidgetView(
                entry: .init(date: .now, snapshot: snapshot),
                familyOverride: family
            )
                .padding(16)
                .frame(
                    width: family == .systemMedium ? 364 : 170,
                    height: 170
                )
                .background(Color(red: 0xF5 / 255, green: 0xF3 / 255, blue: 0xEF / 255))
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                face(snap(dose: nil), family: .systemSmall, caption: "small · ordinary")
                face(snap(protein: 96, floor: 90, dose: "shot today"),
                     family: .systemSmall, caption: "small · floor met + dose")
                face(snap(eaten: 2010, target: 1473, countUp: true,
                          dose: "next shot thursday"),
                     family: .systemMedium, caption: "medium · on-medication (count-up)")
                face(snap(dose: nil), family: .systemMedium, caption: "medium · ordinary")
                face(snap().freshDay(as: JeniWidgetSnapshot.dayKey()),
                     family: .systemMedium, caption: "medium · fresh day")
                face(snap(suppressed: true, dose: "shot today"),
                     family: .systemSmall, caption: "small · suppressed (no numerals)")
                face(nil, family: .systemSmall, caption: "small · begin")
            }
            .padding(24)
        }
        .background(Color(white: 0.85).ignoresSafeArea())
    }
}

// MARK: - HomeRedesignHarness (p59 — THE HOME DESIGN PASS)
//
// Materially different treatments of Home's food block, plan rows,
// dose standing and masthead, mounted with ONE representative
// mid-day state. Laws that must survive any winner: protein leads
// iff a floor exists; the energy sentence's grammar (`of 1,596 kcal
// · 356 left`, count-up, `· holding`); the rest line's drop-when-
// unmeasured; suppression = words only. Everything else is free.

private struct HomeRedesignHarness: View {
    // One state for every panel: mid-afternoon, floor not yet met,
    // three plates (two photographed, one typed).
    private let proteinEaten = 96
    private let proteinFloor = 120
    private let kcalEaten = 1_240
    private let kcalTarget = 1_596
    private let restLine = "carbs 118 g · fat 46 g · fiber 19 g · sugar 33 g · sodium 1,340 mg"

    var body: some View {
        let pageTwo = ProcessInfo.processInfo.arguments.contains("--debug-home-redesign-2")
        ScrollView {
            VStack(alignment: .leading, spacing: 44) {
                if pageTwo {
                    panel("D · the plate ledger (her record leads)") { plateLedgerConcept }
                    panel("rows · shipped vs the day objects") { rowConcepts }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-home-redesign-3") {
                    panel("dose · bare line vs the clinical object") { doseConcepts }
                    panel("masthead · capsule vs dateline") { mastheadConcepts }
                } else if ProcessInfo.processInfo.arguments.contains("--debug-home-redesign-4") {
                    // p59 second steer: kcal deprioritized under the
                    // protein dial; sugar · fiber · kcal as minis.
                    // Sugar has NO collected target (total vs added —
                    // the settled refusal) so its mini may not gauge;
                    // fiber's only denominator is the FDA DV, named.
                    panel("M1 · mini dials (numeral inside, label below)") { miniDials }
                    panel("M2 · stat columns over threads") { miniThreads }
                } else {
                    panel("A · shipped (ring 116 leads)") { shippedControl }
                    panel("B · the receipt (words lead, thread gauge)") { receiptConcept }
                    panel("C · the instrument (compact ring, words promoted)") { instrumentConcept }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.vertical, 40)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
    }

    private func panel(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: A — the shipped band, re-rendered as the control

    private var shippedControl: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("protein")
                .font(.custom("DMSans-SemiBold", size: 13))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    JeniRing(fraction: Double(proteinEaten) / Double(proteinFloor),
                             size: 116, lineWidth: 10)
                    VStack(spacing: 0) {
                        Text("\(proteinEaten)")
                            .font(.custom("JeniHeroSerif-Regular", size: 34))
                        Text("of \(proteinFloor) g")
                            .font(.custom("DMSans-Regular", size: 11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(proteinFloor - proteinEaten) g to the floor")
                        .font(.custom("DMSans-Medium", size: 15))
                        .foregroundStyle(Palette.textPrimary)
                    Text("protein first")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                .padding(.top, 20)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("the day")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(kcalEaten.formatted())
                        .font(.custom("JeniHeroSerif-Regular", size: 20))
                    Text("of \(kcalTarget.formatted()) kcal · 356 left")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
            .padding(.top, 12)
            Text(restLine)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 10)
        }
    }

    // MARK: B — THE RECEIPT: the interpreted state IS the hero;
    // the only shape is a thread of a gauge under the words.

    private var receiptConcept: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("protein")
                    .font(.custom("DMSans-SemiBold", size: 13))
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                Spacer()
                Text("\(proteinEaten) of \(proteinFloor) g")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
            (Text("\(proteinFloor - proteinEaten) g ")
                .font(.custom("JeniHeroSerif-Regular", size: 27))
             + Text("to the floor.")
                .font(.custom("JeniHeroSerif-Italic", size: 27)))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 6)
            floorThread(fraction: Double(proteinEaten) / Double(proteinFloor))
                .padding(.top, 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(kcalEaten.formatted())
                    .font(.custom("JeniHeroSerif-Regular", size: 19))
                Text("of \(kcalTarget.formatted()) kcal · 356 left")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.top, 16)
            plateStrip
                .padding(.top, 14)
            Text(restLine)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 12)
        }
    }

    /// The floor gauge as a THREAD — 3pt, blush track, rose fill,
    /// a hairline tick where the floor sits (82% of the drawn track,
    /// so landing past it is visibly legitimate, never clipped).
    private func floorThread(fraction: Double) -> some View {
        GeometryReader { geo in
            let floorX = geo.size.width * 0.82
            let fillW = max(3, floorX * min(1.25, fraction))
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.accent.opacity(0.18))
                    .frame(height: 3)
                Capsule().fill(Palette.accent)
                    .frame(width: fillW, height: 3)
                Rectangle()
                    .fill(Palette.textPrimary.opacity(0.35))
                    .frame(width: 1.2, height: 9)
                    .offset(x: floorX)
            }
            .frame(height: 9)
        }
        .frame(height: 9)
    }

    // MARK: C — THE INSTRUMENT: the ring survives at garnish size,
    // the words take the space it gives back.

    private var instrumentConcept: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("protein")
                .font(.custom("DMSans-SemiBold", size: 13))
                .foregroundStyle(Palette.textPrimary.opacity(0.55))
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    JeniRing(fraction: Double(proteinEaten) / Double(proteinFloor),
                             size: 58, lineWidth: 5)
                    Text("\(proteinEaten)")
                        .font(.custom("JeniHeroSerif-Regular", size: 19))
                }
                VStack(alignment: .leading, spacing: 2) {
                    (Text("\(proteinFloor - proteinEaten) g ")
                        .font(.custom("JeniHeroSerif-Regular", size: 22))
                     + Text("to the floor.")
                        .font(.custom("JeniHeroSerif-Italic", size: 22)))
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(proteinEaten) of \(proteinFloor) g · protein first")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(kcalEaten.formatted())
                    .font(.custom("JeniHeroSerif-Regular", size: 19))
                Text("of \(kcalTarget.formatted()) kcal · 356 left")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.top, 16)
            plateStrip
                .padding(.top, 14)
            Text(restLine)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 12)
        }
    }

    // MARK: D — THE PLATE LEDGER: her record leads, numbers follow.

    private var plateLedgerConcept: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("today, eaten")
                    .font(.custom("DMSans-SemiBold", size: 13))
                    .foregroundStyle(Palette.textPrimary.opacity(0.55))
                Spacer()
                Text("3 plates")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
            plateStrip
                .padding(.top, 10)
            (Text("\(proteinFloor - proteinEaten) g ")
                .font(.custom("JeniHeroSerif-Regular", size: 24))
             + Text("to the floor.")
                .font(.custom("JeniHeroSerif-Italic", size: 24)))
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 14)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("protein \(proteinEaten) of \(proteinFloor) g")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Text("·")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.cocoaTertiary)
                Text("\(kcalEaten.formatted()) of \(kcalTarget.formatted()) kcal · 356 left")
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 6)
            Text(restLine)
                .font(.custom("DMSans-Regular", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 10)
        }
    }

    // MARK: the plate strip (shared by B/C/D)

    private var plateStrip: some View {
        HStack(spacing: 7) {
            plateThumb(hue: 0.07)
            plateThumb(hue: 0.21)
            typedPlateSeat
            Spacer(minLength: 0)
        }
    }

    private func plateThumb(hue: CGFloat) -> some View {
        Image(uiImage: Self.stillLife(hue: hue))
            .resizable()
            .scaledToFill()
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }

    private var typedPlateSeat: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(Palette.accentSubtle.opacity(0.55))
            Image("doodle-cutlery")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .foregroundStyle(Palette.roseBerry.opacity(0.8))
        }
        .frame(width: 54, height: 54)
    }

    // MARK: minis — the deprioritized metrics under the dial (steer 4)

    /// M1 — three mini dials echoing the big one: numeral inside,
    /// word below. Sugar's seat is an ink hairline circle (a badge,
    /// not a gauge — it has no denominator to draw).
    private var miniDials: some View {
        VStack(spacing: 0) {
            ZStack {
                JeniRing(fraction: 96.0 / 120.0, size: 156, lineWidth: 15)
                VStack(spacing: 1) {
                    Text("24")
                        .font(.custom("JeniHeroSerif-Regular", size: 38))
                    Text("g to the floor")
                        .font(.custom("DMSans-Regular", size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            HStack(alignment: .top, spacing: 0) {
                miniDial(numeral: "33", meta: "g", label: "sugar", fraction: nil)
                miniDial(numeral: "19", meta: "g", label: "fiber · dv", fraction: 19.0 / 28.0)
                miniDial(numeral: "356", meta: nil, label: "kcal left", fraction: 1240.0 / 1596.0)
            }
            .padding(.top, 20)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniDial(
        numeral: String, meta: String?, label: String, fraction: Double?
    ) -> some View {
        VStack(spacing: 7) {
            ZStack {
                if let fraction {
                    JeniRing(fraction: fraction, size: 52, lineWidth: 5)
                } else {
                    Circle()
                        .strokeBorder(Palette.textPrimary.opacity(0.10),
                                      lineWidth: 1.2)
                        .frame(width: 52, height: 52)
                }
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(numeral)
                        .font(.custom("JeniHeroSerif-Regular", size: 15))
                        .monospacedDigit()
                    if let meta {
                        Text(meta)
                            .font(.custom("DMSans-Regular", size: 9))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: 40)
                .minimumScaleFactor(0.6)
            }
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// M2 — three stat columns over 3pt threads (the AX receipt's own
    /// shape family). No denominator → resting track only, the
    /// JeniMetricBar law: the column keeps its rhythm, never a gauge.
    private var miniThreads: some View {
        VStack(spacing: 0) {
            ZStack {
                JeniRing(fraction: 96.0 / 120.0, size: 156, lineWidth: 15)
                VStack(spacing: 1) {
                    Text("24")
                        .font(.custom("JeniHeroSerif-Regular", size: 38))
                    Text("g to the floor")
                        .font(.custom("DMSans-Regular", size: 11.5))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            HStack(alignment: .top, spacing: 18) {
                miniThread(numeral: "33 g", label: "sugar", fraction: nil)
                miniThread(numeral: "19 g", label: "fiber · dv", fraction: 19.0 / 28.0)
                miniThread(numeral: "356", label: "kcal left", fraction: 1240.0 / 1596.0)
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity)
    }

    private func miniThread(
        numeral: String, label: String, fraction: Double?
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundStyle(Palette.textSecondary)
            Text(numeral)
                .font(.custom("JeniHeroSerif-Regular", size: 19))
                .monospacedDigit()
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.accent.opacity(0.18)).frame(height: 3)
                if let fraction {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Palette.accent, Palette.roseBerry],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(3, 88 * min(1, fraction)), height: 3)
                }
            }
            .frame(width: 88)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: rows — shipped vs the day objects

    private var rowConcepts: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Shipped: 40pt seat, 15pt title.
            JeniTaskRow(
                title: "add a meal",
                note: "before you eat, ten seconds",
                chip: .photo(Self.stillLife(hue: 0.21)),
                onOpen: {}, onQuickMark: {}
            )
            Text("vs")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            // The day object: a 52pt seat, a 16.5pt title, air.
            dayObjectRow(
                title: "add a meal",
                note: "before you eat, ten seconds",
                image: Self.stillLife(hue: 0.21), done: false
            )
            dayObjectRow(
                title: "a short strength session",
                note: "10 minutes, muscle kept",
                doodle: "doodle-shoe", done: false
            )
            dayObjectRow(
                title: "weigh in",
                note: nil,
                doodle: "doodle-scale", done: true
            )
            // The offered row, rethought: solid hairline seat, no
            // dash, no trailing furniture — an invitation is QUIET.
            offeredObjectRow(
                title: "7,500 steps",
                note: "counted for you",
                doodle: "doodle-footprints"
            )
        }
    }

    private func dayObjectRow(
        title: String, note: String?,
        image: UIImage? = nil, doodle: String? = nil, done: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(Palette.accentSubtle.opacity(done ? 0.5 : 0.9))
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                        .opacity(done ? 0.55 : 1)
                } else if let doodle {
                    Image(doodle)
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Palette.roseBerry.opacity(done ? 0.5 : 0.9))
                }
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("DMSans-SemiBold", size: 16.5))
                    .foregroundStyle(done ? Palette.cocoaTertiary : Palette.textPrimary)
                if let note {
                    Text(note)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: Space.sm)
            ZStack {
                Circle()
                    .fill(done ? Palette.textPrimary : .clear)
                Circle()
                    .strokeBorder(Palette.textPrimary.opacity(done ? 0 : 0.18),
                                  lineWidth: 1.5)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                }
            }
            .frame(width: 26, height: 26)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bgElevated.opacity(done ? 0.55 : 1))
                .shadow(color: Palette.textPrimary.opacity(done ? 0 : 0.04),
                        radius: 10, x: 0, y: 3)
        }
    }

    private func offeredObjectRow(
        title: String, note: String?, doodle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(Palette.textPrimary.opacity(0.10), lineWidth: 1.2)
                Image(doodle)
                    .renderingMode(.template)
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Palette.textPrimary.opacity(0.4))
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("DMSans-Medium", size: 16))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                if let note {
                    Text(note)
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: Space.sm)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
    }

    // MARK: dose — bare line vs the clinical object

    private var doseConcepts: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Shipped: JeniRow — a bare text pair with a chevron.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("your shot is today")
                        .font(.custom("DMSans-Medium", size: 17))
                        .foregroundStyle(Palette.textPrimary)
                    Text("mark it when you take it")
                        .font(.custom("DMSans-Regular", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Text("vs")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            // The clinical object: an ink-register seat, same row
            // spine as the day objects, no rose anywhere.
            HStack(alignment: .center, spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(Palette.textPrimary.opacity(0.05))
                    Image(systemName: "cross.vial")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Palette.textPrimary.opacity(0.75))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("your shot is today")
                        .font(.custom("DMSans-SemiBold", size: 15.5))
                        .foregroundStyle(Palette.textPrimary)
                    Text("mark it when you take it")
                        .font(.custom("DMSans-Regular", size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: Space.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .strokeBorder(Palette.textPrimary.opacity(0.08), lineWidth: 1)
            }
        }
    }

    // MARK: masthead — capsule vs dateline

    private var mastheadConcepts: some View {
        VStack(alignment: .leading, spacing: 26) {
            // Shipped: greeting + pink capsule + gear.
            HStack(alignment: .center, spacing: Space.sm) {
                greetingText
                Spacer(minLength: Space.sm)
                Text("day 12")
                    .font(.custom("DMSans-SemiBold", size: 12))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(Capsule().fill(Palette.accentSubtle.opacity(0.55)))
                Image(systemName: "gearshape")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            Text("vs")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
            // The dateline: greeting above, the program position as a
            // set line beneath — typography carrying what a capsule
            // was carrying as furniture.
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: Space.sm) {
                    greetingText
                    Spacer(minLength: Space.sm)
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                HStack(spacing: 8) {
                    Text("DAY 12")
                        .font(.custom("Fraunces72pt-SemiBold", size: 11))
                        .tracking(1.8)
                        .foregroundStyle(Palette.textPrimary.opacity(0.65))
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(width: 22, height: 0.5)
                    Text("the steady week")
                        .font(.custom("JeniHeroSerif-Italic", size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
    }

    private var greetingText: some View {
        (Text("afternoon, ")
            .font(.custom("JeniHeroSerif-Regular", size: 24))
            .foregroundColor(Palette.textPrimary)
         + Text("maya.")
            .font(.custom("JeniHeroSerif-Italic", size: 24))
            .foregroundColor(Palette.textPrimary.opacity(0.42)))
    }

    /// A local copy of the seeder's quiet still life, small.
    static func stillLife(hue: CGFloat) -> UIImage {
        let size = CGSize(width: 300, height: 300)
        let sat: CGFloat = 0.18
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let top = UIColor(hue: hue, saturation: sat * 0.8, brightness: 0.88, alpha: 1)
            let bottom = UIColor(hue: fmod(hue + 0.04, 1), saturation: sat, brightness: 0.70, alpha: 1)
            let bg = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]
            )!
            c.drawLinearGradient(bg, start: .zero,
                                 end: CGPoint(x: 0, y: size.height), options: [])
            let plateRect = CGRect(x: 45, y: 55, width: 210, height: 190)
            c.setShadow(offset: CGSize(width: 0, height: 6), blur: 14,
                        color: UIColor.black.withAlphaComponent(0.28).cgColor)
            c.setFillColor(UIColor(white: 0.97, alpha: 1).cgColor)
            c.fillEllipse(in: plateRect)
            c.setShadow(offset: .zero, blur: 0, color: nil)
            c.setFillColor(UIColor(white: 0.92, alpha: 1).cgColor)
            c.fillEllipse(in: plateRect.insetBy(dx: 17, dy: 15))
            let f1 = UIColor(hue: fmod(hue + 0.92, 1), saturation: sat * 1.7, brightness: 0.76, alpha: 1)
            let f2 = UIColor(hue: fmod(hue + 0.10, 1), saturation: sat * 1.4, brightness: 0.70, alpha: 1)
            c.setFillColor(f1.cgColor)
            c.fillEllipse(in: CGRect(x: 85, y: 100, width: 90, height: 66))
            c.setFillColor(f2.cgColor)
            c.fillEllipse(in: CGRect(x: 140, y: 130, width: 75, height: 58))
        }
    }
}
#endif
