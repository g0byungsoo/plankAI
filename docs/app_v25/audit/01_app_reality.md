# APP REALITY AUDIT — v25 input (2026-08-10)

Code-derived inventory of what is implemented AND reachable. Sources: pure reading of
`PlankApp/`, `Packages/`, `supabase/`, git log. No builds. Verdicts: **LIVE** (reachable in
shipping Release UI) / **GATED** (flag / cohort / QA door / founder gate) / **VESTIGIAL**
(compiles, unreachable or superseded).

Scale: ~136k lines of Swift across PlankApp + PlankFood + PlankSync sources. 52 unit-test
files (`plankAITests/`), 6 UI walker files (`plankAIUITests/`). Shipping version in pbxproj:
**1.1.7 (28)**.

---

## ROOT COMPOSITION / APP PHASES

- Entry: `PlankApp/PlankAIApp.swift:504-525` — window mounts `DebugPreviewRoutes` in DEBUG
  (harness router, `App/DebugPreviewRoutes.swift:15-408`, final else = real app) or
  `RootView` in Release.
- `RootView` (`PlankAIApp.swift:1586`) derives phase each body pass via pure
  `AppPhaseMachine.derive` (`App/AppPhase.swift:55-94`), table-tested in `AppPhaseTests`.
- Phases (`AppPhase.swift:15-29`) and gates:
  - `.booting` — until `auth.isReady` + 1.8s loader hold (+ entitlement stream ready unless
    care-entitled). Renders `AffirmationLoaderScreen` (`PlankAIApp.swift:1652`).
  - `.onboarding` — `!hasCompletedOnboarding`. Renders **OnboardingV8Flow**
    (`PlankAIApp.swift:1673`); `--onboarding-v4` / `--onboarding-v5` DEBUG escapes to legacy
    flows (1659-1668) compile out of Release.
  - `.wall(fresh|expired)` — completed onboarding, no `hasPro` AND no care entitlement.
    Renders `WallView` (`App/WallView.swift:26`).
  - `.migration` — entitled + legacy footprint (`programEraEnabled`) + no `appV2SeenAt`.
    `MigrationMomentView`, one-time.
  - `.main` — `MainShell` (`App/MainShell.swift:17`); defense-in-depth re-check at :48.
- Entitlement doors into `.main`: RevenueCat `effectiveHasProAccess` OR
  `care_entitlement_active` (@AppStorage; server-verified by `Sync/AppSync.swift:187`, also
  set by v8 onboarding clinic-code accept, `OnboardingV8/V8Beats.swift:1119-1139`).
  Auth-transition hold keeps last stable phase so sign-in never flashes the wall.
- `MainShell` tab bar (`MainShell.swift:90-106`), native TabView, 4 items
  (`App/AppRouter.swift:19-41`): **today** (sparkles) → `TodayHost` = `ProgramOnrampView`
  until `programEraEnabled`, then `HomeView` (`MainShell.swift:271-280`); **jeni** (bubble)
  → `JeniChatView`; **scan** (viewfinder) = action item, opens `ScanChooser` overlay (body
  or plate, `MainShell.swift:77-84,110-118`), never a destination; **becoming** (book) →
  `BecomingSummaryView`.
- `AppRouter` (`AppRouter.swift:43-109`): routes snap/weighIn/lesson/breath/trend/bodyScan/
  workout/steps + chat seeds; `jenifit://` URL grammar :92-108. Notification taps queue
  until shell mounts.
- Post-purchase: `PostPurchaseFlowView` full-screen cover consumed once
  (`MainShell.swift:164-176,238-245`). Re-auth prompt sheet `MainShell.swift:186-217`.

## HOME / TODAY — LIVE

- Files: `Views/Home/HomeView.swift` (1,435 ln, touched 2026-08-09), `HomeSections.swift`
  (hero carousel), `HomeEvening.swift`, `HomeCalendarStrip.swift`;
  `Views/Today/TodayModules.swift` + `TodayModuleHost.swift` (module state + covers/sheets).
- Structure: day chip (tap = jeni's letter `.jeniNote`, long-press = settings;
  `HomeView.swift:455-479`) → hero carousel `HomeNutritionSummary`
  (`HomeSections.swift:29`, 5 faces: calories ring / protein floor / plate split /
  chemistry / week + safety-gate word face) → TODAY checklist (CarePlanEngine lead +
  supporting + offered rows, `HomeView.swift:560-746`) → TOOLS grid of 6
  (`HomeView.swift:759-822`): snap a meal, weigh in, body check-in, the method, breathe,
  move → evening close row (`HomeView.swift:602-613` → `HomeEveningMoment` cover :331).
- Beat routing (`TodayModules.swift:133-160`): lesson→RepView, snapMeal→CaptureFlowView,
  workout→PreRoutine, steps→TodayStepsSheet, breath→BreathworkFlowView,
  weighIn→JKWeightRitual, medication→DoseSheet, bodyScan→BodyScanFlowView,
  plank/water/measurements→MarkAsDoneSheet.
