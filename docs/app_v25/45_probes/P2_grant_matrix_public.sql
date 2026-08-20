-- =====================================================================
-- 45 · P2 — THE DATA-API GRANT MATRIX FOR EVERY public TABLE
-- =====================================================================
--
-- READ ONLY. §12 of the brief: is the missing-GRANT defect isolated to
-- the E1 spine, or did the same migration pattern break another
-- shipping table?
--
-- One row per public table: RLS state, policy count, and the effective
-- SELECT/INSERT/UPDATE/DELETE privilege of anon / authenticated /
-- service_role, plus the raw ACL so the shape is visible.
--
-- Run: supabase db query --linked -f docs/app_v25/45_probes/P2_grant_matrix_public.sql -o json

select
  c.relname as tbl,
  c.relkind::text as kind,
  c.relrowsecurity as rls,
  (select count(*) from pg_policy p where p.polrelid = c.oid) as policies,
  has_table_privilege('authenticated', c.oid, 'SELECT') as auth_sel,
  has_table_privilege('authenticated', c.oid, 'INSERT') as auth_ins,
  has_table_privilege('authenticated', c.oid, 'UPDATE') as auth_upd,
  has_table_privilege('authenticated', c.oid, 'DELETE') as auth_del,
  has_table_privilege('anon', c.oid, 'SELECT') as anon_sel,
  has_table_privilege('anon', c.oid, 'INSERT') as anon_ins,
  has_table_privilege('anon', c.oid, 'UPDATE') as anon_upd,
  has_table_privilege('anon', c.oid, 'DELETE') as anon_del,
  has_table_privilege('service_role', c.oid, 'SELECT') as svc_sel,
  coalesce(array_to_string(c.relacl::text[], ' ; '), '(null)') as acl
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind in ('r', 'p', 'v', 'm')
order by c.relname;
