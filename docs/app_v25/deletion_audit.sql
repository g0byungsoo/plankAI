-- v25 §38 — THE DELETION AUDIT. READ-ONLY. **WRITTEN AND NOT EXECUTED.**
--
-- ============================================================
-- ==  READ-ONLY. NO INSERT, NO UPDATE, NO DELETE, NO DDL.   ==
-- ==  NO EMAILS. NO NAMES. NO HEALTH PAYLOAD. NO JSON.      ==
-- ==  COUNTS AND BOUNDS ONLY.                               ==
-- ============================================================
--
-- Three questions the record cannot answer from the repository, in
-- the order their answers change what gets built:
--
--   Q1  How much customer-owned data survives account deletion under
--       an ORPHANED ANONYMOUS UID?  (§38 §9.1 — P0, and the largest
--       unknown in the product)
--   Q2  How many care_weekly_summaries rows are ALREADY orphaned?
--       (§38 §10 — this decides whether the FK can be added with
--       `validate` or must go in `not valid` first)
--   Q3  How many customers actually run two devices?  (§38 §21 —
--       it sizes the tombstone migration honestly instead of
--       assuming)
--
-- Every query below returns COUNTS and BOUNDS. Where a figure could
-- be an under-count, it says so in its own column name rather than
-- being presented as a total. No query returns a user id, an email,
-- a name, a jsonb payload, or any health value.
--
-- Run in: Supabase dashboard SQL editor. Read the output, paste the
-- numbers into §38 §16, and decide nothing before all three are in.


-- =====================================================================
-- Q1 · THE ORPHANED-ANONYMOUS-UID CENSUS  (§38 §9.1)
-- =====================================================================
--
-- The app is anonymous-first. Signing in with Apple mints a NEW uid,
-- the merge re-keys the LOCAL rows and pushes fresh copies, and the
-- old server rows stay under the anonymous uid — where
-- `delete_user_account()` (scoped to auth.uid()) can never reach
-- them. `scripts/cleanup_orphaned_anon_users.sql` says so in its own
-- header and is founder-run, unscheduled, on a 90-day window.
--
-- This is NOT the same population as that script's dry run: that one
-- lists anonymous accounts stale for 90 days. This one asks how much
-- HEALTH DATA sits under anonymous accounts at all.

select
    count(*)                                              as anonymous_accounts,
    count(*) filter (where has_any_health_row)            as anonymous_accounts_with_health_data,
    sum(weight_logs)                                      as total_weight_rows,
    sum(food_logs)                                        as total_food_rows,
    sum(observations)                                     as total_observation_rows,
    sum(dose_events)                                      as total_dose_rows,
    min(created_at)::date                                 as oldest_anonymous_account,
    max(created_at)::date                                 as newest_anonymous_account
from (
    select
        u.id,
        u.created_at,
        (select count(*) from public.weight_logs  w where w.user_id = u.id) as weight_logs,
        (select count(*) from public.food_logs    f where f.user_id = u.id) as food_logs,
        (select count(*) from public.observations o where o.user_id = u.id) as observations,
        (select count(*) from public.dose_events  d where d.user_id = u.id) as dose_events,
        (
            exists (select 1 from public.weight_logs  w where w.user_id = u.id)
         or exists (select 1 from public.food_logs    f where f.user_id = u.id)
         or exists (select 1 from public.observations o where o.user_id = u.id)
         or exists (select 1 from public.dose_events  d where d.user_id = u.id)
        ) as has_any_health_row
    from auth.users u
    where u.is_anonymous = true
) t;

-- Q1b · The sharper form: how many anonymous accounts hold health
-- data AND look like they were superseded by a named account (the
-- sign-in merge signature). This is a BOUND, not a join: there is no
-- column linking an anonymous uid to the named uid that replaced it,
-- which is itself a finding — a deletion cannot follow a link that
-- does not exist.

select
    count(*) as anonymous_accounts_with_health_and_no_signin
from auth.users u
where u.is_anonymous = true
  and u.last_sign_in_at is null
  and (
       exists (select 1 from public.weight_logs w where w.user_id = u.id)
    or exists (select 1 from public.food_logs   f where f.user_id = u.id)
  );

-- Q1c · Storage objects under anonymous uids — meal photos and, if
-- backup was ever on, body scans. Object NAMES are never selected;
-- only the count and the total byte size.

select
    o.bucket_id,
    count(*)                                        as objects_under_anonymous_uids,
    pg_size_pretty(sum(coalesce((o.metadata->>'size')::bigint, 0))) as approx_bytes
from storage.objects o
join auth.users u
  on u.id::text = (storage.foldername(o.name))[1]
where u.is_anonymous = true
  and o.bucket_id in ('food-photos', 'body-scans')
group by o.bucket_id;


