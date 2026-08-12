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
        if ProcessInfo.processInfo.arguments.contains("--debug-weekly-receipt") {
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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-lesson-close") {
            // v1.1.2 (2026-06-24) — preview the lesson completion
            // ink-bloom (the inkBleedReveal shader + tomorrow teaser).
            ZStack {
                Palette.programBgPrimary.ignoresSafeArea()
                CompletionBloomOverlay(
                    closingWord: "noted.",
                    subtitle: "tomorrow, the next one \u{2661}"
                )
            }
        } else if ProcessInfo.processInfo.arguments.contains("--debug-method-note") {
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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-steps-detail") {
            // v1.1.2 (2026-06-25) — preview the steps deep-read
            // (iridescent ring shader + energy/distance + week rhythm).
            StepsDetailDebugHarness()
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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-handwritten-lesson") {
            HandwrittenLessonPreviewHarness()
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
        } else if ProcessInfo.processInfo.arguments.contains("--debug-medication") {
            // Medication / hypoglycemia intake screen (case 1642, T4)
            // rendered directly for sim capture + design review. The
            // case number is set in OnboardingView's DEBUG init. Launch:
            // `xcrun simctl launch booted com.bk.plankAI --debug-medication`
            OnboardingView(onComplete: { _ in })
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

        if args.contains("--debug-method-scale") {
            i.recentLoggedDayProteins = [95, 92, 98, 91, 94]
            i.latestWeightKg = 74.4
            i.previousWeightKg = 73.2
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
        if args.contains("--debug-method-suppressed") { i.numericsSuppressed = true }
        return i
    }
}
#endif
