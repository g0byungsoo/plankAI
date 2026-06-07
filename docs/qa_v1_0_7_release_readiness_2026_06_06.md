# QA pass — v1.0.7 release readiness verdict

**Date:** 2026-06-06
**QA team:** 1 manager + 2 generalists + 3 engineers (Cal AI / WL program / DB integrity)
**Scope:** Founder's 11 release concerns

---

## TL;DR — Release verdict

**CONDITIONAL GO.** Two production blockers, both fixable in 30–60 minutes of code or one config flip. Five HIGH items worth shipping (small patches, real impact). LOW items defer cleanly.

### The 2 blockers

1. **Food log persistence is in-memory only.** `FoodLogPersister.inMemoryEntries` — every food log is lost on app restart. Directly violates founder concerns 8 ("food data must be stored in DB") and 11 ("food log system must not lose data"). User scans 5 meals → backgrounds → reopens at lunch → today's plate empty + Becoming balance card silently shows gained=0 + full BMR/steps/workout = false "you're ahead of plan ♥". This is the highest-impact UX regression in the release.
2. **PostHog `identify(supabase_user_id)` never called in production.** `PlankAIApp.swift:228` identifies only in `#if DEBUG`. Production users stay anonymous distinct_ids forever — Apple/email upgrade creates two separate PostHog Persons, cross-device users never unified, Supabase joins impossible. Funnel cohorts will split on every launch.

Both fixable today.

---

## BLOCKER 1 — Food log persistence

**Reports converged on this from DB engineer + calorie engineer.**

> "FoodLogRecord @Model exists in /Users/bko/plankAI/Packages/PlankFood/Sources/PlankFood/Model/FoodLogRecord.swift:19 but is intentionally NOT in the ModelContainer (PlankAIApp.swift:281-296). Risk is only if a future v1.0.8 enables it WITHOUT a VersionedSchema + MigrationPlan."

**Recommended fix path A (30-line patch, ships v1.0.7):**
Add a UserDefaults JSON-blob fallback that survives restarts. `FoodLogPersister` keeps the in-memory entries hot for the session AND persists to UserDefaults on every change. Restore from UserDefaults at first read. Namespaced per-userId. No SwiftData migration risk.

**Recommended fix path B (current state, ship with UX note):**
Add an explicit copy line on the food card: "logs reset on app restart — full sync in v1.0.8." Sets expectations; lowest dev cost; founder must accept the brand-position cost.

**Recommended fix path C (defer to v1.0.8):**
Current state stands. Concerns 8 + 11 fail. Cohort regresses noticeably. NOT recommended for ship.

---

## BLOCKER 2 — PostHog `identify` in production

```swift
// PlankAIApp.swift:228 (current)
#if DEBUG
PostHogSDK.shared.identify("dev-\(vendorId)")
#endif
```

**Fix:** Move `identify` out of the DEBUG block, identify with `currentUser.id.uuidString` post-bootstrap + post-Apple/email upgrade. Wire in AuthService after `bootstrap()` resolves and in the Apple/email upgrade success path. ~10-line patch.

**Without this fix:** entire launch funnel analysis is broken. Cannot compute trial conversion by signup method, cannot segment by Supabase user_id, cannot trace cross-device sessions.

---

## HIGH (should fix before ship — ~2 hours total)

1. **`workout_start` fires only on workout COMPLETE** — `HomeView.swift:1066`. Funnel reports 100% start→complete conversion because the start event emits when complete already happened. Move `firstWorkoutStart` to session-launch.

2. **CohortCatalog persisted kcal drifts via band-bucketing midpoint** — `(kcalLow + kcalHigh)/2` ≠ `item.kcal` for several items (oatmeal 320→300, pizza 320→300, sweetgreen kale 520→500, americano 15→10). Per-meal small; aggregates 50-100 kcal/day error in Becoming balance for heavy quick-add users. Fix: persist `item.kcal` when present, fall back to range midpoint only for ImOutTonight estimates.

3. **No `posthogScreen(...)` modifier applied anywhere** — rageclicks have no screen attribution (memory `project_app_observability_gaps` flagged; still unfixed). Add `.posthogScreen(...)` to each top-level NavigationStack root OR `Analytics.captureScreen` in `onAppear` on Paywall, OnboardingView, RoutineSessionView, CaptureFlowView, ProfileHubView, MainTabView tabs.

4. **BreathworkState not user-scoped** — `UserDefaults` keys `breathwork.total_completed` / `weekly_day_keys` are global. Sign-out → sign-in to different account inherits prior user's breath count. Cross-account leak on shared/test devices. 5-line fix: namespace keys by current userId.

5. **Confirm `FOOD_VISION_MODEL=gpt-5` Supabase secret** in prod before release. Config-only fix; if unset, food-vision falls back to gpt-4o (per memory `feedback_food_vision_models` the locked decision was GPT-5 for accuracy).

