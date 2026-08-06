# Onboarding v5/v6 → consumer DATA-FLOW MAP (verified 2026-08-02)

Method: started from `docs/onboarding_v5/DATA_CONTRACT.md`, then grepped
every key/field for actual readers in `PlankApp/` + `Packages/`. Beat
names are the `OV5Step` cases in `PlankApp/Views/OnboardingV5/OV5Flow.swift:19-45`;
the router (`OV5Flow.swift:422-489`) is the ask-order authority.
Sign-out sweep lists (`PlankApp/Sync/AppSync.swift:1083+`) and
UserRecord sync mirrors (`PlankApp/PlankAIApp.swift:2790-2860`) are
hygiene/storage, NOT counted as consumers. (Agent-produced; verified
against code at every row.)

Verdicts: **PLAN** = changes math/routing/composition/scheduling ·
**EXP** = changes visible copy/content/model-prompt · **ANALYTICS** ·
**DEAD** = no reader.

## Act I — the door

| key/field | asked at (beat) | real consumers found | verdict |
|---|---|---|---|
| `onb_v5_outcome` → `OnboardingData.motivation`/`goal`(legacy mirror) | `outcome` (OV5ScreensArrival.swift:20-34) | Her-file dossier echo ("here for", OV5ScreensClose.swift:87). Legacy mirror collapses noise/clothes/myself/keep→"loseWeight", energy→"fullBody" (OV5Flow.swift:283-293) → `userMotivation` (PlankAIApp.swift:2622) → JeniMethod lesson goalFrame (JeniMethodRitual.swift:190) + analytics props. Only the "energy" answer changes anything downstream. | EXP (thin — 4 of 5 answers identical downstream) |
| `onb_v5_attribution` / `acquisitionSource` | `attribution` | Stamped on every funnel event (AnalyticsManager.swift:719) + UserRecord (PlankAIApp.swift:2832). No product surface reads it. | ANALYTICS |
| `onb_v5_name` / `userName` | `name` | Chat grounding (CoachContextAssembler.swift:22), daily brief (TodayStateService.swift:286), notifications (NotificationOrchestrator.swift:59, RetentionNotifications.swift:684), wall (WallView.swift:312), winback sheet (CancellationWinbackSheet.swift:33-34,92), dossier + signature sub (OV5ScreensClose.swift:22,127), ProfileHub. | EXP (heavy, everywhere) |

## Act II — food + GLP-1 branches

