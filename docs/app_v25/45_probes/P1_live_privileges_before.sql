-- =====================================================================
-- 45 · P1 — THE LIVE PRIVILEGE + RLS STATE, BEFORE G1
-- =====================================================================
--
-- READ ONLY. Catalog introspection and counts only. No DML, no DDL.
-- Independent re-proof of 44 §2 — read from the live catalog, never
-- inferred from migration text.
--
-- Run: supabase db query --linked -f docs/app_v25/45_probes/P1_live_privileges_before.sql -o json

with targets(t) as (
  values ('public.program_facts'), ('public.weekly_reads')
),
roles(r) as (
  values ('anon'), ('authenticated'), ('service_role')
),
priv as (
  select
    'A · TABLE PRIVILEGE' as section,
    t as obj,
    r as role_name,
    has_table_privilege(r, t, 'SELECT') as sel,
    has_table_privilege(r, t, 'INSERT') as ins,
    has_table_privilege(r, t, 'UPDATE') as upd,
    has_table_privilege(r, t, 'DELETE') as del
  from targets, roles
),
acl as (
  select
    'B · RELACL + OWNER + RLS' as section,
    c.oid::regclass::text as obj,
    pg_get_userbyid(c.relowner) as owner,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as rls_forced,
    coalesce(array_to_string(c.relacl::text[], ' | '), '(null — owner default only)') as acl
  from pg_class c
  where c.oid in ('public.program_facts'::regclass, 'public.weekly_reads'::regclass)
),
pol as (
  select
    'C · POLICY' as section,
    p.polrelid::regclass::text as obj,
    p.polname as policy_name,
    case p.polcmd when 'r' then 'SELECT' when 'a' then 'INSERT'
                  when 'w' then 'UPDATE' when 'd' then 'DELETE'
                  when '*' then 'ALL' else p.polcmd::text end as cmd,
    coalesce((select string_agg(pg_get_userbyid(x), ',')
              from unnest(p.polroles) x), 'PUBLIC') as roles,
    coalesce(pg_get_expr(p.polqual, p.polrelid), '(none)') as using_expr,
    coalesce(pg_get_expr(p.polwithcheck, p.polrelid), '(none)') as check_expr
  from pg_policy p
  where p.polrelid in ('public.program_facts'::regclass, 'public.weekly_reads'::regclass)
),
counts as (
  select 'D · ROW COUNT' as section, 'public.program_facts' as obj,
         (select count(*) from public.program_facts) as n
  union all
  select 'D · ROW COUNT', 'public.weekly_reads',
         (select count(*) from public.weekly_reads)
),
colpriv as (
  -- a column-level grant would make has_table_privilege false while
  -- the API still worked; prove there is none hiding underneath.
  select 'E · COLUMN GRANTS' as section,
         table_schema || '.' || table_name as obj,
         grantee as role_name, privilege_type as priv, column_name
  from information_schema.column_privileges
  where table_schema = 'public'
    and table_name in ('program_facts', 'weekly_reads')
    and grantee in ('anon', 'authenticated', 'service_role')
)
select section, obj, role_name, null::text as detail1, null::text as detail2,
       sel::text as a, ins::text as b, upd::text as c, del::text as d
  from priv
union all
select section, obj, owner, rls_enabled::text, rls_forced::text,
       acl, null, null, null from acl
union all
select section, obj, roles, policy_name, cmd,
       using_expr, check_expr, null, null from pol
union all
select section, obj, null, null, null, n::text, null, null, null from counts
union all
select section, obj, role_name, priv, column_name, null, null, null, null
  from colpriv
order by 1, 2, 3, 4;
