-- ============================================================
-- JENI PRODUCTION STATE CENSUS  ·  2026-08-14
-- ============================================================
-- READ ONLY. Two tables. SELECT only — no INSERT / UPDATE / DELETE /
-- CREATE / ALTER / GRANT anywhere in this file. No emails. No PII beyond
-- the account UUIDs in the OPTIONAL second query, which is commented out
-- by default.
--
-- The "live plan" definition is IDENTICAL to the client's
-- (`ProgramService.activePlan` / `AppSync.reconcileLivePlans` as of
-- 2026-08-14): phase in the four live values, archived_at is null, and
-- when several qualify, the EARLIEST start_date wins.
--
-- Caveat, stated rather than hidden: `is_test_user` is a PostHog person
-- property, not a users column, so this counts internal accounts too.
-- Subtract known internal ids before acting on a small number.
-- ============================================================

with live as (
  select user_id, count(*) as live_count
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  group by user_id
),
chosen as (
  select distinct on (user_id)
         user_id,
         id                 as plan_id,
         goal_weight_kg     as plan_goal,
         current_weight_kg  as plan_start,
         total_days,
         phase
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  order by user_id, start_date asc, started_at asc
),
base as (
  select u.id                           as user_id,
         u.onboarding_goal_weight_kg    as profile_goal,
         u.onboarding_current_weight_kg as profile_weight,
         u.onboarding_height_cm         as profile_height,
         coalesce(l.live_count, 0)      as live_count,
         c.plan_goal, c.plan_start, c.total_days
  from public.users u
  left join live   l on l.user_id = u.id
  left join chosen c on c.user_id = u.id
),
t as (
  select count(*)                               as onboarded,
         count(*) filter (where live_count > 0) as with_plan
  from base
),
rows as (
  select 1 as ord, 'onboarded accounts (denominator)' as state,
         (select onboarded from t) as users, (select onboarded from t) as denom
  union all select 2, 'with a live plan',
         (select with_plan from t), (select onboarded from t)
  union all select 3, 'HEALTHY loss plan (goal < start, >= 7 days)',
         (select count(*) from base
           where plan_goal is not null and plan_start is not null
             and plan_start > plan_goal + 0.05 and total_days >= 7),
         (select with_plan from t)
  union all select 4, 'goal == start (THE FABRICATION)',
         (select count(*) from base
           where plan_goal is not null and plan_start is not null
             and abs(plan_goal - plan_start) < 0.05),
         (select with_plan from t)
  union all select 5, 'plan goal ABOVE start (aims above her)',
         (select count(*) from base
           where plan_goal is not null and plan_start is not null
             and plan_goal > plan_start + 0.05),
         (select with_plan from t)
  union all select 6, 'plan goal IS NULL',
         (select count(*) from base where live_count > 0 and plan_goal is null),
         (select with_plan from t)
  union all select 7, 'profile goal missing',
         (select count(*) from base where coalesce(profile_goal, 0) <= 30),
         (select onboarded from t)
  union all select 8, 'profile / plan goal DISAGREE (> 0.5 kg)',
         (select count(*) from base
           where profile_goal is not null and plan_goal is not null
             and abs(profile_goal - plan_goal) > 0.5),
         (select with_plan from t)
  union all select 9, 'profile height missing',
         (select count(*) from base where coalesce(profile_height, 0) <= 100),
         (select onboarded from t)
  union all select 10, 'profile current weight missing',
         (select count(*) from base where coalesce(profile_weight, 0) <= 30),
         (select onboarded from t)
  union all select 11, 'MULTIPLE live plans',
         (select count(*) from base where live_count > 1),
         (select onboarded from t)
  union all select 12, 'NO live plan despite onboarding',
         (select count(*) from base where live_count = 0),
         (select onboarded from t)
  union all select 13, 'maintenance-SHAPED plan for a loss-shaped profile',
         (select count(*) from base
           where plan_goal is not null and plan_start is not null
             and abs(plan_goal - plan_start) < 0.05
             and profile_goal is not null and profile_weight is not null
             and profile_weight > profile_goal + 0.05),
         (select with_plan from t)
  union all select 14, 'plan duration invalid (< 7 days)',
         (select count(*) from base where live_count > 0 and total_days < 7),
         (select with_plan from t)
  union all select 15, 'archived_at set while phase still live',
         (select count(*) from public.program_plans
           where archived_at is not null
             and phase in ('active','maintenance','recomp','pause')),
         (select onboarded from t)
)
select state,
       users,
       round(100.0 * users / nullif(denom, 0), 2) as pct
from rows
order by ord;


-- ============================================================
-- OPTIONAL DIAGNOSTIC — ids only, no emails.
-- Uncomment, set :state to one of the labels below, and run.
--   'fabricated'  goal == start
--   'disagree'    profile goal != plan goal
--   'above'       plan goal above start
--   'multiple'    more than one live plan
--   'noplan'      onboarded, no live plan
-- ============================================================
--
-- with param as (select 'fabricated'::text as state),
-- live as (
--   select user_id, count(*) as live_count
--   from public.program_plans
--   where phase in ('active','maintenance','recomp','pause')
--     and archived_at is null
--   group by user_id
-- ),
-- chosen as (
--   select distinct on (user_id)
--          user_id, id as plan_id, goal_weight_kg, current_weight_kg,
--          total_days, start_date
--   from public.program_plans
--   where phase in ('active','maintenance','recomp','pause')
--     and archived_at is null
--   order by user_id, start_date asc, started_at asc
-- )
-- select u.id as user_id, c.plan_id, c.goal_weight_kg, c.current_weight_kg,
--        c.total_days, c.start_date,
--        u.onboarding_goal_weight_kg as profile_goal,
--        coalesce(l.live_count, 0)   as live_plans
-- from public.users u
-- left join live   l on l.user_id = u.id
-- left join chosen c on c.user_id = u.id
-- cross join param p
-- where case p.state
--   when 'fabricated' then c.goal_weight_kg is not null
--                      and c.current_weight_kg is not null
--                      and abs(c.goal_weight_kg - c.current_weight_kg) < 0.05
--   when 'disagree'   then u.onboarding_goal_weight_kg is not null
--                      and c.goal_weight_kg is not null
--                      and abs(u.onboarding_goal_weight_kg - c.goal_weight_kg) > 0.5
--   when 'above'      then c.goal_weight_kg is not null
--                      and c.current_weight_kg is not null
--                      and c.goal_weight_kg > c.current_weight_kg + 0.05
--   when 'multiple'   then coalesce(l.live_count, 0) > 1
--   when 'noplan'     then coalesce(l.live_count, 0) = 0
--   else false
-- end
-- order by c.start_date desc nulls last;
