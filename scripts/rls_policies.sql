-- absmaxxing — Row Level Security policies
-- Run this in Supabase SQL editor BEFORE testing the auth integration.
--
-- Idempotent + table-existence-tolerant: every block checks `to_regclass`
-- first. If the table doesn't exist yet, the block is skipped (no error).
-- Re-running after creating tables applies their policies cleanly.
--
-- Pattern for every user-data table:
--   1. ALTER TABLE ... ENABLE ROW LEVEL SECURITY
--   2. SELECT  policy: auth.uid() = user_id
--   3. INSERT  policy: auth.uid() = user_id
--   4. UPDATE  policy: auth.uid() = user_id (USING + WITH CHECK)
--   5. DELETE  policy: auth.uid() = user_id
--
-- The `users` table keys on `id` (= auth.uid()), every other user-data
-- table keys on `user_id`. RLS rejects any row whose user_id ≠ caller's
-- auth.uid(), even when the client uses the anon public key.
--
-- Content tables (exercise_bank, workout_presets): RLS on, read-only for
-- authenticated users. Writes are service_role only.

-- =====================================================================
-- USER-DATA TABLES
-- =====================================================================

-- ---------- users ----------
DO $$
BEGIN
    IF to_regclass('public.users') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.users ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "users_select_own" ON public.users';
        EXECUTE 'DROP POLICY IF EXISTS "users_insert_own" ON public.users';
        EXECUTE 'DROP POLICY IF EXISTS "users_update_own" ON public.users';
        EXECUTE 'DROP POLICY IF EXISTS "users_delete_own" ON public.users';
        EXECUTE 'CREATE POLICY "users_select_own" ON public.users FOR SELECT TO authenticated USING (auth.uid() = id)';
        EXECUTE 'CREATE POLICY "users_insert_own" ON public.users FOR INSERT TO authenticated WITH CHECK (auth.uid() = id)';
        EXECUTE 'CREATE POLICY "users_update_own" ON public.users FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id)';
        EXECUTE 'CREATE POLICY "users_delete_own" ON public.users FOR DELETE TO authenticated USING (auth.uid() = id)';
    END IF;
END $$;

-- ---------- session_logs ----------
DO $$
BEGIN
    IF to_regclass('public.session_logs') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.session_logs ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "session_logs_select_own" ON public.session_logs';
        EXECUTE 'DROP POLICY IF EXISTS "session_logs_insert_own" ON public.session_logs';
        EXECUTE 'DROP POLICY IF EXISTS "session_logs_update_own" ON public.session_logs';
        EXECUTE 'DROP POLICY IF EXISTS "session_logs_delete_own" ON public.session_logs';
        EXECUTE 'CREATE POLICY "session_logs_select_own" ON public.session_logs FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_logs_insert_own" ON public.session_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_logs_update_own" ON public.session_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_logs_delete_own" ON public.session_logs FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- day_progress ----------
DO $$
BEGIN
    IF to_regclass('public.day_progress') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.day_progress ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "day_progress_select_own" ON public.day_progress';
        EXECUTE 'DROP POLICY IF EXISTS "day_progress_insert_own" ON public.day_progress';
        EXECUTE 'DROP POLICY IF EXISTS "day_progress_update_own" ON public.day_progress';
        EXECUTE 'DROP POLICY IF EXISTS "day_progress_delete_own" ON public.day_progress';
        EXECUTE 'CREATE POLICY "day_progress_select_own" ON public.day_progress FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "day_progress_insert_own" ON public.day_progress FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "day_progress_update_own" ON public.day_progress FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "day_progress_delete_own" ON public.day_progress FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- weight_logs ----------
DO $$
BEGIN
    IF to_regclass('public.weight_logs') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.weight_logs ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "weight_logs_select_own" ON public.weight_logs';
        EXECUTE 'DROP POLICY IF EXISTS "weight_logs_insert_own" ON public.weight_logs';
        EXECUTE 'DROP POLICY IF EXISTS "weight_logs_update_own" ON public.weight_logs';
        EXECUTE 'DROP POLICY IF EXISTS "weight_logs_delete_own" ON public.weight_logs';
        EXECUTE 'CREATE POLICY "weight_logs_select_own" ON public.weight_logs FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "weight_logs_insert_own" ON public.weight_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "weight_logs_update_own" ON public.weight_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "weight_logs_delete_own" ON public.weight_logs FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- onboarding_profiles ----------
DO $$
BEGIN
    IF to_regclass('public.onboarding_profiles') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.onboarding_profiles ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "onboarding_profiles_select_own" ON public.onboarding_profiles';
        EXECUTE 'DROP POLICY IF EXISTS "onboarding_profiles_insert_own" ON public.onboarding_profiles';
        EXECUTE 'DROP POLICY IF EXISTS "onboarding_profiles_update_own" ON public.onboarding_profiles';
        EXECUTE 'DROP POLICY IF EXISTS "onboarding_profiles_delete_own" ON public.onboarding_profiles';
        EXECUTE 'CREATE POLICY "onboarding_profiles_select_own" ON public.onboarding_profiles FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "onboarding_profiles_insert_own" ON public.onboarding_profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "onboarding_profiles_update_own" ON public.onboarding_profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "onboarding_profiles_delete_own" ON public.onboarding_profiles FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- session_ratings ----------