- Day composition: `CarePlanEngine` (`Program/CarePlanEngine.swift`) over
  `PrescriptionEngineV2` + `TodayStateService` snapshot; targets from `TargetsService`
  (kcal nil = safety-suppressed, `TargetsService.swift:26-40`); dose-day leads via
  CareProtocol regimen policy (`CarePlanEngine.swift:185`).
- Day rollover observed via `NSCalendarDayChanged` (`HomeView.swift:400`).

## ONBOARDING — LIVE (v8 THE CONSULT)

- Files: `Views/OnboardingV8/` (4,940 ln; flow `OnboardingV8Flow.swift`, script
  `V8Beats.swift` 29 beats, chapters arrival/mirror/evidence/file `V8Chapters.swift:13`,
  structured beats snapDemo/safetyGate/signature/healthKit/hold `V8Chapters.swift:10`).
- Branching: clinic code path skips consumer chapters (`V8Beats.swift:57`, code-accept sets
  `care_entitlement_active` :1119-1139); GLP-1 beats glp1Status/glp1Phase/appetiteRhythm/
  shotDay; v24 medication beats write `onb_med_route/product/dose/hour` →
  `MedicationOnboardingBridge.spec` builds a regimen at completion (`PlankAIApp.swift:2388`,
  `Program/MedicationOnboardingBridge.swift` — all-skips build nothing).
- Legacy: `Views/OnboardingV5/` (5,735 ln) behind `--onboarding-v5`; `Views/Onboarding/`
  v4 (15,699 ln, `OnboardingView.swift` alone 9,645) behind `--onboarding-v4` /
  `--debug-medication`. Shared live pieces from the v4 dir: `SignInPromptView` (7 external
  refs incl. MainShell reauth), `SignUpView`/`ForgotPasswordView` (via SignInPromptView),
  `BuildingPlanLoadingView`, `HoldToPromiseButton`, `BecomingProjectionCard`.
- Verdict: v8 LIVE; v5 + v4 flows GATED (DEBUG-only) and 95% VESTIGIAL.

## COHORT ROUTING — LIVE

- `Glp1Cohort` enum defined in `Notifications/RetentionNotifications.swift:23` (odd home);
  `CohortStore` (`Program/CohortStore.swift`) is the ONE reader of the canonical
  `onboarding_*` keys: glp1Status/phase, hormonalStage, sleepHours, stress, weightTrend,
  goalDirection, programMode, foodRelationship, priorAttempts, appetiteRhythm,
  stopWindow, medicationStatus + derived flags (isGLP1Current, isPostGLP1, isEarlyGLP1,
  isPerimenopausal, isShortSleeper, isRegainRisk…).
- Consumers: PrescriptionEngineV2, CarePlanEngine, DailyBriefEngine, chat context,
  curriculum flags, notifications, paywall copy. Safety numerics suppression:
  `safety_numeric_suppression` → `TargetsService` returns nil kcal.

## CHAT (JENI) — LIVE

- Files: `PlankApp/Chat/` — `JeniChatView.swift` (852 ln; letter register, desk when quiet
  `JeniDesk.swift`, heart-glyph stripped at render `JeniChatView.swift:706-713`),
  `ChatSession.swift` (streaming, `--uitest-mock-chat` offline mode),
  `ChatTransport.swift` (SSE POST to `functions/v1/jeni-chat`, :35),
  `CoachContextAssembler.swift` (provenance-only context; v24 `medication{}` envelope
  :212-241), `ChatToolRouter.swift` (7 tools: open_snap_camera, log_weight,
  show_today_plan, open_lesson, start_breathwork, show_weight_trend, set_reminder_hour;
  mutating ones require confirm cards :15-17), `ChatModuleCards.swift` (inline plan/
  workout/steps cards).
- Entry: jeni tab (`MainShell.swift:94`); seeds via `AppRouter.openChat` from letter reply,
  notifications, `jenifit://jeni?seed=`.
- Transcript local-first (`ChatMessageRecord` in the model container). Backend: `jeni-chat`
  EF, OpenAI `gpt-5.1` default, streams SSE, tools defined server-side; medication redlines
  in prompt (never dose advice, route to clinician). Founder gate: v24 EF deploy.

## FOOD (SNAP / SCAN / BOOK) — LIVE

