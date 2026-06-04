-- JeniFit — Supabase schema
-- Run this in Supabase SQL editor BEFORE testing cloud sync.
-- Idempotent: re-running is safe (CREATE TABLE IF NOT EXISTS, CREATE INDEX
-- IF NOT EXISTS, ALTER TABLE ... ADD COLUMN IF NOT EXISTS).
--
-- 2026-05-04 update — schema brought in sync with production. Adds the
-- three legacy columns that SyncService.upsertUser was already sending
-- (focus_area, plank_time, session_length_pref) which existed in the
-- production DB but were missing from this script. Plus three Phase 4
-- additions (body_focus, current_weight_kg, goal_weight_kg). The
-- IF NOT EXISTS guards make all six idempotent for already-applied
-- production tables.
--
-- After this runs, also (re-)run scripts/rls_policies.sql to apply RLS.
-- The two are intentionally split so you can iterate on either independently.
--
-- Schema mirrors the SwiftData @Models in
-- Packages/PlankSync/Sources/PlankSync/Models.swift. Column names use
-- snake_case to match what SyncService.upsert* sends in its payload dicts.
--
-- All user-data tables FK to auth.users(id) directly (Supabase manages that
-- table; rows auto-create on signInAnonymously / signUp / signIn). We do not
-- FK to public.users, because PlankApp does not currently insert profile
-- rows server-side — the FK would block session writes for users without a
-- profile yet. RLS still enforces auth.uid() = user_id on every row.

-- =====================================================================
-- public.users — profile table, 1:1 with auth.users
-- =====================================================================
--
-- Optional. Phase F does not write here yet. Listed for completeness so
-- the schema matches the design doc + UserRecord model. Future phase
-- can sync onboarding profile fields here.

CREATE TABLE IF NOT EXISTS public.users (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL DEFAULT '',
    start_date timestamptz NOT NULL DEFAULT now(),
    current_day int NOT NULL DEFAULT 1,
    core_score double precision NOT NULL DEFAULT 0,
    last_session_date timestamptz,
    streak_current int NOT NULL DEFAULT 0,
    streak_longest int NOT NULL DEFAULT 0,
    streak_last_reset_date timestamptz,
    program_phase text NOT NULL DEFAULT 'foundations',
    foundations_completed_date timestamptz,
    onboarding_goal text,
    onboarding_experience text,
    onboarding_baseline_hold_seconds int,
    onboarding_barriers text[],
    onboarding_age_range text,
    onboarding_activity_level text,
    onboarding_commitment_days_per_week int,
    onboarding_notification_enabled boolean NOT NULL DEFAULT false,
    onboarding_notification_time timestamptz,
    onboarding_voice_preference text
);

-- Bring scripts/schema.sql in sync with production columns + add Phase 4
-- additions. All idempotent — already-present columns are no-ops.

-- Legacy columns missing from the original CREATE TABLE but in production
-- (SyncService.upsertUser has been sending these since the focusArea era).
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_focus_area text,
    ADD COLUMN IF NOT EXISTS onboarding_plank_time text,
    ADD COLUMN IF NOT EXISTS onboarding_session_length_pref int;

-- Phase 4 additions: bodyFocus drives paywall personalization + plan
-- reveal subhead; weights drive the prediction screens and need to
-- survive reinstall / cross-device sign-in.
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_body_focus text[],
    ADD COLUMN IF NOT EXISTS onboarding_current_weight_kg double precision,
    ADD COLUMN IF NOT EXISTS onboarding_goal_weight_kg double precision;

