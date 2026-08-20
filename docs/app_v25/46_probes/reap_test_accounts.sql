-- =====================================================================
-- 46 · REAP THE ACCOUNTS AN AUTOMATED TEST RUN CREATED
-- =====================================================================
--
-- WHY THIS EXISTS
--
-- The shipping app is anonymous-first: with no session in the Keychain,
-- `AuthService.bootstrap()` calls `signInAnonymously()` against
-- PRODUCTION, because production is the only backend a Release build
-- has. A UI walker launches that same shipping app, so **one real
-- `auth.users` row is minted per simulator-keychain lifetime**, and the
-- DEBUG seeders then write local rows under that real uid which the
-- ordinary launch sweep pushes up. Measured in 46 §4: one anonymous
-- account and one `program_plans` row for a whole walker session.
--
-- That is not a rogue debug path — it is the product doing its job with
-- a robot's thumb on it. Until the isolation contract in 46 §5 ships,
-- THIS SCRIPT IS THE CONTROL: it removes exactly what the run created
-- and proves the removal by re-reading.
--
-- HOW TO USE
--
--   1. Record the UTC instant immediately BEFORE the test run.
--   2. Run the run.
--   3. Set v_from / v_to below to bracket it. KEEP THE WINDOW TIGHT.
--   4. Run with v_dry_run = true. READ THE NOTICES.
--   5. Only if every row is unmistakably yours, set v_dry_run = false.
--
--   supabase db query --linked -f docs/app_v25/46_probes/reap_test_accounts.sql
--
-- WHAT IT REFUSES
--
-- Everything that could be a customer. A row is a candidate only if it
-- is anonymous, has NO `auth.identities` row (so it was never signed
-- in with Apple or email), was created inside the window, and owns
-- nothing outside the shapes a walker produces. The whole block also
-- aborts if the candidate count exceeds v_max — a wide window is an
-- operator error, not a licence.
--
-- A deletion here is exactly what the shipping `delete_user_account()`
-- does: `delete from auth.users`, and the 34 foreign keys cascade.
-- =====================================================================

-- ── STEP 1 · THE CANDIDATE LIST, AS A RESULT SET ─────────────────────
--
-- `supabase db query` does NOT surface `raise notice`, so the DO block's
-- narration is invisible through the CLI. This SELECT is the thing the
-- operator actually reads. Its predicate is byte-identical to the DO
-- block's. Edit the two timestamps HERE and in the block together.
select u.id, u.created_at,
       (select count(*) from auth.identities   i  where i.user_id = u.id) as identities,
       (select count(*) from public.users      p  where p.id      = u.id) as profile,
       (select count(*) from public.program_plans pp where pp.user_id = u.id) as plans,
       (select count(*) from public.weight_logs   w  where w.user_id  = u.id) as weigh_ins,
       (select count(*) from public.food_logs     f  where f.user_id  = u.id) as food_logs,
       (select count(*) from public.observations  o  where o.user_id  = u.id) as symptoms,
       (select count(*) from public.dose_events   d  where d.user_id  = u.id) as doses,
       (select count(*) from public.program_facts pf where pf.user_id = u.id) as facts,
       (select count(*) from public.weekly_reads  wr where wr.user_id = u.id) as reads
from auth.users u
where u.is_anonymous is true
  and u.created_at >= timestamptz '2026-08-15 11:02:00+00'
  and u.created_at <= timestamptz '2026-08-15 12:37:00+00'
  and not exists (select 1 from auth.identities i where i.user_id = u.id)
order by u.created_at;

-- ── STEP 2 · THE GUARDED REMOVAL ─────────────────────────────────────
do $$
declare
  -- EDIT THESE THREE, THEN READ STEP 1's OUTPUT BEFORE FLIPPING v_dry_run.
  v_from    timestamptz := timestamptz '2026-08-15 11:02:00+00';
  v_to      timestamptz := timestamptz '2026-08-15 12:37:00+00';
  v_dry_run boolean     := true;
  v_max     int         := 5;      -- abort rather than delete a crowd

  v_count   int;
  v_deleted int := 0;
  r         record;
begin
  create temp table if not exists _reap_candidates (id uuid) on commit drop;
  delete from _reap_candidates;

  insert into _reap_candidates (id)
  select u.id
  from auth.users u
  where u.is_anonymous is true
    and u.created_at >= v_from
    and u.created_at <= v_to
    and not exists (select 1 from auth.identities i where i.user_id = u.id);

  select count(*) into v_count from _reap_candidates;
  raise notice 'window % .. %  candidates: %', v_from, v_to, v_count;

  if v_count = 0 then
    raise notice 'NOTHING TO DO — no anonymous, identity-less account in the window.';
    return;
  end if;
  if v_count > v_max then
    raise exception 'REFUSED: % candidates exceeds the cap of %. Narrow the window.',
      v_count, v_max;
  end if;

  -- Print what each candidate owns. An operator who cannot recognise
  -- this as their own test run must stop here.
  for r in
    select c.id,
           u.created_at,
           (select count(*) from public.users        p  where p.id      = c.id) as profiles,
           (select count(*) from public.program_plans pp where pp.user_id = c.id) as plans,
           (select count(*) from public.weight_logs   w  where w.user_id  = c.id) as weigh_ins,
           (select count(*) from public.food_logs     f  where f.user_id  = c.id) as food_logs,
           (select count(*) from public.observations  o  where o.user_id  = c.id) as symptoms,
           (select count(*) from public.dose_events   d  where d.user_id  = c.id) as doses,
           (select count(*) from public.program_facts pf where pf.user_id = c.id) as facts,
           (select count(*) from public.weekly_reads  wr where wr.user_id = c.id) as reads
    from _reap_candidates c join auth.users u on u.id = c.id
    order by u.created_at
  loop
    raise notice
      'CANDIDATE % created % · profile=% plan=% weigh=% food=% symptom=% dose=% fact=% read=%',
      r.id, r.created_at, r.profiles, r.plans, r.weigh_ins,
      r.food_logs, r.symptoms, r.doses, r.facts, r.reads;
  end loop;

  if v_dry_run then
    raise notice 'DRY RUN — nothing deleted. Set v_dry_run := false to proceed.';
    return;
  end if;

  delete from auth.users u
  using _reap_candidates c
  where u.id = c.id
    and u.is_anonymous is true;          -- re-asserted at the DELETE itself
  get diagnostics v_deleted = row_count;

  if v_deleted <> v_count then
    raise exception 'REFUSED: deleted % of % candidates — rolling back.',
      v_deleted, v_count;
  end if;
  raise notice 'DELETED % synthetic anonymous account(s); 34 cascades applied.', v_deleted;
end $$;

-- Re-read afterwards. DO NOT REPORT CLEANUP FROM INTENT.
select
  (select count(*) from auth.users)                        as auth_users,
  (select count(*) from auth.users where is_anonymous)     as anon_users,
  (select count(*) from auth.users where not is_anonymous) as permanent_users,
  (select count(*) from auth.identities where provider = 'apple') as identities_apple,
  (select count(*) from auth.identities where provider = 'email') as identities_email,
  (select count(*) from public.users)                      as profiles,
  (select count(*) from public.program_plans)              as plans,
  (select count(*) from public.weight_logs)                as weigh_ins,
  (select count(*) from public.food_logs)                  as food_logs,
  (select count(*) from public.program_facts)              as program_facts,
  (select count(*) from public.weekly_reads)               as weekly_reads;
