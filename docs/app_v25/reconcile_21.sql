-- ============================================================
-- JENI · CLASSIFY THE 21 DISAGREEING ACCOUNTS  ·  2026-08-14
-- ============================================================
-- READ ONLY. Paste whole, run, read, roll back.
--
-- The census (docs/app_v25/census.sql, row 8) counted 21 accounts whose
-- profile goal and plan goal disagree by more than 0.5 kg. It returns a
-- COUNT. This returns one labelled row per account so the population can
-- be understood without acting on it.
--
-- NOTHING IN THIS FILE WRITES. Every write-shaped keyword Postgres
-- knows is absent from it, in any casing, in code AND in comments — so a
-- naive grep over this file comes back clean, deliberately. It is
-- wrapped in BEGIN READ ONLY / ROLLBACK so Postgres itself refuses a
-- write even if one were introduced by a copy-paste accident.
--
-- No emails. No names. No auth metadata. Account UUIDs only, and only
-- because row identity is what the first query is for; the aggregate at
-- the bottom returns no identifiers at all.
--
-- THE THRESHOLD IS THE CLIENT'S OWN. `TargetsService.planAgreesWithHer`
-- uses `abs(stored - plan_goal) <= 0.5`, so `> 0.5` here is a byte-exact
-- count of the accounts for which the next build ignores the plan's goal
-- and prices her own answer instead.
--
-- CAVEAT, STATED: `is_test_user` is a PostHog person property, not a
-- users column, so internal accounts are included. Subtract known
-- internal ids before acting on a small number.
--
-- WHAT TO DO WITH THE RESULT: nothing, in the database. Category B must
-- never be written to under any circumstances — a `goal == start` plan is
-- ambiguous between a clinical instruction to hold and a goal the old
-- build lost, and a bulk repair would put a pregnant or eating-pattern-
-- screened user back on a deficit. The next build reaches 18-21 of these
-- accounts with no write at all (see §7 of
-- docs/app_v25/35_THE_SAFETY_ANSWER_MUST_SURVIVE_THE_ACCOUNT.md).
-- ============================================================

BEGIN READ ONLY;

-- ------------------------------------------------------------
-- 1 · ONE LABELLED ROW PER DISAGREEING ACCOUNT
-- ------------------------------------------------------------
-- The "live plan" definition is IDENTICAL to the client's
-- (`ProgramService.activePlan` / `AppSync.reconcileLivePlans`): the four
-- live phase values, `archived_at is null`, and when several qualify the
-- EARLIEST start_date wins, `started_at` breaking a same-day tie.
with live as (
  select distinct on (user_id)
         user_id, id as plan_id, phase, start_date, started_at,
         goal_weight_kg, current_weight_kg, total_days, intensity_tier
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  order by user_id, start_date asc, started_at asc
),
latest as (
  select distinct on (user_id) user_id, weight_kg, logged_at
  from public.weight_logs
  order by user_id, logged_at desc
),
labelled as (
  select
    p.user_id,
    p.plan_id,
    p.phase,
    (current_date - p.start_date)                        as plan_age_days,
    p.total_days,
    p.intensity_tier,
    u.onboarding_current_weight_kg                       as signup_kg,
    w.weight_kg                                          as latest_kg,
    w.logged_at                                          as latest_at,
    u.onboarding_goal_weight_kg                          as profile_goal_kg,
    p.current_weight_kg                                  as plan_start_kg,
    p.goal_weight_kg                                     as plan_goal_kg,
    round((p.goal_weight_kg - u.onboarding_goal_weight_kg)::numeric, 2) as gap_kg,
    u.onboarding_height_cm                               as height_cm,
    case when coalesce(u.onboarding_height_cm, 0) > 100
         then round((18.5 * power(u.onboarding_height_cm / 100.0, 2))::numeric, 2)
    end                                                  as bmi185_kg,
    case
      -- A · the plan correctly holds because she ARRIVED. The profile
      --     goal is the older intent. Nothing to repair.
      when abs(p.goal_weight_kg - p.current_weight_kg) < 0.05
           and w.weight_kg is not null
           and w.weight_kg <= u.onboarding_goal_weight_kg + 0.5
        then 'A · ARRIVED — plan correctly holds'
      -- B · goal == start and she has not arrived. EITHER the safety
      --     gate's zero-deficit instruction (pregnancy / eating-pattern
      --     screen / BMI < 18.5, written by
      --     `ProgramSetupSubflow.safetyAdjustedGoalWeightKg`) OR the
      --     2026-08-13 fabrication. Server-side these are IDENTICAL.
      when abs(p.goal_weight_kg - p.current_weight_kg) < 0.05
        then 'B · HOLD-vs-LOSE — safety cap OR fabrication. DO NOT TOUCH'
      -- C · the plan aims at the lowest healthy weight for her height,
      --     a number she never chose (`29` §2②).
      when coalesce(u.onboarding_height_cm, 0) > 100
           and abs(p.goal_weight_kg - 18.5 * power(u.onboarding_height_cm / 100.0, 2)) < 0.5
        then 'C · BMI-18.5 INVENTION'
      -- D · the plan's start weight is the 65 kg default body (`30` §6).
      when abs(p.current_weight_kg - 65.0) < 0.01
           and abs(coalesce(u.onboarding_current_weight_kg, 0) - 65.0) >= 0.01
        then 'D · 65 kg DEFAULT BODY'
      -- E · the profile goal is the 60 kg default goal (`29` §2③).
      when abs(u.onboarding_goal_weight_kg - 60.0) < 0.01
        then 'E · 60 kg DEFAULT GOAL'
      -- F/G · both are real loss destinations that simply disagree; she
      --     changed her mind and the plan never followed.
      when p.goal_weight_kg < u.onboarding_goal_weight_kg
        then 'F · PLAN AIMS LOWER than she asked'
      else 'G · PLAN AIMS HIGHER than she asked'
    end as classification,
    -- The client rule this session added, evaluated here so the two can
    -- be compared: a `goal == start` plan whose PROFILE is loss-shaped is
    -- the state in which the next build refuses a deficit and asks
    -- ("losing or holding?"). This predicate is byte-identical to
    -- `TargetsService.planHoldsWithUnknownDirection`'s stored-goal half.
    (abs(p.goal_weight_kg - p.current_weight_kg) < 0.05
     and coalesce(u.onboarding_goal_weight_kg, 0) > 30
     and coalesce(u.onboarding_current_weight_kg, 0)
         > coalesce(u.onboarding_goal_weight_kg, 0) + 0.01) as client_will_ask
  from live p
  join public.users u on u.id = p.user_id
  left join latest w on w.user_id = p.user_id
  where u.onboarding_goal_weight_kg is not null
    and p.goal_weight_kg is not null
    and abs(u.onboarding_goal_weight_kg - p.goal_weight_kg) > 0.5
)
select * from labelled
order by classification, gap_kg desc;

