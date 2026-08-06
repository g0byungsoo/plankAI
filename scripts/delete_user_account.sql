-- absmaxxing — Delete Account RPC
-- Apple App Store Review Guideline 5.1.1(v) requires every app that creates an
-- account to also let the user delete it from inside the app. Without this RPC
-- the client can't reach auth.users (Supabase's RLS blocks direct DELETE).
--
-- SECURITY DEFINER lets the function run with the function-owner's privileges
-- (typically supabase_admin), bypassing RLS so it can DELETE FROM auth.users.
-- The function still scopes deletion to auth.uid() — it never deletes a row
-- the requesting user doesn't own — so privilege escalation isn't possible.
--
-- Idempotent. Safe to re-run after schema changes.
--
-- Cascades: every user-data table FKs to auth.users(id) ON DELETE CASCADE
-- (see scripts/schema.sql). Deleting the auth.users row removes:
--   public.users, session_logs, day_progress, session_ratings,
--   exercise_calibrations
-- automatically. We do not need explicit DELETEs in this function.
--
-- Storage note: storage.objects rows do NOT cascade from auth.users
-- (owner is SET NULL, not CASCADE), so the user's food-photos objects
-- must be deleted explicitly. Objects live at {user_id}/{entry_id}.jpg
-- (see scripts/food_photos_storage.sql); we delete by bucket + own-uid
-- prefix AND by owner as belt-and-braces. Deleting the storage.objects
-- row makes the object unreachable immediately; the underlying blob is
-- garbage-collected by Supabase Storage.
--
-- Orphaned anon-uid copies: the anon→named sign-in flow mints fresh
-- ids, so a prior anonymous uid may still hold copies of this user's
-- data. Those rows belong to a DIFFERENT auth uid and cannot be
-- deleted here (auth.uid() scope); they are reaped by the founder-run
-- scripts/cleanup_orphaned_anon_users.sql maintenance pass.
--
-- Apple Sign-In note: deleting the Supabase user does NOT revoke the Apple
-- Services ID linkage. If the user later signs in with the same Apple ID,
-- Supabase creates a fresh anonymous-like row. That's the desired behavior —
-- they get a clean slate, not a "this email is already registered" error.

CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    requesting_user_id uuid;
BEGIN
    requesting_user_id := auth.uid();
    IF requesting_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    -- Purge the user's food-photos storage objects FIRST (no cascade
    -- from auth.users; owner is SET NULL on user deletion). search_path
    -- is '' so every reference stays schema-qualified.
    DELETE FROM storage.objects
    WHERE bucket_id = 'food-photos'
      AND (
          name LIKE requesting_user_id::text || '/%'
          OR owner = requesting_user_id
      );

    DELETE FROM auth.users WHERE id = requesting_user_id;
END;
$$;

-- Lock down execution: authenticated users only, no anon/service callers.
REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