- Package `Packages/PlankFood/Sources/PlankFood/` (leaf SPM; tests run via package scheme):
  Capture/ (28 files: `CaptureFlowView.swift` phases consent→firstScanOnboarding→camera→
  quickAdd→result :277-285; `PhotoCaptureView.swift` with `SnapDial` modes scan·barcode·
  label :46; `SnapResultView` = THE READING; `QuickAddView` describe path;
  `RecentMealsSheet`, `IngredientEditorSheet`, `SnapRefine`), Pipeline/ (13:
  `FoodVisionService` → EF, `BarcodeRead` VN + `OpenFoodFactsClient` by code,
  `NutritionLookupService` pantry>USDA>OFF, `CalorieMathService`, `FoodLogPersister` —
  **JSONL store on disk since 2026-06-11, not SwiftData** :12-20, `FoodPhotoStore`),
  Result/ (`FoodCorrectionSheet` + `Atoms/PortionStepper` — still live via
  `CaptureFlowView.swift:155`), Flags/ (`FoodFlags` entitlement-gated), Theme/, Tiles/
  (handwritten share cards), Analytics/.
- Entries: scan tab action → `ScanChooser` "plate"; Home snap tool tile + snapMeal beat
  (`HomeView.swift:773-779`); chat tool; `jenifit://snap`. Wiring/config at
  `PlankAIApp.swift:1817-1883` (vision EF + USDA + pantry token providers, protein target +
  day-context providers from TargetsService).
- THE BOOK: `Views/Becoming/FoodJournalView.swift` (v23 day spreads, month seams,
  week read, relog) — opened from Becoming row (`BecomingSummaryView.swift:1042,319`).
- `PlateDetailSheet` from Home plate strip (`HomeView.swift:420-429`). HealthKit dietary
  energy write-through via `FoodHealthKitWriter` closure (`PlankAIApp.swift:335-339`).
  Scan Live Activity (`JenifitWidgets/ScanLiveActivity.swift`) — the only widget-target
  surface; no home-screen widgets.

## BECOMING — LIVE

- `Views/Becoming/BecomingSummaryView.swift` (1,185 ln, 2026-08-08): hero body read, scope
  bar (`JeniScope` today/week/month/3mo/year/all), tile grid morph-in-tree expansion,
  insight carousel.
- Tiles (`BecomingTiles.swift:13-19`): weight, calories, protein, fiber, sugar, sodium,
  sleep, steps, movement, waist, bodyFat, **medication** (v24; hidden when no regimen,
  tally strip + dose-era ledger :673-776).
- Doors: body compare `BodyTimelineView` (:305), body check-in (:312), THE BOOK (:319 via
  row :1042), visit packet `VisitPacketView` (:322), re-signing `ReSigningView` (:328,
  weekly consented adaptation). Care-mode variant behind `--uitest-care-mode` (:78).
- `becoming_opened` event fired on tab switch (`MainShell.swift:129` — added 2026-08-08
  because the v21 rebuild killed all `journey_*` events).

## MEDICATION (v24 THE REGIMEN) — LIVE (cohort-shaped)

- Engine files (`PlankApp/Program/`): `MedicationCatalog.swift` (9 products verified),
  `RegimenService.swift` (version chains, `applySelfRegimen` chokepoint, supersede-never-
  mutate), `DoseEventStore.swift` + `DoseEventRecord` (deterministic per-slot ids, synced),
  `MedicationLog.swift` (every surface converges: sheet/notification/chat),
  `MedicationScheduleEngine.swift` (wall-clock, weekly late window),
  `MedicationSites.swift` (rotation suggests), `MedicationPatternEngine.swift`
  (timing-never-causality), `SideEffectLog.swift` (→ ObservationStore `.symptom`),
  `MedicationOnboardingBridge.swift`.
- Surfaces: dose row on Today (medication beat → **DoseSheet**, `TodayModules.swift:150-155`;
  site cells rotation-pre-selected, skip reasons, oral face); **RegimenSheet** = THE
  REGIMEN home (facts as doors, THE RECORD era rows, side-effect logger
  `RegimenSheet.swift:13,85,232`) reachable from Settings "your medication" row
  (`ProfileHubView.swift:257-259,203`) + `.regimen` sheet case; Becoming medication tile;
  chat `medication{}` context; evening ask (HomeEvening).
- Reminders: `Notifications/MedicationReminders.swift` — FIRST actionable category
  `MED_DOSE` (taken / in an hour / log later; :37-40), ids `med_dose_reminder|snooze|open`,
  never names the drug, per-regimen `reminderEnabled` opt-in under the master toggle,
  survives breaks; "taken" action resolves through `MedicationLog`
  (`PlankAIApp.swift:2024-2034`).
- Gating: whole system renders only when a regimen exists (hidden-when-absent). Founder
  gates open: apply `20260809090000_v24_medication_platform` migration + deploy jeni-chat
  EF. **Zero analytics events** (see ANALYTICS).

## WEIGHT — LIVE

- `JKWeightRitual` sheet (`Views/Today/JKWeightRitual.swift`) from tools tile
  (`HomeView.swift:780-786`), weighIn beat, chat `log_weight` tool, `jenifit://weigh-in`.
  Band whisper in keeping chapter (`TodayModuleHost.swift:225-255`, `BandModel`).
