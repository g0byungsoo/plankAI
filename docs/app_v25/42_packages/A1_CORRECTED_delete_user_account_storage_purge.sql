-- PACKAGE A1 — CORRECTED. NOT APPLIED. NOT DEPLOYED.
--
-- ==========================================================================
-- ==  `40`'s A1 IS BROKEN AND WOULD HAVE BROKEN ACCOUNT DELETION FOR      ==
-- ==  100% OF CUSTOMERS. Do not apply                                     ==
-- ==  docs/app_v25/40_packages/A1_delete_user_account_storage_purge.sql.  ==
-- ==  Apply THIS instead, after reading why.                              ==
-- ==========================================================================
--
-- THE DEFECT, found while auditing Package E1 as hostile code (§42 §1) and
-- proven against production before anything was applied:
--
--     storage.objects carries
--
--       CREATE TRIGGER protect_objects_delete
--         BEFORE DELETE ON storage.objects
--         FOR EACH STATEMENT
--         EXECUTE FUNCTION storage.protect_delete()
--
--     and `storage.protect_delete()` raises 42501 unless the session
--     setting `storage.allow_delete_query` is 'true'.
--
-- A **STATEMENT-LEVEL** BEFORE trigger fires once per DELETE STATEMENT
-- **whether or not any row matches**. Proven, verbatim, against production:
--
--     begin;
--     delete from storage.objects where bucket_id = '__no_such_bucket__';
--     -- ERROR: 42501: Direct deletion from storage tables is not allowed.
--     rollback;
--
-- So `40`'s A1 does not "delete strictly more, and today there is nothing
-- more to delete". It THROWS on every call, the exception propagates out of
-- the plpgsql function, and **the `DELETE FROM auth.users` that follows it
-- never runs**. Every "delete my account" tap would have returned an error
-- and deleted nothing — a 5.1.1(v) App Store obligation, broken by the
-- migration written to strengthen it.
--
-- `41` §27 re-verified A1's ASSUMPTIONS and found them all still true. They
-- are. The assumption nobody tested was that the statement would execute.
--
--   ▎ "PROVEN BY CODE" IS NOT PROVEN. `38` §11 wrote that sentence about
--   ▎ this very function, and it was right a second time.
--
-- THE FIX is one line: ask for the permission the Storage service itself
-- asks for, scoped to this transaction only.
--
-- ------------------------------- FORWARD ---------------------------------

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

    -- THE CORRECTION. `is_local => true` scopes the permission to this
    -- transaction, which is the mechanism the Storage service uses. Without
    -- it the DELETE below raises 42501 even when it matches zero rows, and
    -- the account is never deleted.
    PERFORM pg_catalog.set_config('storage.allow_delete_query', 'true', true);

    -- Storage FIRST: no cascade reaches it (storage.objects has NO foreign
    -- key to auth.users), so once auth.users is gone nothing can ever name
    -- these objects again.
    DELETE FROM storage.objects
    WHERE bucket_id IN ('food-photos', 'body-scans')
      AND (
          name LIKE requesting_user_id::text || '/%'
          OR owner = requesting_user_id
      );

    DELETE FROM auth.users WHERE id = requesting_user_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.delete_user_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;

-- ------------------------------- ROLLBACK --------------------------------
-- Re-apply the CURRENTLY DEPLOYED body (266 characters, no storage purge):
--
-- CREATE OR REPLACE FUNCTION public.delete_user_account()
-- RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
-- AS $$
-- DECLARE requesting_user_id uuid;
-- BEGIN
--     requesting_user_id := auth.uid();
--     IF requesting_user_id IS NULL THEN
--         RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
--     END IF;
--     DELETE FROM auth.users WHERE id = requesting_user_id;
-- END;
-- $$;
--
-- ------------------------------ BEFORE APPLYING ---------------------------
-- Run this first. It must succeed, and it must leave storage.objects
-- untouched (0 rows today):
--
--   begin;
--   select pg_catalog.set_config('storage.allow_delete_query','true',true);
--   delete from storage.objects where bucket_id = '__no_such_bucket__';
--   rollback;
--
-- Then apply, then delete a THROWAWAY account through the app and confirm
-- the auth.users row is gone. A migration to a deletion path that has never
-- been exercised is the whole reason this file exists.
--
-- STATUS: READY — DO NOT DEPLOY without the founder's explicit go.
-- URGENCY: unchanged and real — it must land BEFORE the `food-photos`
--          bucket is ever created, and `complete_account_handoff` already
--          carries the corrected form so the HANDOFF does not depend on it.
