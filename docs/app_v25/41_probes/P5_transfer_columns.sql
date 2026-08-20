-- P5 — TRANSFER COLUMNS  (v25 §41 — THE HANDOFF, brief §24 and §29)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `select`.                   ==
-- ==  Reads information_schema.columns — names and types only.  No row is ==
-- ==  read from any customer table.                                       ==
-- ==========================================================================
--
-- A migration written against GUESSED column names is a migration that
-- fails on the founder's machine, and this repository has already recorded
-- the more expensive version of that error twice: `38` §11 called the
-- storage purge "PROVEN BY CODE" from a repository file that was never
-- deployed, and `39` §8 found the deployed function was not the script.
--
-- The base schema is NOT in this repository — `supabase/migrations` starts
-- at 2026-06-23 and the customer tables predate it — so every column the
-- transfer function touches is read from the live catalog first.

select
    table_schema,
    table_name,
    column_name,
    data_type,
    is_nullable
from information_schema.columns
where table_schema in ('public')
  and table_name in (
      'day_progress', 'day_reflections', 'exercise_calibrations',
      'program_plans', 'program_facts', 'regimen_plans',
      'dose_events', 'observations', 'weekly_reads'
  )
  and column_name in (
      'id', 'user_id', 'program_day', 'day_key', 'exercise_type',
      'phase', 'archived_at', 'updated_at', 'created_at',
      'authority', 'org_id', 'source_protocol_id', 'kind',
      'ended_at', 'end_reason', 'window_start_day'
  )
order by table_name, column_name;
