# JeniFit current onboarding map — v2 (2026-06-10)

Source: `PlankApp/Views/Onboarding/OnboardingView.swift` (v2FlowOrder line 1666–1736) + `OnboardingRevealView.swift` (6-phase reveal sequence). Code-grounded, not screenshot-inferred.

---

## Summary

- **48 screens** in v2FlowOrder + **6 reveal phases** post-question.
- **49 signals** collected total.
- **17** persisted to UserRecord (Supabase-synced), **20** AppStorage-only, **8** session-scope `@State`.
- **WorkoutGenerator consumes only 6 of 49 (12%).**
- **1 signal fully dead, 9 partially dead** — collected for loading-copy color or context chips but not for actual program adaptation.

---

## Part 1 — v2FlowOrder screen sequence

| Pos | Case | Type | Purpose | Signal Key | Storage | Status |
|-----|------|------|---------|------------|---------|--------|
| 1-2 | 200, 230 | Divider + Education | "part one: your story" + anti-shame anchor | — | — | Active |
| 3 | 1 | Question | "what's your why?" (goal) | goal | UserRecord | Active |
| 4 | 100 | Question | Attribution ("how did you hear?") | acquisitionSource | UserRecord + Supabase | Active |
| 5 | 168 | Question | "tried everything already?" (sunk-cost) | triedBefore | onboardingTriedBefore | Active |
| 6-11 | 162, 166, 156, 157, 159, 169 | Food wedge | Food relationship → cuisine | foodRelationship, eatingCadence, eatingWindow, priorWin, cuisinePreference | Mixed | Active |
| 12-17 | 110, 2, 8, 25, 17, 270 | Workout cluster + quiz | Body focus → activity → session length → days → habit teach | bodyFocus, experience, activityLevel, sessionLength, commitmentDays | UserRecord | Active |
| 18-26 | 231, 130, 7, 131, 132, 133, 136, 160, 161 | Biometric core | Gender → age → height → current/goal weight → NSV cards → first prediction | gender, ageYears, heightCm, currentWeightKg, goalWeightKg, nsvPriority | UserRecord + onboardingNsvPriority CSV | Active |
| 27 | 167 | Question | "how do you want to get there?" (pace) | paceChoice | onboardingPaceChoice | Active |
| 28-36 | 203, 140, 233, 158, 154, 155, 163, 164, 142 | Identity + vulnerability | Identity → prior attempts → sleep → stress → hormonal → GLP-1 → comparison | identityFeeling, priorAttempts, sleepHours, stressLevel, hormonalStage, glp1Status | Mixed | Active |
| 37-40 | 165, 145, 170, 260 | Confidence + proof | Commitment confidence → video demo → re-prediction → tier ladder | commitConfidence | onboardingCommitConfidence | **Dead** |
| 41-48 | 153, 206, 205, 3, 11, 18, 234, 21 | Relatability + recap + final | Relatability multi → recap → divider → plank → notif time → name → plateau teach → plan reveal | relatabilityMulti, baseline, plankTime, name | UserRecord | Active |

---

## Part 2 — Reveal sequence (6 phases, triggered by case 21)

1. **BuildingPlanLoadingView** (~25s) — proof-line rotation (reads sleep, stress, eatingCadence, eatingWindow, priorAttempts)
2. **ProjectionPresentation** (~8s) — calorie hero + weight curve + context chips (reads currentWeightKg, goalWeightKg, sleep, eatingCadence, hormonalStage, glp1Status; writes foodDailyTarget)
3. **PacePickerPresentation** (interactive) — writes onboardingPickedTier
4. **GoalDateRevealPresentation** (~4s) — ACSM 0.75%/wk derived date
5. **FirstWeekPresentation** (~6s) — 7 generated workouts (reads onboardingPickedTier, bodyFocus, sessionLength)
6. **PairedPermissionsAsk** (~5s) — HealthKit + Notifications dual-ask

---

## Part 3 — Signal inventory

### Persisted to UserRecord (17, Supabase-synced)
goal, acquisitionSource, bodyFocus, experience, activityLevel, sessionLength, commitmentDays, gender, ageYears, heightCm, currentWeightKg, goalWeightKg, identityFeeling, baseline, plankTime, name, voicePreference

