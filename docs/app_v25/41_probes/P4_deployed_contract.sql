-- P4 — THE DEPLOYED CONTRACT  (v25 §41 — THE HANDOFF, brief §27 and §29)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `with`.                     ==
-- ==  Catalog metadata + counts only.  No customer row is read.           ==
-- ==========================================================================
--
-- THREE THINGS THIS PASS MAY NOT ASSUME:
--
--   1. that Package A1 is still unapplied — the handoff's deploy order
--      depends on which body `delete_user_account()` currently has, and
--      "the repository file is not the deployed function" is the exact
--      error class §39 §8 recorded;
--   2. that nothing named like a handoff receipt already exists — a
--      migration that creates a table someone else already created is a
--      failed migration;
--   3. that the storage picture has not moved since §40 (the `food-photos`
--      bucket appearing is the one event that turns A1 from tidy into
--      urgent).

with
fns as (
    select
        'function.' || p.proname                       as measure,
        length(pg_get_functiondef(p.oid))::bigint      as n
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('delete_user_account')
),
fn_has_storage as (
    select
        'delete_user_account.mentions_storage_objects' as measure,
        count(*)::bigint                               as n
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'delete_user_account'
      and pg_get_functiondef(p.oid) ilike '%storage.objects%'
),
handoff_tables as (
    select
        'tables.named_like_handoff'                    as measure,
        count(*)::bigint                               as n
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'r'
      and (c.relname ilike '%handoff%'
           or c.relname ilike '%account_migration%'
           or c.relname ilike '%identity_link%'
           or c.relname ilike '%previous_uid%')
),
buckets as (
    select 'storage.buckets.count' as measure, count(*)::bigint as n from storage.buckets
    union all
    select 'storage.buckets.food_photos_exists', count(*)::bigint from storage.buckets where id = 'food-photos'
    union all
    select 'storage.buckets.body_scans_exists',  count(*)::bigint from storage.buckets where id = 'body-scans'
),
age as (
    select 'project.oldest_auth_user_age_days' as measure,
           floor(extract(epoch from (now() - min(created_at))) / 86400)::bigint as n
    from auth.users
)
select measure, n from fns
union all select measure, n from fn_has_storage
union all select measure, n from handoff_tables
union all select measure, n from buckets
union all select measure, n from age
order by measure;