- Passive import: `Health/BodyMassImportService.swift` (HK background delivery + observer),
  wired at launch + Settings/onboarding HealthKit beats. EMA + zones: `WeightEMA`,
  `BandModel`, `RapidLossTripwire`. Sync: `weight_logs` typed upserts + hydrate.
  Becoming weight tile is the trend surface. Zone pushes on save
  (`NotificationOrchestrator.onWeighSaved` :233).

## BODY SCAN (BODY VISION) — LIVE

- `PlankApp/BodyScan/` — `BodyScanFlowView.swift` (consent→capture→landed→kept→record
  :22-29), `BodyCaptureSession` (rear camera, THE WINDOW), `WaistCrop` (pure, tested),
  `BandProfile` (row-width→words, 3% noise floor), `BodyScanStore` local-first,
  `BodyScanPhotoStore`, `BodyTimelineView` compare, `BodyFatEstimate` (provenance ladder),
  `MirrorGate`, `BodySilhouetteRenderer`.
- Entries: scan tab chooser "body" (`MainShell.swift:79`), Home body check-in tile
  (`HomeView.swift:788-793`), bodyScan beat, Becoming check-in + compare,
  `BodyVisionIntroView` one-time Home cover (`HomeView.swift:343-355`).
- Backup: D3 opt-in via `Sync/BodyScanSyncService.swift` (default OFF), settings rows in
  ProfileHub ("body vision" :426, delete-all).

## METHOD / LESSONS — LIVE (thin daily surface over large dormant corpus)

- Live path: lesson beat / "the method" tile (`HomeView.swift:795-802`) →
  `MethodResolver.resolve` (`Program/RepEngine.swift:331`, cadence-compressed ordinal) →
  **RepView** (`Views/DietEducation/Reader/RepView.swift`, 20-40s decision practice) with
  reader one tap deeper (`LessonReaderView`, :33). No-resolution days get `beginAgainRep`
  (`TodayModuleHost.swift:98`).
- Content: `Resources/manifest_v1.json` (401KB; **84 canonical + 18 extension lessons**,
  6 pillars, 4 acts; generated 2026-07-03) served by `CBTCurriculumService`
  (last logic change 2026-06-13); **17 authored MethodReps** (10 doc-22 + pillar
  fallbacks, `RepEngine.swift` — the 84-slot authoring pass never happened).
- Legacy reader `JeniMethodRitualView` (content `JeniMethodContent.swift`, 2026-07-28):
  production-reachable ONLY as the re-read archive (`ProfileHubView.swift:327` →
  `JeniMethodReReadView`) + QA covers (`--uitest-jeni-lesson`, `--uitest-cbt-lesson`,
  `PlankAIApp.swift:1716-1739`). ~40 `jm_hero_*` imagesets back it. DietEducation subtree
  total 4,248 ln.
- Verdict: RepView/reader LIVE daily; ritual reader GATED (settings archive);
  most of the 84-lesson spread only reachable through the archive.

## BREATHWORK — LIVE

- `Views/Welcome/BreathworkFlowView.swift` + `BreathworkPrimerView` + `BreathworkSessionView`
  (last touched 2026-07-31); engine `Health/BreathworkProtocols.swift` (4 protocols:
  calming 4-6, coherent 5-5, energizing 4-4, windDown 4-7-8), `BreathworkState`,
  `BreathHaptics`. Science-honest cortisol primer.
- Entries: breathe tool tile (`HomeView.swift:803-809`), breath beat (rest days), chat
  `start_breathwork` tool, RepView door routes, `jenifit://breath`. Completion marks the
  beat (`TodayModuleHost.swift:194-205`). Analytics: breathwork_* events live.

## WORKOUT / SESSIONS — LIVE (large legacy content, modest surface)

- Flow: move tile / workout beat → `PreRoutineView` → `RoutineSessionView`
  (`TodayModuleHost.swift:139-192`; both 2026-07-31) → `PostRoutineView` + rating;
  threshold via `SessionCompletion`; saves `SessionLogRecord` (synced).
- Engine `PlankApp/Workout/`: `WorkoutGenerator` + `ExerciseBank` over
  `Resources/exercises.json` (**128 exercises**), presets, `BodyFocus`,
  `EngagementDayCalculator` (program day derived), self-checks at launch.
- Content: **1,105 voice clips** (`Resources/VoiceClips/`), **129 Lottie exercise
  animations** (`Resources/lottie/`), 12 music tracks. AirPlay external display
  (`Views/Routine/ExternalDisplaySceneDelegate.swift`, scene config in
  `PlankAIApp.swift:44-59`).
- Reachability: only through the move tile / workout beats. `BrowseWorkoutsView`
  (a browse catalog) is orphaned (see DEAD WEIGHT). Plank-specific capture
  (PlankEngine pose analysis) fully dead.

## STEPS — LIVE

