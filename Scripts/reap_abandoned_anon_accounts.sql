-- Jeni — REAP ABANDONED ANONYMOUS ACCOUNTS  (v25 §40 — THE LAST ORPHAN)
--
-- ==========================================================================
-- ==  FOUNDER-RUN ONLY.  STEP 1 AND STEP 2 ARE READ-ONLY.                 ==
-- ==  STEP 3 IS DESTRUCTIVE AND IS COMMENTED OUT.  THERE IS NO UNDO.      ==
-- ==  NOTHING IN THIS FILE HAS BEEN EXECUTED AGAINST PRODUCTION.          ==
-- ==========================================================================
--
-- SUPERSEDES scripts/cleanup_orphaned_anon_users.sql, which must not be run.
-- That script's predicate is
--
--     is_anonymous AND coalesce(last_sign_in_at, created_at) < now() - 90d
--
-- and `last_sign_in_at` IS WRITTEN ONCE, AT `signInAnonymously`, AND NEVER
-- MOVES AGAIN. The SDK refreshes the TOKEN, which does not touch it. So a
-- customer who has used Jeni every day for 91 days without ever signing in
-- matches it, and her whole record is deleted with no warning.
--
-- MEASURED IN PRODUCTION, 2026-08-14, read-only:
--
--     anonymous accounts                                        3,425
--     …whose real activity is NEWER than last_sign_in_at         2,344   (68%)
--     matching the old 90-day predicate                             59
--     …of those, active within the last 90 days by a real signal     3
--
-- ▎ THE OLD SCRIPT WOULD DELETE THREE LIVING CUSTOMERS' RECORDS TODAY.
--
-- --------------------------------------------------------------------------
-- WHAT "ABANDONED" MEANS HERE, AND WHAT IT DELIBERATELY DOES NOT
-- --------------------------------------------------------------------------
--
-- ATTRIBUTION — "this anonymous uid became that named account" — IS
-- IMPOSSIBLE. Nothing in the schema records it (§39 §4, re-verified: zero
-- accounts have more than one identity; there is no lineage table and no
-- previous_uid column anywhere in Swift, SQL or TypeScript). This script
-- does not attempt it, does not join on timestamps, devices, body metrics,
-- food, goals or email, and must never be edited to.
--
-- ABANDONMENT IS PROVABLE, and it is a different claim: nothing anywhere in
-- this project has recorded a single act by this account for N days. That is
-- all the predicate below asserts.
--
-- A superseded uid and a dormant-but-still-installed uid look IDENTICAL from
-- the server, which is exactly why the window has to be long enough that
-- "still installed and in use" is not a credible reading of total silence.
--
-- --------------------------------------------------------------------------
-- WHY `live refresh token` IS NOT A GUARD (measured, not assumed)
-- --------------------------------------------------------------------------
--
-- GoTrue never revokes an abandoned anonymous refresh token and these
-- sessions carry no expiry, so ALL 56 accounts that have been silent for 90
-- days still hold a live, unrevoked refresh token and a live session — as do
-- 3,418 of the 3,425. The signal cannot separate anything and is not used.
--
-- --------------------------------------------------------------------------
-- THE ACTIVITY SIGNAL
-- --------------------------------------------------------------------------
--
-- The newest of EVERY trace this project can produce for one uid:
--   auth      created_at · last_sign_in_at · sessions(created/updated/
--             refreshed) · refresh_tokens(created/updated)
--   customer  weight_logs · food_logs · dose_events · observations ·
--             day_progress · program_plans · program_day_checks ·
--             session_logs · day_reflections · program_facts ·
--             weekly_reads · regimen_plans · consent_grants ·
--             exercise_calibrations
--   product   food_vision_telemetry · jeni_chat_telemetry
--
-- A row missing from this list can only make an account look STALER than it
-- is, so every omission is a bias toward RETENTION. That is the correct
-- direction: prefer false retention over false deletion.

-- ==========================================================================
-- STEP 1 — READ-ONLY.  HOW MANY ACCOUNTS, AT EVERY WINDOW.
-- ==========================================================================