-- =====================================================================
-- Q2 · care_weekly_summaries ORPHANS  (§38 §10)
-- =====================================================================
--
-- The table's `user_id` has no `references`, so nothing has ever
-- validated it. If ANY row's user_id is absent from auth.users, a
-- plain `alter table … add constraint … references` FAILS, and the
-- migration must go in `not valid` first. That is the whole reason
-- this query exists.
--
-- NOTHING from `payload` is selected.

select
    count(*)                                             as total_rows,
    count(*) filter (where u.id is not null)             as rows_with_a_living_user,
    count(*) filter (where u.id is null)                 as orphan_rows,
    count(distinct s.user_id) filter (where u.id is null) as distinct_orphaned_user_ids,
    count(distinct s.user_id)                            as distinct_user_ids_total,
    min(s.week_key)                                      as earliest_week,
    max(s.week_key)                                      as latest_week
from public.care_weekly_summaries s
left join auth.users u on u.id = s.user_id;

-- Q2b · The same question for the other three no-FK tables, so the
-- founder decides all four at once instead of one at a time.

select 'care_audit_events'      as table_name,
       count(*)                                  as total_rows,
       count(*) filter (where u.id is null)      as orphan_rows,
       count(distinct e.patient_id) filter (where u.id is null)
                                                 as distinct_orphaned_user_ids
  from public.care_audit_events e
  left join auth.users u on u.id = e.patient_id
 where e.patient_id is not null
union all
select 'ops_events',
       count(*),
       count(*) filter (where u.id is null),
       count(distinct v.actor_id) filter (where u.id is null)
  from public.ops_events v
  left join auth.users u on u.id = v.actor_id
 where v.actor_id is not null
union all
select 'invitation_attempts',
       count(*),
       count(*) filter (where u.id is null),
       count(distinct i.user_id) filter (where u.id is null)
  from private.invitation_attempts i
  left join auth.users u on u.id = i.user_id;

-- Q2c · The two telemetry tables, to confirm the `on delete set null`
-- anonymisation is doing what §38 §1.2 records as a STATED CHOICE
-- rather than quietly retaining an identifier.

select 'food_vision_telemetry' as table_name,
       count(*) as total_rows,
       count(*) filter (where user_id is null) as de_identified_rows
  from public.food_vision_telemetry
union all
select 'jeni_chat_telemetry',
       count(*),
       count(*) filter (where user_id is null)
  from public.jeni_chat_telemetry;


-- =====================================================================
-- Q3 · HOW MANY CUSTOMERS RUN TWO DEVICES?  (§38 §21)
-- =====================================================================
--
-- The resurrection this pass closes needs a SECOND DEVICE. Nothing in
-- the schema records a device, so this is a PROXY and it is labelled
-- as one: `food_logs` carries a `source` and an `id` minted per
-- device, but nothing distinguishes two phones from one phone
-- reinstalled. The honest available signal is auth: how many accounts
-- have more than one identity row, and how many have a refresh-token
-- history consistent with concurrent sessions.
--
-- READ THE ANSWER AS A BOUND, NOT A FIGURE. A prior session's "≤3"
-- predicate became a strict under-count the moment it was quoted
-- without its qualifier (`35` §13); this one names its own ceiling.

select
    count(*)                                   as accounts_with_more_than_one_identity,
    (select count(*) from auth.users)          as all_accounts
from (
    select user_id
    from auth.identities
    group by user_id
    having count(*) > 1
) t;

-- Q3b · Sessions is the closer proxy where the column exists. If
-- `auth.sessions` is not present or not readable in this project,
-- SKIP THIS QUERY rather than substituting a worse one — an absent
-- signal is an absent signal.

select
    count(*) filter (where session_count > 1) as accounts_with_multiple_sessions,
    count(*)                                  as accounts_with_any_session,
    max(session_count)                        as most_sessions_on_one_account
from (
    select user_id, count(*) as session_count
    from auth.sessions
    group by user_id
) t;


-- =====================================================================
-- WHAT EACH ANSWER CHANGES
-- =====================================================================
--
-- Q1 large  → the anonymous-orphan retention contradiction is the P0
--             of the next pass, ahead of everything else in §38, and
--             the privacy policy's "the data is unrecoverable" has to
--             be made true rather than softened.
-- Q1 ~zero  → the merge is preserving uids more often than the code
--             assumes; re-read `AuthService.signInWithApple`'s claim
--             before writing anything.
--
-- Q2 orphans = 0  → the care_weekly_summaries FK can be added and
--                   validated in ONE migration.
-- Q2 orphans > 0  → `not valid` first, then a decision about the
--                   orphans that ALREADY exist, which is the same
--                   legal question §38 §10 refuses to answer alone.
--
-- Q3 near zero → the server tombstone migration is real but low
--                priority; the local ledger already shipped covers
--                the phone she is holding.
-- Q3 material  → tombstones move up, and the client-first ordering in
--                §38 §6 becomes the schedule rather than a caveat.
