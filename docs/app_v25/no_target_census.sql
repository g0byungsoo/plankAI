-- ============================================================
-- JENI · HOW MANY LIVE-PLAN ACCOUNTS OPEN THE CANDIDATE WITH
--        NO CALORIE TARGET?                     ·  2026-08-14
-- ============================================================
-- READ ONLY. Paste whole, run, read, roll back.
--
-- NOTHING IN THIS FILE WRITES. Every write-shaped keyword Postgres
-- knows is absent from it, in any casing, in code AND in comments — so a
-- naive grep over this file comes back clean, deliberately. It is
-- wrapped in BEGIN READ ONLY /
-- ROLLBACK so Postgres refuses a write even if one were introduced by a
-- copy-paste accident. It returns COUNTS ONLY — no UUIDs, no emails, no
-- names, no auth metadata.
--
-- ============================================================
-- WHY THIS FILE REPLACES THE QUERY FROM THE PREVIOUS SESSION
-- ============================================================
-- That query was:
--
--   plan_goal >= plan_start - 0.05
--   AND (profile_goal <= 30 OR profile_weight <= profile_goal + 0.01)
--
-- It reproduced the decision tree of the build as it stood that hour:
-- rule 2 cannot fire on a plan that is not a real loss plan, rule 3
-- cannot fire without a usable stored loss goal, so the basis is
-- `.unknown` and no number is published.
--
-- **It is now a strict UNDER-count.** This session added a rule
-- (`TargetsService.planHoldsWithUnknownDirection`): a live plan whose
-- goal is not below its start weight, held by an account whose PROFILE
-- is loss-shaped, publishes no number either — when the device cannot
-- say whether the hold was asked for. The old query excludes exactly
-- that population, because it requires the stored goal to be missing.
--
-- Re-derived below from the candidate's own resolution order rather than
-- carried forward.
--
-- ============================================================
-- WHAT SQL CAN AND CANNOT KNOW
-- ============================================================
-- `TargetsService.calorieTarget` returns nil in three places:
--
--   1. no resolvable weight        (weight_logs › users.onboarding_* › plan.current_weight_kg)
--   2. height <= 100 cm            (users.onboarding_height_cm)
--   3. `energyBasis == .unknown`
--
-- (1) and (2) are decided BEFORE the basis is consulted, so they hold
-- under every possible local state. **They are the lower bound.**
--
-- (3) depends on four `@AppStorage` keys that have NO COLUMN on
-- `public.users` and are swept on sign-out:
--
--   program_mode · onboarding_goal_direction · safety_pace_cap ·
--   safety_numeric_suppression
--
-- If `program_mode = 'maintenance'` is on the device, the basis is
-- `.maintenance` and she gets a REAL NUMBER. If the two direction keys
-- are absent and her plan holds, she gets NO number and the app asks.
-- The same server row therefore produces either outcome depending on a
-- fact the server has never been told. **That is the unknown dimension,
-- and it is exactly the defect this session's record is about.**
--
-- A fifth unknowable, stated so it is not mistaken for a defect:
-- `safety_numeric_suppression` also withholds the calorie numeral, and
-- when it does that is the product working as designed, not an account
-- opening to a missing number.
--
-- DO NOT turn an unknowable local fact into a precise production count.
-- Read the three numbers below as a range and a caveat, never as one
-- figure.
--
-- CAVEAT, STATED: `is_test_user` is a PostHog person property, not a
-- users column, so internal accounts are included.
-- ============================================================

BEGIN READ ONLY;