-- 2026-05-04 — Phase 4 remaining 11 onboarding fields
--
-- Adds the 11 fields the original 3-field migration deferred. All
-- columns nullable so a legacy row carrying NULL is the "not answered"
-- signal — once OnboardingData adopts optional Swift types in v1.1,
-- the column shape is already forward-compatible. relatability_1/2/3
-- are three separate boolean columns rather than a single text[]
-- because a yes/no per-statement is more useful in cohort analysis.
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_motivation text,
    ADD COLUMN IF NOT EXISTS onboarding_workout_location text,
    ADD COLUMN IF NOT EXISTS onboarding_workout_style text[],
    ADD COLUMN IF NOT EXISTS onboarding_gender text,
    ADD COLUMN IF NOT EXISTS onboarding_height_cm double precision,
    ADD COLUMN IF NOT EXISTS onboarding_body_type_current int,
    ADD COLUMN IF NOT EXISTS onboarding_body_type_desired int,
    ADD COLUMN IF NOT EXISTS onboarding_identity_feeling text,
    ADD COLUMN IF NOT EXISTS onboarding_reward_choice text,
    ADD COLUMN IF NOT EXISTS onboarding_relatability_1 boolean,
    ADD COLUMN IF NOT EXISTS onboarding_relatability_2 boolean,
    ADD COLUMN IF NOT EXISTS onboarding_relatability_3 boolean;

