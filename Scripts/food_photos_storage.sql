-- absmaxxing — food-photos Storage bucket + RLS
-- Run this in Supabase SQL editor AFTER scripts/rls_policies.sql.
--
-- Private bucket for snap-food photo thumbnails. The client uploads
-- JPEG thumbnails (~40KB each) at paths shaped:
--   {user_id_lowercase}/{entry_id_lowercase}.jpg
-- so the first folder segment of every object name IS the owner's
-- auth.uid(). RLS on storage.objects enforces that prefix per
-- operation — a user can only touch objects under her own uid folder.
--
-- Idempotent: bucket insert is ON CONFLICT DO NOTHING; policies use
-- DROP IF EXISTS + CREATE (same pattern as scripts/rls_policies.sql).
--
-- Pattern (canonical Supabase storage RLS):
--   (storage.foldername(name))[1] = auth.uid()::text
-- storage.foldername('abc/def.jpg') = '{abc}', so [1] is the top-level
-- folder — the user id. auth.uid()::text is lowercase, matching the
-- client's lowercase path contract.

-- =====================================================================
-- BUCKET
-- =====================================================================
--
-- public = false: objects are NEVER served anonymously; the client
-- reads via createSignedURL / authenticated download only.
-- file_size_limit: thumbnails are ~40KB; 1MB is a generous ceiling
-- that still blocks abuse (full-res photo dumps, non-image payloads).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('food-photos', 'food-photos', false, 1048576, ARRAY['image/jpeg'])
ON CONFLICT (id) DO NOTHING;

-- =====================================================================
-- storage.objects POLICIES (own-prefix only, per operation)
-- =====================================================================

DO $$
BEGIN
    EXECUTE 'DROP POLICY IF EXISTS "food_photos_select_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "food_photos_insert_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "food_photos_update_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "food_photos_delete_own" ON storage.objects';
    EXECUTE 'CREATE POLICY "food_photos_select_own" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = ''food-photos'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "food_photos_insert_own" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''food-photos'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "food_photos_update_own" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = ''food-photos'' AND (storage.foldername(name))[1] = auth.uid()::text) WITH CHECK (bucket_id = ''food-photos'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "food_photos_delete_own" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''food-photos'' AND (storage.foldername(name))[1] = auth.uid()::text)';
END $$;

-- =====================================================================
-- VERIFICATION
-- =====================================================================
--
-- 1. Bucket exists and is private:
--      SELECT id, public, file_size_limit, allowed_mime_types
--      FROM storage.buckets WHERE id = 'food-photos';
--    Expected: public = false.
--
-- 2. Policies present:
--      SELECT policyname, cmd FROM pg_policies
--      WHERE schemaname = 'storage' AND tablename = 'objects'
--        AND policyname LIKE 'food_photos_%'
--      ORDER BY cmd;
--    Expected: 4 rows (SELECT / INSERT / UPDATE / DELETE).
--
-- 3. Cross-user isolation smoke test (run as User A's JWT via the
--    client SDK): upload to '<user_b_uuid>/x.jpg'.
--    Expected: ERROR — new row violates row-level security policy.
