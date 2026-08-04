-- jeni — body-scans Storage bucket + RLS (app v9 P1, D3)
-- FOUNDER APPLIES in the Supabase SQL editor (consumer dev project),
-- AFTER scripts/food_photos_storage.sql. Until applied, the client's
-- opt-in backup uploads fail quietly and stay queued (local-first).
--
-- Private bucket for Body Vision progress photos — the OPT-IN backup
-- mirror (default OFF; nothing uploads until she flips the toggle).
-- Only the source JPEG is mirrored; the ink silhouette re-renders
-- on-device from it after a restore. Object paths:
--   {user_id_lowercase}/{dayKey}_{scan_id_lowercase}.jpg
--   e.g. 5b3e.../2026-08-03_9f27....jpg
-- The dayKey rides the path so a reinstall can rebuild the record
-- (records are deliberately local-only — no scan table exists).
--
-- RLS: own-prefix per operation, the food-photos pattern verbatim.
-- 2MB ceiling (scans are ~1600px q0.8 JPEGs, ~250-500KB).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('body-scans', 'body-scans', false, 2097152, ARRAY['image/jpeg'])
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
    EXECUTE 'DROP POLICY IF EXISTS "body_scans_select_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "body_scans_insert_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "body_scans_update_own" ON storage.objects';
    EXECUTE 'DROP POLICY IF EXISTS "body_scans_delete_own" ON storage.objects';
    EXECUTE 'CREATE POLICY "body_scans_select_own" ON storage.objects FOR SELECT TO authenticated USING (bucket_id = ''body-scans'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "body_scans_insert_own" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = ''body-scans'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "body_scans_update_own" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = ''body-scans'' AND (storage.foldername(name))[1] = auth.uid()::text) WITH CHECK (bucket_id = ''body-scans'' AND (storage.foldername(name))[1] = auth.uid()::text)';
    EXECUTE 'CREATE POLICY "body_scans_delete_own" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = ''body-scans'' AND (storage.foldername(name))[1] = auth.uid()::text)';
END $$;

-- VERIFICATION
--   SELECT id, public, file_size_limit FROM storage.buckets WHERE id = 'body-scans';
--     -> public = false, 2097152
--   SELECT policyname, cmd FROM pg_policies
--   WHERE schemaname = 'storage' AND tablename = 'objects'
--     AND policyname LIKE 'body_scans%';
--     -> 4 rows (SELECT / INSERT / UPDATE / DELETE)