| key/field | asked at | real consumers found | verdict |
|---|---|---|---|
| `onboarding_glp1_status` | `glp1Status` (router branch point, OV5Flow.swift:431-436) | **Plan**: 0.3%/wk pace floor (ProgramGoalCalculator.swift:204-207 via all build sites: PlankAIApp.swift:2698, ProgramSetupSubflow.swift:214, OnboardingRevealView.swift:328/1364/1433), SCOFF GLP-1-aware core count (ProgramGoalCalculator.swift:564-569), protein 1.6 g/kg (TargetsService.swift:154-161), chapter→`onMedication` day composition (DayModel.swift:32-55 → CarePlanEngine via TodayStateService.swift:267-274), weigh-cadence slots (PrescriptionEngineV2.swift:186), HardTierGate lock (IntensityProfile.swift:165), shot-day regimen gate (PlankAIApp.swift:2749), WeekIntent flag (WeekIntent.swift:38). **Exp**: notification cohort routing (RetentionNotifications.swift:23-46), chat cohort word (CoachContextAssembler.swift:205-211), lesson cohort variant (CBTCurriculumTypes.swift:189), first-week rails variant (OnboardingRevealView.swift:1895-1897), causal receipts + provenance line (OnboardingRevealView.swift:1345-1350,1576-1580), loader tape (BuildingPlanLoadingView.swift:51), paywall length compute (PaywallView.swift:429), PreRoutineView copy, TodayStateBand postGLP1 copy, InsightEngine glp1Rhythm, fear3/NSV option variants, dataMirror + herFile echoes, analytics cohort. | PLAN (the single most load-bearing question) |
| `onboarding_glp1_phase` | `glp1Phase` (current branch) | "just_started" → 0.3%/wk floor (ProgramGoalCalculator.swift:350-352, wired at PlankAIApp.swift:2709, ProgramSetupSubflow, RevealView:1369, PaywallView:433). | PLAN |
| `onb_v5_appetite_rhythm` | `appetiteRhythm` (current branch) | Chat profile (CoachContextAssembler.swift:184-185) + loader tape (BuildingPlanLoadingView.swift:53). | EXP |
| `onb_v5_shot_day` | `shotDay` (current branch) | RegimenService.setShotDay → self-managed regimen → dose-day leads the daily plan (PlankAIApp.swift:2749-2754); wall plan-summary band (PaywallView.swift:1342); first-week rails copy (OnboardingRevealView.swift:1901). | PLAN |
| `onb_v5_supports` | `supports` (current branch) | **No reader anywhere** (only OV5Flow.swift:154,235). Deliberate "intake fact ONLY" per FR8 comment — but nothing consumes it, not even sync/analytics. | DEAD |
| `onboarding_glp1_stop_window` | `stopWindow` (past branch) | Loader tape line only (BuildingPlanLoadingView.swift:52) — 4 cohort-matched variants. CohortStore.glp1StopWindowKey accessor (CohortStore.swift:86) has zero callers. | EXP (one tape line) |
| `onboarding_appetite_return` | `appetiteReturn` (past branch) | **No reader** (only OV5Flow.swift:158,237 + sweep lists). A full question beat whose answer goes nowhere. | DEAD |
| `onboardingFoodRelationship` | `foodRelationship` | → `isRestrictiveRisk` (CohortStore.swift:135-139): prescription composition (PrescriptionEngineV2.swift:45,83,187), QuietHours hard narrate gate (QuietHours.swift:89), WeekIntent (37), InsightEngine weekendRhythm gate (330), BecomingView gating (92,113), TodayStateBand (336,739), JourneyModel (262). Also CBT restrictive variant + food-noise axis (CohortStore.swift:193-199, CBTCurriculumTypes.swift:190), chat flags+profile (CoachContextAssembler.swift:74,182), lesson reader (LessonReaderView.swift:79), Act-II receipt echo. | PLAN (composition + suppression gates) |
| `onb_v5_snap_demo_meal` | `snapDemo` | Commitment chip ordering (OnboardingRevealView.swift:2383-2385) + loader tape (58). | EXP |
| `onboardingEatingCadence` | `eatingCadence` | Projection context chips (OnboardingRevealView.swift:939), Act-II receipt echo, loader tape (48). Contract's claimed "food rail copy" consumer no longer exists. | EXP |
| `onboardingPriorWin` | `priorWin` | **No reader** (only OV5Flow.swift:162,241 + sweeps). Contract's "reveal echo" is gone. | DEAD |
| `onboardingCuisinePreference` | `cuisine` | QuickAdd vision prompt hint (QuickAddView.swift:379), FoodOnboardingSheet + FoodSettingsView prefill, TodayModuleHost, loader tape, Act-II receipt, herFile echo. | EXP (vision-prompt quality) |
| `onboarding_dietary` | `dietary` | DietaryProfileResolver → food-vision EF dietary_profile (DietaryProfileResolver.swift:24, photo+text paths), loader tape. | EXP (vision-prompt) |

## Act III — numbers