DO $$
BEGIN
    IF to_regclass('public.session_ratings') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.session_ratings ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "session_ratings_select_own" ON public.session_ratings';
        EXECUTE 'DROP POLICY IF EXISTS "session_ratings_insert_own" ON public.session_ratings';
        EXECUTE 'DROP POLICY IF EXISTS "session_ratings_update_own" ON public.session_ratings';
        EXECUTE 'DROP POLICY IF EXISTS "session_ratings_delete_own" ON public.session_ratings';
        EXECUTE 'CREATE POLICY "session_ratings_select_own" ON public.session_ratings FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_ratings_insert_own" ON public.session_ratings FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_ratings_update_own" ON public.session_ratings FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "session_ratings_delete_own" ON public.session_ratings FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- exercise_results ----------
DO $$
BEGIN
    IF to_regclass('public.exercise_results') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.exercise_results ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_results_select_own" ON public.exercise_results';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_results_insert_own" ON public.exercise_results';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_results_update_own" ON public.exercise_results';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_results_delete_own" ON public.exercise_results';
        EXECUTE 'CREATE POLICY "exercise_results_select_own" ON public.exercise_results FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_results_insert_own" ON public.exercise_results FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_results_update_own" ON public.exercise_results FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_results_delete_own" ON public.exercise_results FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- performance_metrics ----------
DO $$
BEGIN
    IF to_regclass('public.performance_metrics') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.performance_metrics ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "performance_metrics_select_own" ON public.performance_metrics';
        EXECUTE 'DROP POLICY IF EXISTS "performance_metrics_insert_own" ON public.performance_metrics';
        EXECUTE 'DROP POLICY IF EXISTS "performance_metrics_update_own" ON public.performance_metrics';
        EXECUTE 'DROP POLICY IF EXISTS "performance_metrics_delete_own" ON public.performance_metrics';
        EXECUTE 'CREATE POLICY "performance_metrics_select_own" ON public.performance_metrics FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "performance_metrics_insert_own" ON public.performance_metrics FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "performance_metrics_update_own" ON public.performance_metrics FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "performance_metrics_delete_own" ON public.performance_metrics FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- ---------- exercise_calibrations ----------
DO $$
BEGIN
    IF to_regclass('public.exercise_calibrations') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.exercise_calibrations ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_calibrations_select_own" ON public.exercise_calibrations';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_calibrations_insert_own" ON public.exercise_calibrations';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_calibrations_update_own" ON public.exercise_calibrations';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_calibrations_delete_own" ON public.exercise_calibrations';
        EXECUTE 'CREATE POLICY "exercise_calibrations_select_own" ON public.exercise_calibrations FOR SELECT TO authenticated USING (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_calibrations_insert_own" ON public.exercise_calibrations FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_calibrations_update_own" ON public.exercise_calibrations FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id)';
        EXECUTE 'CREATE POLICY "exercise_calibrations_delete_own" ON public.exercise_calibrations FOR DELETE TO authenticated USING (auth.uid() = user_id)';
    END IF;
END $$;

-- =====================================================================
-- CONTENT TABLES (read-only for authenticated users)
-- =====================================================================

-- ---------- exercise_bank ----------
DO $$
BEGIN
    IF to_regclass('public.exercise_bank') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.exercise_bank ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "exercise_bank_read_all" ON public.exercise_bank';
        EXECUTE 'CREATE POLICY "exercise_bank_read_all" ON public.exercise_bank FOR SELECT TO authenticated USING (true)';
    END IF;
END $$;

-- ---------- workout_presets ----------
DO $$
BEGIN
    IF to_regclass('public.workout_presets') IS NOT NULL THEN
        EXECUTE 'ALTER TABLE public.workout_presets ENABLE ROW LEVEL SECURITY';
        EXECUTE 'DROP POLICY IF EXISTS "workout_presets_read_all" ON public.workout_presets';
        EXECUTE 'CREATE POLICY "workout_presets_read_all" ON public.workout_presets FOR SELECT TO authenticated USING (true)';
    END IF;
END $$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================
--
-- 1. Confirm RLS is enabled on every table that exists:
--      SELECT schemaname, tablename, rowsecurity
--      FROM pg_tables
--      WHERE schemaname = 'public'
--      ORDER BY tablename;
--    Expected: rowsecurity = true on every table that exists.
--
-- 2. List policies per table:
--      SELECT schemaname, tablename, policyname, cmd
--      FROM pg_policies
--      WHERE schemaname = 'public'
--      ORDER BY tablename, cmd;
--
-- 3. Cross-user isolation smoke test (run as User A's JWT):
--      INSERT INTO public.session_logs (id, user_id, ...) VALUES (..., '<user_b_uuid>', ...);
--    Expected: ERROR — new row violates row-level security policy.
--
-- 4. List which expected tables are missing (run before assuming the
--    script applied everything you want):
--      SELECT t.expected
--      FROM (VALUES
--          ('users'), ('session_logs'), ('day_progress'),
--          ('onboarding_profiles'), ('session_ratings'),
--          ('exercise_results'), ('performance_metrics'),
--          ('exercise_calibrations'), ('exercise_bank'), ('workout_presets')
--      ) AS t(expected)
--      WHERE to_regclass('public.' || t.expected) IS NULL;