- `Health/StepsService.swift` (HKObserver + anchored queries, 7,500 default; 17 consumer
  files). Surfaces: steps beat row → `TodayStepsSheet` (`TodayModuleHost.swift:277-281`),
  Becoming steps tile, ProfileHub "connect steps", auto-complete on goal cross
  (`HomeView.swift:417-419`), chat steps card. `StepsPulseTile.swift` (728 ln) is
  **mounted nowhere** — superseded by the sheet + tile.

## SLEEP — LIVE (quiet)

- `Health/SleepService.swift` — consumed by `TodayStateService` (evening composition),
  `CoachContextAssembler`, Becoming sleep tile + recaps (`BecomingSummaryView.swift:25`).
  `LastNightSleepCard` renders ONLY in debug harnesses (`--debug-sleep-preview*`).
  `VitalsService` (resting HR, HRV) and `CycleService` (menstrualFlow) feed context/
  services; no dedicated user surface.

## NOTIFICATIONS — LIVE

- `NotificationDelegate.install()` at app delegate (`PlankAIApp.swift:29`); taps route
  through AppRouter deeplinks; MED_DOSE category registered (see medication).
- Schedulers: `NotificationOrchestrator` — 7-day anchor ladder `anchor_d1..7` (:28,
  refreshed daily), re-signing knock `resigning_knock` (:114), keeping-zone one-shots
  `keeping_zone` / `keeping_line_quiet` / `lapse_support` (:201-203);
  `RetentionNotifications` — `winback_lapse`, `affirmation_drop_*`, `day1_morning`,
  `day5_anti_refund`, `evening_plate_review`, `food_first_log_nudge` (cancelled on first
  food log via analytics hook `PlankAIApp.swift:324-326`), `milestone_<n>`, legacy sweep of
  `daily_reminder`/`daily-plank`; `MedicationReminders` — `med_dose_reminder|snooze|open`;
  `RecapNotificationService` — `becoming.sunday.recap`; `TrialEndNotificationService` —
  `jenifit.trial.ending.reminder` (**dormant**: pay-upfront, no trials);
  `ActivationPushPolicy` gates first-days pushes on day-2 consent (`onb_consent_day2`).
- Master toggle `notificationsEnabled`; per-surface toggles `notif.*` keys.

## SETTINGS — LIVE

- `ProfileHubView` (`Views/Settings/`), reached ONLY by long-press on the Home day chip
  (+ a11y action, `HomeView.swift:465-479`) — no gear icon, no tab. Rows: account
  (AccountView incl. delete/sign-out), coach (ChangeTrainerView), notifications
  (NotificationSettingsView), food (FoodSettingsView incl. HK write toggle), apple health,
  body vision (:426, render mode/backup/delete), **your care team** (:263 →
  CareConnectionSheet), **your medication** (:257 → RegimenSheet), my pace, feedback,
  debug auth (DEBUG).

## PAYWALL / PAYMENT — LIVE

- `PaymentService.swift` (912 ln): RevenueCat `customerInfoStream`, re-configure on auth
  change, `effectiveHasProAccess` (QA overrides), `wasEverEntitled` sticky key,
  `isInAuthTransition` hold, entitlement recovery decision table.
- `WallView` (`App/WallView.swift`): keep wall as destination — `PaywallView` (3 tiers,
  RC localized prices, no trial) + exit-intent chain: `SmallerStepSheet` →
  `DownsellPaywallView` (discounted year) → `CancellationWinbackSheet` (:36-38,
  once-per-install flags). Expired variant with first-class restore + alerts (:56-60).
- In-app: `UpgradeMomentView` — day-6 weekly→quarterly offer from Home
  (`maybeOfferUpgradeMoment`, `HomeView.swift:359`), once per install.
  Trial-nudge machinery preserved dormant (`MainShell.swift:179-184`, binding always false).

## AUTH — LIVE

- `Auth/AuthService.swift` (697 ln): anonymous-first bootstrap (:140), fail-open verify
  classification, `freshAccessToken()` (:293, refreshes JWT — the food-EF 401 fix), email
  sign-up/sign-in/reset, Apple (`AppleSignInService`), delete account (:563), sign-out
  sweep. Re-auth prompt when server rejects a linked session (`MainShell.swift:186`).
  PostHog identify on auth change (`PlankAIApp.swift:468-479`, Release only).

## SYNC — LIVE

- `Sync/AppSync.swift` (1,533 ln) configured at RootView task (:1786): hydrate chain
  (:396-455) = users → weight_logs → program_plans → program_day_checks → live-plan
  reconcile → session_ratings → day_reflections → CareProtocolStore → observations →
  regimen_plans → dose_events → legacy backfill → food_logs (JSONL merge) → UserDefaults
  mirror. Typed upserts (:822-1058): session_logs, day_progress, weight_logs,
  session_ratings, food_logs, day_reflections, program_plans, program_day_checks,
  consent_grants, observations, regimen_plans, dose_events, users.
- `Packages/PlankSync` `SyncService.swift` tables touched: users, session_logs,
  day_progress, day_reflections, weight_logs, session_ratings, program_plans,
  program_day_checks, food_logs, observations, regimen_plans, dose_events, consent_grants,
  protocols, protocol_assignments, visit_packets, care_weekly_summaries.