### AppStorage-only (20)
onboardingTriedBefore, onboardingFoodRelationship, onboardingEatingCadence, onboardingEatingWindow, onboardingPriorWin, onboardingCuisinePreference (CSV), onboardingPriorAttempts, onboardingSleepHours, onboardingStressLevel, onboardingHormonalStage, onboarding_glp1_status, onboardingCommitConfidence, onboardingPaceChoice, onboardingNsvPriority (CSV), onboardingCurrentWeightKg, onboardingGoalWeightKg, onboardingAgeRange, onboardingActivityLevel, foodDailyTarget, onboardingPickedTier

### Session-scope `@State` only (8)
eatingContext (Q237), dailyActivityLevel (Q238), bodyPhotoReadiness (Q239), monthSignals (Q235), priorWorkouts (Q236), rewardChoice (Q141), relatability1/2/3 (legacy Bool? trio)

### Never consumed (1)
habitQuizSelected (Q270 reveal-pattern flag)

---

## Part 4 — Downstream consumption map

| Consumer | Signals read | Count |
|----------|--------------|-------|
| WorkoutGenerator | goal, bodyFocus, sessionLength, commitmentDays, experience, activityLevel | **6** |
| PaywallView (headline personalization) | onboardingPickedTier, hormonalStage, glp1Status | 3 |
| ProjectionPresentation (chips + curve) | currentWeightKg, goalWeightKg, sleep, eatingCadence, hormonalStage, glp1Status | 6 |
| BuildingPlanLoadingView (proof-line tone) | sleep, stressLevel, eatingCadence, eatingWindow, priorAttempts | 5 |
| ProgramSetupSubflow | currentWeightKg, goalWeightKg, ageRange, activityLevel, glp1Status, hormonalStage, onboardingPickedTier | 7 |
| FoodSettingsView / PlanView | onboardingCuisinePreference | 1 |

**WorkoutGenerator uses 6 of 49 collected signals (12%).**

---

## Part 5 — Dead & underutilized signals

### Fully dead (1)
- **onboardingCommitConfidence** (case 165) — written, never read. Collected per Cal AI D67 investment-lock pattern for psychological effect only.

### Partially dead (9) — read only for loading copy / context chips, NOT used to adapt the program
1. **onboardingTriedBefore** — loading-tone ramp, not in WorkoutGenerator
2. **onboardingPriorAttempts** — loading-copy only; intended for Becoming-tab barrier-resolution (Rhodes & de Bruijn 2013), not wired
3. **onboardingFoodRelationship** — commented "calibrate voice", no actual consumer
4. **onboardingEatingCadence** — context chip only; food-rail v2 future consumer
5. **onboardingEatingWindow** — context chip only; late-night-eating stall pattern not adapted
6. **onboardingStressLevel** — loading proof-line only
7. **onboardingSleepHours** — context chip; sleep-adaptive intensity not implemented
8. **onboardingPriorWin** — loading proof-line; could seed running-compatible workouts, not implemented
9. **onboardingNsvPriority** — context chip; "becomes Becoming-tab future", no consumer

---

## Part 6 — Inconsistencies / notes

1. Case 19 (coach selector) cut from v2FlowOrder but still in `currentScreen` switch for v1 back-nav safety
2. Cases 134/135 (body-image AI sliders) cut and replaced with case 136 (NSV outcome cards)
3. `ageYears` + `ageRange` dual-field pattern syncs via onChange — candidate for consolidation
4. Case 165 (commitConfidence) is v2-only; v1 skips it
5. onboardingPaceChoice default was "steady" until 2026-06-07; now "" to avoid anchoring
6. Case 169 (cuisine multi-select) was leaking pre-selected on re-runs; fixed via `resetSingleSelectOnboardingFields()`
7. Case 166 (pre-eat permission wedge) is educational, auto-advance

---

## Part 7 — Flow statistics

| Metric | Value |
|--------|-------|
| Screens in v2FlowOrder | 48 |
| Signals collected | 49 |
| → UserRecord (Supabase) | 17 |
| → AppStorage only | 20 |
| → Session-scope only | 8 |
| Consumed by WorkoutGenerator | 6 (12%) |
| Fully dead signals | 1 |
| Partially dead signals | 9 (18%) |
| Educational auto-advance screens | 6 |
| Question screens (radio/multi/slider/picker/text) | 30 |
| Reveal phases | 6 |
