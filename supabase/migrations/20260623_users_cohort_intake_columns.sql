-- 2026-06-23 — Persistence P0 (medical-grade / GLP-1 partnership).
-- docs/medical_grade_survey_audit_2026_06_23.md
--
-- The onboarding cohort + clinical-intake signals (GLP-1 status, hormonal
-- stage, weight trajectory, and the lifestyle answers) drove in-app cohort
-- routing but were AppStorage-only and never synced — so the GLP-1 cohort
-- the whole strategy routes on never reached the backend, and no cohort
-- analytics (retention/outcomes by cohort) was possible.
--
-- The app now writes these into public.users on onboarding-complete +
-- restores them on cross-device hydrate (SyncService.upsertUser /
-- hydrateUser, UserRecord). This migration adds the matching columns.
--
-- All nullable text (self-reported, no drug brand names, no dose).
-- IF NOT EXISTS makes it safe to re-run. RUN ONCE on the Supabase project
-- (SQL editor or `supabase db push`).

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS onboarding_glp1_status       text,  -- none/considering/past/current/prefer_not_say
  ADD COLUMN IF NOT EXISTS onboarding_glp1_phase        text,  -- just_started/few_months/established/prefer_not (current only)
  ADD COLUMN IF NOT EXISTS onboarding_hormonal_stage    text,  -- cycling/irregular/postpartum/perimenopause/postmenopause/prefer_not_say
  ADD COLUMN IF NOT EXISTS onboarding_weight_trend      text,  -- climbing/stable/declining/cycling
  ADD COLUMN IF NOT EXISTS onboarding_sleep_hours       text,  -- band key
  ADD COLUMN IF NOT EXISTS onboarding_stress_level      text,  -- low/manageable/heavy/overwhelmed
  ADD COLUMN IF NOT EXISTS onboarding_eating_cadence    text,  -- meal-pattern key
  ADD COLUMN IF NOT EXISTS onboarding_eating_window     text,  -- eating-window key
  ADD COLUMN IF NOT EXISTS onboarding_food_relationship text;  -- fuel/comfort/love/control/complicated

-- Verify (expect 9 rows):
-- SELECT column_name FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'users'
--     AND column_name LIKE 'onboarding_%'
--     AND column_name IN (
--       'onboarding_glp1_status','onboarding_glp1_phase','onboarding_hormonal_stage',
--       'onboarding_weight_trend','onboarding_sleep_hours','onboarding_stress_level',
--       'onboarding_eating_cadence','onboarding_eating_window','onboarding_food_relationship');
