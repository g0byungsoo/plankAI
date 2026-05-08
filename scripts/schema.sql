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
-- Next step
-- =====================================================================
--
-- 1. Run scripts/rls_policies.sql to enable RLS + apply per-table policies.
-- 2. Verify in Authentication → Policies that every table above shows the
--    expected select/insert/update/delete-own policies.
-- 3. From the iOS app, run a session → check public.session_logs for the
--    new row attached to your auth.uid().