| key/field | asked at | real consumers found | verdict |
|---|---|---|---|
| `onb_v4_movement_baseline` | `movement` | Calorie activity factor (CalorieTargetCalculator.swift:29-42 via TargetsService.swift:220 + reveal); derives `activityLevel` → HardTierGate activity axis (ProgramSetupSubflow.swift:215-224, IntensityProfile.swift:169-171); derives sessionMinutes + experience + baselineHoldSeconds (OV5Flow.swift:334-369); loader tape. | PLAN (TDEE + Hard-tier lock) |
| `onboardingSleepHours` | `sleep` | 0.4%/wk pace floor (ProgramGoalCalculator.swift:209-211); in-flow ack (OV5ScreensNumbers.swift:63-91); reveal provenance + causal receipt; CBT sleep axis (CohortStore.swift:218); chat profile; dataMirror echo; loader tape. | PLAN |
| `onboardingStressLevel` | `stress` | `isHighStress` → prescription beat swap on balanced days (PrescriptionEngineV2.swift:129) + WeekIntent (36) + chat craving chip (JeniChatView.swift:587) + chat profile + CBT stress axis; loader tape (heavy only). | PLAN (day composition) |
| `onboardingGender` / `OnboardingData.gender` | `gender` (OV5ScreensNumbers.swift:140-164) | **Complete reader list**: TargetsService.profileInputs sex (TargetsService.swift:212-218) → Mifflin-St Jeor BMR (CalorieTargetCalculator.swift:50-63: male +5 vs female −161 = 166 kcal BMR, ~230 kcal after activity); reveal calorie hero (RevealView:1433,2083); passed to `ProgramGoalCalculator.compute()` at 5 sites — **where it is IGNORED: compute() never touches `sex` in the rate math** (ProgramGoalCalculator.swift:168-245; stated at RevealView:319 "compute() ignores sex"). **Zero copy conditionals** on gender anywhere. **Female-assumed regardless of answer**: nonbinary/private → female formula (CalorieTargetCalculator.swift:49,61); hormonal question asked unconditionally; she/her voice app-wide. | PLAN (calorie math only; zero experience effect) |
| `onb_v5_age_years` (+ band mirror) | `age` | Exact age → BMR (TargetsService.swift:207); band → safety-gate under-18 block (ProgramGoalCalculator.swift:534-537), HardTierGate age≥40 lock (IntensityProfile.swift:167), reveal BMR midpoint. NOT used by compute() rate math (explicit TODO PlankAIApp.swift:2693-2696). | PLAN |
| `onb_v5_height_cm` / mirrors | `height` | BMR (TargetsService.swift:204); BMI safety gate + goal-weight floor at BMI 18.5 (ProgramGoalCalculator.swift:530-531,593-609). | PLAN |
| `onb_v5_weight_kg` / mirrors | `weight` | Everything: window math, BMI, calorie, protein (kg × 1.2/1.6, TargetsService.swift:146-165), first weight log seed (PlankAIApp.swift:2730-2740), wall protein line. | PLAN |
| `onb_v5_goal_kg` / mirrors | `goalWeight` | Window math → plan totalDays + goalDate (ProgramService.swift:141-158), projection, fear-resolution weeks line (OV5FearResolution.swift:121-124). | PLAN |
| `onboarding_weight_trend` | `weightTrend` | "cycling" → 0.4%/wk regain notch (ProgramGoalCalculator.swift:214-216,338-340); causal receipt (RevealView:1589); paywall length compute. | PLAN |
| `onboarding_goal_direction` (+ `program_mode`) | `goalDirection` | Seeds goal weight + writes program_mode (OV5Flow.swift:300-316); recomp → 0.25%/wk cap; maintenance mode → TargetsService zero rate (120), BandModel (53), chapter `keeping` (DayModel.swift:34), chat program_mode, InsightEngine maintenanceBand, TodayView. | PLAN |
| `onboardingNsvPriority` | `nsv` | Loader tape only (BuildingPlanLoadingView.swift:56). Contract's "reveal echo, lesson affinity" consumers no longer exist. | EXP (one tape line) |
| `onboarding_medication_status` | `medication` | Safety gate: "insulin_or_sulfonylurea" → `.clinicianFirst` route + 0.25%/wk cap (ProgramGoalCalculator.swift:547-550). CohortStore.medicationStatusKey has zero other callers. | PLAN (safety routing) |
| `safety_pregnancy_status`, `safety_scoff_yes/core` | `safetyGate` | safetyAssessment → mode/paceCap/numericSuppression (ProgramGoalCalculator.swift:529-614) → `safety_pace_cap` + `safety_numeric_suppression` + `program_mode` (RevealView:396-408) → clamps every tier's rate, suppresses all numerics app-wide (CohortStore.swift:143-145, TargetsService.swift:60). | PLAN (the strongest lever) |

## Act IV — vulnerability

