-- PASS 43 · P4 — does the SERVER hold the destination's body facts?
-- READ ONLY, PRESENCE ONLY: booleans and a name, never a value. No
-- weight, height, goal, sex value or clinical answer leaves the database.
with b as (select '280CAA8E-B635-49B7-8BF1-CA725F71798A'::uuid as id)
select 'has_row'                    as k, (select count(*)::text from public.users t, b where t.id=b.id) as v
union all select 'height_cm_present',        (select (t.onboarding_height_cm is not null)::text from public.users t, b where t.id=b.id)
union all select 'current_weight_present',   (select (t.onboarding_current_weight_kg is not null)::text from public.users t, b where t.id=b.id)
union all select 'goal_weight_present',      (select (t.onboarding_goal_weight_kg is not null)::text from public.users t, b where t.id=b.id)
union all select 'gender_present',           (select (coalesce(t.onboarding_gender,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'activity_present',         (select (coalesce(t.onboarding_activity_level,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'age_range_present',        (select (coalesce(t.onboarding_age_range,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'commitment_days_present',  (select (t.onboarding_commitment_days_per_week is not null)::text from public.users t, b where t.id=b.id)
union all select 'glp1_status_present',      (select (coalesce(t.onboarding_glp1_status,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'glp1_phase_present',       (select (coalesce(t.onboarding_glp1_phase,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'hormonal_present',         (select (coalesce(t.onboarding_hormonal_stage,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'sleep_present',            (select (coalesce(t.onboarding_sleep_hours,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'stress_present',           (select (coalesce(t.onboarding_stress_level,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'weight_trend_present',     (select (coalesce(t.onboarding_weight_trend,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'food_relationship_present',(select (coalesce(t.onboarding_food_relationship,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'program_mode_present',     (select (coalesce(t.program_mode,'') <> '')::text from public.users t, b where t.id=b.id)
union all select 'goal_direction_present',   (select (coalesce(t.goal_direction,'') <> '')::text from public.users t, b where t.id=b.id)
-- and the same three body facts across the whole permanent population
union all select 'permanent_with_height',    (select count(*)::text from public.users t join auth.users u on u.id=t.id where not u.is_anonymous and t.onboarding_height_cm is not null)
union all select 'permanent_with_goal',      (select count(*)::text from public.users t join auth.users u on u.id=t.id where not u.is_anonymous and t.onboarding_goal_weight_kg is not null)
union all select 'permanent_profiles_total', (select count(*)::text from public.users t join auth.users u on u.id=t.id where not u.is_anonymous)
;
