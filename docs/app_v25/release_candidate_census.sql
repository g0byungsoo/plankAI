-- =====================================================================
-- PASS 44 · THE RELEASE-CANDIDATE CENSUS
-- =====================================================================
--
-- READ ONLY. Every statement is a SELECT. There is no insert, update,
-- delete, truncate, copy, grant, alter, create, drop, call, do or
-- refresh anywhere in this file, and no function is invoked that could
-- write (the only functions called are pg_catalog introspection and
-- aggregates). Proven mechanically before execution — see
-- `44_WOULD_I_SHIP_THIS_TO_10000_PEOPLE.md` §PRODUCTION CENSUS.
--
-- COUNTS AND BOUNDS ONLY. No email, no name, no Apple subject, no
-- health payload, no free text, no token, no uid.
--
-- Every question here exists because it can CHANGE THE RELEASE
-- DECISION. Nothing is asked out of curiosity.
--
--   Q1  STORAGE            does `food-photos` exist? (gates whether the
--                          plate-photo backup is a broken client or a
--                          broken bucket, and whether creating it would
--                          leave photos behind after account deletion)
--   Q2  DELETION           every FK into auth.users and its delete
--                          action + every user_id column with no FK at
--                          all (the "delete my account" contract)
--   Q3  ORPHAN-CAPABLE     do the no-FK tables actually hold rows today
--   Q4  AUTHORIZATION      the SECURITY DEFINER surface: search_path,
--                          EXECUTE grants, anon reachability
--   Q5  HANDOFF            is anything stranded open or expired
--   Q6  DRIFT              account totals against `43`'s baseline
--   Q7  LIVE PLANS         accounts holding more than one live plan
--                          (the population `43`'s P0 creates)
--   Q8  MISSING FACTS      profiles with no height / no goal, and the
--                          two columns `35` found with zero writers
--   Q9  GRANTS             can `authenticated` actually SELECT the two
--                          families `43` said 42501 on every sign-in
--  Q10  FOOD DOORS         photo-door plates, which bound the failing
--                          upload queue on a real device
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q1 · STORAGE
-- ---------------------------------------------------------------------
select 'Q1 bucket' as q,
       b.id as k,
       (select count(*) from storage.objects o where o.bucket_id = b.id)::text as v
  from storage.buckets b
union all
select 'Q1 bucket', '(total objects, all buckets)', (select count(*)::text from storage.objects)

-- ---------------------------------------------------------------------
-- Q2 · THE DELETION CONTRACT
-- ---------------------------------------------------------------------
union all
select 'Q2 fk->auth.users',
       c.conrelid::regclass::text || '(' ||
         (select string_agg(a.attname, ',')
            from unnest(c.conkey) k
            join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k) || ')',
       case c.confdeltype
         when 'a' then 'NO ACTION' when 'r' then 'RESTRICT'
         when 'c' then 'CASCADE'   when 'n' then 'SET NULL'
         when 'd' then 'SET DEFAULT' else c.confdeltype::text end
  from pg_constraint c
 where c.contype = 'f' and c.confrelid = 'auth.users'::regclass
union all
select 'Q2 user_id WITHOUT fk',
       c.relnamespace::regnamespace::text || '.' || c.relname,
       'no cascade — survives account deletion'
  from pg_class c
  join pg_attribute a
    on a.attrelid = c.oid and a.attname = 'user_id'
   and a.attnum > 0 and not a.attisdropped
 where c.relkind = 'r'
   and c.relnamespace::regnamespace::text in ('public', 'private')
   and not exists (
        select 1 from pg_constraint k
         where k.contype = 'f' and k.conrelid = c.oid
           and k.confrelid = 'auth.users'::regclass
           and a.attnum = any(k.conkey))

-- ---------------------------------------------------------------------
-- Q3 · DO THE ORPHAN-CAPABLE TABLES HOLD ANYTHING TODAY
-- ---------------------------------------------------------------------
union all
select 'Q3 orphan-capable', 'care_weekly_summaries rows',
       (select count(*)::text from public.care_weekly_summaries)
union all
select 'Q3 orphan-capable', 'care_weekly_summaries already orphaned',
       (select count(*)::text from public.care_weekly_summaries s
         where not exists (select 1 from auth.users u where u.id = s.user_id))
union all
select 'Q3 orphan-capable', 'food_vision_telemetry rows / de-identified',
       (select count(*)::text || ' / ' ||
               count(*) filter (where user_id is null)::text
          from public.food_vision_telemetry)
union all
select 'Q3 orphan-capable', 'jeni_chat_telemetry rows / de-identified',
       (select count(*)::text || ' / ' ||
               count(*) filter (where user_id is null)::text
          from public.jeni_chat_telemetry)

-- ---------------------------------------------------------------------
-- Q4 · THE AUTHORIZATION SURFACE
-- ---------------------------------------------------------------------
union all
select 'Q4 secdef',
       p.oid::regprocedure::text,
       'owner=' || pg_get_userbyid(p.proowner) ||
       ' cfg='  || coalesce(array_to_string(p.proconfig, ','), 'NONE') ||
       ' acl='  || coalesce(array_to_string(p.proacl::text[], ' '), 'PUBLIC')
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where p.prosecdef
   and n.nspname in ('public', 'private')
   and (p.proconfig is null
        or not ('search_path=""' = any(p.proconfig))
        or coalesce(array_to_string(p.proacl::text[], ' '), 'PUBLIC') like '%anon%'
        or p.proacl is null)

-- ---------------------------------------------------------------------
-- Q5 · HANDOFF RECEIPTS
-- ---------------------------------------------------------------------
union all
select 'Q5 handoff', 'total / open / completed / expired-open',
       (select count(*)::text || ' / ' ||
               count(*) filter (where state = 'open')::text || ' / ' ||
               count(*) filter (where state = 'completed')::text || ' / ' ||
               count(*) filter (where state = 'open' and expires_at <= now())::text
          from public.account_handoffs)
union all
select 'Q5 handoff', 'open receipts still naming a live source',
       (select count(*)::text from public.account_handoffs h
         where h.state = 'open' and h.source_user_id is not null)
union all
select 'Q5 handoff', 'completed still holding a subject digest',
       (select count(*)::text from public.account_handoffs
         where state = 'completed' and subject_hash is not null)

-- ---------------------------------------------------------------------
-- Q6 · DRIFT AGAINST `43`'s BASELINE (4293 / 3426 / 867)
-- ---------------------------------------------------------------------
union all
select 'Q6 drift', 'auth.users total / anonymous / permanent',
       (select count(*)::text || ' / ' ||
               count(*) filter (where is_anonymous)::text || ' / ' ||
               count(*) filter (where not is_anonymous)::text
          from auth.users)
union all
select 'Q6 drift', 'identities apple / email',
       (select count(*) filter (where provider = 'apple')::text || ' / ' ||
               count(*) filter (where provider = 'email')::text
          from auth.identities)
union all
select 'Q6 drift', 'public.users profile rows',
       (select count(*)::text from public.users)

-- ---------------------------------------------------------------------
-- Q7 · LIVE PLANS — the population `43`'s P0 creates
-- ---------------------------------------------------------------------
union all
select 'Q7 plans', 'accounts holding MORE THAN ONE live plan',
       (select count(*)::text from (
          select user_id from public.program_plans
           where archived_at is null
             and phase in ('active', 'maintenance', 'recomp', 'pause')
           group by user_id having count(*) > 1) t)
union all
select 'Q7 plans', 'accounts holding exactly one live plan',
       (select count(*)::text from (
          select user_id from public.program_plans
           where archived_at is null
             and phase in ('active', 'maintenance', 'recomp', 'pause')
           group by user_id having count(*) = 1) t)
union all
select 'Q7 plans', 'live plans whose goal >= start (maintenance-shaped)',
       (select count(*)::text from public.program_plans
         where archived_at is null
           and phase in ('active', 'maintenance', 'recomp', 'pause')
           and goal_weight_kg is not null and current_weight_kg is not null
           and goal_weight_kg >= current_weight_kg - 0.05)
union all
select 'Q7 plans', 'archived_at set with a LIVE phase (would read live)',
       (select count(*)::text from public.program_plans
         where archived_at is not null
           and phase in ('active', 'maintenance', 'recomp', 'pause'))

-- ---------------------------------------------------------------------
-- Q8 · MISSING FACTS
-- ---------------------------------------------------------------------
union all
select 'Q8 facts', 'permanent profiles: total',
       (select count(*)::text from public.users u
         join auth.users a on a.id = u.id where not a.is_anonymous)
union all
select 'Q8 facts', 'permanent profiles with NO height',
       (select count(*)::text from public.users u
         join auth.users a on a.id = u.id
        where not a.is_anonymous
          and (u.onboarding_height_cm is null or u.onboarding_height_cm <= 100))
union all
select 'Q8 facts', 'permanent profiles with NO goal weight',
       (select count(*)::text from public.users u
         join auth.users a on a.id = u.id
        where not a.is_anonymous
          and (u.onboarding_goal_weight_kg is null or u.onboarding_goal_weight_kg <= 30))
union all
select 'Q8 facts', 'users.program_mode non-null',
       (select count(*)::text from public.users
         where program_mode is not null)
union all
select 'Q8 facts', 'users.goal_direction non-null',
       (select count(*)::text from public.users
         where goal_direction is not null)

-- ---------------------------------------------------------------------
-- Q9 · GRANTS — `43` named a 42501 on every sign-in, for everyone
-- ---------------------------------------------------------------------
union all
select 'Q9 grant', 'authenticated SELECT ' || t.tab,
       has_table_privilege('authenticated', t.tab, 'SELECT')::text
  from (values ('public.program_facts'), ('public.weekly_reads'),
               ('public.observations'),  ('public.dose_events'),
               ('public.day_reflections'), ('public.consent_grants'),
               ('public.food_logs'), ('public.weight_logs'),
               ('public.program_plans')) as t(tab)
union all
select 'Q9 grant', 'rls enabled ' || c.relnamespace::regnamespace::text || '.' || c.relname,
       c.relrowsecurity::text || ' policies=' ||
       (select count(*)::text from pg_policies p
         where p.schemaname = c.relnamespace::regnamespace::text
           and p.tablename = c.relname)
  from pg_class c
 where c.relkind = 'r'
   and c.relnamespace = 'public'::regnamespace
   and c.relname in ('program_facts', 'weekly_reads', 'account_handoffs',
                     'care_weekly_summaries')

-- ---------------------------------------------------------------------
-- Q10 · FOOD DOORS — bounds the failing photo-upload queue on a device
-- ---------------------------------------------------------------------
union all
select 'Q10 food', 'logs by door: ' || coalesce(source, '(null)'),
       count(*)::text
  from public.food_logs group by source
union all
select 'Q10 food', 'photo-door plates since the backup seam (2026-07-25)',
       (select count(*)::text from public.food_logs
         where source in ('photo', 'label', 'barcode')
           and logged_at >= timestamptz '2026-07-25')
union all
select 'Q10 food', 'largest photo-door queue one customer would carry',
       (select coalesce(max(c), 0)::text from (
          select count(*) c from public.food_logs
           where source in ('photo', 'label', 'barcode')
             and logged_at >= timestamptz '2026-07-25'
           group by user_id) t)

order by 1, 2;
