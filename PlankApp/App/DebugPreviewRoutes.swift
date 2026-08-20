#if DEBUG
import SwiftUI
import SwiftData
import PlankFood
import PlankSync
import PhotosUI

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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-sleep-preview") {
            SleepCardPreviewHarness()
        } else if ProcessInfo.processInfo.arguments.contains("--debug-sleep-preview-empty") {
            SleepCardEmptyStatesHarness()
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
#endif
