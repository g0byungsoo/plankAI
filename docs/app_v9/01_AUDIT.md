# app v9 — 01 THE AUDIT (verified 2026-08-03)

Six parallel read-only reconnaissance passes over the tree at
`2c7037d` (feat/app-v2, clean). Every claim below was verified with
a file anchor this session. Scale: ~342 first-party Swift files,
~126K LOC (PlankApp 260 files / ~103K; PlankFood 74 / ~19.5K;
PlankSync/Engine/Voice small). 407/407 units green per STATE.md.

## 1. What stands strong (build on, never replace)

- **The phase machine.** `AppPhaseMachine.derive` is a pure total
  function over an 11-field input (`App/AppPhase.swift:50`);
  RootView cross-fades phases; all three tabs stay mounted
  (`App/MainShell.swift:48`). New surfaces = new module cases, not
  new routing.
- **The module host pattern.** Today-screen modules are enum cases
  dispatched by one host (`Views/Today/TodayModuleHost.swift:52`,
  covers + sheets). A Body Vision module is an additive case.
- **The "one thing" spine already exists.** `day.oneThing`
  (`Program/DayModel.swift:266`) → `CarePlanEngine.Plan.lead`
  ("the day's one thing", `Program/CarePlanEngine.swift:101`) with
  a clinical promotion ladder (`:284` — rapid-loss → protein) and
  gentle-day collapse to ONE move (`:172`). The brief's "One Daily
  Focus" is a promotion of existing architecture, not new
  construction. A second, weekly-scoped one-move engine exists too:
  `CoachSummary` (`Program/Signals.swift:743`).
- **The signals culture.** Eight deterministic passive signals
  (overnight window, sleep bands, post-meal moves, rhythm, sugar
  timing, cycle season, protein pacing, BodyLine) — observed-never-
  prescribed is already engine law (`Program/Signals.swift`).
- **Camera + Vision competence, including the exact capability
  Body Vision needs.** A production body-pose stack ships today:
  `VNDetectHumanBodyPoseRequest`, 14-joint live mapping, front
  camera (`PlankApp/Camera/CameraManager.swift:146-189`) — currently
  ORPHANED (no live consumer; the plank session views are gone).
  The food camera owns a hardened still-capture core: freeze-frame,
  resume-once continuation funnel, torch/zoom, EXIF-stripped resize
  (`Packages/PlankFood/.../Capture/FoodCameraManager.swift`). A
  guided body camera is a hybrid of the two — both halves exist.
- **The photo storage + cloud-backup pattern is clonable.** Local
  store keyed by entry id + private Storage bucket `{uid}/{id}.jpg`
  under per-user RLS + persistent retry queue + re-key on sign-in
  merge (`FoodPhotoStore.swift`, `Sync/FoodPhotoSyncService.swift`,
  `scripts/food_photos_storage.sql:43`). Born from the 2026-07-25
  photos-lost-on-reinstall incident — the lesson is encoded.
- **The synced-entity seam is a documented 6-step recipe** (@Model
  + container + upsert/hydrate + AppSync pass-through + sweep +
  additive SQL) — `Packages/PlankSync/.../SyncService.swift`,
  `PlankApp/Sync/AppSync.swift:350,517,1018`.
- **Honest trend math with floors.** EMA-7 (`WeightTrendChart
  .computeEMA:117`), stall/rate/projection floors ≥3 logs
  (`Workout/WeightAnalytics.swift:46,67,118`), unit-aware narrative
  with data floors (`Program/InsightEngine.swift:170`), manual-row-
  wins-day HK reconciliation (`Health/BodyMassImportService
  .swift:124`). The honesty law has running code.
- **WeeklyReview consent mechanics.** One proposal max, keep/
  adjust/decline all recorded, provenance-gated proposals
  (`Program/WeeklyReview.swift:83,165,227`) — the consent grammar a
  weekly body review needs.
