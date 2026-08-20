-- P6 — SERVER CAPABILITIES  (v25 §41 — THE HANDOFF, brief §29)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `select`.                   ==
-- ==  Reads pg_proc metadata and one GUC.  No customer row is read.       ==
-- ==========================================================================
--
-- Package E's authorization computes a SHA-256 of the caller's own subject
-- and its receipt id defaults to a random uuid. Both are written against
-- `pg_catalog` builtins rather than an extension, because a migration that
-- assumes `pgcrypto` is installed in a particular schema is a migration
-- that fails on the day it matters. This checks the assumption instead of
-- making it.

select 'server_version' as measure, current_setting('server_version') as v
union all
select 'has_sha256', (select count(*)::text from pg_proc p
                       join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'pg_catalog' and p.proname = 'sha256')
union all
select 'has_gen_random_uuid_pg_catalog', (select count(*)::text from pg_proc p
                       join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'pg_catalog' and p.proname = 'gen_random_uuid')
union all
select 'has_convert_to', (select count(*)::text from pg_proc p
                       join pg_namespace n on n.oid = p.pronamespace
                      where n.nspname = 'pg_catalog' and p.proname = 'convert_to');
