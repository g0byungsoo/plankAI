-- absmaxxing — Orphaned anonymous-user cleanup (ADMIN MAINTENANCE)
--
-- ============================================================
-- ==  FOUNDER-RUN ONLY. DESTRUCTIVE. NOT WIRED TO ANYTHING. ==
-- ==  ALWAYS RUN THE DRY-RUN SELECT FIRST AND READ THE LIST ==
-- ==  BEFORE RUNNING STEP 2. THERE IS NO UNDO.              ==
-- ============================================================
--
-- Why this exists: the app is anonymous-first. When a user upgrades an
-- anonymous session to a named account (Apple / email), the sign-in
-- merge mints FRESH row ids under the new uid — the old anonymous uid
-- and its copies of her health data (weight logs, food logs, program
-- state, …) are left behind in auth.users + the public tables. Those
-- orphans survive account deletion (delete_user_account only scopes to
-- the CALLING uid) and accumulate forever. This script reaps anonymous
-- accounts with no sign-in activity for N days.
--
-- Safety properties:
--   * Only touches rows where auth.users.is_anonymous = true. Named
--     accounts (Apple / email) are NEVER matched, no matter how stale.
--   * "Activity" = last_sign_in_at, falling back to created_at for
--     accounts that never completed a sign-in.
--   * Public-table data cascades automatically: every user-data table
--     FKs auth.users(id) ON DELETE CASCADE (scripts/schema.sql).
--   * storage.objects does NOT cascade — food-photos objects are
--     deleted explicitly, by owner and by uid path prefix.
--
-- Parameter: retention window in days. Default 90. To change it,
-- edit the `retention_days` value in BOTH steps below.
--
-- Run in: Supabase dashboard SQL editor (runs as postgres, bypasses
-- RLS — which is exactly why it must never be exposed to clients).

-- =====================================================================
-- STEP 1 — DRY RUN (read-only). Run this first, every time.
-- =====================================================================
--
-- Lists every anonymous account the destructive step WOULD delete,
-- with its data footprint. Expect mostly-empty rows (abandoned
-- onboarding sessions). If a row shows a heavy footprint AND recent
-- table activity, investigate before deleting.

WITH params AS (
    SELECT 90 AS retention_days          -- <— retention window (days)
),
candidates AS (
    SELECT u.id, u.created_at, u.last_sign_in_at
    FROM auth.users u, params p
    WHERE u.is_anonymous = true
      AND COALESCE(u.last_sign_in_at, u.created_at)
          < now() - make_interval(days => p.retention_days)
)
SELECT
    c.id,
    c.created_at,
    c.last_sign_in_at,
    (SELECT count(*) FROM public.weight_logs w WHERE w.user_id = c.id)   AS weight_logs,
    (SELECT count(*) FROM public.food_logs f WHERE f.user_id = c.id)     AS food_logs,
    (SELECT count(*) FROM public.session_logs s WHERE s.user_id = c.id)  AS session_logs,
    (SELECT count(*) FROM public.day_progress d WHERE d.user_id = c.id)  AS day_progress,
    (SELECT count(*) FROM public.program_plans pp WHERE pp.user_id = c.id) AS program_plans,
    (SELECT count(*) FROM storage.objects o
      WHERE o.bucket_id = 'food-photos'
        AND o.name LIKE c.id::text || '/%')                              AS food_photos
FROM candidates c
ORDER BY c.created_at;

-- =====================================================================
-- STEP 2 — DESTRUCTIVE DELETE. Only after reviewing Step 1's output.
-- =====================================================================
--
-- ██ DESTRUCTIVE ██ Deletes the listed auth.users rows. Public-table
-- data cascades; storage objects are purged explicitly first. Keep the
-- retention_days value IDENTICAL to Step 1 or you will delete a
-- different set than you reviewed.

DO $$
DECLARE
    retention_days constant int := 90;   -- <— keep in sync with Step 1
    cutoff timestamptz := now() - make_interval(days => retention_days);
    deleted_users int;
    deleted_objects int;
BEGIN
    -- 2a. Purge orphaned food-photos objects (no cascade from auth.users).
    DELETE FROM storage.objects o
    WHERE o.bucket_id = 'food-photos'
      AND EXISTS (
          SELECT 1 FROM auth.users u
          WHERE u.is_anonymous = true
            AND COALESCE(u.last_sign_in_at, u.created_at) < cutoff
            AND (o.name LIKE u.id::text || '/%' OR o.owner = u.id)
      );
    GET DIAGNOSTICS deleted_objects = ROW_COUNT;

    -- 2b. Delete the anonymous auth rows; public tables cascade.
    DELETE FROM auth.users u
    WHERE u.is_anonymous = true
      AND COALESCE(u.last_sign_in_at, u.created_at) < cutoff;
    GET DIAGNOSTICS deleted_users = ROW_COUNT;

    RAISE NOTICE 'cleanup_orphaned_anon_users: deleted % anon users, % storage objects (cutoff %)',
        deleted_users, deleted_objects, cutoff;
END $$;