- **The B2B loop is real and server-enforced.** RPC-only clinician
  access, 3 consent scopes + lookback, append-only audit, F1
  masking server-side; dashboard + site + demo tenant + ops set
  (S4/S5 migrations; `clinic/src/`). And a ready-made unused seam:
  `care_get_patient_series` (S4:1093) computes dose/sit/hydration/
  weight series — **zero consumers today**.
- **Design system depth.** ~40 JK components, three Metal shaders,
  a motion token set incl. `trendDrawIn`, the museum-hung story
  frame, and a full plate-photo-as-art stack (cover art, day-
  grouped gallery, strips — `Views/Becoming/BecomingView.swift:514`,
  `JourneyPlatesPage.swift`, `Kit/JKGallery.swift`) that a body
  timeline reuses wholesale.
- **Verification culture.** 407 units, per-cohort walker legs,
  recorded frame review, a11y floors as tested law, erased-sim
  rituals. v9 inherits the bar.

## 2. The honest gaps (numbered; the plan cites these)

- **W1 — "Am I changing?" is answered by the scale alone, and only
  if she types.** The single outcome surface is the weight EMA,
  rendered once, in Becoming page 1 (`BecomingView.swift:1275`);
  Home shows no trend at all (verified). Every floor is
  self-report-gated: <2 logs = no line, <3 = no verdict; an
  un-logged week reads "a quiet week. nothing logged."
  (`WeeklyReview.swift:325`). Diligence, not her body, drives the
  verdict.
- **W2 — No visual body evidence exists anywhere.** Zero progress
  photos, zero measurements, zero body-composition capture
  (exhaustive search confirmed). The Becoming cover hero is her
  *plate*, not her. The one body-composition read (HK bodyFat/lean
  mass) renders as a single text line (`BecomingView.swift:1251`).
- **W3 — Passive weight is dead code.** `BodyMassImportService
  .importIfEnabled` is defined and **called nowhere**
  (`Health/BodyMassImportService.swift:81`); the service is absent
  from the launch bootstrap (`PlankAIApp.swift:2564-2574`); the
  onboarding bodyMass grant (`OV5ScreensClose.swift:321`) triggers
  no import and never sets the flag — the grant is wasted and
  Settings still says "connect." New scale weigh-ins never flow in.
- **W4 — No true passive ingestion.** `enableBackgroundDelivery`
  is never called; only Steps has a foreground observer
  (`StepsService.swift:304-317`). Sleep/vitals/cycle/body-mass
  refresh only on view-appear or launch. "Data lands without
  opening the app" is not achievable today.
- **W5 — HealthKit scope ≠ permission story, and five reads are
  dead.** The share sheet silently requests 8 vitals types beyond
  the three the usage string names (`Info.plist:50` names steps/
  weigh-ins/sleep; `StepsService.swift:159` unions vitals; cycle
  adds menstrualFlow). HRV, VO2max, respiratory rate, and both BP
  types are read into memory and rendered **nowhere**
  (`VitalsService.swift:134-156`). Trust + App Review exposure.
  The string also still says "JeniFit" — a brand-sweep straggler.
- **W6 — Missing passive streams the brief names.** Workouts,
  active energy, and walking distance are never referenced; waist
  circumference never read. No HKWorkout awareness means no
  strength-training signal for any muscle-preservation story.
- **W7 — Body state is fragmented across five stores with no
  aggregate.** Weight in SwiftData, vitals/sleep/cycle/steps in
  four independent HK singletons, typed observations in
  ObservationStore; `TodaySnapshot` hand-stitches ~25 fields per
  pass (`Program/TodayStateService.swift:18-88`). There is no
  BodyStateService; a longitudinal body model has nowhere to live.
- **W8 — The food→body link is thin and one-directional.** Only
  `BodyLine` (juxtaposition, only when the trend already eased —
  `Signals.swift:659-698`) and kcal/protein-only `InsightEngine`.
  Sodium — cited in copy as *the* scale-swing mechanism
  (`InsightEngine.swift:211`) — is returned by no EF, persisted
  nowhere, and renders as a dead "—" cell (`NutrientGrid.swift:83`).
  Sugar + per-ingredient detail live only in device-local JSONL,
  invisible to any future explanation layer (`FoodLogPersister
  .swift:107,210`). No weekly food-quality aggregation exists.