-- ------------------------------------------------------------
-- 2 · THE COMPACT AGGREGATE — classification | users
-- ------------------------------------------------------------
-- The same population, counted, so the shape is legible without
-- reading UUIDs. Returns no identifiers.
with live as (
  select distinct on (user_id)
         user_id, goal_weight_kg, current_weight_kg
  from public.program_plans
  where phase in ('active','maintenance','recomp','pause')
    and archived_at is null
  order by user_id, start_date asc, started_at asc
),
latest as (
  select distinct on (user_id) user_id, weight_kg
  from public.weight_logs
  order by user_id, logged_at desc
),
labelled as (
  select
    case
      when abs(p.goal_weight_kg - p.current_weight_kg) < 0.05
           and w.weight_kg is not null
           and w.weight_kg <= u.onboarding_goal_weight_kg + 0.5
        then 'A · ARRIVED — plan correctly holds'
      when abs(p.goal_weight_kg - p.current_weight_kg) < 0.05
        then 'B · HOLD-vs-LOSE — safety cap OR fabrication. DO NOT TOUCH'
      when coalesce(u.onboarding_height_cm, 0) > 100
           and abs(p.goal_weight_kg - 18.5 * power(u.onboarding_height_cm / 100.0, 2)) < 0.5
        then 'C · BMI-18.5 INVENTION'
      when abs(p.current_weight_kg - 65.0) < 0.01
           and abs(coalesce(u.onboarding_current_weight_kg, 0) - 65.0) >= 0.01
        then 'D · 65 kg DEFAULT BODY'
      when abs(u.onboarding_goal_weight_kg - 60.0) < 0.01
        then 'E · 60 kg DEFAULT GOAL'
      when p.goal_weight_kg < u.onboarding_goal_weight_kg
        then 'F · PLAN AIMS LOWER than she asked'
      else 'G · PLAN AIMS HIGHER than she asked'
    end as classification
  from live p
  join public.users u on u.id = p.user_id
  left join latest w on w.user_id = p.user_id
  where u.onboarding_goal_weight_kg is not null
    and p.goal_weight_kg is not null
    and abs(u.onboarding_goal_weight_kg - p.goal_weight_kg) > 0.5
)
select classification, count(*) as users
from labelled
group by classification
order by users desc, classification;

ROLLBACK;