- Care publishers: `Care/WeeklySummaryPublisher`, `VisitPacketPublisher`.

## CARE PLATFORM (v8) — GATED (pilot founder-gated; consumer doors LIVE)

- App side: `CareConnectionSheet` (Settings row), `ReconciliationSheet` (Home,
  care-plan reconcile offer), `CorrectionSheet`, consent (`ConsentGrantRecord`,
  `Program/ConsentService`), `CareProtocolStore` served config, visit packet + weekly
  summaries from Becoming. Clinic web app in `clinic/` (separate dist). Care entitlement
  passes the wall without RevenueCat. QA doors `--uitest-care-*` in `AppSync.swift:196-243`.

## ANALYTICS — LIVE (uneven coverage)

- `Analytics/AnalyticsManager.swift` queue + sinks; `PostHogSink`; bootstrap before first
  event (`PlankAIApp.swift:276-408`); DEBUG = dev-{vendorId} + is_test_user super-props,
  flushAt 1; crash autocapture ON (:307). TikTok SDK deferred background init (:216).
  PlankFood events bridge through `FoodAnalytics.register` (:319).
- Event names (grep-verified): **onboarding/consult** onboarding_start(ed)/complete,
  onboarding_step_viewed/completed, ov5_step_advanced/back, ov5_gate_outcome,
  ov5_demo_completed, personalization_completed, care_safety_completed,
  acquisition_source_answered, quiz_*, plan_loader_*, plan_reveal_*, projection_chart_*,
  comparison_chart_viewed, consent_ritual_*, brand_promises_*, coach_intro_*,
  method_preview_*, onboarding_video_demo_viewed, notification_preprompt_*/prompt_shown/
  permission_result; **paywall/payment** paywall_view/cta_tapped/tier_selected/
  dismiss_attempted/transaction_abandoned, purchase_sheet_shown, purchase_completed,
  downsell_*, smaller_step_*, upgrade_moment_*, tier_ladder_viewed, trial_cancelled/
  converted, wall_sign_in_tapped, paywall_sign_in_tapped, entitlement_auto_sync;
  **shell** main_tab_appeared, becoming_opened, settings_hub_opened, migration_moment_*,
  reauth_prompt_shown, jenis_note_viewed; **food** food_scan_started/completed/cost,
  food_first_scan_*, food_log_saved, food_first_log_saved, food_quick_add_*,
  food_im_out_*, food_satiety_marked, food_write_it, food_library_well, food_ai_consent_*,
  food_scan_correction_*, food_scan_fallback_fired, food_budget_cap_hit,
  food_rate_limit_hit, food_book_opened, barcode_error/unknown, food_rail_dev_override;
  **chat** jeni_chat_opened/message_sent/tool_called/care_routed; **body** body_scan_kept,
  body_vision_intro; **weight** weight_logged, weight_outcome_milestone; **workout**
  workout_start/complete, first_workout_*, session_feedback_given; **breath**
  breathwork_primer_*/session_*; **steps** steps_connected/goal_hit/viewed_*; **method**
  diet_education_* (legacy reader); **misc** rating_prompt_*, feedback_submitted,
  weekly_review_signed, coach_changed, program_invite_tapped, log_saved.
- **Dark zones**: the entire v24 medication platform (no dose_marked/regimen_created —
  zero events), Becoming interior (tiles/scopes; only becoming_opened), Home checklist
  marks, evening close, RepView. Orphaned enum constants with dead emitters:
  journey_day_opened, journey_week_opened, plank_checkin_started, breathwork_card_tapped,
  lesson_card_tapped, food_card_tapped, home_food_card, future_rail_tapped,
  affirmation_viewed, trial_start, workout_energy_changed.

## HEALTHKIT

- Read: stepCount + distanceWalkingRunning (StepsService), sleepAnalysis (SleepService),
  bodyMass (BodyMassImportService, background delivery), bodyFatPercentage
  (BodyStateService ladder), activeEnergyBurned (MovementService), restingHeartRate +
  heartRateVariabilitySDNN (VitalsService), menstrualFlow (CycleService).
- Write: bodyMass (weigh-in save; `--debug-hk-write-weight` harness), dietaryEnergyConsumed
  (HealthKitDietaryEnergyWriter behind FoodSettings toggle).

## BACKEND (supabase/)

- Edge functions: **food-vision** (857 ln, LIVE — direct-kcal read, model env
  `FOOD_VISION_MODEL` default gpt-4o, cost meta); **jeni-chat** (466 ln, LIVE —
  SSE stream, tools, `JENI_CHAT_MODEL` default gpt-5.1; v24 medication prompt block
  present locally, deploy = founder gate); **nutrition-lookup** (60 ln, **SKELETON**);
  **food-photo-cleanup** (53 ln, **SKELETON**).