| key/field | asked at | real consumers found | verdict |
|---|---|---|---|
| `onb_v5_identity` / `identityFeeling` | `identity` (photo grid) | HerFile "becoming" echo (OV5ScreensClose.swift:98); post-purchase CoachIntroView copy (CoachIntroView.swift:49); JeniMethod ritual identity word (JeniMethodRitual.swift:157-166); notification affirmation library (RetentionNotifications.swift:688-695). | EXP |
| `onboardingHormonalStage` | `hormonal` — **asked unconditionally**: router `identity → hormonal` has no gender condition (OV5Flow.swift:476-477); options are cycle-stages only. **A "male" answer at the gender beat still gets the perimenopause question.** | "perimenopause" → 0.3%/wk floor (ProgramGoalCalculator.swift:204-207,326-328) + HardTierGate lock (IntensityProfile.swift:168,181) + CoachNote line; peri also SUPPRESSES cycle/season features (TodaySignals.swift:50,245; BecomingView.swift:128,1986,2001; CoachContextAssembler.swift:94). "postpartum" → CBT postpartum variant + in-flow duty-of-care card. Loader tape + projection chips + dataMirror echo. | PLAN |
| `onboardingPriorAttempts` | `startedOver` | `hasManyPriorAttempts`/`priorAttemptsApprox` (CohortStore.swift:153-165) → CBT `prior_attempts_high` lesson variant (CBTCurriculumTypes.swift:193, threshold ≥4); chat profile; dataMirror echo; loader tape. | EXP (lesson variant + chat; no plan math) |
| `onb_fear_quickResults` | `fear1` | Paywall closing line (PaywallView.swift:1551,1560); fear-resolution beat (OV5FearResolution.swift:137-145); chat fears; barriers/relatability derivation → CoachIntroView. | EXP (live paywall echo confirmed) |
| `onb_fear_anotherDiet` | `fear2` | PaywallView.swift:1552,1558; OV5FearResolution.swift:119-135 (cites her real weeks); chat fears. | EXP |
| `onb_fear_priorAttempt` | `fear3` (general) | PaywallView.swift:1553,1559; OV5FearResolution.swift:110-117; barriers. NOT in chat fears. | EXP |
| `onb_fear_offramp` | `fear3` (current variant) | Fear-resolution only (OV5FearResolution.swift:101-108) + relatability3/barriers. NOT in paywall closing line, NOT in chat. | EXP (thin) |
| `onb_fear_regain` | `fear3` (past variant) | Fear-resolution (OV5FearResolution.swift:92-99) + chat fears. NOT in paywall closing line. | EXP |

## Act V + reveal-collected

| key/field | asked at | real consumers found | verdict |
|---|---|---|---|
| `onb_consent_personalize` | `signature` toggle (OV5ScreensClose.swift:133) | **No reader** outside flow + sweep. Contract's "notification gating" consumer no longer exists. | DEAD |
| `onb_consent_day2` | `signature` toggle (:139) | **No reader**. The day-2 push is not gated on it anywhere. | DEAD |
| `medicalDisclaimerAckAtISO` | `signature` ack | Compliance record → UserRecord.medicalDisclaimerAckAt (PlankAIApp.swift:2684-2688). | PLAN-adjacent (legal record; keep) |
| HealthKit grant | `healthKit` | Steps rail / VitalsService reads. | PLAN |
| `onboardingPickedTier` | reveal PacePicker | Plan totalDays/goalDate (ProgramService.swift:142-158), calorie deficit rate, steps goal (TargetsService.swift:186-192), workout tier (TodayModules.swift:211-224), first-week preview, derivedCommitmentDays, paywall "N-day plan" headline. | PLAN |
| `plankTime` + `notificationsEnabled` | reveal NudgePermissionAsk | Daily-reminder hour (NotificationTimeBucket.swift:51), completion payload notificationTime. | PLAN (notification schedule) |
| `day1Promise*` | reveal commitment | Promise-kept brief input (TodayStateService.swift:282-284), Day-1 push payload. | PLAN/EXP |

## §B legacy fields v5 fills with constants (all confirmed vestigial)

| field | v5 source | readers | verdict |
|---|---|---|---|
| `experience` | derived from movement, never asked | JeniMethodAnalytics props only. `WorkoutGenerator.startingTier(experience:...)` has **zero callers** — live workouts read the plan tier. | ANALYTICS |
| `baselineHoldSeconds` | derived | written to `userBaselineSeconds` — **no reader**. | DEAD |
| `activityLevel` | derived from movement | TargetsService activity fallback + HardTierGate mapping — but `onb_v4_movement_baseline` wins both. | duplicate mirror |
| `barriers` | derived from fears | `userBarriers` → CoachIntroView copy. | EXP (derived) |
| `focusArea` | constant "fullCore" | `userGoal` mapping — `userGoal` itself has **no reader**. | DEAD |
| `bodyFocus` | never set | Live only via post-purchase EditProfile. | vestigial |
| `voicePreference` | constant "encouraging" | Live axis later (settings, CBT voice axis, notification coach name) — not an onboarding datum anymore. | vestigial constant |
| `bodyTypeCurrent/Desired`, `relatability1-3`, `rewardChoice`, `workoutLocation/Style` | constants/derived | UserRecord sync only. | DEAD |
| `plankTime` bucket / `commitmentDaysPerWeek` / `sessionLengthMinutes` | derived | commitmentDays + sessionLengthPref paywall @AppStorage declarations (PaywallView.swift:162-163) **unused in the current wall body**; no other reader. | DEAD mirrors |
| `onboardingTriedBefore` | **not asked in v5 at all** | legacy OnboardingView only + sweep. | DEAD |
| `onb_restrictive_food` | never asked (honored if ever set — CohortStore.swift:135-137) | latent input to isRestrictiveRisk. | latent |

