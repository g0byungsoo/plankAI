-- P3 — HANDOFF POPULATION  (v25 §41 — THE HANDOFF, brief §34)
--
-- ==========================================================================
-- ==  READ-ONLY.  ONE STATEMENT.  FIRST TOKEN `with`.                     ==
-- ==  COUNTS ONLY.  No uid, email, name, jsonb payload or health value is ==
-- ==  selected anywhere.  Every projected column is a text label or a     ==
-- ==  bigint count.                                                       ==
-- ==========================================================================
--
-- WHAT IT SIZES, and nothing else:
--
--   1. how many permanent accounts exist, by provider
--   2. how many anonymous accounts hold each customer-data family
--      (the collision-handoff payload)
--   3. how many PERMANENT accounts already hold a live plan / a regimen /
--      program facts — the destination side of a collision, which decides
--      whether §16's conflict rules are hypothetical or live
--   4. THE TWO AUTHORITY POPULATIONS the RLS shapes just exposed:
--      care-assigned regimen plans and PRESCRIBED program facts. A client
--      may neither insert nor update either one (P2), so a merge that
--      re-keys them locally creates a prescription under an identity no
--      clinician ever assigned it to.
--   5. the composite-key collision surface: day_progress (PK is
--      (user_id, program_day)), exercise_calibrations (PK is
--      (user_id, exercise_type)) and day_reflections (UNIQUE
--      (user_id, day_key)) are the only families whose ownership cannot be
--      rewritten without a collision rule.
--
-- IT DOES NOT ATTEMPT ATTRIBUTION. No join on timestamps, devices, body
-- metrics, food, goals or email appears here, and none may be added.

with
anon as (
    select id from auth.users where is_anonymous = true
),
named as (
    select id from auth.users where is_anonymous = false
),
labels as (

    -- 1 ── the two account populations
    select 'accounts.anonymous'                 as measure, count(*)::bigint as n from anon
    union all
    select 'accounts.named',                    count(*)::bigint from named
    union all
    select 'identities.total',                  count(*)::bigint from auth.identities
    union all
    select 'identities.apple',                  count(*)::bigint from auth.identities where provider = 'apple'
    union all
    select 'identities.email',                  count(*)::bigint from auth.identities where provider = 'email'
    union all
    select 'accounts.named.with_two_identities',
           count(*)::bigint from (
               select user_id from auth.identities group by user_id having count(*) > 1
           ) m

    -- 2 ── the collision-handoff payload: what an anonymous account holds
    union all
    select 'anon.with.profile',                 count(distinct u.id)::bigint from public.users u join anon a on a.id = u.id
    union all
    select 'anon.with.weight',                  count(distinct t.user_id)::bigint from public.weight_logs t join anon a on a.id = t.user_id
    union all
    select 'anon.with.food',                    count(distinct t.user_id)::bigint from public.food_logs t join anon a on a.id = t.user_id
    union all
    select 'anon.with.dose',                    count(distinct t.user_id)::bigint from public.dose_events t join anon a on a.id = t.user_id
    union all
    select 'anon.with.observation',             count(distinct t.user_id)::bigint from public.observations t join anon a on a.id = t.user_id
    union all
    select 'anon.with.regimen',                 count(distinct t.user_id)::bigint from public.regimen_plans t join anon a on a.id = t.user_id
    union all
    select 'anon.with.program_plan',            count(distinct t.user_id)::bigint from public.program_plans t join anon a on a.id = t.user_id
    union all
    select 'anon.with.program_fact',            count(distinct t.user_id)::bigint from public.program_facts t join anon a on a.id = t.user_id
    union all
    select 'anon.with.weekly_read',             count(distinct t.user_id)::bigint from public.weekly_reads t join anon a on a.id = t.user_id
    union all
    select 'anon.with.day_progress',            count(distinct t.user_id)::bigint from public.day_progress t join anon a on a.id = t.user_id
    union all
    select 'anon.with.day_reflection',          count(distinct t.user_id)::bigint from public.day_reflections t join anon a on a.id = t.user_id
    union all
    select 'anon.with.session_log',             count(distinct t.user_id)::bigint from public.session_logs t join anon a on a.id = t.user_id
    union all
    select 'anon.with.calibration',             count(distinct t.user_id)::bigint from public.exercise_calibrations t join anon a on a.id = t.user_id
    union all
    select 'anon.with.consent_grant',           count(distinct t.user_id)::bigint from public.consent_grants t join anon a on a.id = t.user_id

    -- 3 ── the destination side: what a PERMANENT account already holds
    union all
    select 'named.with.profile',                count(distinct u.id)::bigint from public.users u join named b on b.id = u.id
    union all
    select 'named.with.live_plan',              count(distinct t.user_id)::bigint from public.program_plans t join named b on b.id = t.user_id where t.archived_at is null and t.phase in ('active','maintenance','recomp','pause')
    union all
    select 'named.with.regimen',                count(distinct t.user_id)::bigint from public.regimen_plans t join named b on b.id = t.user_id
    union all
    select 'named.with.program_fact',           count(distinct t.user_id)::bigint from public.program_facts t join named b on b.id = t.user_id
    union all
    select 'named.with.day_progress',           count(distinct t.user_id)::bigint from public.day_progress t join named b on b.id = t.user_id
    union all
    select 'named.with.day_reflection',         count(distinct t.user_id)::bigint from public.day_reflections t join named b on b.id = t.user_id
    union all
    select 'named.with.calibration',            count(distinct t.user_id)::bigint from public.exercise_calibrations t join named b on b.id = t.user_id

    -- 4 ── the two AUTHORITY populations a client may not write
    union all
    select 'regimen.rows.total',                count(*)::bigint from public.regimen_plans
    union all
    select 'regimen.rows.not_self_authority',   count(*)::bigint from public.regimen_plans where authority is distinct from 'self'
    union all
    select 'regimen.rows.org_scoped',           count(*)::bigint from public.regimen_plans where org_id is not null
    union all
    select 'regimen.rows.not_self.under_anon',  count(*)::bigint from public.regimen_plans t join anon a on a.id = t.user_id where t.authority is distinct from 'self'
    union all
    select 'program_facts.rows.total',          count(*)::bigint from public.program_facts
    union all
    select 'program_facts.rows.prescribed',     count(*)::bigint from public.program_facts where authority = 'prescribed'
    union all
    select 'program_facts.rows.prescribed.under_anon',
           count(*)::bigint from public.program_facts t join anon a on a.id = t.user_id where t.authority = 'prescribed'
    union all
    select 'care_relationships.patient_anon',   count(*)::bigint from public.care_relationships t join anon a on a.id = t.patient_id
    union all
    select 'consent_grants.rows.total',         count(*)::bigint from public.consent_grants
    union all
    select 'consent_grants.rows.org_scoped',    count(*)::bigint from public.consent_grants where org_id is not null

    -- 5 ── the composite-key collision surface, as row totals
    union all
    select 'day_progress.rows',                 count(*)::bigint from public.day_progress
    union all
    select 'day_reflections.rows',              count(*)::bigint from public.day_reflections
    union all
    select 'exercise_calibrations.rows',        count(*)::bigint from public.exercise_calibrations
    union all
    select 'food_log_items.rows',               count(*)::bigint from public.food_log_items
    union all
    select 'food_corrections.rows',             count(*)::bigint from public.food_corrections
    union all
    select 'care_weekly_summaries.rows',        count(*)::bigint from public.care_weekly_summaries
    union all
    select 'storage.objects.rows',              count(*)::bigint from storage.objects
)
select measure, n from labels order by measure;
