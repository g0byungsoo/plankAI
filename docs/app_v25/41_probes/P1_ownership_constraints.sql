-- P1 — OWNERSHIP CONSTRAINTS  (v25 §41 — THE HANDOFF, brief §24)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `select`.                   ==
-- ==  NO INSERT / UPDATE / DELETE / UPSERT / MERGE / DDL / DCL.           ==
-- ==  Selects catalog metadata only: table names, constraint definitions, ==
-- ==  policy expressions.  NO customer row, id, email, name, health value ==
-- ==  or jsonb payload is read anywhere in this file.                     ==
-- ==========================================================================
--
-- THE QUESTION: for every customer-owned table, what would block a
-- server-side `update … set user_id = <destination>`?
--
--   · a PRIMARY KEY that IS the user id           (public.users)
--   · a UNIQUE constraint or index on (user_id, …)
--   · a foreign key that must follow the rewrite
--   · an RLS policy shape that makes a CLIENT-side rewrite impossible
--     (USING evaluates the OLD row, WITH CHECK the NEW one, so no single
--     bearer token can satisfy both halves of an ownership change)
--
-- Answering this BEFORE writing the function is the brief's own rule:
-- "Do not discover these during implementation by trial and error."

select
    c.relname                                   as table_name,
    n.nspname                                   as schema_name,
    con.conname                                 as constraint_name,
    case con.contype
        when 'p' then 'primary key'
        when 'u' then 'unique'
        when 'f' then 'foreign key'
        when 'c' then 'check'
        else con.contype::text
    end                                         as constraint_kind,
    pg_get_constraintdef(con.oid)               as definition
from pg_constraint con
join pg_class c on c.oid = con.conrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname in ('public', 'private')
  and c.relname in (
      'users', 'weight_logs', 'food_logs', 'food_log_items',
      'food_corrections', 'dose_events', 'observations',
      'program_plans', 'program_day_checks', 'program_facts',
      'weekly_reads', 'regimen_plans', 'session_logs', 'session_ratings',
      'day_progress', 'day_reflections', 'exercise_calibrations',
      'consent_grants', 'coach_messages', 'visit_packets',
      'care_weekly_summaries', 'care_relationships', 'org_members',
      'correction_requests', 'protocol_assignments',
      'patient_invitations', 'care_audit_events',
      'food_vision_telemetry', 'jeni_chat_telemetry'
  )
  and con.contype in ('p', 'u', 'f')
order by c.relname, con.contype, con.conname;