with anon as (
  select u.id, u.created_at, u.last_sign_in_at
  from auth.users u
  where u.is_anonymous = true
),
act as (
  select a.id, a.created_at,
    greatest(
      a.created_at,
      coalesce(a.last_sign_in_at, a.created_at),
      coalesce((select max(greatest(s.refreshed_at at time zone 'UTC', s.updated_at, s.created_at))
                  from auth.sessions s where s.user_id = a.id), a.created_at),
      coalesce((select max(greatest(r.created_at, r.updated_at))
                  from auth.refresh_tokens r where r.user_id = a.id::text), a.created_at),
      coalesce((select max(t.ts) from (
          select max(w.created_at)  as ts from public.weight_logs           w  where w.user_id  = a.id
          union all select max(f.updated_at)     from public.food_logs      f  where f.user_id  = a.id
          union all select max(d.updated_at)     from public.dose_events    d  where d.user_id  = a.id
          union all select max(o.updated_at)     from public.observations   o  where o.user_id  = a.id
          union all select max(p.updated_at)     from public.day_progress   p  where p.user_id  = a.id
          union all select max(pl.updated_at)    from public.program_plans  pl where pl.user_id = a.id
          union all select max(pc.updated_at)    from public.program_day_checks pc where pc.user_id = a.id
          union all select max(sl.completed_at)  from public.session_logs   sl where sl.user_id = a.id
          union all select max(dr.created_at)    from public.day_reflections dr where dr.user_id = a.id
          union all select max(pf.updated_at)    from public.program_facts  pf where pf.user_id = a.id
          union all select max(wr.updated_at)    from public.weekly_reads   wr where wr.user_id = a.id
          union all select max(rp.updated_at)    from public.regimen_plans  rp where rp.user_id = a.id
          union all select max(cg.created_at)    from public.consent_grants cg where cg.user_id = a.id
          union all select max(ec.calibrated_at) from public.exercise_calibrations ec where ec.user_id = a.id
          union all select max(fv.requested_at)  from public.food_vision_telemetry fv where fv.user_id = a.id
          union all select max(jc.created_at)    from public.jeni_chat_telemetry   jc where jc.user_id = a.id
      ) t), a.created_at)
    ) as last_activity
  from anon a
)
select
    w.days                                                             as window_days,
    count(*) filter (where a.last_activity < now() - make_interval(days => w.days)
                       and a.created_at    < now() - make_interval(days => w.days)) as accounts_reaped,
    count(*)                                                           as anonymous_total
from act a
cross join (values (90),(120),(180),(270),(365)) as w(days)
group by w.days
order by w.days;

-- Expected shape, from the 2026-08-14 read (the project is 107 DAYS OLD, so
-- every window at or above 120 days is EMPTY BY CONSTRUCTION):
--
--     window_days | accounts_reaped | anonymous_total
--     ------------+-----------------+----------------
--              90 |              56 |           3,425
--             120 |               0 |           3,425
--             180 |               0 |           3,425
--             270 |               0 |           3,425
--             365 |               0 |           3,425
--
-- ▎ READ THAT BEFORE PLANNING A REPAIR. A reaper cannot clean up the
-- ▎ existing orphans today at any window that is safe, because the
-- ▎ population is younger than the window. It is a MAINTENANCE job that
-- ▎ becomes useful with time — it is not the fix.


-- ==========================================================================
-- STEP 2 — READ-ONLY.  EXACTLY WHAT WOULD BE REMOVED AT THE CHOSEN WINDOW.
-- ==========================================================================
--
-- Counts only. No uid, no email, no name, no health value, no jsonb, no
-- object name is selected anywhere in this file.
--
-- EDIT `retention_days` IN STEP 2 AND STEP 3 TOGETHER, OR YOU WILL DELETE A
-- DIFFERENT SET THAN YOU REVIEWED.