- Migrations (all 11): 20260623 users cohort intake columns · 20260628 clinical baseline +
  promises_kept · 20260703 v2 chat/cohort columns · 20260708 food_logs.sugar_g ·
  20260728000000 v8 foundation (observations + regimen_plans + RLS) · 20260728120000
  regimen authority seams (authority/rxnorm/strength) · 20260729120000 consent_grants ·
  20260729180000 s4 clinic loop (organizations, org_members, invitation RPC, private
  config) · 20260730090000 s5 pilot-ready (org status, is_demo, roles) · 20260804090000
  care_weekly_summaries · 20260809090000 **v24 medication platform** (regimen_plans
  product/route/chain columns + dose_events table) — **NOT YET APPLIED** (founder gate).

## DOORS (launch arguments; all DEBUG-compiled unless noted)

- Phase/entitlement: `--uitest-inapp-qa` (completed-onboarding land), `--uitest-pro-access`
  (mock entitlement), `--uitest-fresh-onboarding` (full key sweep), `--uitest-force-migration`,
  `--uitest-force-expired`, `--uitest-skip-payment`, `--uitest-skip-review`,
  `--uitest-keep-reviews`, `--uitest-start-tab <tab>`.
- Seeding: `--uitest-seed-program` (+`--uitest-seed-day N`, `--uitest-cohort
  current|past|considering`, seeds 2 plates + 13-day week shape), `--uitest-seed-regimen`,
  `--uitest-seed-medication <injectable|oral|b2b|history>` (MedicationQASeeder),
  `--uitest-seed-week` (food book), `--uitest-seed-scans`, `--uitest-seed-oneweight`,
  `--uitest-open-gap 0|6|10` (return-gap state).
- Open-directly: `--uitest-open-scan-chooser`, `--uitest-open-body-scan`,
  `--uitest-open-dose-sheet`, `--uitest-open-regimen`, `--uitest-open-care-connect`,
  `--uitest-open-food-journal`, `--uitest-open-downsell`, `--uitest-downsell-preview`,
  `--uitest-plate-detail`, `--uitest-letter`, `--uitest-breath-preview`,
  `--uitest-cbt-lesson N D` (+`--uitest-cbt-page`, `--uitest-cbt-open-prompt`),
  `--uitest-jeni-lesson N`.
- State forcing: `--uitest-force-evening`/`--uitest-force-day`, `--uitest-seal-day`/
  `--uitest-unseal-day`, `--uitest-force-body-intro`, `--uitest-force-scan-day`,
  `--uitest-scan-allow-manual`, `--uitest-scan-simulate-pose`, `--uitest-reset-body-scan`,
  `--uitest-gentle-preview`, `--uitest-suppress-reconcile`, `--uitest-upgrade-moment`,
  `--uitest-pricing-fail`, `--uitest-today-bottom`, `--uitest-becoming-bottom`.
- Walkers/films: `--uitest-walk-carousel`, `--uitest-walk-strip`, `--uitest-walk-scope`,
  `--uitest-walk-sheet`, `--uitest-walk-book`, `--uitest-walk-medication`,
  `--uitest-open-tile`, `--uitest-mark-lead`, `--uitest-land-plate`,
  `--uitest-save-moment`, `--uitest-select-figure`, `--debug-gallery-tour` (JeniKit).
- Chat: `--uitest-mock-chat`, `--uitest-chat-demo`, `--uitest-chat-plan-demo`,
  `--uitest-chat-trend-demo`, `--uitest-chat-shimmer`, `--uitest-chat-typing`.
- Care: `--uitest-care-connect-code CODE`, `--uitest-care-refresh`,
  `--uitest-care-auto-confirm`, `--uitest-care-submit-correction`, `--uitest-care-revoke`,
  `--uitest-care-mode`, `--uitest-clinic-code-accept` (onboarding).
- Food package: `--food-debug-autostart`, `--food-debug-mode barcode|label`,
  `--food-debug-success`, `--food-debug-hang`, `--food-debug-timeout`, `--food-debug-5xx`,
  `--food-debug-empty`, `--food-debug-slow N`, `--food-debug-deadline N`,
  `--food-debug-gallery-confirm`.
- Harness screens (`DebugPreviewRoutes.swift`, replace the app root): --debug-weekly-receipt,
  post-routine, v11-gallery, jenikit, lesson-close, steps-detail, safety-screen/-recovery/
  -consent/-pregnancy/-checkin/-gate, program-setup(-pace/-commit), profile-hub, v8-hold,
  v8-health, hold-promise, glp1-nutrition, sleep-preview(-empty), trial-day2/3, winback
  (-bare), log-weight-sheet, handwritten-share/-weekly/-lesson/-snap, result-carousel,
  snap-camera, describe, arrival, promise-confirm, kept-promise, activation-gallery,
  projection(-maintenance/-suppressed), commitment, building, disclaimer, first-week,
  rating-ask, rating-gate, nudge, medication (v4 screen), paywall; plus legacy
  `--onboarding-v4`, `--onboarding-v5`, `--carousel-page=N`, `--debug-hk-write-weight`.

