## Project status (2026-05-08)

The product ships as **JeniFit** for v1.0. The Xcode project name + Bundle ID
intentionally stay legacy (`plankAI` / `com.bk.plankAI`) — renaming those forces
a re-onboarding for every TestFlight tester and a re-submission run through
App Review. v1.1 handles the project + Bundle + SKU rename together.

JeniFit rebrand (Phases 1–13) shipped end-to-end and was followed by extensive
v1 polish + accessibility + research-led depth. Code-level smoke test passes
(zero user-visible `AI` / `absmaxxing` / `Sarah` / `plankAI` matches in Swift
strings; the few remaining are code comments preserving rebrand history or
internal identifiers tracked in TODOS.md for the v1.1 SKU + Bundle rename).

- **Auth + sync**: functional end-to-end. Anonymous-first Supabase auth, Apple + email
  upgrade, sign-in recovery. Profile + session_logs + day_progress + weight_logs
  + session_ratings sync via typed Codable upserts; cross-account isolation
  enforced via @Query userId filters; UUID case normalized at hydrate boundaries.
- **Auth UX (Phases A-F)**: shipped. Delete Account, Forgot Password (anti-
  enumeration), polished sign-up + sign-in, unified friendly error copy,
  PulsingDots loading, ShakeEffect on submission errors.
- **Payment (RevenueCat)**: customerInfoStream observation, auth-state sync,
  paywall with bodyFocus-personalized headline. **Phase F shipped**:
  `TrialEndNotificationService.scheduleIfNeeded` wired into
  `PaymentService.reconcileTrialReminder` (24h before yearly renew, idempotent,
  cancelled when trial state changes).
- **Onboarding**: Phase 4 rewrote the question set into 6 parts. Phase 5 added
  prediction + loading carousel + plan reveal. Phases 6/7/8 redid home/paywall/
  settings + auth. Phase 9 renamed the trainer system Sarah → Jeni. Phase 13
  removed the dead in-flow paywall (case 24); post-onboarding paywall lives on
  RootView's fullScreenCover.
- **Workout engine (rules-doc compliant)**: source of truth at
  `docs/workout_session_rules.md`. Position-block ordering (standing →
  quadruped → plank → prone → sideLying → supine → seated), same-area
  secondary sort, family clustering, block-repeat for ≥15-min sessions
  ("Round 1 / Round 2" — Pamela Reif convention), exercise-aware rest mini-
  factor (impact/type/difficulty layered on goal/tier/pace base), duration
  grid {30..60}, rest grid {5..20}, difficulty floor + cap per tier, side-
  lying L/R batching. 5 DEBUG validators prevent regression. XCTest target
  shipped via `Scripts/add_test_target.rb` (uses `xcodeproj` Ruby gem); 29
  tests cover Weight (Unit + Analytics), StreakCalculator, WorkoutGenerator
  parameter grid + edge cases. `validatePositionFlow` was round-blind and
  over-applied to warmup/cooldown — both fixed (per (category, round) walk;
  scoped to `.main` only per rules §2.1).
- **Voice cascade (rules §7)**: switch-side detection on unilateral L→R hops,
  window-aware variant selection (`prep_full` ≥12s, `prep_short` 6–11s, silent
  ≤5s), VM fires cue early enough to fit the chosen variant — voice never gets
  cut. BGM ducks under voice. TSV-driven generation script ready for ElevenLabs
  run (384 prep_short + 384 prep_full + 6 switch_sides clips) at
  `Scripts/generate_voice_clips.sh`. Matson display-renamed to "Sam"
  (asset prefix `matson_` stays internal until next ElevenLabs pass).
- **Becoming tab (was "past")**: research-led modules pulling only from
  collected data — identity hero (Q140 + Q111), WHO Activity Ring with
  adaptive 90-min target for low-baseline users, Weight Trend EMA (Helander
  2014), Goal Pace Projection (ACSM 0.5–1%/wk overlay, Wing & Phelan 2005
  10% cap), BMI card (AHA 2021 banding, anti-shame caption), Barrier-
  Resolved Card (Rhodes & de Bruijn 2013, counter per stated barrier),
  plank Mastery Curve (Bandura/Annesi 2011), adaptive home subtitle
  (barrier/experience tagged). First-session hint replaces binary empty-state.
- **Plank check-in screen**: research-led brief — McGill Waterloo norms,
  Biering-Sørensen 1984 LBP threshold, "what your time means" reference
  table, last-hold pill with bucket label, position-aware setup cue.
- **Weight features**: kg storage canonical, lb-default display via
  `WeightUnit`, kg/lb toggle pill, **one-per-day policy** (update-in-place
  on same-day re-log per Helander 2014 + Pacanowski 2014), seed first
  weight log at onboarding completion (was lazy/wrong-dated pre-fix).
  Schema `weight_logs` GRANT fix in `scripts/schema.sql`.
- **Design system**:
  - **Motion tokens** in `DesignSystem/Tokens.swift`: `entrance` (0.55s),
    `entranceSoft` (0.42s), `exit` (0.32s), `crossFade` (0.45s easeInOut),
    `tap` (0.16s), `gentleSpring` (response 0.55, damping 0.88),
    `stagger` (0.10s), `breathing` (1.6s). ~100 of 180 sites migrated;
    remaining are intentional bespoke set-pieces (celebration springs,
    fireworks, magical-loading typewriter).
  - **Scrapbook chrome** (24pt corners, 1.5pt accent border, hard offset
    shadow) on Home, all 6 Settings sub-pages, Becoming tab modules,
    Browse, PreSession, LogWeightSheet, PostSession, PostRoutine.
  - **JeniFit voice signal**: italic Fraunces on the punch word (`*becoming*`,
    `*today*`, `*shows up*`) — applied via `ItalicAccentText` or per-Text
    custom-font swap. Lowercase casual copy throughout, no AI language.
