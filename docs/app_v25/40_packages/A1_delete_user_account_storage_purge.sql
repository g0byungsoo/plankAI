-- PACKAGE A · 1 of 3 — RESTORE THE STORAGE PURGE TO delete_user_account()
--
-- ==========================================================================
-- ==  NOT WRITTEN TO supabase/migrations. NOT APPLIED. NOT DEPLOYED.      ==
-- ==  A file in supabase/migrations is applied by the next `db push`;     ==
-- ==  this one is staged here so a person applies it deliberately.        ==
-- ==========================================================================
--
-- WHY.
-- `scripts/delete_user_account.sql` in the repository has always contained a
-- `DELETE FROM storage.objects` block. THE DEPLOYED FUNCTION HAS NEVER HAD
-- IT. Re-read from `pg_proc` in production on 2026-08-14, verbatim:
--
--     CREATE OR REPLACE FUNCTION public.delete_user_account()
--      RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
--     AS $function$
--     DECLARE requesting_user_id uuid;
--     BEGIN
--         requesting_user_id := auth.uid();
--         IF requesting_user_id IS NULL THEN
--             RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
--         END IF;
--         DELETE FROM auth.users WHERE id = requesting_user_id;
--     END;
--     $function$
--
-- `storage.objects` has exactly ONE foreign key, `objects_bucketId_fkey`, to
-- `storage.buckets`. It has NO reference to `auth.users` at all — confirmed
-- from the live catalog, both `owner` and `owner_id` read NO_FK — so the
-- repo header's "owner is SET NULL on user deletion" reasoning is wrong
-- about this project. NOTHING removes a storage object when its owner is
-- deleted.
--
-- BLAST RADIUS TODAY: ZERO. `storage.objects` holds 0 rows in every bucket,
-- and the only bucket that exists is `body-scans` (private, created
-- 2026-08-04, empty). The `food-photos` bucket the client uploads to DOES
-- NOT EXIST, so every food-photo upload fails and re-queues.
--
-- ▎ THAT IS WHY THIS MUST LAND BEFORE THE `food-photos` BUCKET IS EVER
-- ▎ CREATED. The day the bucket exists, every meal photo of every deleted
-- ▎ account survives deletion, unreachable by any credential and removable
-- ▎ by no client.

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

    -- Storage FIRST: no cascade reaches it, so once auth.users is gone
    -- nothing can ever name these objects again. Both buckets, by uid
    -- PREFIX and by owner — belt and braces, because an object uploaded
    -- through the service role carries a null owner and one uploaded by an
    -- older client may not carry the prefix.
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
-- Re-apply the currently deployed body (drop the storage DELETE):
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
-- ------------------------------ SAFETY MATRIX -----------------------------
-- OLD CLIENT (build 30, live):  SAFE. It calls the RPC by name and reads no
--                               result. It deletes strictly more, and today
--                               there is nothing more to delete.
-- NEW CLIENT (build 31):        SAFE. Identical, and the client's pre-RPC
--                               `BodyScanSyncService.deleteAllRemote` stays
--                               as the belt to these braces.
-- ANONYMOUS RETIREMENT (§40):   SAFE and BENEFICIAL. The new retirement call
--                               reaches this same RPC with the outgoing
--                               anonymous token, so an abandoned anonymous
--                               account's storage goes with it.
-- DEPLOY ORDER:                 STANDALONE. No client depends on it. It must
--                               land BEFORE `food-photos` is created.
-- SECRET REQUIRED:              none.
-- FOUNDER ACTION:               apply it.