with live as (
  -- The client's own rule: the four live phases, not archived, earliest
  -- start_date wins, `started_at` breaking a same-day tie.
  select distinct on (user_id)
         user_id, goal_weight_kg, current_weight_kg, total_days
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
acct as (
  select
    p.user_id,
    -- THE ONE WEIGHT LADDER (`TargetsService.resolvedWeightKg`):
    -- freshest weigh-in › her own stored answer › the plan's start
    -- weight, last.
    coalesce(w.weight_kg,
             nullif(u.onboarding_current_weight_kg, 0),
             p.current_weight_kg)                       as resolved_kg,
    u.onboarding_height_cm                              as height_cm,
    u.onboarding_goal_weight_kg                         as profile_goal_kg,
    u.onboarding_current_weight_kg                      as profile_start_kg,
    p.goal_weight_kg                                    as plan_goal_kg,
    p.current_weight_kg                                 as plan_start_kg,
    p.total_days
  from live p
  join public.users u on u.id = p.user_id
  left join latest w on w.user_id = p.user_id
),
flags as (
  select
    user_id,
    -- (1) + (2): decided before the basis, so basis-independent.
    (coalesce(resolved_kg, 0) <= 30)                    as no_weight,
    (coalesce(height_cm, 0) <= 100)                     as no_height,
    -- rule 2: a coherent loss plan that AGREES with her stored answer.
    -- `planAgreesWithHer` compares at 0.5 kg; with no stored goal the
    -- plan may speak only while its goal is below the body in front of
    -- us.
    (plan_goal_kg is not null and plan_start_kg is not null
     and plan_start_kg > plan_goal_kg + 0.05
     and coalesce(total_days, 0) >= 7
     and (
       case when coalesce(profile_goal_kg, 0) > 30
            then abs(profile_goal_kg - plan_goal_kg) <= 0.5
            else coalesce(resolved_kg, 0) > 30 and plan_goal_kg < resolved_kg
       end
     ))                                                 as plan_prices_it,
    -- rule 3: her own onboarding numbers describe a real loss.
    (coalesce(profile_goal_kg, 0) > 30
     and coalesce(profile_start_kg, 0) > coalesce(profile_goal_kg, 0) + 0.01)
                                                        as own_numbers_price_it,
    -- the new rule: the plan states a HOLD and her profile is
    -- loss-shaped, so the two meanings collide and the app asks.
    -- Byte-identical to `planHoldsWithUnknownDirection`'s server-visible
    -- half; its remaining half (`directionIsUnknown`) is the unknown
    -- dimension.
    (plan_goal_kg is not null and plan_start_kg is not null
     and plan_goal_kg >= plan_start_kg - 0.05
     and coalesce(profile_goal_kg, 0) > 30
     and coalesce(profile_start_kg, 0) > coalesce(profile_goal_kg, 0) + 0.01)
                                                        as hold_vs_lose,
    -- arrival: the goal was a real loss destination when it was set and
    -- she has reached it. Publishes maintenance — a REAL number.
    (coalesce(profile_goal_kg, 0) > 30
     and coalesce(profile_start_kg, 0) > coalesce(profile_goal_kg, 0) + 0.01
     and coalesce(resolved_kg, 0) > 30
     and resolved_kg <= profile_goal_kg + 0.01)         as arrived
  from acct
)
select 'live-plan accounts (denominator)'                as measure,
       count(*)                                          as accounts,
       'exact'                                           as certainty
from flags
union all
select 'LOWER BOUND — no target under EVERY local state',
       count(*) filter (where no_weight or no_height),
       'exact — height and weight are read before the basis'
from flags
union all
select 'UPPER BOUND — no target under the WORST local state',
       count(*) filter (
         where no_weight or no_height
            or (not plan_prices_it and not arrived
                and (hold_vs_lose or not own_numbers_price_it))
       ),
       'depends on program_mode / onboarding_goal_direction, which have no column'
from flags
union all
select '  of which: HOLD-vs-LOSE (the app asks "losing or holding?")',
       count(*) filter (where not no_weight and not no_height
                          and not plan_prices_it and not arrived
                          and hold_vs_lose),
       'no number ONLY when the direction keys are absent; a maintenance mode on the device publishes a real number instead'
from flags
union all
select '  of which: no usable goal anywhere (the app asks for a goal)',
       count(*) filter (where not no_weight and not no_height
                          and not plan_prices_it and not arrived
                          and not hold_vs_lose and not own_numbers_price_it),
       'same dependency'
from flags
union all
-- No FROM on purpose: this row is a caveat, not a measurement, and a
-- `select ... from flags` without an aggregate would emit one copy per
-- account.
select 'UNKNOWN DIMENSION — safety_numeric_suppression (device-only)',
       null::bigint,
       'a suppressed cohort is shown no calorie numeral BY DESIGN. Not countable server-side, and not a missing number.';

ROLLBACK;