with params as (select 180 as retention_days),          -- <— THE WINDOW
anon as (
  select u.id, u.created_at, u.last_sign_in_at
  from auth.users u where u.is_anonymous = true
),
act as (
  select a.id, a.created_at,
    greatest(
      a.created_at,
      coalesce(a.last_sign_in_at, a.created_at),
      coalesce((select max(greatest(s.refreshed_at at time zone 'UTC', s.updated_at, s.created_at))
                  from auth.sessions s where s.user_id = a.id), a.created_at),
      coalesce((select max(greatest(r.created_at, r.updated_at))
                  from auth.refresh_tokens r where r.user_id = a.id::text), a.created_at),
      coalesce((select max(t.ts) from (
          select max(w.created_at)  as ts from public.weight_logs           w  where w.user_id  = a.id
          union all select max(f.updated_at)     from public.food_logs      f  where f.user_id  = a.id
          union all select max(d.updated_at)     from public.dose_events    d  where d.user_id  = a.id
          union all select max(o.updated_at)     from public.observations   o  where o.user_id  = a.id
          union all select max(p.updated_at)     from public.day_progress   p  where p.user_id  = a.id
          union all select max(pl.updated_at)    from public.program_plans  pl where pl.user_id = a.id
          union all select max(pc.updated_at)    from public.program_day_checks pc where pc.user_id = a.id
          union all select max(sl.completed_at)  from public.session_logs   sl where sl.user_id = a.id
          union all select max(dr.created_at)    from public.day_reflections dr where dr.user_id = a.id
          union all select max(pf.updated_at)    from public.program_facts  pf where pf.user_id = a.id
          union all select max(wr.updated_at)    from public.weekly_reads   wr where wr.user_id = a.id
          union all select max(rp.updated_at)    from public.regimen_plans  rp where rp.user_id = a.id
          union all select max(cg.created_at)    from public.consent_grants cg where cg.user_id = a.id
          union all select max(ec.calibrated_at) from public.exercise_calibrations ec where ec.user_id = a.id
          union all select max(fv.requested_at)  from public.food_vision_telemetry fv where fv.user_id = a.id
          union all select max(jc.created_at)    from public.jeni_chat_telemetry   jc where jc.user_id = a.id
      ) t), a.created_at)
    ) as last_activity
  from anon a
),
doomed as (
  select a.id from act a, params p
  where a.last_activity < now() - make_interval(days => p.retention_days)
    and a.created_at    < now() - make_interval(days => p.retention_days)
)
select 'accounts'      as what, count(*)::bigint from doomed
union all select 'profile_rows',      (select count(*) from public.users            x join doomed d on d.id = x.id)
union all select 'weight_rows',       (select count(*) from public.weight_logs      x join doomed d on d.id = x.user_id)
union all select 'food_rows',         (select count(*) from public.food_logs        x join doomed d on d.id = x.user_id)
union all select 'observation_rows',  (select count(*) from public.observations     x join doomed d on d.id = x.user_id)
union all select 'dose_rows',         (select count(*) from public.dose_events      x join doomed d on d.id = x.user_id)
union all select 'regimen_rows',      (select count(*) from public.regimen_plans    x join doomed d on d.id = x.user_id)
union all select 'program_plans',     (select count(*) from public.program_plans    x join doomed d on d.id = x.user_id)
union all select 'program_facts',     (select count(*) from public.program_facts    x join doomed d on d.id = x.user_id)
union all select 'weekly_reads',      (select count(*) from public.weekly_reads     x join doomed d on d.id = x.user_id)
union all select 'day_progress',      (select count(*) from public.day_progress     x join doomed d on d.id = x.user_id)
union all select 'session_logs',      (select count(*) from public.session_logs     x join doomed d on d.id = x.user_id)
union all select 'day_reflections',   (select count(*) from public.day_reflections  x join doomed d on d.id = x.user_id)
union all select 'consent_grants',    (select count(*) from public.consent_grants   x join doomed d on d.id = x.user_id)
union all select 'visit_packets',     (select count(*) from public.visit_packets    x join doomed d on d.id = x.user_id)
union all select 'storage_objects',   (select count(*) from storage.objects o
                                        where o.bucket_id in ('food-photos','body-scans')
                                          and exists (select 1 from doomed d
                                                       where o.name like d.id::text || '/%'
                                                          or o.owner = d.id))
-- The five NO-FK columns. These do NOT cascade, so they are counted
-- separately and each one is a decision, not an oversight (§40 §11).
union all select 'NOFK care_weekly_summaries', (select count(*) from public.care_weekly_summaries x join doomed d on d.id = x.user_id)
union all select 'NOFK care_audit_events',     (select count(*) from public.care_audit_events     x join doomed d on d.id = x.patient_id)
union all select 'NOFK patient_invitations',   (select count(*) from public.patient_invitations   x join doomed d on d.id = x.accepted_by)
union all select 'NOFK invitation_attempts',   (select count(*) from private.invitation_attempts  x join doomed d on d.id = x.user_id)
union all select 'NOFK ops_events',            (select count(*) from public.ops_events            x join doomed d on d.id = x.actor_id)
-- SET NULL, by stated choice: the row survives, de-identified.
union all select 'SETNULL food_vision_telemetry', (select count(*) from public.food_vision_telemetry x join doomed d on d.id = x.user_id)
union all select 'SETNULL jeni_chat_telemetry',   (select count(*) from public.jeni_chat_telemetry   x join doomed d on d.id = x.user_id);


