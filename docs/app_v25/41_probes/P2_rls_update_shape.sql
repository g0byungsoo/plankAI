-- P2 — RLS UPDATE SHAPE  (v25 §41 — THE HANDOFF, brief §8 and §24)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `select`.                   ==
-- ==  Reads pg_policies (catalog metadata).  NO customer row is read.     ==
-- ==========================================================================
--
-- THE QUESTION THE BRIEF ASKS IN §8:
--
--   "If RLS prevents a direct client rekey: that is evidence the transfer
--    belongs server-side."
--
-- The proof is the shape of the UPDATE policies, not an experiment. For an
-- UPDATE, Postgres evaluates the policy's USING clause against the OLD row
-- and the WITH CHECK clause against the NEW row. An ownership change makes
-- those two rows belong to two different accounts, so:
--
--   · with SOURCE's token:      USING passes (old row is A's)
--                               WITH CHECK fails (new row is B's)
--   · with DESTINATION's token: USING fails  (old row is A's)
--
-- ▎ NO SINGLE BEARER TOKEN CAN SATISFY BOTH HALVES OF AN OWNERSHIP CHANGE.
-- ▎ THAT IS NOT A GAP IN THE POLICIES. IT IS THE POLICIES WORKING.
--
-- This query prints every policy so the claim is read off the catalog
-- rather than asserted.

select
    schemaname,
    tablename,
    policyname,
    cmd,
    roles::text                as granted_to,
    coalesce(qual, '')         as using_expression,
    coalesce(with_check, '')   as with_check_expression
from pg_policies
where schemaname in ('public', 'private')
  and tablename in (
      'users', 'weight_logs', 'food_logs', 'dose_events', 'observations',
      'program_plans', 'program_day_checks', 'program_facts',
      'weekly_reads', 'regimen_plans', 'session_logs', 'session_ratings',
      'day_progress', 'day_reflections', 'exercise_calibrations',
      'consent_grants', 'care_weekly_summaries'
  )
order by tablename, cmd, policyname;