- **Accessibility (4 passes shipped)**:
  - `accessibilityLabel` on every icon-only button (close X, refresh shuffle,
    eye toggle, mute, end-workout, etc.) — 17 sites total.
  - `accessibilityHidden(true)` on 14 inline decorative sticker overlays.
  - `tappableArea(_)` extension on 11 buttons that visually sit at 30–32pt —
    HIG-compliant 44pt hit area without changing chrome.
  - Reduce-motion gates on HomeView animateIn (snap to final), refresh icon
    rotation skip, AnalyticsView 9-section cascade, ChangeTrainerView
    cascade, BrowseWorkoutsView swell.
  - Dynamic Type via `Font.custom(_:size:relativeTo:)` for every Typo token,
    plus `dynamicTypeSize(...accessibility1)` clamps on hero numerics
    (88pt timer, 64pt weight digit, 64pt onboarding analyzing %).
  - WCAG AA palette darkenings: `textSecondary` `#8E6D6D` → `#7B5959`
    (4.31 → 5.76:1), `stateGood` sage → `#5F7345` (2.32 → 4.89:1),
    `stateWarn` amber → `#8D6A2E` (2.12 → 4.65:1).
  - VoiceOver compound-view grouping via `accessibilityElement(children: .combine)`
    on 5 row types — barrier rows, hero stats, BMI card (custom label),
    bucket rows, setup rows, exercise rows.
- **Self-check harness** (DEBUG-only, detached at launch): three modules with
  scenario coverage — `WorkoutGeneratorSelfCheck` (~112 generations across
  tier × length × bodyFocus + edge cases + validators), `StreakCalculatorSelfCheck`
  (9 freeze-logic scenarios), `WeightSelfCheck` (kg↔lb conversion round-trips
  + WeightAnalytics goal-progress capping). Migrate to XCTest when a test
  target lands; each scenario is already a standalone function.
- **Notification scheduling unified**: both onboarding completion and
  Settings tab route through `NotificationPermission.scheduleDailyReminder`
  (canonical id `daily_reminder`, voice-adaptive body, surgical pending-removal
  so trial-end notification isn't nuked). Three silent bugs fixed:
  duplicate identifiers, pre-rebrand "Time to plank" copy, blanket
  `removeAllPendingNotificationRequests()`.
- **Pre-TestFlight metadata**: `MARKETING_VERSION = 1.0.0`,
  `CFBundleDisplayName = JeniFit`,
  `LSApplicationCategoryType = public.app-category.healthcare-fitness`,
  `NSCameraUsageDescription` rewritten anti-AI + on-device privacy
  disclosure. DebugAuthView verified release-safe.
- **Privacy + Terms + App Store metadata drafts** at `docs/privacy_policy.md`
  + `docs/terms_of_service.md` + `docs/app_store_metadata.md`. All grounded
  in the real data flow (Supabase + RevenueCat + Apple + APNs, no analytics
  trackers).
- **Pre-TestFlight cleanup pass**: FeedbackView wired to `support@jenifit.app`
  via mailto handoff (was a fake-submit). PostSessionView dead share button
  replaced with SwiftUI `ShareLink`. 26 production-path `print()` calls
  wrapped in `#if DEBUG` (was leaking user UUIDs + payment IDs to Console.app
  on TestFlight builds) — across PlankAIApp, AuthService, AppSync,
  PaymentService, TrialEndNotificationService, HomeView, SignInPromptView,
  PaywallView, BackgroundMusicService, AccountView. Email standardized
  (`hello@` → `support@jenifit.app`). 4 dead `@State` vars + 2 orphan Shape
  structs removed. `UIImage(named:)` existence checks moved off the
  body-recompute path (PhotoSlot caches at init; 3 OnboardingView inline
  sites switched to direct `Image()`).
- **Asset binary dedup**: 26MB saved (62MB → 36MB, 42% reduction) via
  `Scripts/dedupe_imagesets.sh`. 11 social/logo + 3 coach imagesets shipped
  byte-identical @1x/@2x/@3x copies; collapsed to single @3x where safe
  (kept @1x on coaches — see TODOS for the @1x mismatch decision).
- **Open items**: see TODOS.md "Pre-TestFlight blockers" — almost entirely
  user-handled now (privacy/terms hosting, screenshots, banking, mailbox).
  Claude-actionable remainders: Phase G physical-device smoke test, run
  ElevenLabs script, visual position-block validation, decide on coach @1x
  slot.

## Skill routing

When the user's request matches an available skill, ALWAYS invoke it using the Skill
tool as your FIRST action. Do NOT answer directly, do NOT use other tools first.
The skill has specialized workflows that produce better results than ad-hoc answers.

Key routing rules:
- Product ideas, "is this worth building", brainstorming → invoke office-hours
- Bugs, errors, "why is this broken", 500 errors → invoke investigate
- Ship, deploy, push, create PR → invoke ship
- QA, test the site, find bugs → invoke qa
- Code review, check my diff → invoke review
- Update docs after shipping → invoke document-release
- Weekly retro → invoke retro
- Design system, brand → invoke design-consultation
- Visual audit, design polish → invoke design-review
- Architecture review → invoke plan-eng-review
- Save progress, checkpoint, resume → invoke checkpoint
- Code quality, health check → invoke health