-- ==========================================================================
-- STEP 3 — DESTRUCTIVE.  COMMENTED OUT.  DO NOT UNCOMMENT WITHOUT READING
-- STEP 2's OUTPUT AT THE SAME `retention_days`.
-- ==========================================================================
--
-- Properties, each one deliberate:
--   * ONE transaction. A partial reap is the one outcome worse than none.
--   * IDEMPOTENT. Every delete is predicate-driven; a second run matches
--     nothing new.
--   * STORAGE FIRST, AUTH LAST. `storage.objects` has NO foreign key to
--     `auth.users` (verified from the live catalog, 2026-08-14), so nothing
--     removes an object once its owner is gone. Deleting auth first would
--     strand every object permanently.
--   * THE FIVE NO-FK TABLES ARE HANDLED EXPLICITLY, not left to a cascade
--     that does not exist. `patient_invitations.accepted_by` is set to NULL
--     rather than deleted: the invitation is the CLINIC's record that it
--     issued and that it was accepted, and destroying another party's row is
--     not a customer's deletion right. `care_audit_events`,
--     `invitation_attempts` and `ops_events` are left standing pending §40
--     §11's founder decision, and this script says so rather than silently
--     choosing.
--   * NO IDENTITIES PRINTED. `RAISE NOTICE` emits counts only.
--   * NO PAYLOAD OUTPUT anywhere in this file.
--
-- do $$
-- declare
--     retention_days constant int := 180;   -- <— KEEP IN SYNC WITH STEP 2
--     cutoff timestamptz := now() - make_interval(days => retention_days);
--     n_objects int; n_invites int; n_users int;
-- begin
--     create temp table _doomed on commit drop as
--     with anon as (select u.id, u.created_at, u.last_sign_in_at
--                     from auth.users u where u.is_anonymous = true)
--     select a.id from anon a
--     where a.created_at < cutoff
--       and greatest(
--             a.created_at,
--             coalesce(a.last_sign_in_at, a.created_at),
--             coalesce((select max(greatest(s.refreshed_at at time zone 'UTC', s.updated_at, s.created_at))
--                         from auth.sessions s where s.user_id = a.id), a.created_at),
--             coalesce((select max(greatest(r.created_at, r.updated_at))
--                         from auth.refresh_tokens r where r.user_id = a.id::text), a.created_at),
--             coalesce((select max(t.ts) from (
--                 select max(w.created_at) as ts from public.weight_logs w where w.user_id = a.id
--                 union all select max(f.updated_at)     from public.food_logs      f  where f.user_id  = a.id
--                 union all select max(d.updated_at)     from public.dose_events    d  where d.user_id  = a.id
--                 union all select max(o.updated_at)     from public.observations   o  where o.user_id  = a.id
--                 union all select max(p.updated_at)     from public.day_progress   p  where p.user_id  = a.id
--                 union all select max(pl.updated_at)    from public.program_plans  pl where pl.user_id = a.id
--                 union all select max(pc.updated_at)    from public.program_day_checks pc where pc.user_id = a.id
--                 union all select max(sl.completed_at)  from public.session_logs   sl where sl.user_id = a.id
--                 union all select max(dr.created_at)    from public.day_reflections dr where dr.user_id = a.id
--                 union all select max(pf.updated_at)    from public.program_facts  pf where pf.user_id = a.id
--                 union all select max(wr.updated_at)    from public.weekly_reads   wr where wr.user_id = a.id
--                 union all select max(rp.updated_at)    from public.regimen_plans  rp where rp.user_id = a.id
--                 union all select max(cg.created_at)    from public.consent_grants cg where cg.user_id = a.id
--                 union all select max(ec.calibrated_at) from public.exercise_calibrations ec where ec.user_id = a.id
--                 union all select max(fv.requested_at)  from public.food_vision_telemetry fv where fv.user_id = a.id
--                 union all select max(jc.created_at)    from public.jeni_chat_telemetry   jc where jc.user_id = a.id
--             ) t), a.created_at)
--           ) < cutoff;
--
--     -- 3a. STORAGE FIRST. No FK, so nothing else will ever reach these.
--     delete from storage.objects o
--      where o.bucket_id in ('food-photos','body-scans')
--        and exists (select 1 from _doomed d
--                     where o.name like d.id::text || '/%' or o.owner = d.id);
--     get diagnostics n_objects = row_count;
--
--     -- 3b. THE CLINIC'S RECORD IS NOT HERS TO DELETE, AND HER UID IS NOT
--     --     THEIRS TO KEEP. De-identify, do not remove.
--     update public.patient_invitations i set accepted_by = null
--      where exists (select 1 from _doomed d where d.id = i.accepted_by);
--     get diagnostics n_invites = row_count;
--
--     -- 3c. care_audit_events / invitation_attempts / ops_events are
--     --     DELIBERATELY NOT TOUCHED here. §40 §11 sizes each one and
--     --     leaves the retention call to the founder. Doing it silently in
--     --     a maintenance script is how an omission becomes a policy.
--
--     -- 3d. AUTH LAST. 24 customer-owned tables cascade from this row.
--     delete from auth.users u
--      where exists (select 1 from _doomed d where d.id = u.id)
--        and u.is_anonymous = true;   -- belt and braces: NEVER a named account
--     get diagnostics n_users = row_count;
--
--     raise notice 'reap_abandoned_anon_accounts: % accounts, % storage objects, % invitations de-identified (cutoff %)',
--                  n_users, n_objects, n_invites, cutoff;
-- end $$;
