## Project status (2026-08-05)

**APP v11 — THE REBIRTH + v11.5 MODERNITY (feat/app-v2). SHIPPED 2026-08-05.**
**`docs/app_v11/00_REBIRTH.md` is THE LAW** (L1-L13); `01_PLAN.md` is
the plan. The founder's brief: the current app disappears; the
architecture and business logic stay; the experience is reborn in the
onboarding's design language. Executed as a **DESIGN PASS** — THE LOOP
(drive the sim → record → dump frames → compare neighbours → fix →
repeat) after every surface; per-screen gate "would Apple ship this?".
**v11.5 THE MODERNITY PASS** (`docs/app_v11/03_MODERNITY.md`, amends
the law): printed page → living surface. JeniSurface (depth without
chrome), JeniCheck (drawn check), JeniPressable, springs everywhere;
the calendar strip is a first-class selector (week paging, disc morph,
the page re-keys to the selected day); TODAY/TOOLS are soft cards;
Becoming's tiles MORPH in-tree into their pages (11 tiles incl.
calories, waist, body fat).
Shape: the editorial kit (7 primitives + motion layer) → JeniChart (one
Canvas engine, SwiftUI Charts dead) → Home from zero (MFP information
architecture: calendar strip → nutrition → TODAY → TOOLS) → Becoming
chart-driven (Apple Fitness Summary IA in paper+ink; body progress
lives HERE, not on Home; 8 provenance-backed tiles incl. fiber, sugar
intake, sodium). Next cycles: S (body scan instrument + result page),
N (Lovi-style scan chooser).

### Standing law (survives every era)

- `docs/app_v9/00_MISSION.md` — L1-L7 product laws (three-questions,
  honesty, body-privacy, passive, register).
- `docs/app_v9/04_DESIGN.md` — the design constitution (ADA bar,
  remove>add), sharpened by v11 §1+§11.
- `docs/jeni_release/00_JENI_RELEASE.md` — brand identity: the
  hand-drawn j mark, one-colour law, paper+ink palette, voice pass
  (hearts retired, dose-dot ornaments, "— jeni").
- `docs/onboarding_v7/00_DIRECTION.md` — onboarding law (persona /
  consequence / evidence / register).
- `docs/app_v8/` — the care platform (Jeni Health › Jeni Care › Jeni);
  S1-S5 shipped; internal dev alpha, test data only, NO BAA — never
  say "HIPAA compliant".
- `docs/glp1_strategy_2026_06_16.md` — cohort strategy + compliance
  floors (no drug brand names, no equivalence claims, no numeric
  weight-loss claims).
- Body privacy: never a number from a photo; BF% via provenance ladder
  only (Health reading, else Deurenberg band); scans local-first,
  backup default OFF; fasting vocabulary never renders;
  observed-never-prescribed enforced in code.

### Shipped history (one line per era; full records in git history)

| era | date | what stands |
|---|---|---|
| v10-v10.4 mirror/relaunch/instrument | 2026-08-04 | WaistCrop + BandProfile laws (§9 of v11 law), rear-camera capture, BodyScan/ modules |
| v9 BODY OS P0-P7 | 2026-08-03/04 | BodyStateService, Body Vision capture, passive weight, care summaries; 488 units |
| onboarding v7 clinical pass | 2026-08-03 | OV5Persona, question/evidence law — live |
| onboarding v6 conversion | 2026-08-02 | keep-wall trust bands, dormant real-proof — live |
| THE JENI RELEASE 1.2.0 | 2026-07-30 | brand + palette + voice — standing law above |
| v8 CARE PLATFORM S1-S5 | 2026-07-28/30 | clinic loop live on dev; pilot founder-gated |
| v7 THE CARE PLAN | 2026-07-27 | CarePlanEngine — still the day composer |
| v6 THE SIGNALS | 2026-07-17 | Signals engine + safety rules — engine law |
| v5 and earlier | 2026-07 | engines survive; layouts long superseded |

The Xcode project name + Bundle ID intentionally stay legacy
(`plankAI` / `com.bk.plankAI`) — renaming forces re-onboarding for
every TestFlight tester; a later founder-gated release handles it.

**Authoritative state doc: `/docs/STATE.md`.** Read it first.

### Auth + sync
- Anonymous-first Supabase auth, Apple + email upgrade, sign-in
  recovery, delete-account + forgot-password (anti-enumeration).
- All entity reads filter via `@Query userId` for cross-account
  isolation. Sign-out sweeps user-scoped `@AppStorage` + cancels
  retention notifications.
- Profile, session_logs, day_progress, weight_logs, session_ratings
  sync via typed Codable upserts; UUID case normalized at hydrate
  boundaries.
- Files: `PlankApp/Auth/`, `PlankApp/Sync/`,
  `Packages/PlankSync/Sources/PlankSync/`.

### Payment (RevenueCat)
- `customerInfoStream` observation. `PaymentService` re-configures on
  `auth.currentUser` changes so sign-in/out doesn't strand prior
  user's entitlement.
- THE KEEP WALL (no-trial, pay-upfront): yearly (badged, pre-selected)
  + quarterly + weekly, billed-today everywhere; v6 earned-trust bands
  + dormant real-proof slot (founder fills verbatim ASC reviews —
  never fabricate). Tier-matched downsell sheets on cancellation
  intent.
- Paywall reads RevenueCat's localized `storeProduct.localizedPriceString`
  per Apple Guideline 3.1.2(a). No hard-coded prices.
- `restore()` respects existing paid users (no re-onboarding).
- Files: `PlankApp/Payment/`, `PlankApp/Views/Paywall/`.

