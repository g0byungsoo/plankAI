-- 2026-06-28 - Phase 1a: computed_start_bmi, target_rate_pct_per_week, medical_disclaimer_ack_at, promises_kept
--
-- These fields were computed at onboarding and stored device-local only.
-- Now synced via SyncService.upsertUser / hydrateUser (UserRecord Phase 1a).
--
-- computed_start_bmi: BMI derived from weight + height at onboarding completion.
-- target_rate_pct_per_week: cohort-adjusted loss-rate floor (GLP-1 / perimenopause /
--   short-sleep modifiers encoded) used to size the program plan.
-- medical_disclaimer_ack_at: timestamp the user acknowledged the medical disclaimer
--   screen; nil = not yet seen.
-- promises_kept: cumulative count of habit completions honoured (lesson, breath,
--   food log, weigh-in). Non-null with default 0 so existing rows are safe.
--
-- IF NOT EXISTS makes it safe to re-run. RUN ONCE on the Supabase project
-- (SQL editor or `supabase db push`).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS computed_start_bmi         double precision,
  ADD COLUMN IF NOT EXISTS target_rate_pct_per_week   double precision,
  ADD COLUMN IF NOT EXISTS medical_disclaimer_ack_at  timestamptz,
  ADD COLUMN IF NOT EXISTS promises_kept              integer not null default 0;

-- Verify (expect 4 rows):
-- SELECT column_name FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'users'
--     AND column_name IN (
--       'computed_start_bmi', 'target_rate_pct_per_week',
--       'medical_disclaimer_ack_at', 'promises_kept');