## The plan function actually reads

1. **Duration window / goal date** (`ProgramGoalCalculator.compute`, :168-245): `currentWeightKg`, `goalWeightKg`, `glp1_status=="current"`, `glp1_phase=="just_started"`, `hormonalStage=="perimenopause"`, `sleepHours∈{under5,five6}`, `weight_trend=="cycling"`, safety `paceCap`. **`sex` and `age` are accepted and ignored** (RevealView:319 comment; PlankAIApp.swift:2693 TODO).
2. **Daily calories** (`CalorieTargetCalculator.dailyTarget` via TargetsService.swift:89-133): latest weight, height, exact age (else band midpoint), gender (male +166 kcal BMR; nonbinary/private→female), movement baseline, plan-implied rate.
3. **Protein** (TargetsService.swift:146-165): weight × 1.6 if glp1-current else 1.2.
4. **Steps** (TargetsService.swift:186-192): pickedTier only.
5. **Safety routing** (ProgramGoalCalculator.swift:529-614): ageRange, medication_status, SCOFF yes/core (+glp1_status), pregnancy status, BMI → mode / paceCap / numeric suppression.
6. **Hard-tier lock** (IntensityProfile.swift:164-172): glp1-current, peri, age≥40, sedentary.
7. **Daily composition** (PrescriptionEngineV2 + CarePlanEngine chapter): glp1_status, foodRelationship (restrictive), program_mode (maintenance), stress (high), shot day.
8. **Notifications**: glp1_status (cohort copy), plankTime, notificationsEnabled, identityFeeling + userName (affirmation texture).

## Questions whose answers change nothing today (candidates under the founder's rule)

Full beats collecting dead data:
- **`appetiteReturn`** (past branch) — zero readers.
- **`supports`** (current branch) — zero readers (FR8 "intake fact" that nothing consumes).
- **`priorWin`** — zero readers (claimed reveal echo is gone).
- **`attribution`** — analytics-only (legitimate under a different rule; shapes nothing she experiences).

Beats whose only consumer is one loader-tape line:
- **`nsv`** — tape only; claimed lesson-affinity/reveal-echo consumers no longer exist.
- **`stopWindow`** (past branch) — tape only (4 cohort variants).

Signature-screen toggles that gate nothing:
- **`onb_consent_personalize`** and **`onb_consent_day2`** — zero readers; the claimed notification gating does not exist in code.

Near-duplicates in the "tried before" family: v5 asks `priorAttempts` (live: CBT variant + chat) AND `priorWin` (dead) AND carries `onboardingTriedBefore` (never asked, dead) — one live question, two dead siblings. Similarly `outcome` collapses 4 of 5 answers to the same legacy value, leaving the dossier echo as its main effect.

Gender-specific finding: **gender is plan-live (calorie math only) but the flow ignores it structurally** — a "male" answer still routes through the perimenopause question, and no copy anywhere conditions on it.

## Conditionality that EXISTS today

- **In-flow routing**: only `glp1Status` branches the router. `fear3` content varies by cohort; NSV adds a cohort option; foodNoise/whyItCameBack teach copy varies by cohort. Nothing else branches — gender, sleep, stress, hormonal answers change acks/copy but never the path.
- **Pace floor cascade** (ProgramGoalCalculator.swift:204-218): glp1-current OR peri OR just_started → 0.3%; else short-sleep → 0.4%; else cycling-trend → 0.4%; else 0.5%; safety paceCap clamps all.
- **Suppression gates**: safety numericSuppression (ED/pregnant) kills all numerics; restrictiveRisk (from foodRelationship) mutes kcal-register narration; peri suppresses cycle/season surfaces.
- **Chapter spine**: glp1-current → onMedication, maintenance → keeping, else losing (DayModel.swift:32-55).
- **Echo surfaces that make answers visible**: loader tape (14 keys), projection causal receipts (glp1/sleep/peri/trend), pace provenance line, dataMirror, act receipts, herFile dossier, paywall closing line (3 fear keys), fear-resolution beat (5 fear keys), first-week rails (glp1 + shot day), wall plan band (weight→protein, shot day).