-- 2026-05-30 — epic #1 child #7. TikTok/IG/friend attribution. Nullable;
-- legacy rows get NULL, no migration prompt. The ONE schema exception
-- in v1.0.7 because attribution is durable signal worth keeping
-- (vision-injection questions stay session-scope per #6).
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS onboarding_acquisition_source text;

-- =====================================================================
-- public.session_logs — append-only session record
-- =====================================================================
--
-- Client-generated UUIDs (text), so retries from a crash idempotently
-- upsert without collision. Phase F's HomeView writes here on every
-- routine + benchmark completion.

CREATE TABLE IF NOT EXISTS public.session_logs (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_type text NOT NULL,
    session_type text NOT NULL DEFAULT 'plank_benchmark',  -- "routine" | "plank_benchmark"
    completed_at timestamptz NOT NULL DEFAULT now(),
    hold_time double precision NOT NULL DEFAULT 0,
    target_time double precision NOT NULL DEFAULT 0,
    quality_score double precision NOT NULL DEFAULT 0,
    form_faults_count int NOT NULL DEFAULT 0,
    modified_version boolean NOT NULL DEFAULT false,
    -- v2 routine fields
    preset_id text,
    total_duration double precision,
    plank_hold_time double precision,
    plank_form_score double precision,
    exercise_results jsonb
);

CREATE INDEX IF NOT EXISTS session_logs_user_completed_idx
    ON public.session_logs (user_id, completed_at DESC);

-- =====================================================================
-- public.day_progress — derived state, one row per user per program_day
-- =====================================================================
--
-- Last-write-wins on updated_at. Phase F's HomeView upserts here after
-- every session completion. The composite primary key
-- (user_id, program_day) replaces SwiftData's compositeKey artifact.

CREATE TABLE IF NOT EXISTS public.day_progress (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    program_day int NOT NULL,
    date timestamptz NOT NULL DEFAULT now(),
    primary_session_id text,
    primary_quality_score double precision NOT NULL DEFAULT 0,
    primary_hold_time double precision NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT now(),
    session_log_ids text[],
    PRIMARY KEY (user_id, program_day)
);

CREATE INDEX IF NOT EXISTS day_progress_user_idx
    ON public.day_progress (user_id);

-- =====================================================================
-- public.session_ratings — 1-5 star post-session rating
-- =====================================================================
--
-- SwiftData's SessionRatingRecord lacked a user_id column; we add one
-- here so RLS can scope rows. Future SwiftData migration should add it
-- locally too.

CREATE TABLE IF NOT EXISTS public.session_ratings (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_log_id text NOT NULL,
    rating int NOT NULL CHECK (rating >= 1 AND rating <= 5),
    tags text[] NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS session_ratings_user_idx
    ON public.session_ratings (user_id);

CREATE INDEX IF NOT EXISTS session_ratings_session_idx
    ON public.session_ratings (session_log_id);

-- =====================================================================
-- public.exercise_calibrations — per-exercise difficulty
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.exercise_calibrations (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_type text NOT NULL,
    difficulty text NOT NULL DEFAULT 'full',  -- "regression" | "modified" | "full"
    calibrated_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, exercise_type)
);

-- =====================================================================
-- public.exercise_bank — content table (no user data, read-only via RLS)
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.exercise_bank (
    type text PRIMARY KEY,
    unlock_day int NOT NULL,
    is_static boolean NOT NULL DEFAULT true
);

-- Seed the foundations program (idempotent — UPSERT on type).
INSERT INTO public.exercise_bank (type, unlock_day, is_static) VALUES
    ('plank',      1,  true),
    ('deadBug',    8,  false),
    ('sidePlank',  15, true),
    ('hollowHold', 22, true),
    ('birdDog',    22, false)
ON CONFLICT (type) DO UPDATE SET
    unlock_day = EXCLUDED.unlock_day,
    is_static = EXCLUDED.is_static;

-- =====================================================================
-- public.weight_logs — append-only weight history
-- =====================================================================
--
-- Phase 7 (weight-loss analytics). Append-only timeline of weigh-ins;
-- the analytics surface reads this to draw the 7-day EMA trend.
-- See docs/weight_loss_analytics_research.md.
--
-- `source` audits input modality:
--   onboarding   — seeded from users.onboarding_current_weight_kg
--   manual       — user typed it on the analytics tab
--   healthkit    — pulled from Apple Health (Phase 7b)
--
-- Client-generated UUIDs so crash retries idempotently upsert.

CREATE TABLE IF NOT EXISTS public.weight_logs (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    weight_kg double precision NOT NULL,
    logged_at timestamptz NOT NULL DEFAULT now(),
    source text NOT NULL DEFAULT 'manual',
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS weight_logs_user_logged_idx
    ON public.weight_logs (user_id, logged_at DESC);

-- 2026-05-07 — Postgres GRANT for the authenticated role.
-- Tables created via raw SQL (vs. the Supabase Table Editor UI) don't get
-- the implicit role grants the dashboard adds; without this, every insert
-- 42501s "permission denied" before RLS even evaluates. Idempotent — Postgres
-- allows re-granting the same privileges. Anonymous-bootstrap users still
-- run as `authenticated` (not `anon`), so this single grant covers them.
GRANT SELECT, INSERT, UPDATE, DELETE ON public.weight_logs TO authenticated;

-- =====================================================================
-- (Optional) Auto-create users profile row on auth.users insert
-- =====================================================================
--
-- Uncomment if you want every newly-signed-in user (anonymous or
-- otherwise) to automatically have a public.users row. Without this,
-- public.users stays empty until the app explicitly upserts a profile,
-- which Phase F does not do. Session writes still work either way
-- because session_logs FKs to auth.users, not public.users.
--
-- CREATE OR REPLACE FUNCTION public.handle_new_user()
-- RETURNS trigger
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path = public
-- AS $$
-- BEGIN
--     INSERT INTO public.users (id) VALUES (new.id) ON CONFLICT DO NOTHING;
--     RETURN new;
-- END;
-- $$;
--
-- DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
-- CREATE TRIGGER on_auth_user_created
--     AFTER INSERT ON auth.users
--     FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =====================================================================
-- food rail (v1.0.7) — food_logs, food_log_items, food_corrections,
-- canonical_pantry, jenimethod_lessons
-- =====================================================================
--
-- 2026-06-04 — per docs/food_rail_plan.md (v5 wins). Hybrid schema per
-- v3 §Architecture: stable queryable columns + JSONB payload for
-- evolving fields. Items live in their own table (1-to-many to a parent
-- food_log row). Corrections-as-moat data is analytics-only, separate
-- from user-visible food_logs. canonical_pantry + jenimethod_lessons
-- are public-content tables (all authenticated users read; writes
-- service_role only).
--
-- D35 lock: NO streak fields anywhere. The "showing up streak" was
-- skipped entirely (cohort year-2 retention risk per
-- feedback_food_ux_antishame). "Showing up" stays as language in Jeni
-- greeting copy, never as a metric.
--
-- Order matters: canonical_pantry MUST be created before food_log_items
-- because food_log_items.canonical_pantry_id has an FK reference. Other
-- FK chains: food_log_items + food_corrections both reference food_logs.

-- ---------- canonical_pantry ----------
-- Hand-curated cohort-specific entries. ~100 at launch per v3 pantry
-- ordering (25 beverages / 15 girl-dinner / 15 Korean / 20 restaurant
-- chains / 10 Mediterranean / 15 Mexican); expand via correction-rate
-- analysis after launch. Public-content table: authenticated users read;
-- writes service_role only via curator workflow.

CREATE TABLE IF NOT EXISTS public.canonical_pantry (
    id text PRIMARY KEY,
    name text NOT NULL,
    search_terms text[] NOT NULL,
    cuisine_hint text,
    category text,                    -- 'beverage' | 'girl_dinner' | 'korean' | ...
    default_serving_g double precision NOT NULL,
    kcal_per_100g double precision NOT NULL,
    protein_per_100g double precision NOT NULL DEFAULT 0,
    carbs_per_100g double precision NOT NULL DEFAULT 0,
    fat_per_100g double precision NOT NULL DEFAULT 0,
    fiber_per_100g double precision,
    source text,                       -- 'manual_curator' | 'starbucks_official' | ...
    reviewed_by text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS canonical_pantry_search_idx
    ON public.canonical_pantry USING GIN (search_terms);

CREATE INDEX IF NOT EXISTS canonical_pantry_category_idx
    ON public.canonical_pantry (category, cuisine_hint);

-- Read-only for authenticated users. No INSERT/UPDATE/DELETE grant —
-- writes happen via service_role (curator workflow / migrations only).
GRANT SELECT ON public.canonical_pantry TO authenticated;

-- ---------- food_logs ----------

CREATE TABLE IF NOT EXISTS public.food_logs (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    logged_at timestamptz NOT NULL DEFAULT now(),
    meal_slot text CHECK (meal_slot IN ('breakfast','lunch','dinner','snack')),
    kcal_total double precision NOT NULL,
    -- Range fields for restaurant_estimate source (per v1 §Three wedges).
    -- For single-value sources kcal_total_low/high mirror kcal_total or
    -- stay NULL — readers should prefer kcal_total unless source is range-like.
    kcal_total_low double precision,
    kcal_total_high double precision,
    protein_g double precision,
    carbs_g double precision,
    fat_g double precision,
    fiber_g double precision,
    plate_type text NOT NULL DEFAULT 'single',
    -- Capture source enum — mirrors FoodCapture cases in Swift
    -- (Packages/PlankFood/Sources/PlankFood/PlankFood.swift). Future
    -- modes (barcode/voice/text/menu) are in the CHECK list so a plug-in
    -- ship doesn't need a schema migration.
    source text NOT NULL DEFAULT 'photo' CHECK (source IN (
        'photo','quick_add','im_out','restaurant_estimate',
        'barcode','voice','text','menu'
    )),
    -- D13 pre-eat mode tracking. NULL = pre-D13 entry or non-photo source.
    photo_mode text CHECK (photo_mode IN ('just_ate','deciding')),
    confidence double precision,
    -- Evolving fields per v3 schema design: cuisine_hint, needs_second_photo,
    -- restaurant_metadata, glp1_context, correction_history, etc. Anything
    -- not stable enough yet for a real column. Promote to a column when hot.
    payload jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS food_logs_user_logged_idx
    ON public.food_logs (user_id, logged_at DESC);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_logs TO authenticated;

-- ---------- food_log_items ----------
-- Items as a separate table per v3 schema design. Parent delete cascades.
-- user_id replicated for RLS performance (saves a join on every read).
-- llm_* columns preserve the original model output so we can compute
-- correction-diff post-hoc for the corrections-as-moat dataset.

CREATE TABLE IF NOT EXISTS public.food_log_items (
    id text PRIMARY KEY,
    food_log_id text NOT NULL REFERENCES public.food_logs(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    portion_g double precision NOT NULL,
    kcal double precision NOT NULL,
    protein_g double precision,
    carbs_g double precision,
    fat_g double precision,
    -- Lookup source: which DB answered (USDA / OFF / pantry / LLM only)
    usda_fdc_id int,
    canonical_pantry_id text REFERENCES public.canonical_pantry(id) ON DELETE SET NULL,
    open_food_facts_code text,
    -- Original LLM-suggested fields, kept even after user correction so
    -- corrections-as-moat can compute the diff. NULL = no LLM (quick_add etc).
    llm_name text,
    llm_portion_g double precision,
    llm_confidence double precision,
    position int NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS food_log_items_log_idx
    ON public.food_log_items (food_log_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_log_items TO authenticated;

-- ---------- food_corrections ----------
-- Corrections-as-moat data per v3. ~5KB per scan; raw photo opt-in only
-- (30-day auto-delete via photo_retention_expires_at + Edge Function
-- food-photo-cleanup). NOT user-visible — the corrections sheet writes
-- here but the user never reads from this table directly. Used for
-- (a) cohort-fit telemetry, (b) future fine-tune dataset assembly at
-- Phase 3 (v1.1) when ~50k corrections accumulated (per v3 D27).

CREATE TABLE IF NOT EXISTS public.food_corrections (
    id text PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    food_log_id text REFERENCES public.food_logs(id) ON DELETE SET NULL,
    scan_timestamp timestamptz NOT NULL DEFAULT now(),
    image_hash text NOT NULL,             -- perceptual hash, always stored
    image_url text,                        -- nullable; set only when consent_to_train
    llm_provider text,                     -- 'openai' | 'anthropic' | 'gemini'
    llm_model_version text,
    llm_raw_output jsonb,
    user_corrections jsonb,                -- diff between LLM and final
    final_logged jsonb,                    -- what got saved to food_logs
    cuisine_profile jsonb,                 -- snapshot at time of scan, for ablation
    consent_to_train boolean NOT NULL DEFAULT false,
    photo_retention_expires_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS food_corrections_user_idx
    ON public.food_corrections (user_id, scan_timestamp DESC);

CREATE INDEX IF NOT EXISTS food_corrections_retention_idx
    ON public.food_corrections (photo_retention_expires_at)
    WHERE photo_retention_expires_at IS NOT NULL;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.food_corrections TO authenticated;

-- ---------- jenimethod_lessons ----------
-- D30 — JeniMethod content moves from hardcoded JeniMethodContent.swift
-- enum cases to Supabase content table. Unblocks v1.0.8 content-only
-- delivery (Days 31-75) without app submission.
--
-- 75-day arc: Days 1-15 = original (with Day 2 reorder per D28).
-- Days 16-30 = food rail intro + cohort eating (ships v1.0.7).
-- Days 31-75 = depth + cycle + plateau + identity completion (v1.0.8
-- content update). Day 76+ = generic maintenance pool (is_generic=true).
--
-- D34 lock: Day number displayed in UI is JUST "Day N" — NEVER
-- "Day N of 75". 75 Hard adjacency is cohort-toxic.
-- D49 lock: catch-up tiles for missed days surface as items, never
-- reset day counter. day_number advances every calendar day.

CREATE TABLE IF NOT EXISTS public.jenimethod_lessons (
    day_number int PRIMARY KEY,
    title text NOT NULL,
    -- Pages array shape: [{ headline, body, illustration_asset }, ...]
    -- 2 pages is the locked default per feedback_jenimethod_design;
    -- some lessons may be 1 or 3 pages.
    pages jsonb NOT NULL,
    illustration_asset text,
    -- Optional today's prompt linking the lesson to a food/movement action.
    -- Shape: { kind: 'food_scan'|'quick_add'|'movement'|'reflect', copy: '...' }
    today_prompt jsonb,
    -- Soft publishing controls — server can hide a lesson without an app deploy
    published_at timestamptz,
    -- Day 76+ "generic" maintenance pool (cycled weekly, never numbered)
    is_generic boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS jenimethod_lessons_generic_idx
    ON public.jenimethod_lessons (is_generic, day_number);

-- Read-only for authenticated users.
GRANT SELECT ON public.jenimethod_lessons TO authenticated;

-- ---------- public.users — food onboarding fields ----------
-- D40 onboarding restructure: 4 new questions added (Q300/Q301/Q303/Q304).
-- Q302 cuisine moves to Act 3. All nullable so legacy v1 users carry
-- NULL = "not answered" — a retro-prompt fires at first scan attempt
-- per v4 Existing-user-journey §2 Option A.

ALTER TABLE public.users
    -- Q300 multi-select competitor list
    ADD COLUMN IF NOT EXISTS onboarding_prior_apps_used text,
    -- Q301 multi-select failure modes (conditional on Q300 ≠ "none yet")
    ADD COLUMN IF NOT EXISTS onboarding_prior_apps_failure_modes text,
    -- Q302 cuisine multi-select (Act 3 per D39)
    ADD COLUMN IF NOT EXISTS onboarding_cuisine_preference text,
    -- Q303 single-select 4-option (often / weekly / occasionally / rarely)
    ADD COLUMN IF NOT EXISTS onboarding_dining_frequency text,
    -- Q304 single-select photo comfort
    ADD COLUMN IF NOT EXISTS onboarding_photo_comfort text;

-- One-time Apple 5.1.2(i) AI disclosure modal acceptance. Re-prompt if
-- NULL or older than the current provider contract date. Per v3 + v5
-- Honesty Doctrine: "we send your photo to read the plate. openai +
-- anthropic see it. they don't train on it. photo's gone after."

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS food_ai_consent_at timestamptz;

-- ---------- food_vision_telemetry ----------
-- Append-only log of every food-vision Edge Function invocation. Powers
-- the daily budget kill-switch ($50/day cap) and per-user rate limit
-- (30 scans/day) per v3 D26 + v5 §Sprint W1-T3.
--
-- Service-role-only access: RLS is enabled with NO policies, so
-- authenticated users cannot read/write. The Edge Function uses the
-- service_role key (bypasses RLS by design). Keeps per-user scan
-- patterns and cost data invisible from the client.
--
-- One row per Edge Function call, regardless of outcome. status='success'
-- = LLM responded; status='rate_limit'|'budget_cap' = rejected before
-- LLM; status='error' = LLM call failed. cost_usd is 0 for the rejected
-- variants (no LLM call made).

CREATE TABLE IF NOT EXISTS public.food_vision_telemetry (
    id text PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    requested_at timestamptz NOT NULL DEFAULT now(),
    model text NOT NULL,
    cost_usd numeric(10, 6) NOT NULL DEFAULT 0,
    tokens_in integer,
    tokens_out integer,
    duration_ms integer,
    status text NOT NULL CHECK (status IN ('success','rate_limit','budget_cap','error'))
);

-- Budget cap queries filter `WHERE requested_at >= start_of_day_iso`,
-- which is a range scan satisfied by a plain btree on requested_at.
-- (Avoid date_trunc here — it's STABLE not IMMUTABLE so Postgres
-- rejects it in index expressions with error 42P17.)
CREATE INDEX IF NOT EXISTS food_vision_telemetry_requested_idx
    ON public.food_vision_telemetry (requested_at DESC);

CREATE INDEX IF NOT EXISTS food_vision_telemetry_user_day_idx
    ON public.food_vision_telemetry (user_id, requested_at DESC);

-- Service-role-only (no SELECT/INSERT/UPDATE/DELETE for authenticated).
-- The Edge Function uses SUPABASE_SERVICE_ROLE_KEY which bypasses RLS.
ALTER TABLE public.food_vision_telemetry ENABLE ROW LEVEL SECURITY;
-- No policies defined = no authenticated access. service_role still works.

-- =====================================================================
-- Next step
-- =====================================================================
--
-- 1. Run scripts/rls_policies.sql to enable RLS + apply per-table policies.
-- 2. Verify in Authentication → Policies that every table above shows the
--    expected select/insert/update/delete-own policies.
-- 3. From the iOS app, run a session → check public.session_logs for the
--    new row attached to your auth.uid().
