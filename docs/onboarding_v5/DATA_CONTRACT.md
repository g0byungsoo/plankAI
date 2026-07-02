# Onboarding v5 — Data Contract

Audited 2026-07-02 against `OnboardingView.swift` (v1.1.3),
`PlankAIApp.handleOnboardingComplete`, `OnboardingRevealView`,
`ProgramGoalCalculator`, `CalorieTargetCalculator`. v5 MUST keep every
row here alive. "Writer" = where v5 collects it.

## A. AppStorage keys written during the question flow

| Key | Values | Consumers |
|---|---|---|
| `onboarding_glp1_status` | `none/considering/past/current/prefer_not_say` | Glp1Cohort (notifications, Becoming identity, paywall), pace floor via `isGLP1User` |
| `onboarding_glp1_phase` | `just_started/few_months/established/prefer_not` | `isEarlyGLP1` pace floor |
| `onboardingHormonalStage` | `cycling/irregular/postpartum/perimenopause/postmenopause/prefer_not_say` | `isPerimenopausal` floor, postpartum duty-of-care |
| `onboardingSleepHours` | `under5/five6/six7/seven8/eightPlus` | `isShortSleeper` pace penalty, lifecycle copy |
| `onboardingStressLevel` | option string | lesson affinity, copy |
| `onboarding_weight_trend` | `climbing/stable/declining/cycling` | `isRegainRisk` pace notch, reveal copy |
| `onboarding_goal_direction` | `lose/maintain/maintain_kept/recomp` (maintain* sets goal=current + program_mode=maintenance; recomp = gentle ~0.25%/wk) | goal-weight slider seeding, program_mode |
| `program_mode` | `loss/maintenance` | ProgramService, reveal framing, safety gate |
| `onboarding_medication_status` | `none/insulin_sulf/glp1/other/prefer_not`* | SafetyGate `.clinicianFirst` |
| `onboardingEatingCadence` | `one_meal/two_meals/three_meals/grazing/chaotic` | food rail copy |
| `onboardingFoodRelationship` | `fuel/comfort/love/control/complicated` | CBT curriculum, reveal echo |
| `onboardingPriorAttempts` | option string | CBT curriculum seed |
| `onboardingPriorWin` | option string | reveal echo |
| `onboardingTriedBefore` | option string | copy |
| `onboardingCuisinePreference` | CSV of cuisine keys | food-vision prompt hint, QuickAdd chips |
| `onboarding_dietary` | CSV (pattern + restrictions + allergies) | food-vision dietary_profile, nutrition program |
| `onboardingNsvPriority` | CSV of NSV keys | reveal echo, lesson affinity |
| `onb_fear_quickResults` / `onb_fear_anotherDiet` / `onb_fear_priorAttempt` | `yes/no/""` | paywall objection copy, CBT |
| `onb_consent_personalize` / `onb_consent_day2` | Bool | notification gating |
| `onb_v4_movement_baseline` | option string | WorkoutGenerator.baselineSeconds, legacy activity mirrors |
| `onboardingPickedTier` | `gentle/medium/strong` (default `medium`) | pace everywhere (written by reveal PacePicker; v5 flow must NOT double-ask) |

RULE while building: before writing any v5 screen, read the matching
v4.5 case body and copy option keys VERBATIM (labels may change, keys
may not). Rows still unverified are marked *.

## B. Completion pipeline (`finish()` → `OnboardingData` → `handleOnboardingComplete`)

`OnboardingData` fields v5 must assemble (names are load-bearing):
`goal` (motivation), `experience`, `baselineHoldSeconds` (derived from
movement baseline), `barriers` [String], `ageRange` (band mirror of ageYears via
`bucketize`: `under18/18to24/25to34/35to44/45to54/55plus`), `activityLevel`,
`focusArea` (legacy; default `fullCore`), `plankTime`,
`commitmentDaysPerWeek`, `sessionLengthMinutes`, `notificationsEnabled`,
`notificationTime`, `name`, `voicePreference` (default `encouraging`),
`bodyFocus` [String], `motivation`, `workoutLocation`, `workoutStyle`,
`gender` (`female/male/nonbinary/private`), `heightCm`,
`currentWeightKg`, `goalWeightKg`, `bodyTypeCurrent/Desired` (Int 0-5;
legacy — seed 3), `identityFeeling`, `rewardChoice`,
`relatability1/2/3` (legacy Bools — derive from fears), `acquisitionSource`
(`tiktok/instagram/friend/app_store/google/other`).

`handleOnboardingComplete` then writes: `userName`, `userGoal`,
`userExperience`, `voicePreference`, `userMotivation`, `ageRange`,
`activityLevel`, `focusArea`, `bodyFocus`, `plankTime`,
`commitmentDays`, `sessionLengthPref`, `userBaselineSeconds`,
`userBarriers`, `identityFeeling`, `notificationsEnabled`,
`onboardingCurrentWeightKg`, `onboardingGoalWeightKg`,
`onboardingGoalDate`, UserRecord upsert (+ Supabase sync) +
ClinicalBaseline compute + `medicalDisclaimerAckAtISO` readback.

**v5 decision: do not touch `handleOnboardingComplete`.** v5 assembles
the same struct. Anything new v5 collects rides its own AppStorage key.

## C. Reveal sequence (kept, re-skinned)

`OnboardingRevealView` owns post-finish: disclaimer (writes
`medicalDisclaimerAckAtISO`) → SafetyGate (pregnancy/SCOFF/BMI/meds
routing; only `.loss`+healthy passes) → BuildingPlanLoadingView →
PacePicker (writes `onboardingPickedTier` + soft-floor rate) →
Projection → FirstWeek → RatingAsk → Commitment (Day-1 promise nudge)
→ NudgePermissionAsk (notifications) → `onRevealComplete` → paywall.

v5 flow hands off to this sequence exactly as v4.5 does (same
constructor args). Re-skin work happens INSIDE these presentations,
never to their side effects.

## D. New v5 keys (only with a live consumer)

| Key | Values | Consumer |
|---|---|---|
| `onb_v5_snap_demo_meal` | `bowl/toast/plate/skipped` | Day-0 first-snap lifecycle copy (post-purchase bridge cites the demo meal) |
| `onb_v5_seen` | Bool | analytics segmentation of v5 vs v4.5 installs |

Everything else new that v5 asks must map onto an EXISTING key or be
cut (data-provenance rule: collect nothing without a consumer).
