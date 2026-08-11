## Project status (2026-08-11)

**APP v25 E3 — ONE JENI (feat/app-v2). BUILT 2026-08-11; rides the
same RC 1.2.0 (30). NO migration.**
`docs/app_v25/11_E3_DECISION.md` is why this era REPLACED the
roadmap's movement era; `12_E3_ONE_JENI.md` the law;
`13_E3_EVIDENCE.md` the loop's record + founder gates. **The decision
turned on one number: 82% of everyone who finishes onboarding has
exactly ONE active day (28 of 2,237 ever reach a second week), so
every mechanic five eras shipped speaks only to a tail that barely
exists.** Bloom (arXiv 2510.05449, RCT N=54) supplied the mechanism:
5.6× app time for an LLM with tool access to the user's own data,
write access to the structured plan, and memory — and its lesson that
users named *plans, not chat*. So: the coach can READ her record
(`JeniReadTools`, 8 lookups over the SAME engines the surfaces
render from; honest emptiness — an unlogged day is "not logged",
never zero; suppression + never-brand hold) → REMEMBER what she is
told (`JeniMemoryRecord` + `MemoryGuard` refusing doses/diagnoses/
symptoms/body judgements at the door; written only through a card;
`what jeni remembers` in settings with per-row forget) → CHANGE THE
PLAN IN WORDS (`propose_program_fact` through `ProgramFactStore`:
chat writes `preferred` only, a **prescribed head REFUSES** and
routes, the clamped value is what gets acknowledged) — all through
the same chokepoints as the weekly read. THE TOOL LOOP was the
structural fix: `ChatSession` used to run a tool and stop, so a
read's result could never reach the model. Tools now live
CLIENT-side (`JeniToolCatalog`, allowlisted server-side) — the last
jeni-chat deploy a tool addition needs. **The 08-10 unisex sweep
missed both EF prompts** ("a program for women", "serving gen-z
women"); rewritten, plus the CA/IL/TX identity line ("jeni is a
digital coach. not a person, not your clinician."). 809/809 (+26,
zero regressions); the compounding loop FILMED (a sentence in chat →
Today composes "6,000 steps"); 6 frame-caught fixes. Doors:
--uitest-chat-read · --uitest-chat-propose · --uitest-chat-auto-
confirm · --debug-jeni-memory · --uitest-seed-memory. Founder gates:
**deploy jeni-chat AND food-vision** (the prompt still says "gen-z
women" in production until then) + the standing migrations/merge.
Movement (old E3) and the workout-library kill are DEFERRED, not
cancelled; the method library is NOT killed (132 post-onboarding
openers make it the #2 activity — the audit's REMOVE line was about
the literature, not this corpus).

**APP v25 E2 — THE MEDICATED YEAR (feat/app-v2). BUILT 2026-08-10;
RC 1.2.0 (30) — lands WITH the main-merge release, not behind it.**
`docs/app_v25/08_E2_BRIEF.md` the mandate; `09_E2_MEDICATED_YEAR.md`
the architecture + 10 recon corrections; `10_E2_EVIDENCE.md` the
loop's record + founder gates. The medication platform became part
of the adaptive intelligence: COHORT IDENTITY as PostHog person
properties + the dark v24/E1 events wired + AnalyticsHygiene
allowlist-as-mechanism (the kill/redirect trigger: medicated share
readable post-release) → THE CYCLE (`CyclePosition`: event-anchored
day 1..7, open slot outranks the rhythm, zero daily/non-med leakage)
→ LABEL FACTS on `MedicationCatalog` (7 products verbatim vs
2025/26 FDA PIs, per-label frames, compounded = no-label truth,
routing always closes) → the late door WIRED (openLateSlot → Today
support row + DoseSheet late face + label card; tap/quick-mark/
evening-yes converge on THE SLOT) → food noise + underreported
symptoms (hair/menstrual/cold/mood; mood = 988 support FIRST;
severity re-record fixed) → `foodNoiseReturn` signature observation
(≥3 cycles, 2-day cluster) → WEIGHT INTELLIGENCE
(`WeightWeekReadEngine`: time-aware EMA τ9.5d, clamp, unit-error
rejection, ±0.25%BM/wk band, sufficiency ladder) → THE READ GROWS UP
(dose-week story + weight signal in the band + cycle/era/plateau
teachings under offer-first precedence; richer never longer) → Today
reasons with the cycle ("your dose day. the week starts here";
late-cycle appetite named; evening ask scoped to open-dose evenings)
→ chat one-jeni (cycle_day/basis + open_dose_slot + week{} envelope;
EF cycle rule — founder deploys) → VisitPacket reads the real
symptom timeline → `SnapRefineMerge` correction-scope guard (the
SnappyMeal ablation defense) + FoodCorrectionSheet swept. 783/783
app + 113/113 package (+74/+7, zero regressions); films
frame-inspected (5 frame-caught fixes). NO new migration. Doors:
--uitest-seed-medication late · --uitest-open-side-effects ·
--uitest-expand-mood. Founder gates (10_E2 §5): v24+E1 migrations ·
jeni-chat deploy · key rotation · archive/TestFlight 1.2.0(30) ·
merge feat/app-v2→main · device walk · post-release PostHog read of
the medicated share (kill/redirect).

**APP v25 — THE SYSTEM (feat/app-v2). E1 THE SPINE SHIPPED 2026-08-10.**
`docs/app_v25/00_THE_SYSTEM.md` is the MASTER PRODUCT PLAN (the law
for eras E1-E7); `05_E1_SPINE.md` the build architecture;
`06_E1_EVIDENCE.md` the loop's record. E1 shipped ONE PROGRAM WITH
MEMORY: program_facts authority chains (prescribed › preferred ›
recommended › defaulted; consent-gated recommendations; iOS never
writes prescribed; prescription end RESUMES preference) through
`ProgramFactStore` (the RegimenService law generalized; v4 knobs
write-through) → THE WEEKLY READ (ReSigningView/WeeklyReview
EVOLVED: anchor ladder preference › dose-day › enrollment, composer
signals vs her own usual, v4 rules lead the ONE offer, step-goal
recalc + logging lighten join, 14-day cooldowns) → THE WALKING
ACTION (AdaptiveStepsEngine 60th-percentile-of-own-days; composes
only with a consented goal; "2,100 steps left"; HK workouts absorb;
resolved-goal auto-complete) → THE NOTIFICATION BRAIN (veto arbiter:
≤5/wk hard budget, same-id replaces free, medication exempt from
everything, auto-silence + engagement reset, FNV holdouts) →
lifecycle telemetry (categorical only). 709/709 (+122, zero
regressions); the loop FILMED: read → "let's try it" → fact →
relaunch → Today "0 of 3" with the walk row → survives again.
Doors: --uitest-force-read-day · --uitest-walk-read(-decline) ·
--uitest-read-prefer-steps · --uitest-force-hour N ·
--uitest-steps-today N. Founder gates: apply 20260810090000
migration (stacks after v24's) · device walk · teaching-lines voice
pass. Next eras per 00_THE_SYSTEM §15: E2 THE MEDICATED YEAR → E3
KEEP WHAT YOU BUILT → E4 THE PLATE'S MEMORY → E5 THE DISPERSAL → E6
THE QUEUE → E7 THE GLANCE.

**APP v24 — THE REGIMEN (feat/app-v2). SHIPPED 2026-08-09.**
`docs/app_v24/00_REGIMEN.md` is the law; `01_EVIDENCE.md` the
loop's record. The medication experience rebuilt as a PLATFORM
(MeAgain + Shotsy studied, nothing copied): MedicationCatalog
(9 products; new med = one entry) → RegimenPlanRecord as
append-only VERSION CHAINS (`applySelfRegimen` chokepoint;
supersede never mutate) → DoseEventRecord (deterministic per-slot
ids; every surface converges) → symptoms on the chart. Engines:
schedule (wall clock, DST-safe, weekly late window), rotation
(suggests, never insists), patterns (timing-never-causality;
"picked up after the dose changed"), reminders (FIRST actionable
category: taken / in an hour / log later; never named; survives
breaks). THE DOSE SHEET (site cells pre-selected by rotation, ink
mark, skip reasons, late + oral faces); daily cadence rides as
support OUTSIDE the cap (never dominates); 4 consult beats for
current cohort (clinic door skips all); THE REGIMEN home (facts as
doors + THE RECORD eras + side-effect logger); becoming tile
(tally strip + DOSE ERAS ledger); chat envelope medication{}.
587/587 units; consult walker green. Doors:
--uitest-seed-medication <injectable|oral|b2b|history> ·
--uitest-open-dose-sheet · --uitest-walk-medication. Founder
gates: apply 20260809090000 migration · deploy jeni-chat EF ·
device walk. Tradeoffs (law §11): no PK curve, no site photo, no
lock-screen skip, era ledger over annotated curve.

**APP v23 — THE STILL LIFE (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v23/00_STILL_LIFE.md` is the law; `01_EVIDENCE.md` the
loop's record. The food experience reborn from zero: one material
story (glass → understanding → paper → book). THE DIAL (SnapDial —
morphing hairline plate, the reading closes the circle) replaced
brackets+sweep; full-bleed IMMERSION shipped; barcode (live VN +
OpenFoodFacts by code) + label (EF text-hint, zero deploy) modes;
THE READING is ONE page (carousel dead, Result/ subtree deleted,
"add it", no scores); THE BOOK (day spreads, photos lead, month
seams, week read, relog re-homed). PlankFoodTests run via the
package scheme (106/106 — palette pins finally execute); app
557/557. Doors: --food-debug-mode · --uitest-seed-week ·
--uitest-walk-book. Queued: chip→row flash, plate page = reading
read mode, filing beat, device walk, XXXL floors.

**APP v22 — ONE HAND, first pass (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v22/00_ONE_HAND.md` is the law: consistency gate, THE
MODULE CONTRACT (B2C/B2B by composition, never forks), propagation
map, THE METHOD rethink (ONE IDEA ONE ACT cards — design bound,
build queued). Shipped: THE FOOD EXPERIENCE — FoodTheme palette came
home (it had drifted a full era; PlankFoodTests isn't in the scheme,
so its pins never ran), plain scan captions + halved sweep + "add it
before you eat", SnapUnderstandingChips (real items land on the
photo — honest theater), protein floor bar + plate split on the
result, sage/amber retired, last heart died. testGrantCameraOnce
primer (sim ignores simctl camera grants). Queued: body motion pass,
moments/chat/settings sweeps, METHOD slice, journal sweep, B2B
registry surfacing.

**APP v21 — THE INSTRUMENT (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v21/00_INSTRUMENT.md` + `01_EVIDENCE.md`. The founder's
product redesign after the v13-v20 refinement line (those eras live
in the design law's migration log): the app surfaces communicate
VISUALLY first — the rose ramp became the data language (blush ·
dusty · berry; quantities fill rose, trajectories draw ink,
selection stays ink; clinical stays unadorned); Home = one-line
header + the five-face HERO CAROUSEL (ring with counted numeral
inside) + JeniTaskRow checklist objects (real plate photo chips) +
JeniToolTile destinations with live instruments + the close as a
row; Becoming = numeral-first body card, scope-bar-as-header, rose
tile faces, five-breath detail reveal. 557/557 units; anatomy +
zero-data + gallery legs solo green; XXXL floors walked. New door:
--uitest-walk-carousel. Gotchas: a stale TEST BUNDLE lies (rm the
runner + build-for-testing + watch Compiling); iOS launch snapshots
impersonate the old build after reinstall — wait past the cold
start before judging a capture.

**APP v12 — THE CRAFT PASS (feat/app-v2). SHIPPED 2026-08-07.**
`docs/app_v12/00_CRAFT.md` + `01_EVIDENCE.md`. Architecture
untouched; presentation 100×: the glance layer
(JeniGlance: ring · metric bar · week dots · scope bar · insight
pager + the visibility gate), the chart-craft maturation in
JeniChart (smooth monotone lines, grounded bars, emphasized today;
JeniRibbon/JeniPillBars deleted), Home's nutrition centerpiece
(landed plates MORPH the numeral+ring forward), the living greeting,
tools-as-destinations, directional recap, Becoming's time scopes
(morph never reload) + real mini-chart faces + the weekly insight
carousel (R6 grammar) + deepened detail pages (ledger · WHAT THE
PLAN DOES · provenance), care-first Becoming for clinic patients,
and the evening close's 96pt hero numeral. Film doors:
--debug-gallery-tour · --uitest-walk-strip · --uitest-walk-scope ·
--uitest-open-tile · --uitest-mark-lead · --uitest-land-plate ·
--uitest-care-mode. Synthesized XCUI drags can't scroll the iOS 26.2
sim (probe-proven) — tours film what walkers cannot.

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
- **`docs/design/00_JENI_DESIGN_LANGUAGE.md` IS THE DESIGN LAW**
  (canonical, 2026-08-06). Philosophy, typography, motion,
  transitions, interaction, haptics, layout, spacing, components,
  animation rules, a11y, copywriting (B2C + B2B), never-do list, and
  good/bad examples. Read it before touching ANY surface. It
  supersedes older design docs where they conflict. The v8 onboarding
  (`docs/onboarding_v8/`) is its reference implementation.
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