## DISCREPANCIES (code vs CLAUDE.md/docs)

1. **CLAUDE.md "Onboarding" standing section is two eras stale**: claims v5 architecture,
   `onboarding_version: v7`, "Files: PlankApp/Views/OnboardingV5/". Production is
   OnboardingV8Flow (`PlankAIApp.swift:1673`); V5/V4 are DEBUG doors only.
2. **MARKETING_VERSION**: CLAUDE.md compliance section says 1.2.0; pbxproj says **1.1.7
   (28)** (matches the release-audit memory, contradicts the standing section).
3. **v23 claim "Result/ subtree deleted"**: `PlankFood/Result/` survives and is LIVE —
   `FoodCorrectionSheet` mounted from `CaptureFlowView.swift:155`, `PortionStepper` inside.
   Only the carousel result views died.
4. **Chat "streamed heart emoji stripped by normalizer"**: stripping is a render-time glyph
   map in `JeniChatView.swift:706-713`, not a transport normalizer. Cosmetic but the
   architecture note misleads.
5. **Food persistence**: model-container comment promises "v1.0.8 ships a proper SwiftData
   integration" (`PlankAIApp.swift:564-570`); reality is a permanent JSONL store
   (`FoodLogPersister.swift:12-20`). Works, but the docs/comments describe a stop-gap.
6. **Medication "first-class" but analytics-invisible**: v24 shipped zero events; PostHog
   cannot see a single dose mark, regimen creation, or reminder action.
7. **CLAUDE.md notifications section** cites "trial-window anchors + daily reminder";
   `daily_reminder` is now a legacy id actively REMOVED by the orchestrator sweep, and the
   trial services are dormant under pay-upfront.
8. **THE METHOD scale**: docs speak of an 84-day curriculum; only 17 reps are authored and
   the daily surface is the rep, with the 84-lesson manifest mostly reachable via the
   settings re-read archive. "ONE IDEA ONE ACT cards — design bound, build queued" (v22)
   remains unbuilt.
9. **`Glp1Cohort` lives in RetentionNotifications.swift**, not a cohort module — CohortStore
   depends on the notifications file for the core routing enum.
10. **nutrition-lookup / food-photo-cleanup EFs are skeletons** while docs list a
    "server-side cache layer" — app-side `NutritionLookupService` does the real work.

## DEAD WEIGHT (deletion candidates, evidence-backed)

1. **`Packages/PlankEngine`** (pose analyzer + plank state machine, last touched
   2026-05-08) + **`Spike/PoseSpike.swift`** — zero `import PlankEngine` anywhere.
2. **`Packages/PlankVoice`** (2026-05-10) — zero imports (voice clips play via
   `RoutineAudioManager`, not this package).
3. **`Views/Onboarding/OnboardingView.swift` (9,645 ln) + OnboardingRevealView (2,550) +
   OnboardingComponents (1,223)** — v4 flow behind `--onboarding-v4`/`--debug-*` DEBUG
   doors only. Keep SignInPromptView/SignUpView/ForgotPasswordView/BuildingPlanLoadingView/
   HoldToPromiseButton/BecomingProjectionCard (live refs), delete the rest.
4. **`Views/OnboardingV5/` (5,735 ln)** — behind `--onboarding-v5` only (OV5Store types
   still referenced by V8HoldMoment harness; sweep needs a type-level pass).
5. **`Views/Home/StepsPulseTile.swift` (728 ln)** — mounted nowhere (comments only).
6. **`Views/Analytics/`** — BreathworkBentoTile + StepsBentoTile unreferenced;
   LastNightSleepCard harness-only.
7. **`Views/Browse/BrowseWorkoutsView.swift`** + **`Views/Share/RoastCardView.swift`** —
   unreferenced since 2026-06-10.
8. **Trial machinery** — `Views/Trial/TrialNudge.swift` (dormant binding
   `MainShell.swift:179-184`), TrialDay2/3 modals (harness-only),
   `TrialEndNotificationService` — pay-upfront made trials impossible.
9. **`Health/EnergyLedger.swift`** — sole consumer is legacy OnboardingRevealView.
10. **Orphaned analytics enum constants** (journey_*, plank_checkin_started,
    food_card_tapped, home_food_card, future_rail_tapped, trial_start,
    workout_energy_changed…) — dead emitters, misleading dashboards.
11. **Skeleton EFs** `nutrition-lookup`, `food-photo-cleanup` — 2-month-old placeholders.
12. **`--onboarding-v4`/`--onboarding-v5` root escapes + their QA covers** once 3+4 land.
13. Asset review: 39 `Stickers/` imagesets and 40 `jm_hero_*` imagesets ride every install
    (bundle weight; hero images only reachable via the settings re-read archive).
