# 06 — Data model + Supabase wiring plan

## Intent

Fix the wiring defects the audit found, add the minimum new storage
chat + the ritual need, and make cohort context survive devices.
No breaking changes to existing tables; additive migrations only.

## A. Canonical cohort store (fixes defect #2)

New `CohortStore` (PlankApp/Program/CohortStore.swift) — the ONLY
reader of cohort-ish AppStorage keys, exposing typed accessors:
`glp1Cohort`, `isEarlyGLP1`, `isPerimenopausal`, `isShortSleeper`,
`isRegainRisk`, `restrictiveRisk` (derived: `onb_restrictive_food` OR
foodRelationship ∈ {control, complicated}), `stressBand`,
`priorAttemptsBand`, `programMode`, `appetiteRhythm`, `goalDirection`.

- `CBTCurriculumTypes.CohortFlags.fromAppStorage` is rewired to read
  through CohortStore's canonical keys (kills the zero-writer reads:
  `onb_glp1_status`, `onb_stress_level`, `onb_prior_attempts_count`,
  `onb_food_noise`, `onb_perimenopausal`, `onb_pcos`).
- PlanView/MainTabView/AnalyticsView inline key reads migrate to it.
- Chat context + brief engine + prescription engine read only it.

## B. users table — sync the cohort columns that gate behavior

Migration `20260703_users_v2_cohort_columns.sql` (additive):
`program_mode text`, `goal_direction text`, `medication_status text`,
`dietary_csv text`, `nsv_priority_csv text`, `appetite_rhythm text`,
`glp1_stop_window text`, `fears_csv text`, `snap_demo_meal text`.
`SupabaseUserUpsert`/`Row` extend accordingly; hydrate mirrors back
to the canonical AppStorage keys (restores safety-gate + paywall +
copy context on device switch — defect #7).

## C. New tables

```sql
create table public.coach_messages (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('user','jeni','tool')),
  body text not null,
  tool_name text, tool_payload jsonb,
  day_key text not null,           -- '2026-07-03' local-day bucketing
  created_at timestamptz not null default now()
);
create table public.jeni_chat_telemetry (   -- EF service-role only
  id bigint generated always as identity primary key,
  user_id uuid not null, model text, input_tokens int, output_tokens int,
  cost_usd numeric(8,5), status text, duration_ms int,
  created_at timestamptz not null default now()
);
create table public.day_reflections (
  id text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  day_key text not null, feeling text not null,
  created_at timestamptz not null default now(),
  unique (user_id, day_key)
);
```
RLS: `coach_messages` + `day_reflections` standard auth.uid()=user_id
CRUD; `jeni_chat_telemetry` RLS-enabled with **no policies** (mirrors
food_vision_telemetry — service-role only). Ship in one migration
with the column adds; RLS statements in the same file so the runbook
gap can't recur for new tables.

## D. Sync layer additions (PlankSync)

- `ChatMessageRecord` @Model + upsert/hydrate (last 50, LWW by
  created_at) — registered in the app container (single-package @Model
  like the existing nine; the food-package hang doesn't apply).
- `DayReflectionRecord` @Model + upsert (tiny).
- `SessionRatingRecord` gains `userId` (lightweight migration; field
  optional-defaulted) + `upsertSessionRating`; PostRoutine's rating
  finally writes it (fixes defect #3). Cross-account isolation via
  the same `@Query userId` discipline.
- Hydration policy (defect #8): `hydrateAndSync` also runs when
  `lastHydratedAt` > 24h old (stored per-user), not only on empty
  cache. Pending-upsert-first ordering preserved.

## E. Food

- Wire `onboardingCuisinePreference` + `onboarding_dietary` into
  `FoodVisionService.scan` defaults when FoodSettings hasn't
  overridden them (defect #9) — one resolver in FoodModule.configure.
- Journal/plate detail storage stays JSONL device-local (v1.2
  decision stands); v2 adds nothing server-side here beyond what
  ships. Documented trade-off: per-item detail doesn't survive
  reinstall; plate-level does.

## F. Derived-state services (no storage)

- `TargetsService` (04) — pure reads over UserRecord + WeightLog +
  active plan.
- `TodayStateService` — one @Observable aggregating today's plates
  (FoodLogPersister), steps (StepsService), checks
  (ProgramDayCheckRecord), weigh-in state; Today + chat + brief all
  read this single object (kills the triple-tile duplication).

## G. Explicit non-goals

No auth changes; no RevenueCat schema changes; no food_log_items
server writes; no photo uploads. UUID-case discipline: all new
hydrates store the uppercase Swift userId per the established rule.