### Onboarding
- v5 architecture (typed state machine, 5 acts, GLP-1 branches) + v6
  conversion evolution + v7 clinical grade pass. `onboarding_version:
  v7`. Read `docs/onboarding_v7/00_DIRECTION.md` before touching.
- QA: `OnboardingV5WalkerUITests` (TEST_RUNNER_GLP1_COHORT,
  TEST_RUNNER_GENDER); StoreKit review-sheet dismissal needed on iOS
  26.2 sim; `--uitest-skip-payment`.
- Files: `PlankApp/Views/OnboardingV5/`.

### Program / plan engines
- `CarePlanEngine` composes the day (gentle tone, clinical lead
  promotions, dose day leads); `ProgramDayPrescription` beats;
  `TargetsService` + `CohortStore` single sources of truth;
  ACSM-grade pacing floors in `ProgramGoalCalculator`; never hardcode
  75 — read `plan.totalDays`.
- Medication first-class: dose day, sit-check, RegimenSheet, verb law
  (add / mark / weigh in).
- Files: `PlankApp/Program/`, `PlankApp/Views/Plan/`.

### Body Vision (BodyScan/)
- Guided on-device scans; rear camera; THE WINDOW fixed-aperture
  capture; WaistCrop (pure, tested — EXIF-normalize before crop) +
  BandProfile (per-row width → words; 3% noise floor; fuller weeks
  never scolded); BodyScanStore local-first; D3 opt-in backup.
- QA: `--uitest-open-body-scan` · `--uitest-scan-allow-manual` ·
  `--uitest-force-scan-day` · `--uitest-scan-simulate-pose` ·
  `--uitest-seed-scans`.
- Files: `PlankApp/BodyScan/`.

### Chat
- Two voices (serif letter + rose marginalia), bare-hairline composer;
  streamed heart emoji stripped by normalizer; EF
  `supabase/functions/jeni-chat`.
- Files: `PlankApp/Chat/`.

### Snap Food (food rail)
- Snap / describe / again modes; camera → vision EF (env-selected
  model; USDA calibration) → 3-slide carousel result (plate panel ·
  jeni note · share composer); PlateEditSession coherent macro↔kcal
  math; sodium/sat-fat/sugar/fiber captured end-to-end; per-ingredient
  ledger rides `food_logs.payload` jsonb.
- Files: `Packages/PlankFood/`.

### Breathwork
- Science-honest primer (cortisol mechanism, NOT fat-burn claims).
- Files: `PlankApp/Views/Welcome/Breath*`.

### Steps + health rails
- HealthKit steps (7,500 anchor), sleep, passive weight (background
  delivery + observers), VitalsService, MovementService.
- Files: `PlankApp/Health/`.

### Launch + loader
- `LaunchBackground` == `bgPrimary` — one continuous surface, no grey
  flash; AffirmationLoaderScreen.
- Files: `PlankApp/Views/Welcome/AffirmationLoaderScreen.swift`,
  `PlankApp/PlankAIApp.swift`.

### Notifications
- Trial-window anchors + daily reminder (`daily_reminder`, surgical
  pending-removal); cohort-aware variants per
  `docs/notification_system_spec_2026_06_16.md`; day-2 consent gates
  first-days pushes (v7).
- Files: `PlankApp/Notifications/`.

### GLP-1 cohort strategy
- Convergence-not-pivot; `Glp1Cohort` enum; cohort signal in the noun
  phrase; bodies reference only shipping features. See
  `docs/glp1_strategy_2026_06_16.md` for the compliance floors.

### Design system
- `PlankApp/DesignSystem/Tokens.swift` is the source of truth. Paper
  `#FCFAF7` + ink `#2A1F1E`; 8 locked tokens; `bgPrimary` is the ONLY
  background. JeniHeroSerif on heroes, Fraunces punch, DMSans body.
- v11 kit: `DesignSystem/Kit/JeniKit.swift` + `JeniMotion.swift` +
  `JeniChart*.swift` — the seven primitives + motion layer are the
  ONLY building blocks on v11 surfaces; default SwiftUI transitions
  banned there.
- Voice: lowercase casual; italic punch via `ItalicAccentText` (never
  `*markers*`); zero hearts; no em-dashes between words; never "AI"
  in user copy; "sugar intake" never "sweetness".
- `JKBorderBeam` placement law in its header (earned surfaces only).
- See `docs/THEME.md`, `docs/her75_typeface_spec_2026_06_10.md`,
  `docs/itgirl_illustration_system_2026_06_12.md`.

### Compliance + metadata
- `MARKETING_VERSION = 1.2.0`, healthcare-fitness category; privacy +
  terms at `jenifit.app`; App Store metadata in
  `docs/app_store_metadata.md`; screenshots spec in
  `docs/APP_STORE_SCREENSHOTS.md`; bundle-size plan in
  `docs/odr_migration_plan.md`.

### QA doors (most-used)
- Post-paywall: `--uitest-inapp-qa --uitest-pro-access`.
- Regimen: `--uitest-seed-regimen`, `--uitest-open-gap 0`.
- Care: `--uitest-care-connect-code`.
- Body: see Body Vision section above.
- Sim gotchas: UI legs run SOLO (unit-suite chaining drops presses);
  incremental builds can skip edits (`touch` + compile-count);
  dedicated QA sim `QA-iPhone16` UDID
  `259952D4-444F-4EFE-864A-F3DD5FBA5D22`; MainActor class deinit
  aborts on iOS 26.2 sim (use @MainActor enum services); Canvas
  animation must self-drive from `.task` phases.

### Open items
- See `TODOS.md`.
- v1.2+ Bundle ID + project rename (founder-gated).
- ElevenLabs voice clip generation pass.

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