- **W9 — The engine has no body-outcome axis.** `CarePlanEngine
  .Input` (`CarePlanEngine.swift:33-66`) carries zero body-
  measurement/scan/composition fields; promotion priorities are
  protein-only; 7 of 8 signals are intake/timing. Two "one-thing"
  engines (daily lead vs weekly CoachSummary) run un-unified.
- **W10 — B2B has no longitudinal substrate, and the consent
  posture forecloses monitoring.** `visit_packets` is one
  overwritten row per patient+org (`Care/VisitPacketPublisher
  .swift:89`) — no history, no rollup, no adherence series;
  `needs_attention` is a generated-question proxy (S4:953). The
  shipped promise "nothing is watched in real time"
  (`CareConnectionSheet.swift:244`) means a dropout-risk dashboard
  needs a new consent scope + reframe, not just a screen.

## 3. Latent assets (already paid for, currently idle)

- The orphaned pose camera (`PlankApp/Camera/CameraManager.swift`)
  — salvage into Body Vision guidance, then retire per dead-code
  law.
- `care_get_patient_series` — the unconsumed clinician trend RPC.
- Dormant EF skeletons: `nutrition-lookup` (USDA/OFF server cache —
  the sodium fix) and `food-photo-cleanup` (retention cron — the
  body-scan retention template).
- HK bodyFat/leanMass reads already flowing (when her scale writes
  them) — a real body-composition source with provenance, unused as
  a story.
- `ObservationRecord.source` already admits `"photo"`
  (`PlankSync/Models.swift:561`) — the chart anticipated this.
- The migration-moment pattern (`Views/Migration/
  MigrationMomentView.swift`) — the shipped way to introduce v9 to
  existing users.
- `FoodFlags`' 3-layer flag stack (debug override → entitlement →
  PostHog rollout, `Packages/PlankFood/.../FoodFlags.swift:17-76`)
  — the rollout mechanism for every v9 surface.

## 4. Trust/compliance findings to fix regardless of v9

- Usage-string scope mismatch + "JeniFit" brand straggler in both
  health strings (`Info.plist:50,52`) — W5.
- Sensitive reads with no rendered surface (HRV/VO2max/RR/BP) — L5
  violation; drop or render (D5).
- `PrivacyInfo.xcprivacy` will need new data categories the moment
  scans ship; camera usage string must honestly cover body capture
  (it currently covers plank form + meal scan only).

## 5. Engineering-health notes (opportunistic, not v9-gating)

- `PlankAIApp.swift` is 3,262 lines (~380 = DEBUG harness switch)
  — mechanical decomposition candidate during P7.
- Food @Models declared but deliberately unregistered (JSONL is
  the real store) — fine, but any server-visible explanation layer
  needs the sync gaps in W8 closed first.
- AppStorage isolation is sweep-list-by-hand (`AppSync
  .swift:1083-1218`) with a documented history of leaks; every v9
  key must join the sweep in the same commit (L4).

## 6. Today's surfaces vs the three questions

| Surface | Am I changing? | Why? | What next? |
|---|---|---|---|
| Home checklist + rail | — | — | strong (lead/one-thing) |
| TodayStateBand rings | weak (process, not outcome) | — | weak |
| Signals band | — | partial (habit receipts) | — |
| Becoming trend page | **the only real yes** (gated) | — | — |
| Becoming signal pages | — | partial (juxtaposition) | — |
| Jeni's read + WeeklyReview | weak | partial | one weekly move |
| Chat | — | on request | on request |
| Snap results | — | plate-level only | room-today only |
| Visit packet | 28-day snapshot | partial | — |
| Breath / lessons / method | — | — | supports (kept: engagement data) |

The center of gravity sits in the right column. v9's work is to
give the left column a home worth opening the app for — and wire
the middle column to real mechanisms.