6. **AppSync.clearLocalUserData doesn't delete WeightLogRecord** — Delete Account flow leaves prior account's weight logs in SwiftData on re-bootstrap. 5-line fix in AppSync.swift:361-398.

7. **ImOutTonight Mexican center 600 kcal too low** — cohort-typical Chipotle bowl + chips-and-guac lands 750-900 kcal. Suggest center → 750 (one-line change in `FoodCaptureDispatcher.swift:122`).

---

## LOW (post-ship)

- Dead `tileGrid` / `tileButton` / `QuickAddEditSheet` in QuickAddView (unreachable after chip cloud refactor — cleanup pass)
- `capturedPhoto` not cleared on retake from result phase header (mirror line 261 reset)
- mode chips have no useful VoiceOver labels — emoji glyph names read verbatim (PhotoCaptureView:264-300)
- Long Task with sleep(600ms) in CaptureFlowView camera→result — use `.task` modifier for auto-cancel
- New v1.0.7 onboarding food-rail columns in schema (`onboarding_prior_apps_used`, `onboarding_cuisine_preference`, etc.) not sent in upsert payload — dead at launch for cohort analysis but not user-facing
- SessionRatingRecord @Model registered + queried, never written — pre-existing gap, no regression
- Legacy v1.0.6 SKU constants still named `absmaxxing_*` (no user-facing impact)
- Missing events: `log_weight_tapped`, `depth_sheet_opened`, `refresh_workout_tapped`, `becoming_opened`, per-chip-tap on CohortCatalog, balance/spent breakdown taps, identity caption taps
- `dietEducationStarted` / `dietEducationActionCompleted` enum values defined but never fired

---

## VERIFIED — Founder concern coverage

| # | Concern | Status |
|---|---|---|
| 1 | New users see paywall at end of onboarding | ✅ Hard paywall fullScreenCover at PlankAIApp:437; gated by `!effectiveHasProAccess && !isInAuthTransition` |
| 2 | Existing paid users skip paywall | ✅ PaymentService.init seeds from `lastKnownEntitlementKey` UserDefaults cache; customerInfoStream confirms within 500ms; 3s safety timeout |
| 3 | Paywall 100% functional | ✅ Cover dismissable=false, restore button always visible, transactionAbandoned tracking, quarterly default plan computed from goal-to-12-weeks math |
| 4 | Nothing broken in onboarding | ✅ 28 fields persisted in `handleOnboardingComplete`, all 4 workout-generator keys written, AppStorage retains answers across cold-kill mid-flow |
| 5 | Custom workout creation intact | ✅ HomeView's WorkoutGenerator reads `userGoal` / `bodyFocus` / `sessionLengthPref` / `userExperience` — all written by onboarding, all mirrored by AppSync after Apple sign-in upgrade |
| 6 | Onboarding personalization questions functional | ✅ Q140, Q111, Q22, age range, height, weights, baseline, activity level — all persisted to UserDefaults AND UserRecord with Supabase sync |
| 7 | No DB changes impacting current users | ✅ `git log scripts/schema.sql` shows only ADDITIVE changes since v1.0.6 baseline (new tables + ADD COLUMN IF NOT EXISTS). Zero columns dropped/renamed/retyped. v1.0.6 clients reading existing tables see no change. |
| 8 | Necessary food/health data stored in DB | ⚠️ **BLOCKER 1** — food logs in-memory only. Weight/sessions/day_progress all sync correctly. Steps from HealthKit (passive read, no DB). Breath state local-only + cross-account leak (HIGH item). |
| 9 | PostHog logs for important actions | ⚠️ **BLOCKER 2** — 70+ events fire BUT no production identify, no screen attribution, workout_start fires on complete |
| 10 | Calorie tracking accurate | ✅ USDA Branded-filter fix holds; Mifflin-St Jeor BMR correct; balance card math correct; calorie hero on scan result; CapturedFood.totalKcal guards against partial USDA join. ⚠️ Mexican cuisine center low, CatalogItem drift small |
| 11 | Food log doesn't lose/alter data | ⚠️ **BLOCKER 1** — cold-launch wipe. End-to-end sync chain VERIFIED (photo/quickAdd/imOut → CapturedFood → onLogged → persist → changeNotifier → HomeFoodCard.refresh) but persistence layer is volatile. |

---

## Recommended release path

1. **Fix the 2 blockers** (~60 minutes): UserDefaults JSON fallback for FoodLogPersister + move PostHog identify to production
2. **Optionally fix 2-3 of the HIGH items** (`workout_start` placement, BreathworkState user-scoping, CohortCatalog kcal drift) — ~30 minutes each
3. **Confirm `FOOD_VISION_MODEL=gpt-5` Supabase secret** in prod (config — founder action)
4. **Bump CURRENT_PROJECT_VERSION 12 → 13** for the patch
5. **Archive + upload to TestFlight**
